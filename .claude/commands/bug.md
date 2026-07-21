You are executing the `/bug` command for dev-team.

**Input:** `$ARGUMENTS` — bug description or symptom

Your job: investigate the bug systematically, find the root cause, and implement the minimal fix.

---

## Step 1 — Create bug task

Generate a bug ID (B-001, B-002, etc. — check tasks/ for existing B-XXX files).

Create `tasks/available/B-XXX-[slug].md`:
```markdown
---
id: B-XXX
type: bug
agent: [TBD — assigned after investigation]
status: available
branch: ~
pr: ~
---

## [Symptom description]

**Reported:** [date]
**Severity:** [TBD]
**Root cause:** [TBD]
**Affected module:** [TBD]
```

Commit the new bug task to main, then claim it — this reuses the same reliable path as `/orchestrate` (atomic lock branch `fix/B-XXX-slug` + isolated worktree + IN_PROGRESS on main):

```bash
git add tasks/available/B-XXX-[slug].md
git commit -m "chore(B-XXX): file bug"
git push origin main

bash scripts/dt-claim.sh B-XXX
```

**If the claim exits non-zero**: another agent is already on this bug — stop (use `/restart B-XXX` if it's stale).

All work in Steps 2–6 happens inside the worktree it created (`../[project-name]-B-XXX/`). The main repo stays on main.

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

Then run the ready script from the main repo — it removes the worktree, syncs main, and moves the bug to `ready-for-pr/`:

```bash
cd ../[project-name]
bash scripts/dt-ready.sh B-XXX
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
