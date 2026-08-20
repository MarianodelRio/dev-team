# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]

## [1.8.0] — current

### Fixed
- **Task-file path mismatch between branch and main (critical)** — `dt-claim.sh` pushed the lock branch *before* committing the `available/` → `in-progress/` move, so the worktree held the task file at `tasks/available/` while `main` held it at `tasks/in-progress/`. The Coder is handed the in-progress path (read from `main`) and, finding nothing there, could create a second file at that path — reproducing as `CONFLICT (add/add)` at the Phase 4 rebase, needing manual resolution. `dt-claim.sh` now fast-forwards the lock branch and the worktree onto the claim commit (no `--force`; the first push still wins the race, so the atomic lock is unchanged), leaving exactly one path for the task file on both sides. The path rule is documented where it is enforced: `coder-complete.md`, `coder.md` (both the completion section and the Rules list, since the agent definition is read even when no steering is relayed), the task-lifecycle section and Key rules of `CLAUDE.md`, and the script table in `docs/WORKFLOWS.md`.
- **`/status` elapsed time read the newest, not the oldest, commit** — the doc says "first placed the file in `tasks/in-progress/`" but `git log ... | head -1` returns the most recent match; added `--reverse`.

### Added
- **PR mergeability check** — `dt-pr.sh` polls `gh pr view --json mergeable` after pushing to main (GitHub reports `UNKNOWN` for a few seconds while it computes) and emits `PR_MERGEABLE` alongside `PR_NUMBER`/`PR_URL`. On `CONFLICTING` it keeps the worktree, since that is where the rebase has to happen; `/orchestrate` Phase 4 and `/prepare-pr` document the recovery. Detection rather than prevention: the cause of the observed `CONFLICTING` PR was never confirmed.

## [1.7.0] — 2026-08-20

