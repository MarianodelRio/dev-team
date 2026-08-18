---
inclusion: agentMatch
agents: [coder]
---

# Completion obligation

Before your final commit, you **must** append a `## Completed` section to the task file in the worktree:

```markdown
## Completed
- What was implemented (summary of deliverables)
- Deviations from plan: [any significant changes from the Planner's plan and why, or "None"]
- Key decisions: [non-obvious decisions made during implementation, or "None"]
- Dependencies added: [new external dependencies added to package.json/go.mod/requirements.txt/etc., or "None"]
```

This is written to the task file before the final commit — not after. It records what was actually built versus what was planned, and is read by future orchestrations as context.

**Do NOT write directly to `context/decisions/T-XXX.md` during implementation.** Record decisions in `## Completed` only; the Orchestrator surfaces this content to main after the PR is merged. The one exception: if you discover something affecting another module, write that to `context/discoveries/T-XXX.md` (see cross-cutting rules in always.md).
