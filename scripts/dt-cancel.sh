#!/usr/bin/env bash
# dt-cancel.sh — abandon a task cleanly. Parks it in tasks/cancelled/ as cancelled
# (audit trail), tears down its worktree, and optionally deletes its branch.
#
#   dt-cancel.sh T-XXX [--delete-branch] [--reason "why"] [--dry-run]
#
# The human checkpoint (confirmation + branch keep/delete choice) lives in
# /cancel; this script performs the agreed action.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

ID=""; DRY=0; DELBR=0; REASON=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --delete-branch) DELBR=1 ;;
    --reason) shift; REASON="${1:-}" ;;
    *) ID="$1" ;;
  esac
  shift
done
[ -n "$ID" ] || die "usage: dt-cancel.sh T-XXX [--delete-branch] [--reason \"why\"] [--dry-run]"
validate_id "$ID"

FILE="$(find_task_file "$ID")" || die "$ID not found in tasks/"
case "$FILE" in *"/tasks/done/"*) die "$ID is already DONE and cannot be cancelled" ;; esac
BRANCH="$(task_branch_from_file "$FILE")"
WT="$(dt_worktree_path "$ID")"
NEWFILE="$REPO_ROOT/tasks/cancelled/$(basename "$FILE")"

if [ "$DRY" -eq 1 ]; then
  log "DRY-RUN cancel $ID"
  log "  remove worktree : $WT"
  log "  delete branch   : $([ "$DELBR" -eq 1 ] && echo "yes ($BRANCH)" || echo no)"
  log "  move            : $(basename "$FILE") → cancelled (status: cancelled)"
  exit 0
fi

sync_main

[ -e "$WT" ] && { git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null && ok "removed worktree" || true; }

if [ "$DELBR" -eq 1 ]; then
  git -C "$REPO_ROOT" branch -D "$BRANCH" 2>/dev/null || true
  git -C "$REPO_ROOT" push origin --delete "$BRANCH" --quiet 2>/dev/null && ok "deleted origin/$BRANCH" || true
fi

set_task_field "$FILE" status cancelled
{
  echo ""
  echo "## Cancelled"
  echo "Cancelled on $(date -u +%Y-%m-%d). Reason: ${REASON:-not specified}"
} >> "$FILE"

mkdir -p "$REPO_ROOT/tasks/cancelled"
mv "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" add "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" commit -m "chore($ID): cancel task" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID cancelled (parked in tasks/cancelled/)"

refresh_index
