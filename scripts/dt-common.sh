#!/usr/bin/env bash
# dt-common.sh — shared helpers for the dev-team scripts.
# Sourced by dt-claim / dt-ready / dt-done / dt-cancel / dt-restart / dt-board.
# Not meant to be run directly.
#
# Coordination model (single source of truth = git):
#   - Task STATUS transitions (available → in-progress → ready-for-pr → pr-open → done)
#     are folder moves committed on `main`. main must NOT be a protected branch.
#   - The CODE for a task lives on `feature/<id>-<slug>` and is developed in a worktree.
#   - The atomic CLAIM LOCK is creating the remote feature branch. If that push loses a
#     race, the task was already claimed — the loser never touches main.
#   - `.dt-index.json` is a derived cache (git-ignored), never a decision authority.

set -euo pipefail

# ── Locate repo root ─────────────────────────────────────────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "[dt] error: not inside a git repository" >&2
  exit 1
fi
DT_CONFIG="$REPO_ROOT/devteam.config.yml"
DT_INDEX="$REPO_ROOT/.dt-index.json"
DT_SCRIPTS="$REPO_ROOT/scripts"

# ── Logging ──────────────────────────────────────────────────────────────────
log()  { echo "[dt] $*"; }
ok()   { echo "[dt] ✓ $*"; }
err()  { echo "[dt] error: $*" >&2; }
die()  { err "$*"; exit 1; }

# ── ID validation ────────────────────────────────────────────────────────────
# Accepts task IDs (T-123) and bug IDs (B-7). Rejects anything else so IDs are
# safe to interpolate into paths and branch names.
validate_id() {
  local id="$1"
  [[ "$id" =~ ^[TB]-[0-9]{1,3}$ ]] || die "invalid id '$id' (expected T-NNN or B-NNN)"
}

