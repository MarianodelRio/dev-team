---
inclusion: agentMatch
agents: [orchestrator, architect, coder, planner]
---

# Context file formats

## context/decisions/T-XXX.md

Non-obvious implementation decisions made during a task.

- **The Architect** writes decision records here after Phase 1 analysis (approved/rejected/modified)
- **The Coder** contributes decisions through the `## Completed` section of the task file — the Orchestrator surfaces this content; the Coder does NOT write directly to `context/decisions/` during implementation

Format:
```
## YYYY-MM-DD — T-XXX [Agent name]
Decided: [what]
Why: [reason]
Affects: [files/modules]
Discarded: [alternative and why not]
```

## context/discoveries/T-XXX.md

Cross-module alerts found during implementation. **The Coder writes this** when it finds something that affects a module outside its `folders:`. Create the file if it does not exist.

```
## OPEN — YYYY-MM-DD [Source agent → Target agent]
[What was found and what action is needed]
Task where this should be addressed: T-YYY (or "unassigned")
Status: open / resolved in T-YYY
```

**`Status: open` is load-bearing.** The Orchestrator reads all discovery files at the start of each task and surfaces only entries with `Status: open` to the Architect (Phase 1) and Planner (Phase 2). When a discovery is resolved in another task, update its entry to `Status: resolved in T-YYY`.

When `/refine` or `/bug` writes a discovery to alert an **in-progress task** about a changed spec or new finding, it uses this format:

```markdown
## Discovery [YYYY-MM-DD] from [source command/agent]
**Alert:** [what changed and how it affects this task]
**Impact:** [specific impact on T-XXX's implementation]
**Required action:** [what the agent working on this task should do differently]
Status: open
```

**Agents do not read `context/` directly.** The Orchestrator pre-selects relevant content from `context/decisions/` (folder-filtered) and `context/discoveries/` (open entries only) and passes it in your prompt.
