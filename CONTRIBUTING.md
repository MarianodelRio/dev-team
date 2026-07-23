# Contributing to dev-team

Thank you for your interest in contributing to dev-team. This document explains how to get involved.

## Code of Conduct

Be respectful and constructive. We welcome contributors regardless of experience level, background, or perspective. Harassment of any kind is not tolerated.

## How to contribute

### Reporting bugs

Open an issue with:
- A clear title
- Steps to reproduce
- What you expected vs. what happened
- Your OS, shell, and Claude Code version

### Suggesting features

Open an issue tagged `enhancement`. Describe the problem you're solving, not just the solution.

### Submitting a pull request

1. Fork the repository and create a branch from `main`:
   ```
   git checkout -b feat/your-feature-name
   ```

2. Make your changes. Keep PRs focused — one concern per PR.

3. If you add or change a command (`.claude/commands/`), update `CLAUDE.md` and `README.md` to reflect it.

4. If you add an agent (`.claude/agents/`), document its folder ownership, responsibilities, and which phase of the orchestration pipeline it belongs to.

5. Open a PR against `main` with a clear description of:
   - What the change does
   - Why it is needed
   - How to test it

### Commit style

**Human contributions to this repository** use conventional commits:
```
feat: add /restart command to reset in-progress tasks
fix: orchestrator picks blocked tasks when no available tasks exist
docs: clarify branch policy in CLAUDE.md
chore: update devteam.config.yml defaults
```

Note: the framework generates two different commit formats inside the projects that use dev-team — `T-XXX: description` for implementation commits (by the Orchestrator) and `chore(T-XXX): ...` for status transitions (by the dt-* scripts). Those are intentional framework conventions; this conventional-commits rule applies only to contributions to the dev-team repo itself.

### Agent roles

Agents in dev-team have specific roles in the orchestration pipeline:

- **Coordinator**: the orchestrator — one per /orchestrate session
- **Phase agents**: architect (phase 1), planner (phase 2), coder (phase 3)
- **Shared resource**: advisor — any agent can invoke it
- **Review agents**: code-quality, security, adversarial, smoke-tester, mutation-tester (phase 4)

When adding a new agent, define clearly which phase it belongs to, who invokes it,
and what its output format is. Agents should never exceed their phase scope
(e.g., a planner should not write production code).

## What we are looking for

- New phase agents that fit the coordinator pattern (analyze → plan → code → review)
- Improvements to existing agents within their defined role
- Better defaults and timeout values in `devteam.config.yml`
- Documentation fixes and clarifications
- Examples: real projects built with dev-team as showcase

## What to avoid

- Changes that add external service dependencies (the framework is intentionally git-only)
- Features that require a database or dashboard
- Large refactors without prior discussion in an issue

## Questions

Open a GitHub Discussion or an issue tagged `question`.
