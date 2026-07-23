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

Run the cancel script with the choices from the checkpoint. It syncs main, removes the worktree, optionally deletes the branch, appends a `## Cancelled` note, and parks the task in `tasks/cancelled/` as `cancelled` — committed and pushed:

```bash
# Add --delete-branch only if the user chose option A (discard work).
bash scripts/dt-cancel.sh [ID] [--delete-branch] --reason "[one-line reason]"
```

If the user chose to keep the branch (option B), omit `--delete-branch`.

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
- **Cancelled tasks go to `tasks/cancelled/`**, not deleted — preserves audit trail
- **Always clean up worktrees** — orphaned worktrees break future orchestrations
