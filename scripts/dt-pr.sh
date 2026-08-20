#!/usr/bin/env bash
# dt-pr.sh — open the PR and mark a task PR_OPEN atomically.
#
#   dt-pr.sh T-XXX --title "T-XXX: title" --body-file /tmp/body.md [--dry-run]
#   dt-pr.sh T-XXX --pr-url "https://github.com/.../pull/42"        [--dry-run]
#
# First form (pr_mode: automatic): runs gh pr create, captures URL, updates task.
# Second form (pr_mode: manual):   user already created the PR; just updates task.
# Both forms: move task to pr-open/, commit+push to main, poll GitHub for mergeability,
# and remove the worktree (kept when the PR comes back CONFLICTING).
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

# ISS-057: Sync main BEFORE creating the PR; if sync fails, abort without creating a PR.
sync_main
# ISS-107: Read base branch from config instead of hardcoding "main".
BASE_BRANCH=$(dt_config git.base_branch "main")

ORIGIN_URL="$(git -C "$REPO_ROOT" remote get-url origin)"
if [[ ! "$ORIGIN_URL" =~ github\.com ]]; then
  die "origin remote is not a GitHub URL: $ORIGIN_URL — dt-pr requires a GitHub remote"
fi
REPO_SLUG="$(echo "$ORIGIN_URL" | sed 's/.*github\.com[:/]//; s/\.git$//')"

# ── Create or accept the PR ──────────────────────────────────────────────────
if [ -n "$BODY_FILE" ]; then
  command -v gh >/dev/null 2>&1 || die "gh CLI not found — install and authenticate with 'gh auth login'"
  # ISS-002: Check if a PR already exists for this branch before creating.
  EXISTING_PR=$(gh pr list --head "$BRANCH" --json url -q '.[0].url' 2>/dev/null)
  if [[ -n "$EXISTING_PR" ]]; then
    echo "PR already exists: $EXISTING_PR"
    exit 0
  fi
  log "creating PR for $ID (branch: $BRANCH)..."
  PR_URL="$(
    git -C "$REPO_ROOT" fetch origin --quiet 2>/dev/null || true
    gh pr create \
      --title "$TITLE" \
      --body-file "$BODY_FILE" \
      --head "$BRANCH" \
      --base "$BASE_BRANCH" \
      --repo "$REPO_SLUG"
  )"
  [ -n "$PR_URL" ] || die "gh pr create returned no URL — check 'gh auth status'"
fi

PR_NUMBER="$(echo "$PR_URL" | grep -oE '[0-9]+$')"
[ -n "$PR_NUMBER" ] || die "could not extract PR number from URL: $PR_URL"
ok "PR: #$PR_NUMBER — $PR_URL"

# ── Update task and push to main ─────────────────────────────────────────────

set_task_field "$FILE" status pr-open
set_task_field "$FILE" pr "$PR_URL"
mkdir -p "$REPO_ROOT/tasks/pr-open"
mv "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" add "$FILE" "$NEWFILE"
git -C "$REPO_ROOT" commit -m "chore($ID): mark PR_OPEN — PR #$PR_NUMBER" --quiet
git -C "$REPO_ROOT" push origin main --quiet
ok "$ID marked pr-open on main"

# ── Mergeability check ───────────────────────────────────────────────────────
# GitHub computes mergeability asynchronously and reports UNKNOWN for a few
# seconds after a PR is created or after its base branch moves — and the push to
# main above just moved it. Poll until it resolves so the caller gets a real
# answer instead of a race. Runs before the worktree is torn down, because a
# CONFLICTING result is fixed by rebasing in that worktree. Never fatal: the PR
# exists either way.
PR_MERGEABLE="UNKNOWN"
if command -v gh >/dev/null 2>&1; then
  for _ in 1 2 3 4 5; do
    PR_MERGEABLE="$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json mergeable -q '.mergeable' 2>/dev/null || echo UNKNOWN)"
    [ -n "$PR_MERGEABLE" ] || PR_MERGEABLE="UNKNOWN"
    [ "$PR_MERGEABLE" != "UNKNOWN" ] && break
    sleep 3
  done
  case "$PR_MERGEABLE" in
    MERGEABLE)   ok "PR #$PR_NUMBER is mergeable" ;;
    CONFLICTING) err "PR #$PR_NUMBER is CONFLICTING — rebase $BRANCH on $BASE_BRANCH and force-push before merging" ;;
    *)           log "PR #$PR_NUMBER mergeability still UNKNOWN — re-check with: gh pr view $PR_NUMBER --json mergeable" ;;
  esac
fi

# ── Remove worktree (silent if already gone) ──────────────────────────────────
# Kept when the PR is CONFLICTING: it is where the rebase has to happen.
if [ "$PR_MERGEABLE" = "CONFLICTING" ] && [ -e "$WT" ]; then
  log "worktree kept for the rebase: $WT"
elif [ -e "$WT" ]; then
  git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null \
    && ok "worktree removed: $WT" \
    || log "could not remove worktree $WT (already gone?)"
fi

refresh_index

echo ""
echo "PR_NUMBER=$PR_NUMBER"
echo "PR_URL=$PR_URL"
echo "PR_MERGEABLE=$PR_MERGEABLE"
