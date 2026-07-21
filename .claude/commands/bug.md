You are executing the `/bug` command for dev-team.

**Input:** `$ARGUMENTS` — bug description or symptom

Your job: investigate the bug systematically, find the root cause, and implement the minimal fix.

---

## Step 1 — Create bug task

Generate a bug ID (B-001, B-002, etc. — check tasks/ for existing B-XXX files).

Create `tasks/in-progress/B-XXX-[slug].md`:
```markdown
---
id: B-XXX
type: bug
agent: [TBD — assigned after investigation]
status: in-progress
branch: fix/B-XXX-[slug]
pr: ~
---

## [Symptom description]

**Reported:** [date]
**Severity:** [TBD]
**Root cause:** [TBD]
**Affected module:** [TBD]
```

Claim the branch and set up an isolated worktree (same model as `/orchestrate`):

```bash
git checkout -b fix/B-XXX-[slug]
git add tasks/in-progress/B-XXX-[slug].md
git commit -m "chore(B-XXX): start investigation"
git push -u origin fix/B-XXX-[slug]

# Isolated worktree — all investigation and fix work happens here
git worktree add ../[project-name]-B-XXX fix/B-XXX-[slug]
```

**If push fails**: another agent is already on this bug. Stop and pick it up with `/restart` if it's stale.

All work in Steps 2–6 happens inside `../[project-name]-B-XXX/`. The main repo stays on main.

---

## Step 2 — Reproduce

Write a minimal reproduction case first — the simplest possible input that triggers the bug.

```bash
[run the reproduction]
```

If you cannot reproduce it, report to the human:
```
⚠️ Cannot reproduce with: [what you tried]
More information needed:
- [question 1]
- [question 2]
```

---

## Step 3 — Isolate

Narrow down to the exact file and line. Check:
- Which module owns this code?
- Is it a logic error, a missing edge case, or a contract mismatch?
- Does a test exist that should have caught this?

---

## Step 4 — Mandatory human checkpoint

Update the bug task with findings. Present:

```
Bug: B-XXX — [symptom]

Reproduced with: [minimal case]
Root cause: [clear explanation of WHY this happens]
Location: [file:line]
Module: [module name] → agent: [agent name]

Proposed fix:
- [specific change 1]
- [specific change 2]
Test to add: [what case it covers]

[If fix crosses module boundaries:]
⚠️ Also affects [other module] — requires your explicit authorization

Questions: [or "None"]
```

**Wait for human confirmation before touching any production code.**

---

## Step 5 — Implement fix

Apply the minimal fix. Do not refactor surrounding code. Do not fix unrelated issues.

Add a test that would have caught this bug.

---

## Step 6 — Verify

```bash
[full test suite — all must pass]
```

---

## Step 7 — Mark READY_FOR_PR and clean up

Commit and push the fix from the worktree:

```bash
cd ../[project-name]-B-XXX
git add [specific files]
git commit -m "B-XXX: [fix description]"
git push origin fix/B-XXX-[slug]
```

Remove the worktree and update task status on main:

```bash
cd ../[project-name]
git worktree remove ../[project-name]-B-XXX
git checkout main
git pull origin main --ff-only
```

Move `tasks/in-progress/B-XXX-slug.md` → `tasks/ready-for-pr/B-XXX-slug.md`, set status `ready-for-pr`:

```bash
git add tasks/ready-for-pr/B-XXX-slug.md
git commit -m "chore(B-XXX): mark READY_FOR_PR"
git push origin main
```

Report:
```
B-XXX is READY_FOR_PR.
Run /prepare-pr B-XXX to open the PR.
```

---

## Rules

- **Always work in an isolated worktree** — never fix directly on main or in the main checkout
- **Minimal fix only** — do not clean up or refactor beyond the bug
- **Never cross module boundaries** without explicit human approval
- **Always add a regression test** — if there's no test, the bug will return
- **Always checkpoint before coding** — the human must approve the root cause diagnosis
