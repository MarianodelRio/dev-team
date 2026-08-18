#!/usr/bin/env bash
# dt-board.sh — regenerate the task index cache (.dt-index.json) and optionally
# print a human-readable board.
#
#   dt-board.sh              → fetch + regenerate .dt-index.json
#   dt-board.sh --no-fetch   → regenerate without hitting the network
#   dt-board.sh --print      → also print a board to stdout
#
# READ-ONLY on repo state: it fetches and reads folders/branches, and writes only
# the git-ignored cache file. The cache is derived data, never a decision authority.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dt-common.sh
source "$SCRIPT_DIR/dt-common.sh"

DO_FETCH=1
DO_PRINT=0
for arg in "$@"; do
  case "$arg" in
    --no-fetch) DO_FETCH=0 ;;
    --print)    DO_PRINT=1 ;;
    *) die "unknown flag: $arg" ;;
  esac
done

# ISS-090: mtime-based cache — skip rebuild if no task file is newer than the index
# Only skip when not printing; --print always requires a fresh build.
if [[ "$DO_PRINT" -eq 0 && -f "$DT_INDEX" ]]; then
  NEWER=$(find "$REPO_ROOT/tasks/" -newer "$DT_INDEX" -name "*.md" 2>/dev/null | head -1)
  if [[ -z "$NEWER" ]]; then
    exit 0  # Cache is fresh; nothing to rebuild
  fi
fi

[ "$DO_FETCH" -eq 1 ] && git -C "$REPO_ROOT" fetch origin --quiet 2>/dev/null || true

# Remote feature/fix branches → used to mark claimed tasks.
REMOTE_BRANCHES="$(git -C "$REPO_ROOT" branch -r 2>/dev/null | sed 's/^[[:space:]]*//' | grep -E 'origin/(feature|fix)/' || true)"

# ISS-073: Replace declare -A (Bash 4+ only) with a temp-directory key-value store
# that works on Bash 3.2 (default on macOS).
TDIR=$(mktemp -d)
trap 'rm -rf "$TDIR"' EXIT

tset()  { printf '%s' "$3"   > "$TDIR/$1.$2"; }       # tset  MAP KEY VALUE
tget()  { cat "$TDIR/$1.$2" 2>/dev/null || true; }    # tget  MAP KEY
tadd()  { printf ' %s' "$3" >> "$TDIR/$1.$2"; }       # tadd  MAP KEY VALUE (space-sep append)

ALL_IDS=""

# ── Pass 1: read every task file ─────────────────────────────────────────────
for folder in "${TASK_FOLDERS[@]}"; do
  for f in "$REPO_ROOT/tasks/$folder/"*.md; do
    [ -e "$f" ] || continue
    id="$(task_field "$f" id)"
    [ -n "$id" ] || continue
    tset FOLDER  "$id" "$folder"
    tset STATUS  "$id" "$(task_field "$f" status)"
    tset PHASE   "$id" "$(task_field "$f" phase)"
    tset AGENT   "$id" "$(task_field "$f" agent)"
    tset BRANCH  "$id" "$(task_field "$f" branch)"
    tset PR      "$id" "$(task_field "$f" pr)"
    tset DEPS    "$id" "$(task_depends_on "$f")"
    # ISS-059: DONE_IDS was computed but never used — removed.
    # Title = first "## " heading, quotes neutralised for JSON.
    tset TITLE   "$id" "$(grep -m1 '^## ' "$f" | sed 's/^## //; s/"/'"'"'/g' | sed 's/[[:space:]]*$//')"
    ALL_IDS="$ALL_IDS $id"
  done
done

# ── Pass 2: invert depends_on into unblocks ──────────────────────────────────
for id in $ALL_IDS; do
  for dep in $(tget DEPS "$id"); do
    [ -n "$dep" ] || continue
    tadd UNBLOCKS "$dep" "$id"
  done
done

claimed_remote() {
  local id="$1" br
  br="$(tget BRANCH "$id")"
  # Explicit branch field first, else the conventional pattern.
  if [ -n "$br" ] && [ "$br" != "~" ]; then
    echo "$REMOTE_BRANCHES" | grep -q "origin/$br$" && { echo true; return; }
  fi
  echo "$REMOTE_BRANCHES" | grep -qE "origin/(feature|fix)/$id-" && { echo true; return; }
  echo false
}

