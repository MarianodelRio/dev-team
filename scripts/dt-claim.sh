#!/usr/bin/env bash
# dt-claim.sh — claim an available task: create the lock branch, set up a worktree,
# and record IN_PROGRESS on main.
#
#   dt-claim.sh T-XXX [--dry-run]
#
# The atomic lock is `git push origin main:refs/heads/<branch>`. If it loses a
# race the task was already claimed and main is never touched.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

ID=""; DRY=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; *) ID="$a" ;; esac; done
[ -n "$ID" ] || die "usage: dt-claim.sh T-XXX [--dry-run]"
validate_id "$ID"

FILE="$(find_task_file "$ID" available)" || die "$ID is not in tasks/available/"
BRANCH="$(task_branch_from_file "$FILE")"
WT="$(dt_worktree_path "$ID")"
NEWFILE="$REPO_ROOT/tasks/in-progress/$(basename "$FILE")"

git -C "$REPO_ROOT" fetch origin --quiet 2>/dev/null || true
remote_branch_exists "$BRANCH" && die "$ID already claimed (origin/$BRANCH exists) — pick another task"
[ -e "$WT" ] && die "worktree path already exists: $WT (use /restart $ID)"

if [ "$DRY" -eq 1 ]; then
  log "DRY-RUN claim $ID"
  log "  lock branch : $BRANCH"
  log "  worktree    : $WT"
  log "  move        : $(basename "$FILE") available → in-progress (on main)"
  exit 0
fi

sync_main

# 1) Atomic lock — create the remote branch without switching the checkout.
if ! git -C "$REPO_ROOT" push origin "main:refs/heads/$BRANCH" --quiet 2>/dev/null; then
  die "$ID already claimed (branch push lost the race) — pick another task"
fi
ok "claimed lock branch origin/$BRANCH"

# 2) Worktree tracking the new branch.
git -C "$REPO_ROOT" fetch origin "$BRANCH" --quiet 2>/dev/null || true
git -C "$REPO_ROOT" worktree add --track -b "$BRANCH" "$WT" "origin/$BRANCH" >/dev/null
ok "worktree at $WT"

# 3) Record IN_PROGRESS on main (status metadata).
set_task_field "$FILE" status in-progress
set_task_field "$FILE" branch "$BRANCH"
mkdir -p "$REPO_ROOT/tasks/in-progress"
mv "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" add "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" commit -m "chore($ID): claim [IN_PROGRESS]" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID marked in-progress on main"

refresh_index
echo ""
log "Implement in: $WT"
log "When done, run: bash scripts/dt-ready.sh $ID  (via /orchestrate)"
