# /reopen T-XXX

Move a task from `pr-open` back to `available` after a PR was rejected or closed without merging.

## Steps

1. Validate the task exists and is in `pr-open` state.
   ```bash
   source scripts/dt-common.sh
   TASK_FILE=$(find tasks/pr-open -name "${TASK_ID}-*.md" 2>/dev/null | head -1)
   [[ -z "$TASK_FILE" ]] && { echo "ERROR: Task $TASK_ID is not in pr-open state."; exit 1; }
   ```

2. Fetch the current PR state:
   ```bash
   PR_URL=$(task_field "$TASK_FILE" pr)
   PR_STATE=$(gh pr view "$PR_URL" --json state -q '.state' 2>/dev/null)
   ```
   - If state is `MERGED`: refuse — "This PR was merged. Use /done $TASK_ID instead."
   - If state is `OPEN`: ask the user "The PR is still open. Close it before reopening? (y/N)"
     - If y: `gh pr close "$PR_URL" --comment "Task $TASK_ID reopened for revision"`

3. Reset the task frontmatter:
   - Set `status: available`
   - Set `branch: ~`
   - Set `pr: ~`
   - Move the file: `mv "$TASK_FILE" "tasks/available/$(basename "$TASK_FILE")"`

4. Push to main:
   ```bash
   git add tasks/
   git commit -m "reopen: $TASK_ID — PR closed, task available for retry"
   git push origin main
   ```

5. Report: "Task $TASK_ID is now available. Run /orchestrate $TASK_ID to restart."
