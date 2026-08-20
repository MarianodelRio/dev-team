---
inclusion: agentMatch
agents: [coder]
---

# Completion obligation

Before your final commit, you **must** append a `## Completed` section to the task file in the worktree.

**Locate that file, do not assume its path.** The task file you were given in your prompt was read from `main`, where it lives under `tasks/in-progress/`. The worktree may hold it under a different folder, because `main` moves the file between `tasks/*/` folders as the task advances. Find the one that is actually there:

```bash
git ls-files 'tasks/*/T-XXX.md'
```

Append to the path that command prints, in place. **Never create the file at another path and never move it** — `main` owns those folder moves, and a second copy at the folder `main` is using becomes an add/add conflict at the review rebase that a human has to resolve by hand. If the command prints nothing, stop and report it as a blocker instead of creating the file.

The section to append:

```markdown
## Completed
- What was implemented (summary of deliverables)
- Deviations from plan: [any significant changes from the Planner's plan and why, or "None"]
- Key decisions: [non-obvious decisions made during implementation, or "None"]
- Dependencies added: [new external dependencies added to package.json/go.mod/requirements.txt/etc., or "None"]
```

This is written to the task file before the final commit — not after. It records what was actually built versus what was planned, and is read by future orchestrations as context.

**Do NOT write directly to `context/decisions/T-XXX.md` during implementation.** Record decisions in `## Completed` only; the Orchestrator surfaces this content to main after the PR is merged. The one exception: if you discover something affecting another module, write that to `context/discoveries/T-XXX.md` (see cross-cutting rules in always.md).
