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

When `/refine` or `/bug` writes a discovery to alert an **in-progress task** about a
changed spec or new finding, it uses this format:

```markdown
## Discovery [YYYY-MM-DD] from [source command/agent]
**Alert:** [what changed and how it affects this task]
**Impact:** [specific impact on T-XXX's implementation]
**Required action:** [what the agent working on this task should do differently]
```

**Agents do not read `context/` directly.** The Orchestrator pre-selects relevant
content from `context/decisions/` (folder-filtered) and `context/discoveries/`
(open entries only, no folder filter) and passes it in your prompt. If you receive
decision or discovery content, it was filtered and handed to you by the Orchestrator —
do not re-read these folders yourself.

---

## Completing a task

Before the Coder marks a task `ready-for-pr`, it **must** append a `## Completed`
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
- **Always append `## Completed` to the task file** before marking `ready-for-pr`

---

## Task file reference

### Field types

| Field | Type | Valid values |
|---|---|---|
| `id` | string | `T-NNN` or `B-NNN` (three-digit number) |
| `phase` | integer | `0`, `1`, `2`, … (project phase number) |
| `agent` | string | agent name matching a file in `.claude/agents/` |
| `depends_on` | YAML array | `[]` or `[T-001, T-002]` |
| `status` | string | `available`, `in-progress`, `ready-for-pr`, `pr-open`, `done`, `blocked`, `cancelled` |
| `folders` | YAML array | relative paths the agent may modify, e.g. `[apps/api/, libs/auth/]` |
| `outputs` | YAML array | see format below |
| `size` | string | `S`, `M`, `L` |
| `branch` | string | branch name (e.g. `feature/T-001-slug`), or `~` when not yet created |
| `pr` | string | full GitHub PR URL (e.g. `https://github.com/org/repo/pull/123`), or `~` when none |

### `outputs:` format

Use the appropriate format for each output type:

```yaml
outputs:
  - "POST /api/resource → {id: string}"          # REST endpoint
  - "fn name(args) → ReturnType | ErrorType"      # function or method
  - "event: name.occurred → {field: type}"        # domain event
```

### Bug task frontmatter

Bug tasks use `B-NNN` IDs and **must** include the `phase:` field:

```markdown
---
id: B-001
phase: 0
agent: [agent name]
depends_on: []
status: available
folders: [...]
outputs: [...]
size: S
branch: ~
pr: ~
---
```

### "Done when" checklist structure

Separate implementation criteria from process criteria:

```markdown
**Implementation done when:**
- [ ] feature is built and works
- [ ] tests written and passing

**Task done when (post-review):**
- [ ] PR merged into main
- [ ] primary doc updated
```
