You are executing the `/add-task` command for dev-team.

**Input:** `$ARGUMENTS` — a description of the new task (e.g., "export playlist to JSON file")

Your job: design a well-formed task through a short conversation and add it to the task backlog.

---

## Step 1 — Understand the request

Regenerate the index for a fast view of all task IDs and their dependency graph:

```bash
bash scripts/dt-board.sh
```

Read:
- `design.md` — to understand the existing architecture
- `spec.md` — to understand the expected behavior of the affected module(s)
- `plan.md` — to understand phases and the current dependency graph
- `.dt-index.json` — the current tasks, their IDs, and the dependency graph (to pick the next free ID and check for overlap)

Determine:
- Next available task ID (T-XXX + 1 from the highest existing ID across **all** task folders, including `tasks/cancelled/` — to avoid ID collisions with cancelled tasks)
- Which phase this belongs to (determined by the task's dependencies: the task belongs to the phase AFTER the highest phase of its dependencies; if no dependencies, default to phase 1 — always confirm the phase with the user rather than silently defaulting to the current project phase)
- Which agent should own it (based on folder ownership in `design.md`)
- Likely dependencies (which existing tasks must be done first)
- Whether the new task changes a module's behavior beyond what spec.md defines (if so, flag it)

---

## Step 2 — Short design conversation

Ask the human (3 questions max):

```
Adding task: "[description from $ARGUMENTS]"

Quick questions:
1. What exactly should this deliver? (specific function, endpoint, or UI change)
2. Any dependencies — does this need something else to be done first?
3. How urgent is this? (can it wait, or should it be next up?)
```

Wait for response.

---

## Step 3 — Propose the task

```
## Proposed Task: T-XXX — [short title]

Phase: [N]
Agent: [agent name]
Folders: [folders it will touch]
Depends on: [T-YYY, T-ZZZ or "none"]
Size: [S/M/L]

Scope: [1-2 sentences]

Delivers:
- [specific output 1]
- [specific output 2]

Done when:
- [ ] [acceptance criterion 1]
- [ ] [acceptance criterion 2]
- [ ] tests written and passing (types per the Testing strategy in `design.md`)
- [ ] [primary doc from the Documentation plan] updated (if it adds a public surface)

Initial placement: tasks/[available or blocked]/

Does this look right, or should I adjust anything?
```

If the proposed task changes module behavior beyond what `spec.md` defines:
```
⚠️ This task modifies the behavior of [module] beyond its current spec.
Consider running /refine first — it will update spec.md and propagate the change to related tasks.
```

Wait for approval. Iterate if needed.

---

## Step 4 — Validate against DAG

Before creating the file, verify:
- All listed `depends_on` IDs exist across all task folders (available, blocked, in-progress, pr-open, done, cancelled). Warn the user if any ID is unknown — do not proceed with unresolved dependencies.
- No circular dependencies — perform a DFS check on the full dependency graph. T-XXX cannot depend on a task that (directly or transitively) depends on T-XXX.
- The assigned agent owns the listed folders

If there's a problem, explain it and propose a fix.

---

## Step 5 — Create the task file

Determine placement:
- If `depends_on` is empty or all deps are in `tasks/done/` or `tasks/cancelled/` → `tasks/available/`
- Otherwise → `tasks/blocked/`

Create `tasks/[folder]/T-XXX-[slug].md`:

```markdown
---
id: T-XXX
phase: N
agent: [agent-name]
depends_on: [T-YYY]
status: [available | blocked]
folders: [libs/example/]
outputs: [function_name()]
size: M
branch: ~
pr: ~
---

## [Title]

**Scope:** [what this task touches]

**Delivers:**
- [specific output]

**Done when:**
- [ ] [acceptance criterion]
- [ ] tests written and passing (types per the Testing strategy in `design.md`)
- [ ] [primary doc from the Documentation plan] updated (if it adds a public surface)
```

After creating the task file, update `plan.md` to include the new task and its `depends_on` relationships in the phases and dependency graph.

```bash
git add tasks/[folder]/T-XXX-[slug].md plan.md
git commit -m "chore(T-XXX): add task — [short title]"
git push origin main
```

Report:
```
✓ T-XXX added to tasks/[folder]/

To start it: run /orchestrate (it will pick this up when dependencies are met)
```

---

## Rules

- **Never create tasks that overlap** with existing tasks in scope
- **Always validate the DAG** — circular dependencies silently break the workflow
- **Keep task size honest** — if it's clearly more than a day's work, propose splitting it
- **Assign to the correct agent** — check folder ownership in `design.md`, not just the description
- **Inherit the conventions** — build the "Done when" from the Testing strategy and Documentation plan in `design.md`, not a hardcoded default
