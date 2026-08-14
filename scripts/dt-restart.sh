#!/usr/bin/env bash
# dt-restart.sh — recover a task stuck in in-progress: tear down its worktree,
# reset it to available, and (by default) delete the branch so it can be reclaimed.
#
#   dt-restart.sh T-XXX [--keep-branch] [--dry-run]
#
# The human checkpoint (reset vs. keep vs. abandon) lives in /restart; this script
# performs the reset actions. Use /cancel for the "abandon" path.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

ID=""; DRY=0; KEEP=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; --keep-branch) KEEP=1 ;; *) ID="$a" ;; esac; done
[ -n "$ID" ] || die "usage: dt-restart.sh T-XXX [--keep-branch] [--dry-run]"
validate_id "$ID"

FILE="$(find_task_file "$ID" in-progress)" || die "$ID is not in tasks/in-progress/ (use /cancel to abandon)"
BRANCH="$(task_branch_from_file "$FILE")"
WT="$(dt_worktree_path "$ID")"
NEWFILE="$REPO_ROOT/tasks/available/$(basename "$FILE")"

if [ "$DRY" -eq 1 ]; then
  log "DRY-RUN restart $ID"
  log "  remove worktree : $WT"
  log "  delete branch   : $([ "$KEEP" -eq 1 ] && echo "no (kept: $BRANCH)" || echo "yes ($BRANCH)")"
  log "  move            : $(basename "$FILE") in-progress → available (branch reset)"
  exit 0
fi

sync_main

[ -e "$WT" ] && { git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null && ok "removed worktree" || true; }

if git -C "$REPO_ROOT" worktree list | grep -q "$BRANCH"; then
  OLD_WORKTREE=$(git -C "$REPO_ROOT" worktree list | grep "$BRANCH" | awk '{print $1}')
  git -C "$REPO_ROOT" worktree remove --force "$OLD_WORKTREE" 2>/dev/null || true
fi

if [ "$KEEP" -eq 0 ]; then
  git -C "$REPO_ROOT" branch -D "$BRANCH" 2>/dev/null || true
  git -C "$REPO_ROOT" push origin --delete "$BRANCH" --quiet 2>/dev/null && ok "deleted origin/$BRANCH" || true
fi

if [[ "$KEEP" -eq 1 ]]; then
  echo "WARNING: --keep-branch was specified. The remote branch '$BRANCH' still exists."
  echo "  This task will NOT be auto-picked by /orchestrate."
  echo "  To re-orchestrate it, run: /orchestrate $ID explicitly."
fi

set_task_field "$FILE" status available
set_task_field "$FILE" branch "~"
set_task_field "$FILE" pr "~"
mkdir -p "$REPO_ROOT/tasks/available"
mv "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" add "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" commit -m "chore($ID): restart — reset to available" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID reset to available"
echo "Task $ID is now available. Run: /orchestrate $ID"

refresh_index
