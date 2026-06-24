# ADR 0001 — Core Framework Design Decisions

**Date:** 2026-06-24
**Status:** Accepted
**Author:** Mariano del Rio

---

## Context

dev-team is a framework for parallel, spec-driven software development using AI agents. Several foundational design choices were made early that shape every other aspect of the framework. This ADR records those decisions and their rationale so future contributors understand the constraints and can evaluate changes against them.

---

## Decision 1 — Git worktrees for parallelism

**Chosen:** Each in-progress task runs in its own git worktree (`../project-T-XXX/`).

**Why:** Multiple agents need to write code simultaneously without stepping on each other. Separate worktrees give each agent a fully independent working directory and staging area, sharing only the `.git` database. This avoids the complexity of container orchestration, network coordination, or file locking while keeping everything local and auditable via normal git commands.

**Discarded:** Running agents in the same working directory with file-level locking — too error-prone. Docker containers per task — adds infrastructure dependency, slows setup, requires credentials management.

---

## Decision 2 — Markdown + YAML frontmatter for tasks

**Chosen:** Each task is a `.md` file with YAML frontmatter (`id`, `status`, `depends_on`, `agent`, etc.) living in `tasks/<status>/`.

**Why:** Markdown is readable by humans and agents without tooling. YAML frontmatter gives machine-parseable structured data without a database. Moving a file between `tasks/available/` and `tasks/in-progress/` is both a visual signal (visible in any file browser) and a machine-readable state transition. Git history naturally tracks all state changes with authorship and timestamps.

**Discarded:** SQLite or JSON database — requires a daemon or sync mechanism, breaks the "single source of truth is git" principle. Dedicated task tracking service (Linear, Jira) — adds external dependency, requires credentials, doesn't survive offline work.

---

## Decision 3 — Mandatory human checkpoints

**Chosen:** Agents must present their implementation plan and wait for human approval before writing code (configurable to also checkpoint before opening the PR).

**Why:** AI agents make confidently wrong decisions. A checkpoint costs 30 seconds and catches misunderstood scope, wrong architecture choices, or unnecessary complexity before hours of implementation. The checkpoint also keeps the human in the loop without requiring them to micromanage — they review intent, not every line.

**Discarded:** Fully autonomous mode with no checkpoints — too risky for production codebases where a wrong assumption in a task compounds across dependent tasks. Post-implementation review only — by then the cost of a redirect is much higher.

---

## Decision 4 — Strict folder ownership per agent

**Chosen:** Each agent is assigned specific folders and must never write outside them, even if it sees an obvious improvement in another module.

**Why:** Parallel agents without ownership boundaries create race conditions, conflicting edits, and cross-cutting concerns that nobody owns. Strict ownership means merge conflicts are rare, each agent can reason about its module without knowing the full codebase, and blame is always clear. The constraint also forces good module design — if an agent constantly needs to touch another agent's folder, the boundary is wrong.

**Discarded:** Shared ownership with coordination protocol — requires synchronization, slows parallelism. No ownership (any agent can touch anything) — works at small scale, breaks as soon as two agents pick up tasks touching the same file.

---

## Decision 5 — `context/` separate from `docs/`

**Chosen:** Agent coordination files (`decisions.md`, `discoveries.md`) live in `context/`, not `docs/`.

**Why:** `context/` is operational — it is written during development and read by agents at task start to avoid duplicate decisions and surface cross-module issues. `docs/` is product — it documents what was built, for users and future maintainers. Mixing them blurs the audience and lifecycle. An agent reading `context/` should find fresh, actionable information; an agent reading `docs/` should find stable, authoritative reference material.

**Discarded:** Single `docs/` tree for everything — `decisions.md` gets buried, agents skip it. External wiki — adds dependency, diverges from the codebase over time.

---

## Consequences

- The framework has no runtime dependencies beyond git and Claude Code.
- Adding a new coordination mechanism (e.g., agent-to-agent messaging) must fit into markdown files committed to git — no external services.
- Any change to task schema (frontmatter fields) is a breaking change for existing projects using the framework.
- Human checkpoints are non-optional by design; `devteam.config.yml` controls *when* they trigger, not *whether* they trigger.