### Fixed
- **Sub-agent registration (critical)** — the 12 framework agents in `.claude/agents/` declared only `model:` in their frontmatter. Claude Code registers a file as an invocable sub-agent type only when both `name` and `description` are present, so none of them were ever registered: every spawn in `/orchestrate` Phases 1–4 and `/prepare-pr` silently fell back to a generic agent with the definition pasted inline, and the per-agent `model:` routing (opus for architect/orchestrator, fable for advisor, sonnet for the rest) was never applied. Present since 1.4. All 12 agents now declare `name` (matching the filename) and a one-line `description`; `model:` values are unchanged.
- **`/bootstrap` generated unregistered project agents** — the agent-generation step never specified frontmatter, so every `[module].md` it wrote had the same defect. It now emits a required `name`/`description`/`model` template, runs a registration check before reporting success, and ensures `.claude/settings.json` exists with the spawn-depth keys.
- **`install.sh`** — when the target already had a `.claude/` directory it merged only `commands/` and `agents/`, so `steering/`, `AGENTS.md` and `settings.json` (which carries `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, required for the review-coordinator to spawn reviewers) never reached the project. All four are now merged, and the installer warns about unregistered agents and about an existing `settings.json` missing the spawn-depth key. Stale header version/URL corrected.
- **`CLAUDE.md` / `.claude/AGENTS.md` steering claim** — both stated that steering files are "injected automatically by the Claude Code harness based on their `inclusion:` frontmatter" and that the Orchestrator does not relay them. There is no harness-side injection: the Orchestrator reads the files in Phase 0 and pastes them inline into each sub-agent prompt. Documented as it actually works.
- **`context-formats.md` scope** — its `agents:` list included `review-coordinator`, which is never sent that file; aligned with what `/orchestrate` actually relays.

### Changed
- **Fourth model slot: `model.advisor`** — the `reasoning` slot mapped to three agents (advisor, architect, orchestrator) that were never on the same model, so the stored config value did not describe two of its own agents and any `/team-init` Section E change collapsed the distinction. `reasoning` is now `claude-opus-5` and covers architect + orchestrator only; the new `advisor` slot holds `claude-fable-5` for the Advisor alone. Slot documentation, the Section E mapping table, the state card and the README updated to match.
- **Models bumped to the current generation** — `claude-opus-4-8` → `claude-opus-5` (architect, orchestrator) and `claude-sonnet-4-6` → `claude-sonnet-5` (coder, planner, review-coordinator, code-quality, security, adversarial, smoke-tester, mutation-tester, spec-coverage). Advisor stays on `claude-fable-5`; project agents stay on `claude-haiku-4-5` (no Haiku 5 exists). Also updated in `devteam.config.yml` (`model.implementation`), the `/team-init` Section E menu, and the frontmatter examples in `CLAUDE.md` and `CONTRIBUTING.md`. The previous IDs were never broken — they still resolve — this is a capability upgrade, not a fix.

### Added
- Registration pre-flight checks wherever an agent is spawned or configured: `/orchestrate` Phase 0 (halts on unregistered architect/planner/coder, warns on advisor/review-coordinator), `/prepare-pr` Step 4, `review-coordinator` Phase 2 (now verifies frontmatter, not just file existence), `/team-init` Step 2b (also warns when `settings.json` lacks the spawn-depth key), and `/cheatsheet` (new "Unregistered agent" bucket).
- "Agent file format" section in `CLAUDE.md` documenting the required frontmatter and why it is load-bearing.

## [1.6.0] — 2026-08-19

### Fixed
- **Scripts** — 8 bug fixes: worktree path extraction in dt-cancel/dt-restart; remote branch deletion ordering in dt-done/dt-restart; stale `--rebuild-index` flag; false-negative in dt-ready (fetch before unpushed check); PR number validation in dt-pr; validate_id regex now accepts 1–3 digits (B-7, B-42); worktree path sanitization in dt-common; temp file cleanup trap in dt-claim; newline/tab escaping in dt-board
- **Commands** — 9 fixes: config key corrections in orchestrate/prepare-pr (`quality.review_profile`, `quality.smoke_test_mode`); find pattern slug matching; reopen/refine/restart description corrections; bug task template missing phase field; add-task counting cancelled deps as satisfied; team-init auto_merge and model menu fixes
- **Agents** — 12 fixes: orchestrator empty-board exit and retrospective injection; architect ADR placeholder and circular dependency protocol; planner contradicting folder rules; coder worktree exception and push failure path; advisor timing constraint removed; review-coordinator halt on missing agents and BLOCKED verdict for timeouts; security task_file input; adversarial full diff input; smoke-tester missing-fixtures error path; mutation-tester WEAK always BLOCKER; spec-coverage fabricated κ value replaced

### Changed
- `CLAUDE.md` updated: /reopen added to commands table, steering injection documented, PLANNED options noted
- `devteam.config.yml`: `auto_merge` values quoted, `checkpoint_timeout_minutes` added

## [1.5.0] — 2026-08-19

### Changed
- Reasoning model updated to `claude-fable-5` (advisor, architect, orchestrator)
- `dt-board.sh` — fixed array iteration and numeric ID parsing

## [1.4.0] — 2026-08-18

### Changed
- Advisor agent model updated to `claude-fable-5`

## [1.3.0] — 2026-08-18

### Added
- Steering files (`.claude/steering/`) — scoped rule injection replacing monolithic `AGENTS.md`: `always.md` and `task-format.md` injected into every agent, `context-formats.md` into orchestrator/architect/coder/planner, `coder-complete.md` into coder only
- `spec-coverage` reviewer — maps `spec.md` Logic+Interface constraints to tests in the PR diff; advisory only, never blocks; controlled by `spec_coverage_enabled` in config
- `context/retrospectives/` — persistent lessons-learned memory per role (coder, planner, architect); extracted at `/done`, injected in Phase 0 of `/orchestrate`
- `memory.retrospective_memory_enabled` and `spec_coverage_enabled` / `spec_coverage_threshold` options in `devteam.config.yml`

### Changed
- `AGENTS.md` slimmed down — content moved to steering files; now a lightweight cross-reference
- `/done` extended to extract and persist retrospective lessons
- `/orchestrate` Phase 0 injects retrospective memory into sub-agents
- `/explore`, `/bootstrap`, `/prepare-pr`, `team-init` improved
- `docs/adr/0002` updated

## [1.2.0] — 2026-08-14

### Added
- `AGENTS.md` — cross-cutting runtime reference injected into every agent session; replaces scattered inline rules across agent files
- `/reopen` command — reopens a closed or cancelled task cleanly
- review-coordinator promoted to a dedicated agent with `fast` and `full` review profiles; `fast` skips smoke/mutation/adversarial for docs and config changes, reducing token cost on low-risk PRs
- `.editorconfig` for consistent formatting across editors

### Changed
- Agent prompts refactored across the board for token efficiency — removed redundant context, tightened instructions, eliminated duplication between agents
- Many inconsistencies resolved between agent definitions, commands, and scripts (orchestrate, prepare-pr, cancel, restart, bootstrap, status, cheatsheet, done, add-task, guide, team-init)
- `devteam.config.yml` expanded with better inline documentation and new configuration options
- All `dt-*.sh` scripts hardened (dt-claim, dt-cancel, dt-restart, dt-board, dt-done, dt-pr, dt-verify, dt-ready)
- `install.sh` improved
- `CONTRIBUTING.md` updated

## [1.1.0] — 2026-08-10

### Added
- `spec.md` artifact — module-level behavioral specification generated by `/bootstrap`; bridge between `design.md` and `tasks/`
- `/refine` command — state-aware spec.md updates with propagation to affected tasks
- `/bug` and `/explore` investigation commands
- Brownfield mode in `/bootstrap` (Mode 5)
- Per-task context files (`context/decisions/T-XXX.md`, `context/discoveries/T-XXX.md`) replacing shared flat files
- `dt-pr.sh` and `dt-verify.sh` scripts
- Spec validation in Phase 1 (Architect checks task scope against spec.md)
- Final rebase before PR in `/orchestrate` and `/prepare-pr`

### Changed
- Orchestrator pipeline extended to 5 phases (Phase 0: config extraction)
- Planner receives spec.md sections as input
- Coder agent improved: layer separation, N+1 checks, strengthened test criteria

## [1.0.0] — 2026-07-24

Initial stable release.

### Added
- `/bootstrap` — conversational design session generating `design.md`, `plan.md`, tasks, and agent definitions
- `/orchestrate` — 4-phase pipeline: architect → planner → coder → parallel review
- `/done`, `/add-task` — task lifecycle commands
- `/status`, `/cheatsheet`, `/guide` — project visibility commands
- `/restart`, `/cancel`, `/prepare-pr` — recovery and escape hatch commands
- `scripts/` — `dt-claim`, `dt-ready`, `dt-done`, `dt-cancel`, `dt-restart`, `dt-board`
- `devteam.config.yml` — full configuration with inline documentation
- Agent definitions — orchestrator, architect, planner, coder, advisor, code-quality, security, adversarial, smoke-tester, mutation-tester
