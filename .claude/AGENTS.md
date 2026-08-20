# dev-team — Agent Reference

> Content has moved to `.claude/steering/`. The `inclusion:` frontmatter in each steering
> file declares its intended scope; the **Orchestrator** is what actually relays them — it
> reads the files in Phase 0 and pastes the relevant ones inline at the top of each
> sub-agent prompt. There is no automatic harness-side injection.
>
> - `always.md` — cross-cutting rules (all agents)
> - `task-format.md` — task frontmatter schema (all agents)
> - `context-formats.md` — context file formats (orchestrator, architect, coder, planner)
> - `coder-complete.md` — completion obligation (coder only)

## Agent files

Agent definitions live in `.claude/agents/`. Each file must declare `name` (equal to the
filename without `.md`) and `description` in its frontmatter, or Claude Code will not
register it as an invocable sub-agent type — see the "Agent file format" section of
`CLAUDE.md`.
