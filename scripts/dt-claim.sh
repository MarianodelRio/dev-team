#!/usr/bin/env bash
# dt-claim.sh — claim an available task: create the lock branch, set up a worktree,
# record IN_PROGRESS on main, and fast-forward the branch onto that commit so the
# task file sits at the same path on the branch as on main.
#
#   dt-claim.sh T-XXX [--dry-run]
#
# The atomic lock is `git push origin main:refs/heads/<branch>`. If it loses a
# race the task was already claimed and main is never touched.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

ID=""; DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    T-*|B-*) ID="$a" ;;
    *) die "unknown argument: $a" ;;
  esac
done
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
_CLAIM_ERR_TMP="$(mktemp)"
trap 'rm -f "$_CLAIM_ERR_TMP"' EXIT
if ! git -C "$REPO_ROOT" push origin "main:refs/heads/$BRANCH" --quiet 2>"$_CLAIM_ERR_TMP"; then
  if grep -qiE "already exists|rejected" "$_CLAIM_ERR_TMP" 2>/dev/null; then
    rm -f "$_CLAIM_ERR_TMP"
    echo "CLAIM_RESULT=already_claimed"
    die "$ID already claimed (branch push lost the race) — pick another task"
  else
    cat "$_CLAIM_ERR_TMP" >&2
    rm -f "$_CLAIM_ERR_TMP"
    echo "CLAIM_RESULT=error"
    exit 1
  fi
fi
rm -f "$_CLAIM_ERR_TMP"
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
_SESS_LABEL=""
[ -n "${CLAUDE_SESSION_ID:-}" ] && _SESS_LABEL=" [session: ${CLAUDE_SESSION_ID}]"
git -C "$REPO_ROOT" commit -m "chore($ID): claim [IN_PROGRESS]${_SESS_LABEL}" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID marked in-progress on main"

# 4) Fast-forward the lock branch (and the worktree) onto the claim commit.
#
# The lock push in step 1 branched from main BEFORE the move above, so without
# this the worktree holds the task file at tasks/available/ while main holds it
# at tasks/in-progress/. The Coder is handed the in-progress path (read from
# main) and, finding nothing there, may create a second file at that path — an
# add/add conflict against main at the Phase 4 rebase. Aligning the branch here
# leaves exactly one path for the task file, on both sides.
#
# This is a fast-forward (main is a descendant of the lock point), so it needs
# no --force and cannot clobber anything: nothing has been committed on the
# branch yet. Best-effort — a failure here degrades to the old behaviour, which
# the Phase 4 rebase can still resolve, so warn instead of aborting the claim.
if git -C "$REPO_ROOT" push origin "main:refs/heads/$BRANCH" --quiet 2>/dev/null; then
  git -C "$WT" fetch origin "$BRANCH" --quiet 2>/dev/null || true
  if git -C "$WT" merge --ff-only "origin/$BRANCH" --quiet 2>/dev/null; then
    ok "branch and worktree aligned with main (task file at tasks/in-progress/)"
  else
    log "WARNING: could not fast-forward the worktree to origin/$BRANCH"
    log "         the task file is at tasks/available/ in $WT but tasks/in-progress/ on main"
  fi
else
  log "WARNING: could not fast-forward origin/$BRANCH onto the claim commit"
  log "         the task file is at tasks/available/ in $WT but tasks/in-progress/ on main"
fi

refresh_index
echo ""
log "Implement in: $WT"
log "When done, run: bash scripts/dt-ready.sh $ID  (via /orchestrate)"
