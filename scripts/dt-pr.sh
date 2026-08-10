#!/usr/bin/env bash
# dt-pr.sh — open the PR and mark a task PR_OPEN atomically.
#
#   dt-pr.sh T-XXX --title "T-XXX: title" --body-file /tmp/body.md [--dry-run]
#   dt-pr.sh T-XXX --pr-url "https://github.com/.../pull/42"        [--dry-run]
#
# First form (pr_mode: automatic): runs gh pr create, captures URL, updates task.
# Second form (pr_mode: manual):   user already created the PR; just updates task.
# Both forms: move task to pr-open/, commit+push to main, remove worktree if it exists.
#
# Task must be in tasks/in-progress/ or tasks/ready-for-pr/.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

ID=""; TITLE=""; BODY_FILE=""; PR_URL=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --title)      shift; TITLE="${1:-}" ;;
    --body-file)  shift; BODY_FILE="${1:-}" ;;
    --pr-url)     shift; PR_URL="${1:-}" ;;
    --dry-run)    DRY=1 ;;
    *)            ID="$1" ;;
  esac
  shift
done

[ -n "$ID" ] || die "usage: dt-pr.sh T-XXX --title \"...\" --body-file /tmp/body.md [--dry-run]
       dt-pr.sh T-XXX --pr-url \"https://github.com/.../pull/42\" [--dry-run]"
validate_id "$ID"

# Exactly one of --body-file or --pr-url must be provided
if [ -z "$BODY_FILE" ] && [ -z "$PR_URL" ]; then
  die "provide either --body-file (automatic mode) or --pr-url (manual mode)"
fi
if [ -n "$BODY_FILE" ] && [ -n "$PR_URL" ]; then
  die "--body-file and --pr-url are mutually exclusive"
fi
if [ -n "$BODY_FILE" ] && [ -z "$TITLE" ]; then
  die "--title is required when using --body-file"
fi
if [ -n "$BODY_FILE" ] && [ ! -f "$BODY_FILE" ]; then
  die "body file not found: $BODY_FILE"
fi

# Find the task — accept in-progress (normal flow) or ready-for-pr (escape hatch)
FILE=""; TASK_FOLDER=""
if find_task_file "$ID" in-progress >/dev/null 2>&1; then
  FILE="$(find_task_file "$ID" in-progress)"
  TASK_FOLDER="in-progress"
elif find_task_file "$ID" ready-for-pr >/dev/null 2>&1; then
  FILE="$(find_task_file "$ID" ready-for-pr)"
  TASK_FOLDER="ready-for-pr"
else
  die "$ID is not in tasks/in-progress/ or tasks/ready-for-pr/"
fi

BRANCH="$(task_branch_from_file "$FILE")"
WT="$(dt_worktree_path "$ID")"
NEWFILE="$REPO_ROOT/tasks/pr-open/$(basename "$FILE")"

if [ "$DRY" -eq 1 ]; then
  log "DRY-RUN pr $ID"
  log "  task folder : tasks/$TASK_FOLDER/"
  log "  branch      : $BRANCH"
  if [ -n "$BODY_FILE" ]; then
    log "  mode        : automatic (gh pr create)"
    log "  title       : $TITLE"
    log "  body-file   : $BODY_FILE"
  else
    log "  mode        : manual (pr-url provided)"
    log "  pr-url      : $PR_URL"
  fi
  log "  move        : $(basename "$FILE") $TASK_FOLDER → pr-open (on main)"
  log "  worktree    : $([ -e "$WT" ] && echo "remove $WT" || echo "not found, skip")"
  exit 0
fi

# ── Create or accept the PR ──────────────────────────────────────────────────
if [ -n "$BODY_FILE" ]; then
  command -v gh >/dev/null 2>&1 || die "gh CLI not found — install and authenticate with 'gh auth login'"
  log "creating PR for $ID (branch: $BRANCH)..."
  PR_URL="$(
    git -C "$REPO_ROOT" fetch origin --quiet 2>/dev/null || true
    gh pr create \
      --title "$TITLE" \
      --body-file "$BODY_FILE" \
      --head "$BRANCH" \
      --base main \
      --repo "$(git -C "$REPO_ROOT" remote get-url origin | sed 's/.*github\.com[:/]//; s/\.git$//')"
  )"
  [ -n "$PR_URL" ] || die "gh pr create returned no URL — check 'gh auth status'"
fi

PR_NUMBER="$(echo "$PR_URL" | grep -oE '[0-9]+$')"
ok "PR: #$PR_NUMBER — $PR_URL"

# ── Update task and push to main ─────────────────────────────────────────────
sync_main

set_task_field "$FILE" status pr-open
set_task_field "$FILE" pr "$PR_URL"
mkdir -p "$REPO_ROOT/tasks/pr-open"
mv "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" add "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" commit -m "chore($ID): mark PR_OPEN — PR #$PR_NUMBER" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID marked pr-open on main"

# ── Remove worktree (silent if already gone) ──────────────────────────────────
if [ -e "$WT" ]; then
  git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null \
    && ok "worktree removed: $WT" \
    || log "could not remove worktree $WT (already gone?)"
fi

refresh_index

echo ""
echo "PR_NUMBER=$PR_NUMBER"
echo "PR_URL=$PR_URL"
