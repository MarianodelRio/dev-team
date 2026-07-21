You are executing the `/restart` command for dev-team.

**Input:** `$ARGUMENTS` — task ID (e.g., `T-026` or `B-003`)

Your job: recover a task that is stuck in `in-progress` — no active agent is working on it, the worktree may be gone, or the agent crashed. Reset it cleanly so it can be picked up again.

---

## Step 1 — Find the task

Look in `tasks/in-progress/` for `[ID]-*.md`. If not found, check all other folders and report where it is.

If the task is NOT in `in-progress`, stop:
```
[ID] is currently [status], not in-progress.
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
  C) Abandon — cancel the task entirely (moves to blocked with a note)
  D) Abort — leave everything as is

What would you like to do?
```

Wait for response.

---

## Step 4A — Reset to available (delete branch)

```bash
git checkout main
git pull origin main --ff-only
```

Clean up worktree if it exists:
```bash
# Check for worktrees
git worktree list
# Remove if found matching this task
git worktree remove --force ../[project-name]-[ID]
```

Delete the branch:
```bash
git branch -D feature/[slug]               2>/dev/null || true
git push origin --delete feature/[slug]    2>/dev/null || true
```

Update task file:
- `status: available`
- `branch: ~`
- Move file: `tasks/in-progress/` → `tasks/available/`

```bash
git add tasks/available/[ID]-slug.md
git commit -m "chore([ID]): restart — reset to available"
git push origin main
```

Report:
```
✓ [ID] reset to available.
Branch deleted. Task is ready to be picked up again.
Run /orchestrate to start it.
```

---

## Step 4B — Reset to available (keep branch)

Same as 4A but skip branch deletion. Update task frontmatter only.

Report:
```
✓ [ID] reset to available.
Branch feature/[slug] kept on origin — pick it up manually or let /orchestrate reclaim it.
```

---

## Step 4C — Cancel (moves to blocked with a note)

See `/cancel` command for this flow.

---

## Rules

- **Never reset without human confirmation** — the task may appear stuck but an agent could be working slowly
- **Never force-delete a branch with non-trivial commits** without warning the human explicitly
- **Always clean up worktrees** — orphaned worktrees cause git errors on future orchestrations