json_arr() { # space-separated ids → JSON array
  local out="" x
  for x in $1; do out="$out\"$x\","; done
  echo "[${out%,}]"
}

# Sanitise a scalar for embedding inside a JSON string: drop backslashes and
# double quotes (frontmatter values are ids/urls/branches — no structure lost).
js() { local v="${1//\\/}"; printf '%s' "${v//\"/}"; }

# ── critical_path_next: available + unclaimed, most unblocks, smallest id ─────
# Extract numeric part of an ID (T-001 → 1, B-42 → 42) for numeric tiebreaking.
id_num() { printf '%d' "$((10#${1#*-}))"; }

CRIT_NEXT=""
CRIT_SCORE=-1
for id in $ALL_IDS; do
  [ "$(tget FOLDER "$id")" = "available" ] || continue
  [ "$(claimed_remote "$id")" = "false" ] || continue
  n=0; for u in $(tget UNBLOCKS "$id"); do n=$((n+1)); done
  if [ "$n" -gt "$CRIT_SCORE" ]; then
    CRIT_SCORE=$n; CRIT_NEXT="$id"
  elif [ "$n" -eq "$CRIT_SCORE" ] && [ -n "$CRIT_NEXT" ]; then
    [ "$(id_num "$id")" -lt "$(id_num "$CRIT_NEXT")" ] && CRIT_NEXT="$id"
  fi
done

# ── Write .dt-index.json (ISS-006: atomic write via tmp + rename) ─────────────
{
  echo "{"
  echo "  \"generated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"tasks\": {"
  first=1
  for id in $ALL_IDS; do
    [ "$first" -eq 1 ] && first=0 || echo ","
    printf '    "%s": {' "$id"
    printf '"status": "%s", ' "$(js "$(tget STATUS "$id")")"
    printf '"folder": "%s", ' "$(tget FOLDER "$id")"
    printf '"phase": "%s", ' "$(js "$(tget PHASE "$id")")"
    printf '"agent": "%s", ' "$(js "$(tget AGENT "$id")")"
    printf '"title": "%s", ' "$(js "$(tget TITLE "$id")")"
    printf '"branch": "%s", ' "$(js "$(tget BRANCH "$id")")"
    printf '"pr": "%s", ' "$(js "$(tget PR "$id")")"
    printf '"depends_on": %s, ' "$(json_arr "$(tget DEPS "$id")")"
    printf '"unblocks": %s, ' "$(json_arr "$(tget UNBLOCKS "$id")")"
    printf '"claimed_remote": %s}' "$(claimed_remote "$id")"
  done
  [ "$first" -eq 0 ] && echo ""
  echo "  },"
  # summary
  cnt() { local c=0 i; for i in $ALL_IDS; do [ "$(tget FOLDER "$i")" = "$1" ] && c=$((c+1)); done; echo "$c"; }
  echo "  \"summary\": {"
  echo "    \"available\": $(cnt available),"
  echo "    \"in_progress\": $(cnt in-progress),"
  echo "    \"ready_for_pr\": $(cnt ready-for-pr),"
  echo "    \"pr_open\": $(cnt pr-open),"
  echo "    \"done\": $(cnt done),"
  echo "    \"blocked\": $(cnt blocked),"
  echo "    \"cancelled\": $(cnt cancelled),"
  echo "    \"critical_path_next\": \"$CRIT_NEXT\""
  echo "  }"
  echo "}"
} > "${DT_INDEX}.tmp"
mv "${DT_INDEX}.tmp" "$DT_INDEX"

# ── Optional human board ─────────────────────────────────────────────────────
if [ "$DO_PRINT" -eq 1 ]; then
  echo "dev-team board — $(dt_project_name)"
  for folder in done pr-open ready-for-pr in-progress available blocked; do
    ids=""; for id in $ALL_IDS; do [ "$(tget FOLDER "$id")" = "$folder" ] && ids="$ids $id"; done
    [ -n "$ids" ] || continue
    echo ""
    echo "[$folder]"
    for id in $ids; do
      mark=""; [ "$id" = "$CRIT_NEXT" ] && mark=" ⭐"
      echo "  $id — $(tget TITLE "$id")$mark"
    done
  done
  if [ -n "$CRIT_NEXT" ]; then echo ""; echo "Suggested next: $CRIT_NEXT"; fi
fi

exit 0
