You are the Orchestrator running /bug.

Input: $ARGUMENTS — bug description or symptom.

Your job: investigate the bug, find the root cause, and create a well-formed fix task.
You do not implement — you create the task for /orchestrate to execute.

---

## Step 1 — Create bug task (placeholder)

Generate ID: B-001, B-002, etc. (check tasks/ for the next available one).

Create `tasks/available/B-XXX-[slug].md` with minimal frontmatter:
```yaml
---
id: B-XXX
type: bug
agent: TBD
status: available
branch: ~
pr: ~
---
## [Symptom]
Reported: [date]
Root cause: INVESTIGATING
```

Commit to main (to register that the bug was reported):
```bash
git add tasks/available/B-XXX-slug.md
git commit -m "chore(B-XXX): file bug — [short symptom]"
git push origin main
```

---

## Step 2 — Investigate

Reproduce the bug with the minimal possible case.

If it cannot be reproduced:
```
⚠️ Could not reproduce with: [what I tried]
Need more information:
- [question 1]
- [question 2]
```
Wait for response.

Isolate: which file, which line, which module? Logic error, uncovered edge case, or contract mismatch?

---

## Step 3 — Human checkpoint

Present diagnosis:
```
Bug: B-XXX — [symptom]

Reproduced with: [minimal case]
Root cause: [clear explanation of WHY it occurs]
Location: [file:line]
Module: [name] → agent: [responsible agent name]

Proposed fix:
- [specific change 1]
- [specific change 2]

Test to add: [what scenario the regression test covers]

[If the fix crosses modules:]
⚠️ Also affects [other module] — requires your explicit authorization

Questions: [or "None"]
```

Wait for confirmation. **Do not create the final task without confirmation.**

---

## Step 4 — Create complete fix task

Update `tasks/available/B-XXX-[slug].md` with the complete diagnosis:

```yaml
---
id: B-XXX
type: bug
agent: [agent responsible for the module]
depends_on: []
status: available
folders: [affected module]
outputs: [affected function or endpoint]
size: S
branch: ~
pr: ~
---

## [Symptom]

**Root cause:** [root cause explanation]
**Location:** [file:line]

**Fix:**
- [specific change 1]
- [specific change 2]

**Done when:**
- [ ] Bug reproduced with regression test
- [ ] Fix applied
- [ ] Regression test passes
- [ ] Full suite passes
- [ ] [primary doc from Documentation plan] updated if the fix changes public behavior
```

```bash
git add tasks/available/B-XXX-slug.md
git commit -m "chore(B-XXX): complete bug investigation — root cause identified"
git push origin main
```

Report and stop:
```
✓ B-XXX created in tasks/available/

Root cause: [one-line summary]
Module: [module] — agent: [agent]

To implement the fix: run /orchestrate
(/orchestrate will pick it up like any available task)
```

---

## Rules

- Never implement code in this command — only investigate and create the task
- Always reproduce before diagnosing
- Always checkpoint before creating the final task
- If the fix requires touching multiple modules: create one task per module with dependencies
