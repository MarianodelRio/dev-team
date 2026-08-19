You are executing the `/restart` command for dev-team.

**Input:** `$ARGUMENTS` — task ID (e.g., `T-026` or `B-003`)

Your job: recover a task that is stuck in `in-progress` — no active agent is working on it, the worktree may be gone, or the agent crashed. Reset it cleanly so it can be picked up again.

---

## Step 1 — Find the task

Look in `tasks/in-progress/` for `[ID]-*.md`. If not found, check all other folders and report where it is.

If the task is in `pr-open`, offer to recover it for a fresh attempt:
```
[ID] is currently in pr-open with an open PR: [PR URL from frontmatter]

Options:
  A) Close the PR and move the task back to available for a fresh attempt
  B) Abort — leave everything as is

What would you like to do?
```

If **A**:
1. Close the GitHub PR: `gh pr close [PR_URL] --comment "Closing for restart — task reset to available"`
2. Run `bash scripts/dt-restart.sh [ID]` to clear the branch and pr fields, reset status to available, and move the task to `tasks/available/`
3. Report:
   ```
   ✓ [ID] PR closed and task reset to available.
   Run /orchestrate to start a fresh attempt.
   ```
Stop — do not continue further steps.

If **B**: Stop — leave everything as is.

If the task is NOT in `in-progress` AND NOT in `pr-open`, stop:
```
[ID] is currently [status], not in-progress or pr-open.
Use /cancel [ID] if you want to abandon it entirely.
```

---

## Step 2 — Show current state

Read the task frontmatter and print:

```
Task: [ID] — [title]
Status: in-progress
Branch: [branch from frontmatter, or "none recorded"]
Last known agent: [agent from frontmatter]

Checking remote branch...
```

```bash
git fetch origin
git branch -r | grep "[branch-slug]"
```

Report what exists:
- Branch exists on origin with commits → "Branch has work — review before resetting"
- Branch exists on origin but is empty (only the claim commit) → "Branch is empty — safe to reset"
- Branch does not exist → "Branch gone — safe to reset"

---

## Step 3 — Mandatory human checkpoint

```
Found: [what was found in Step 2]

Options:
  A) Reset to available — move task back, delete the branch (any uncommitted work in the worktree is lost)
  B) Reset to available — move task back, keep the branch (someone can continue from it manually)
  C) Abandon — cancel the task entirely (moves to `tasks/cancelled/` — audit trail preserved)
  D) Abort — leave everything as is

What would you like to do?
```

Wait for response.

---

## Step 4A — Reset to available (delete branch)

Run the restart script — it syncs main, removes the worktree, deletes the branch (local + remote), resets the task to `available` with `branch: ~`, and moves it back to `tasks/available/`:

```bash
bash scripts/dt-restart.sh [ID]
```

Report:
```
✓ [ID] reset to available.
Branch deleted. Task is ready to be picked up again.
Run /orchestrate to start it.
```

---

## Step 4B — Reset to available (keep branch)

Same as 4A but keep the branch on origin:

```bash
bash scripts/dt-restart.sh [ID] --keep-branch
```

Report:
```
✓ [ID] reset to available.
Branch feature/[slug] kept on origin — pick it up manually or let /orchestrate reclaim it.
```

---

## Step 4C — Cancel (moves to `tasks/cancelled/`)

See `/cancel` command for this flow.

---

## Rules

- **Never reset without human confirmation** — the task may appear stuck but an agent could be working slowly
- **Never force-delete a branch with non-trivial commits** without warning the human explicitly
- **Always clean up worktrees** — orphaned worktrees cause git errors on future orchestrations
