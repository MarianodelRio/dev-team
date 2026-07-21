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
  [[ "$id" =~ ^[TB]-[0-9]+$ ]] || die "invalid id '$id' (expected T-NNN or B-NNN)"
}

# ── Config reader (flat, two-level YAML) ─────────────────────────────────────
# Usage: dt_config section.key   e.g. dt_config workflow.cleanup_merged_branches
# Returns the value with surrounding quotes and inline comments stripped.
dt_config() {
  local path="$1" section key
  section="${path%%.*}"
  key="${path#*.}"
  [ -f "$DT_CONFIG" ] || { echo ""; return 0; }
  awk -v s="$section" -v k="$key" '
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
  ' "$DT_CONFIG"
}

# Project name → drives worktree path `../<name>-<ID>`. Falls back to repo dir name.
dt_project_name() {
  local n; n="$(dt_config project.name)"
  [ -n "$n" ] && { echo "$n"; return; }
  basename "$REPO_ROOT"
}

dt_worktree_path() { echo "$REPO_ROOT/../$(dt_project_name)-$1"; }

# ── Task file discovery ──────────────────────────────────────────────────────
TASK_FOLDERS="available in-progress ready-for-pr pr-open done blocked"

# Echo the path of the single task file for ID, optionally restricted to a folder.
find_task_file() {
  local id="$1" only="${2:-}"
  local f
  for folder in $TASK_FOLDERS; do
    [ -n "$only" ] && [ "$folder" != "$only" ] && continue
    for f in "$REPO_ROOT/tasks/$folder/${id}-"*.md; do
      [ -e "$f" ] && { echo "$f"; return 0; }
    done
  done
  return 1
}

# Read a frontmatter scalar field from a task file (e.g. status, branch, agent).
task_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf && $0 ~ "^"f":" {
      line=$0; sub("^"f":[[:space:]]*","",line); sub(/[[:space:]]+$/,"",line)
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
set_task_field() {
  local file="$1" field="$2" value="$3"
  # Only touch the first occurrence inside frontmatter.
  awk -v f="$field" -v v="$value" '
    NR==1 && $0=="---" { print; inf=1; next }
    inf && $0=="---"   { inf=0; print; next }
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

# True if a task id currently lives in tasks/done/.
is_done() { find_task_file "$1" done >/dev/null 2>&1; }

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

# ── main sync helper ─────────────────────────────────────────────────────────
sync_main() {
  git -C "$REPO_ROOT" checkout main >/dev/null 2>&1
  git -C "$REPO_ROOT" pull origin main --ff-only >/dev/null 2>&1 \
    || die "main is not fast-forward — resolve divergence manually before continuing"
}
