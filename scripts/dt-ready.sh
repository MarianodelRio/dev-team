#!/usr/bin/env bash
# dt-ready.sh — mark an in-progress task READY_FOR_PR: tear down the worktree and
# move the task file on main. Assumes code was already committed and pushed to the
# feature branch (that is /orchestrate's responsibility before calling this).
#
#   dt-ready.sh T-XXX [--dry-run]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

ID=""; DRY=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; *) ID="$a" ;; esac; done
[ -n "$ID" ] || die "usage: dt-ready.sh T-XXX [--dry-run]"
validate_id "$ID"

FILE="$(find_task_file "$ID" in-progress)" || die "$ID is not in tasks/in-progress/"
WT="$(dt_worktree_path "$ID")"
NEWFILE="$REPO_ROOT/tasks/ready-for-pr/$(basename "$FILE")"

if [ "$DRY" -eq 1 ]; then
  log "DRY-RUN ready $ID"
  log "  remove worktree : $WT"
  log "  move            : $(basename "$FILE") in-progress → ready-for-pr (on main)"
  exit 0
fi

if [ -e "$WT" ]; then
  git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null \
    && ok "removed worktree $WT" \
    || log "could not remove worktree $WT (already gone?)"
fi

sync_main
set_task_field "$FILE" status ready-for-pr
mkdir -p "$REPO_ROOT/tasks/ready-for-pr"
mv "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" add "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" commit -m "chore($ID): mark READY_FOR_PR" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID marked ready-for-pr"

refresh_index
echo ""
log "Next: run /prepare-pr $ID"
