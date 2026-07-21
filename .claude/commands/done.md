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

## Step 3 — Mark DONE

```bash
git fetch origin
git checkout main
git pull origin main --ff-only
```

Move task file: `tasks/pr-open/T-XXX-slug.md` → `tasks/done/T-XXX-slug.md`

Update frontmatter:
```yaml
status: done
```

```bash
git add tasks/done/[ID]-slug.md
git commit -m "chore([ID]): mark DONE"
git push origin main
```

---

## Step 3b — Clean up merged branch (if configured)

Read `cleanup_merged_branches` from `devteam.config.yml`.

If `true`:
```bash
# Derive branch name from task frontmatter (branch: field) or standard pattern
git push origin --delete [branch-slug]  2>/dev/null || true
```

If the branch is already gone (already deleted by GitHub's auto-delete on merge), skip silently.
If `cleanup_merged_branches: false`, skip this step entirely.

---

## Step 4 — Report unblocked tasks

Scan all files in `tasks/blocked/`. For each task where:
- `[ID]` appears in `depends_on`
- All other items in `depends_on` are also `done`
- The task is not `cancelled`

→ Move that task to `tasks/available/` and update its frontmatter to `status: available`.

```bash
git add tasks/available/
git add tasks/blocked/
git commit -m "chore: unblock tasks after T-XXX"
git push origin main
```

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
