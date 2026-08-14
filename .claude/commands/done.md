You are executing the `/done` command for dev-team.

**Input:** `$ARGUMENTS` — task ID (e.g., `T-026` or `B-003`)

Your job: mark the task DONE after the human has merged the PR, then report which tasks are now unblocked.

This command handles both regular tasks (`T-XXX`) and bug tasks (`B-XXX`).

---

## Step 1 — Find the task

Look in `tasks/pr-open/` for `[ID]-*.md` (matches both `T-XXX` and `B-XXX`). If not found, check other folders.

---

## Step 2 — Validate state

Check the `status` field in frontmatter:

- `status: pr-open` → proceed normally
- `status: done` → report "T-XXX is already DONE." and stop
- Any other status → warn:
  ```
  ⚠️ T-XXX is currently [status], not pr-open.
  This usually means the PR hasn't been merged yet.
  Are you sure you want to mark it DONE?
  ```
  Wait for explicit confirmation.

---

## Step 2.5 — Verify CI checks passed

Read the PR URL from the task file's `pr:` frontmatter field. Then:

```bash
gh pr view [PR_URL_OR_NUMBER] --json statusCheckRollup,state \
  --jq '{state: .state, checks: [.statusCheckRollup[] | {name: .name, conclusion: .conclusion}]}'
```

If the PR is already merged (`state: MERGED`):
- Check if any `conclusion` is `FAILURE` or `CANCELLED`
- If all are `SUCCESS` or `SKIPPED` (or `statusCheckRollup` is empty): proceed to Step 3 silently
- If any failed:
  ```
  ⚠️ T-XXX was merged but some CI checks failed:
    ✗ [check name]: FAILURE
    ✓ [check name]: SUCCESS

  This may indicate the main branch is broken. Proceed marking as DONE?
  (Recommended: investigate the failure before confirming)
  ```
  Wait for explicit confirmation before proceeding.

If the PR is not yet merged (`state: OPEN`):
```
⚠️ T-XXX — PR #[N] is still open, not merged.
CI status: [check summary]

Are you sure you want to mark this DONE? This should only happen if you
merged outside of GitHub (e.g. git merge locally).
```
Wait for explicit confirmation.

If `gh` returns an error (PR not found, no CI configured):
Skip silently — do not block `/done` for projects without CI.

---

## Step 3 — Mark DONE, clean up, and unblock

Before running the done script, identify all tasks in `tasks/blocked/` whose `depends_on` includes [ID]. For each candidate to unblock:
- Verify that **every** ID in its `depends_on` list is in `tasks/done/` OR `tasks/cancelled/`. Only move to `tasks/available/` if ALL dependencies are satisfied — do not move a task that still has outstanding dependencies.
- Perform a DFS cycle check on the dependency graph before moving any task to available. If a cycle is detected (e.g., T-A → T-B → T-A), report it and stop — do not proceed with unblocking until the cycle is resolved.

Run the done script. It syncs main, moves the file to `done/`, deletes the merged branch (if `cleanup_merged_branches: true`, silent when already gone), and moves qualifying dependents from `blocked/` to `available/` — all committed and pushed to main:

```bash
bash scripts/dt-done.sh [ID]
```

Works for both `T-XXX` and `B-XXX`.

After the script completes, clear the `branch:` field in the moved task file so it does not contain a stale branch name. Edit `tasks/done/[ID]-*.md` and set:

```
branch: ~
```

Then stage and commit this change to main alongside the done status update (or as a follow-up commit if the script already pushed).

---

## Step 4 — Report unblocked tasks

Use the script's output (and `.dt-index.json`) to report what was just unblocked.

Report:
```
✓ T-XXX marked DONE.

Newly available:
- T-YYY — [title] (was blocked by T-XXX)
- T-ZZZ — [title] (was blocked by T-XXX + T-AAA, now both done)

Still blocked:
- T-BBB — waiting for T-CCC [in-progress]

Run /orchestrate to pick up the next task.
```

If nothing was unblocked: "No new tasks unblocked."

---

## Step 5 — Check if architecture docs need updating

Review the merged PR's changes. If any module interfaces, API contracts, or shared data models changed, prompt the user:

```
⚠️ The PR for [ID] may have changed module interfaces.
If any output contracts changed (APIs, data models, shared types), run /refine
to propagate the changes to spec.md and dependent tasks.
```

---

## Rules

- **Never mark DONE without the task being in pr-open** (without explicit human override)
- **Always update blocked tasks** — don't leave tasks in blocked/ when their deps are done
- **Push to main** — done status must be visible to all agents immediately
- **Works for both T-XXX and B-XXX** — bug tasks follow the same lifecycle after they reach pr-open
- **Skip branch cleanup silently if branch is already gone** — GitHub auto-deletes on merge is common
