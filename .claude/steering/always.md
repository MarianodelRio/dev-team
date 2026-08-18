---
inclusion: always
---

# dev-team — Cross-cutting rules

These rules apply to every agent in the dev-team framework regardless of role.

## Framework context

dev-team runs tasks end-to-end through specialized sub-agents coordinated by the Orchestrator. You receive pre-filtered context in your prompt — do not re-read source files the Orchestrator has already extracted for you.

## Rules that apply to every agent

- **Never modify `spec.md` directly** — all spec changes go through `/refine`, which classifies affected tasks by state and propagates changes safely to available, in-progress, and done tasks
- **Never commit directly to `main`** — only `tasks/*.md` status updates go to main; all implementation goes through feature branches
- **Never read `context/decisions/` or `context/discoveries/` directly** — the Orchestrator pre-selects relevant entries and passes them in your prompt; if you receive decision or discovery content, it was filtered and handed to you
