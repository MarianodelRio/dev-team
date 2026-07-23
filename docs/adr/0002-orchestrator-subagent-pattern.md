# ADR 0002 — Orchestrator as Sub-agent Coordinator

**Date:** 2026-07-23
**Status:** Accepted

## Context

dev-team v1 used a monolithic orchestrator that performed all phases of a task
in a single session: analysis, planning, coding, testing, and quality review.
The PR review phase was a separate manual command (/prepare-pr) that the user
had to remember to run.

This created context bloat (one session held planning context, code context,
and review context simultaneously), unclear responsibility boundaries, and
required user intervention between implementation and review.

## Decision

Refactor the orchestrator into a coordinator that delegates to specialized
sub-agents:

- **Architect** (existing): validates the task against current project state
- **Planner** (new): produces the concrete implementation plan
- **Coder** (new): implements in an isolated worktree
- **Reviewers** (existing, now called directly): run in parallel at the end

The PR review phase is absorbed into /orchestrate — the user no longer runs
/prepare-pr as a normal step. /prepare-pr becomes a manual escape hatch.

## Consequences

- Each sub-agent has a focused context window (planning context ≠ coding context)
- The user has one human checkpoint (after analysis, before code) instead of
  managing multiple commands
- /prepare-pr is demoted to escape hatch; pr-reviewer agent is removed
- New agents (planner, coder) must be created
- orchestrator.md and orchestrate.md must be fully rewritten
- The Advisor remains a shared resource available to any sub-agent

## What does NOT change

- Git worktree isolation per task
- Atomic task claim via branch push
- Task file lifecycle (available → in-progress → pr-open → done in normal /orchestrate flow;
    ready-for-pr exists as an escape hatch state for /prepare-pr)
- context/ append-only pattern with git pull before write
- The /done command and post-merge flow
- All seven framework agents (architect, advisor, and the five review agents: code-quality,
  security, adversarial, smoke-tester, mutation-tester)
