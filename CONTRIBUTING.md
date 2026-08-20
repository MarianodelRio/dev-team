# Contributing to dev-team

Thank you for contributing to dev-team. This guide covers the conventions and workflows for modifying the framework itself.

---

## Naming conventions

- **Script names:** `dt-[verb].sh` — e.g. `dt-claim.sh`, `dt-done.sh`, `dt-verify.sh`
- **Agent names:** lowercase, hyphen-separated — e.g. `review-coordinator`, `code-quality`, `smoke-tester`
- **Task IDs:** `T-NNN` for feature tasks, `B-NNN` for bug tasks (three-digit zero-padded)
- **Branch names:** `feature/T-NNN-short-slug` or `fix/B-NNN-short-slug`

### Reserved agent names

The following names are reserved for framework agents and must not be used for project-generated agents:

```
orchestrator, architect, planner, coder, advisor,
review-coordinator, code-quality, security, adversarial,
smoke-tester, mutation-tester
```

---

## How to test framework changes

### Commands (`.claude/commands/`)

Commands are Markdown files that define prompts executed by Claude Code. To test a command change:

1. Make your edit to the relevant `.claude/commands/name.md` file.
2. Open a Claude Code session in a test repository that has dev-team installed.
3. Run `/name` and verify the behavior matches the updated spec.
4. Test edge cases: missing files, unexpected task states, empty config values.

There is no automated test runner for commands — testing is conversational and observational.

### Agents (`.claude/agents/`)

Agent definitions are Markdown files consumed by Claude Code when spawning sub-agents. To test an agent change:

1. Edit the relevant `.claude/agents/name.md`.
2. Trigger the flow that invokes the agent (e.g. run `/orchestrate` to invoke the Architect, Planner, and Coder in sequence).
3. Verify the agent behaves according to its updated instructions.

When changing agent inputs or outputs, also check the calling command or agent (e.g. changing the Architect's output format requires updating `orchestrate.md` to match).

### Scripts (`scripts/`)

Scripts are Bash files that perform mechanical git/filesystem operations. To test a script change:

1. Edit the relevant `scripts/dt-*.sh`.
2. Run the script directly in a test repository:
   ```bash
   bash scripts/dt-claim.sh T-001
   bash scripts/dt-done.sh T-001 https://github.com/org/repo/pull/42
   ```
3. Verify the output messages and filesystem/git state match expectations.
4. Test failure paths: missing task file, wrong task state, network failure.

All scripts use `set -e` and should produce clear error messages on failure. Use `bash -x` for step-by-step tracing during debugging.

---

## How to add a new command

1. Create `.claude/commands/name.md` with the command prompt content.
2. Register the command in the `## Available commands` table in `CLAUDE.md`.
3. If the command is user-facing, add it to the commands list in `README.md`.
4. If the command requires a new skill entry, add it to `.claude/settings.json` under `skills`.

Command files follow this structure:

```markdown
# /command-name

Brief description of what this command does.

## When to use
...

## Steps
1. ...
2. ...
```

---

## How to add a new agent

1. Create `.claude/agents/name.md`. The filename must match the name used when spawning the agent.
2. Do not use any name from the reserved list above.
3. Document the agent's inputs, outputs, folder ownership, and decision rules clearly.
4. If the agent is invoked by a command or another agent, update that file to reference the new agent name.
5. If the agent needs specific tool permissions, update `.claude/settings.json`.

Agent files follow this structure:

```markdown
---
model: claude-sonnet-5    # or claude-opus-5 for reasoning-heavy agents
tools: [Read, Edit, Bash]
---

# Agent Name

Brief description.

## Inputs
...

## Outputs
...

## Rules
...
```

---

## Making changes to shared contracts

**Protected files** — `design.md`, `spec.md`, `plan.md`, and any file listed under `protected_files` in `devteam.config.yml` — require special care:

- Never edit `spec.md` directly; use `/refine`.
- Changes to shared contracts must be propagated to all consuming modules.
- If a change affects in-progress tasks, write a discovery to `context/discoveries/T-XXX.md` for each affected task.

---

## Commit style

Follow the existing commit style visible in `git log`. Keep commit messages concise and focused on intent, not mechanics. One logical change per commit.
