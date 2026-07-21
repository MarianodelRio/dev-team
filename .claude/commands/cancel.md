You are executing the `/cancel` command for dev-team.

**Input:** `$ARGUMENTS` — task ID (e.g., `T-026` or `B-003`)

Your job: cleanly abandon a task that is no longer needed. This is destructive — the task is removed from active flow and any branch work is optionally discarded.

---

## Step 1 — Find the task

Search `tasks/` (all subfolders) for `[ID]-*.md`. Report where it is.

If already in `tasks/done/`:
```
[ID] is already DONE and cannot be cancelled.
```
Stop.

---

## Step 2 — Show current state

```
Task: [ID] — [title]
Status: [current status]
Branch: [branch or "none"]
Depends on: [deps or "none"]

Tasks that depend on this one (would be affected by cancellation):
[list any tasks in tasks/ that have [ID] in their depends_on, or "None"]
```

---

## Step 3 — Mandatory human checkpoint

```
⚠️ Cancelling [ID] — [title]

[If other tasks depend on this:]
⚠️ The following tasks depend on [ID] and will remain blocked:
  - [T-YYY — title]
  - [T-ZZZ — title]
  You will need to update their depends_on manually or cancel them too.

[If branch exists:]
Branch feature/[slug] exists on origin.
  A) Delete the branch (discard all work on it)
  B) Keep the branch (preserve work, just remove from task board)

Confirm cancellation? (yes / no)
```

Wait for explicit "yes". Any other response aborts.

---

## Step 4 — Execute cancellation

```bash
git fetch origin
git checkout main
git pull origin main --ff-only
```

Clean up worktree if it exists:
```bash
git worktree list
git worktree remove --force ../[project-name]-[ID]  2>/dev/null || true
```

If user chose to delete branch:
```bash
git branch -D feature/[slug]               2>/dev/null || true
git push origin --delete feature/[slug]    2>/dev/null || true
```

Update task file:
- `status: cancelled`
- Append a note:

```markdown
## Cancelled
Cancelled on [date]. Reason: [ask user for one-line reason if not provided in $ARGUMENTS]
```

Move file to `tasks/blocked/[ID]-slug.md` (cancelled tasks park here — not available, not done).

```bash
git add tasks/blocked/[ID]-slug.md
git commit -m "chore([ID]): cancel task"
git push origin main
```

---

## Step 5 — Report

```
✓ [ID] cancelled.

[If branch deleted:] Branch feature/[slug] deleted.
[If branch kept:]    Branch feature/[slug] preserved.
[If dependents:]     ⚠️ T-YYY and T-ZZZ remain blocked — update their depends_on if you want to unblock them.

[ID] will appear as cancelled in /status and will not be picked up by /orchestrate.
```

---

## Rules

- **Never cancel without explicit "yes"** — this operation discards work
- **Always warn about dependent tasks** before cancelling
- **Cancelled tasks go to blocked/**, not deleted — preserves audit trail
- **Always clean up worktrees** — orphaned worktrees break future orchestrations
