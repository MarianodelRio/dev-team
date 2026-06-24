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

4. If you add an agent (`.claude/agents/`), document its folder ownership and responsibilities.

5. Open a PR against `main` with a clear description of:
   - What the change does
   - Why it is needed
   - How to test it

### Commit style

Use conventional commits:
```
feat: add /restart command to reset in-progress tasks
fix: orchestrator picks blocked tasks when no available tasks exist
docs: clarify branch policy in CLAUDE.md
chore: update devteam.config.yml defaults
```

## What we are looking for

- New commands that fit the `IDEA → design → plan → implement → PR → done` lifecycle
- Improvements to existing agents (orchestrator, pr-reviewer, etc.)
- Better defaults in `devteam.config.yml`
- Documentation fixes and clarifications
- Examples: real projects built with dev-team as showcase

## What to avoid

- Changes that add external service dependencies (the framework is intentionally git-only)
- Features that require a database or dashboard
- Large refactors without prior discussion in an issue

## Questions

Open a GitHub Discussion or an issue tagged `question`.
