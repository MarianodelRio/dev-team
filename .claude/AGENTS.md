# dev-team — Agent Reference

This file is injected into every agent session alongside your own system prompt.
It contains formats and cross-cutting rules that are needed at runtime and are not
defined in individual agent prompts.

---

## Context file formats

### context/decisions/T-XXX.md

Non-obvious implementation decisions made during a task. **The Coder writes this.**
Create the file if it does not exist.

```
## YYYY-MM-DD — T-XXX [Agent name]
Decided: [what]
Why: [reason]
Affects: [files/modules]
Discarded: [alternative and why not]
```

### context/discoveries/T-XXX.md

Cross-module alerts found during implementation. **The Coder writes this.**
Create the file if it does not exist.

```
## OPEN — YYYY-MM-DD [Source agent → Target agent]
[What was found and what action is needed]
Task where this should be addressed: T-YYY (or "unassigned")
Status: open / resolved in T-YYY
```

**`Status: open` is load-bearing.** The Orchestrator reads all discovery files at
the start of each task and surfaces only entries with `Status: open` to the Architect
(Phase 1) and Planner (Phase 2). When a discovery is resolved in another task, update
its entry to `Status: resolved in T-YYY`.

**Agents do not read `context/` directly.** The Orchestrator pre-selects relevant
content from `context/decisions/` (folder-filtered) and `context/discoveries/`
(open entries only, no folder filter) and passes it in your prompt. If you receive
decision or discovery content, it was filtered and handed to you by the Orchestrator —
do not re-read these folders yourself.

---

## Completing a task

Before the Coder marks a task READY_FOR_PR, it **must** append a `## Completed`
section to the task file in the worktree:

```markdown
## Completed
- What was implemented
- What changed from the original plan
- Decisions made and why
```

This is written to the task file before the final commit. It records what was actually
built versus what was planned, and is read by future orchestrations as context.

---

## Cross-cutting rules

- **Never modify `spec.md` directly** — changes go through `/refine`, which classifies
  affected tasks by state and propagates changes safely to available, in-progress, and
  done tasks
- **Agents do not read `context/discoveries/` directly** — the Orchestrator surfaces
  open entries and passes them in your prompt
- **Always append `## Completed` to the task file** before marking READY_FOR_PR