# ── Config reader (flat, two-level YAML) ─────────────────────────────────────
# Usage: dt_config section.key [default]   e.g. dt_config workflow.cleanup_merged_branches true
# Returns the value with surrounding quotes and inline comments stripped.
# If the key is absent or null/~, returns the default (second argument, default "").
dt_config() {
  local path="$1" default="${2:-}" section key value
  section="${path%%.*}"
  key="${path#*.}"
  [ -f "$DT_CONFIG" ] || { echo "$default"; return 0; }
  value=$(awk -v s="$section" -v k="$key" '
    $0 ~ "^"s":"            { inb=1; next }
    inb && /^[^[:space:]#]/ { inb=0 }
    inb && $0 ~ "^[[:space:]]+"k":" {
      line=$0
      sub("^[[:space:]]+"k":[[:space:]]*", "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      sub(/[[:space:]]+$/, "", line)
      gsub(/^"|"$/, "", line)
      gsub(/^'"'"'|'"'"'$/, "", line)
      print line
      exit
    }
  ' "$DT_CONFIG")
  if [[ -z "$value" || "$value" == "null" || "$value" == "~" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Project name → drives worktree path `../<name>-<ID>`. Falls back to repo dir name.
dt_project_name() {
  local n; n="$(dt_config project.name)"
  [ -n "$n" ] && { echo "$n"; return; }
  basename "$REPO_ROOT"
}

dt_worktree_path() {
  local name; name="$(dt_project_name | tr ' /' '__')"
  echo "$REPO_ROOT/../${name}-$1"
}

# ── Task file discovery ──────────────────────────────────────────────────────
TASK_FOLDERS=(
  "available"
  "in-progress"
  "ready-for-pr"
  "pr-open"
  "done"
  "blocked"
  "cancelled"
)

# Echo the path of the single task file for ID, optionally restricted to a folder.
find_task_file() {
  local id="$1" only="${2:-}"
  local f
  for folder in "${TASK_FOLDERS[@]}"; do
    [ -n "$only" ] && [ "$folder" != "$only" ] && continue
    for f in "$REPO_ROOT/tasks/$folder/${id}-"*.md "$REPO_ROOT/tasks/$folder/${id}.md"; do
      [ -e "$f" ] && { echo "$f"; return 0; }
    done
  done
  return 1
}

# Read a frontmatter scalar field from a task file (e.g. status, branch, agent).
# Strips surrounding YAML quotes (" and ') and treats ~ as empty/null.
task_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf && $0 ~ "^"f":" {
      line=$0; sub("^"f":[[:space:]]*","",line); sub(/[[:space:]]+$/,"",line)
      gsub(/^"|"$/, "", line)
      gsub(/^'"'"'|'"'"'$/, "", line)
      if (line == "~") line = ""
      print line; exit
    }
  ' "$file"
}

# Read depends_on as space-separated ids (handles "[]", "[T-1, T-2]").
task_depends_on() {
  local file="$1" raw
  raw="$(task_field "$file" depends_on)"
  raw="${raw#[}"; raw="${raw%]}"
  echo "$raw" | tr ',' ' ' | tr -s ' '
}

# Set a frontmatter scalar field in place (portable sed).
# If the field is missing from the frontmatter, inserts it before the closing ---.
set_task_field() {
  local file="$1" field="$2" value="$3"
  # Only touch the first occurrence inside frontmatter.
  # If the field is missing, insert it before the closing ---.
  awk -v f="$field" -v v="$value" '
    NR==1 && $0=="---" { print; inf=1; next }
    inf && $0=="---"   { if (!done) { print f": "v; done=1 } inf=0; print; next }
    inf && !done && $0 ~ "^"f":" { print f": "v; done=1; next }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Branch name for a task: prefer the frontmatter `branch:` field, else derive
# from the filename. T-* → feature/…, B-* → fix/…
task_branch_from_file() {
  local file="$1" b id base
  b="$(task_field "$file" branch)"
  if [ -n "$b" ] && [ "$b" != "~" ]; then echo "$b"; return; fi
  id="$(task_field "$file" id)"
  base="$(basename "$file" .md)"
  case "$id" in B-*) echo "fix/$base" ;; *) echo "feature/$base" ;; esac
}

# True if a task id currently lives in tasks/done/ or tasks/cancelled/.
is_done() {
  find_task_file "$1" done >/dev/null 2>&1 || find_task_file "$1" cancelled >/dev/null 2>&1
}

# ── Remote branch checks ─────────────────────────────────────────────────────
remote_branch_exists() {
  git -C "$REPO_ROOT" ls-remote --exit-code --heads origin "$1" >/dev/null 2>&1
}

# ── Index refresh ────────────────────────────────────────────────────────────
# Called at the end of every mutating script so no command reads a stale board.
refresh_index() {
  if [ -f "$DT_SCRIPTS/dt-board.sh" ]; then
    bash "$DT_SCRIPTS/dt-board.sh" --no-fetch >/dev/null 2>&1 || true
  fi
}

# ── Task validation helpers ──────────────────────────────────────────────────

# Warn if depends_on is not a YAML array ([T-001, T-002]).
validate_depends_on() {
  local file="$1"
  local raw
  raw="$(task_field "$file" depends_on)"
  if [[ -n "$raw" ]] && [[ ! "$raw" =~ ^\[.*\]$ ]]; then
    echo "WARNING: depends_on in $(basename "$file") is not a YAML array. Expected format: [T-001, T-002]" >&2
  fi
}

# Warn if the task body (below frontmatter) exceeds 150 words.
validate_task_body() {
  local file="$1"
  local word_count
  word_count=$(awk '
    /^---$/ { if (++cnt == 2) { body=1; next } }
    body    { print }
  ' "$file" | wc -w)
  if [[ "$word_count" -gt 150 ]]; then
    echo "WARNING: Task body in $(basename "$file") has $word_count words (max recommended: 150)" >&2
  fi
}

# ── main sync helper ─────────────────────────────────────────────────────────
sync_main() {
  git -C "$REPO_ROOT" checkout main || { echo "ERROR: Could not checkout main" >&2; exit 1; }
  git -C "$REPO_ROOT" pull origin main --ff-only \
    || { echo "ERROR: Could not pull main — resolve divergence manually before continuing" >&2; exit 1; }
}
