# Changelog

All notable changes to dev-team will be documented in this file.

## [1.0.0] — 2026-07-24

Initial stable release of the dev-team framework.

### What's included

- **`/bootstrap`** — conversational design session that generates `design.md`, `plan.md`, tasks, and agent definitions from a vague idea
- **`/orchestrate`** — full 4-phase pipeline: architect analysis → planner → coder → parallel PR review (code quality, security, adversarial, smoke test, mutation test)
- **`/done`, `/add-task`, `/bug`, `/explore`** — task lifecycle management commands
- **`/status`, `/cheatsheet`, `/guide`** — project visibility commands
- **`/restart`, `/cancel`, `/prepare-pr`** — recovery and escape hatch commands
- **`scripts/`** — canonical state transition scripts: `dt-claim`, `dt-ready`, `dt-done`, `dt-cancel`, `dt-restart`, `dt-board`
- **`devteam.config.yml`** — full configuration with inline documentation
- **Agent definitions** — orchestrator, architect, planner, coder, advisor, code-quality, security, adversarial, smoke-tester, mutation-tester
- **Branch policy** — one worktree per task, `feature/T-XXX` branches, direct push of task metadata to `main`
- **Quality gates** — linting, type checking, coverage threshold, no secrets, protected files, auto-merge rules
