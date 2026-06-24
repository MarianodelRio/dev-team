You are executing the `/done` command for dev-team.

**Input:** `$ARGUMENTS` — task ID (e.g., `T-026`)

Your job: mark the task DONE after the human has merged the PR, then report which tasks are now unblocked.

---

## Step 1 — Find the task

Look in `tasks/pr-open/` for `T-XXX-*.md`. If not found, check other folders.

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
git add tasks/done/T-XXX-slug.md
git commit -m "chore(T-XXX): mark DONE"
git push origin main
```

---

## Step 4 — Report unblocked tasks

Scan all files in `tasks/blocked/`. For each task where:
- T-XXX appears in `depends_on`
- All other items in `depends_on` are also `done`

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
