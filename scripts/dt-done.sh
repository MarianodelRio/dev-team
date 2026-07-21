#!/usr/bin/env bash
# dt-done.sh — mark a merged task DONE and unblock its dependents.
#
#   dt-done.sh T-XXX [--dry-run]
#
# Run this AFTER the PR is merged on GitHub. Cleans up the merged branch when
# workflow.cleanup_merged_branches is true.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

ID=""; DRY=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; *) ID="$a" ;; esac; done
[ -n "$ID" ] || die "usage: dt-done.sh T-XXX [--dry-run]"
validate_id "$ID"

FILE="$(find_task_file "$ID" pr-open)" || die "$ID is not in tasks/pr-open/ (is the PR merged?)"
BRANCH="$(task_branch_from_file "$FILE")"
NEWFILE="$REPO_ROOT/tasks/done/$(basename "$FILE")"

if [ "$DRY" -eq 1 ]; then
  log "DRY-RUN done $ID"
  log "  move   : $(basename "$FILE") pr-open → done (on main)"
  log "  branch : cleanup=$(dt_config workflow.cleanup_merged_branches) → $BRANCH"
  log "  unblock: scan tasks/blocked/ for dependents of $ID"
  exit 0
fi

sync_main

# 1) Mark DONE.
set_task_field "$FILE" status done
mkdir -p "$REPO_ROOT/tasks/done"
mv "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" add "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" commit -m "chore($ID): mark DONE" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID marked done"

# 2) Branch cleanup (silent if already deleted by GitHub auto-delete).
if [ "$(dt_config workflow.cleanup_merged_branches)" = "true" ]; then
  git -C "$REPO_ROOT" push origin --delete "$BRANCH" --quiet 2>/dev/null \
    && ok "deleted origin/$BRANCH" || true
fi

# 3) Unblock dependents whose deps are now all done.
UNBLOCKED=""
for f in "$REPO_ROOT/tasks/blocked/"*.md; do
  [ -e "$f" ] || continue
  [ "$(task_field "$f" status)" = "cancelled" ] && continue
  deps="$(task_depends_on "$f")"
  ready=1
  for d in $deps; do [ -n "$d" ] || continue; is_done "$d" || { ready=0; break; }; done
  [ "$ready" -eq 1 ] || continue
  bid="$(task_field "$f" id)"
  set_task_field "$f" status available
  nf="$REPO_ROOT/tasks/available/$(basename "$f")"
  mkdir -p "$REPO_ROOT/tasks/available"
  mv "$f" "$nf"
  git -C "$REPO_ROOT" add "$f" "$nf"
  UNBLOCKED="$UNBLOCKED $bid"
done

if [ -n "$UNBLOCKED" ]; then
  git -C "$REPO_ROOT" commit -m "chore: unblock tasks after $ID —$UNBLOCKED" --quiet
  git -C "$REPO_ROOT" push origin main --quiet
  ok "unblocked:$UNBLOCKED"
else
  log "no tasks unblocked by $ID"
fi

refresh_index
