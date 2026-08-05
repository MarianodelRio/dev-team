# ADR 0003 — Per-task context files

**Date:** 2026-08-05
**Status:** Accepted

## Context

The original design (ADR 0001, Decision 5) stored agent coordination data in two shared flat files: `context/decisions.md` and `context/discoveries.md`. All agents appended to these files as they implemented their tasks.

In practice, every feature branch touched the same two files. When one branch merged to main, all other in-progress branches had a mechanical conflict in `context/` on their next rebase — even though the changes were pure appends with no logical overlap. The Orchestrator classified these as mechanical conflicts and resolved them alone, but the friction was constant and unnecessary.

## Decision

Replace the two shared flat files with per-task files in subfolders:

- `context/decisions/T-XXX.md` — decisions made during task T-XXX
- `context/discoveries/T-XXX.md` — cross-module alerts found during task T-XXX

Each task's implementing agent creates and writes only to its own files. No two branches ever touch the same context file, eliminating the conflict entirely.

**Read logic** (Orchestrator, Phase 1):
- **Decisions:** read `context/decisions/T-YYY.md` for tasks in `done/` and `in-progress/` whose `folders:` overlap with the current task's `folders:`
- **Discoveries:** read all `context/discoveries/T-YYY.md` files across done and in-progress tasks; surface entries with `Status: open` (no folder filter — discoveries are cross-module alerts by definition)

The selected content is passed to the Architect and Planner. Agents do not read the context folders directly.

## Consequences

- Zero rebase conflicts on context files — each branch owns its own file exclusively
- Navigation changes: instead of one file per type, context is browsed per task (`context/decisions/` folder)
- `cat context/decisions/*.md` or a simple glob gives the aggregated view when needed
- `install.sh` creates the subdirectories with `.gitkeep`; no template files needed (agents create task files at first write)
- 13 files updated: agents (coder, code-quality, planner, orchestrator), commands (orchestrate, explore, guide, prepare-pr), CLAUDE.md, install.sh, ADR 0001, ADR 0002, design_v2.md

## Discarded

**Git union merge driver** (`context/*.md merge=union` in `.gitattributes`): keeps flat files and handles appends automatically. Discarded because it requires setup on every clone and worktree, is fragile when appends land in overlapping line ranges, and adds infrastructure complexity without eliminating the root cause.
