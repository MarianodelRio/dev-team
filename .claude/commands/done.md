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

## Step 3 — Mark DONE, clean up, and unblock

Run the done script. It syncs main, moves the file to `done/`, deletes the merged branch (if `cleanup_merged_branches: true`, silent when already gone), and moves every dependent whose dependencies are now all done from `blocked/` to `available/` — all committed and pushed to main:

```bash
bash scripts/dt-done.sh [ID]
```

Works for both `T-XXX` and `B-XXX`.

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

## Rules

- **Never mark DONE without the task being in pr-open** (without explicit human override)
- **Always update blocked tasks** — don't leave tasks in blocked/ when their deps are done
- **Push to main** — done status must be visible to all agents immediately
- **Works for both T-XXX and B-XXX** — bug tasks follow the same lifecycle after they reach pr-open
- **Skip branch cleanup silently if branch is already gone** — GitHub auto-deletes on merge is common
