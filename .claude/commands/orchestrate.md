You are executing the `/orchestrate` command for dev-team.

Your job: find the best available task, present a plan to the human, get approval, implement it, and mark it READY_FOR_PR. You stop there — you never open PRs.

---

## Step 0 — Sync with main

```bash
git fetch origin
git checkout main
git pull origin main --ff-only
```

If pull fails (not fast-forward), stop and tell the human to resolve the divergence.

---

## Step 1 — Find the best available task

Regenerate and read the index — it already resolves dependencies, marks claimed tasks from remote branches, and precomputes how many tasks each one unblocks:

```bash
bash scripts/dt-board.sh
```

Read `.dt-index.json`. Candidate tasks are those with `folder: "available"`, `claimed_remote: false`, and `agent` not equal to `"TBD"`. Tasks with `agent: TBD` are bug investigation tasks owned by `/bug` — skip them.

**Selection criteria** (in order):
1. `folder: available` (dependencies already resolved by the board)
2. `claimed_remote: false` (unclaimed)
3. Prefer the task with the most `unblocks` (the board's `critical_path_next` is the top pick)
4. Prefer smaller size (S before M before L)

The index only *prioritises*. The real claim lock is the branch push in Step 4 — if two chats pick the same task, `dt-claim` lets only one win.

If no tasks are available, report:
```
No tasks available right now.
[List any in-progress tasks and their branches]
[List blocked tasks and what's blocking them]
```

---

## Step 2 — Study the task

Read:
- The full task file
- The assigned agent file in `.claude/agents/`
- Relevant sections of `design.md`
- `context/decisions.md` — entries relevant to this task's modules
- `context/discoveries.md` — any OPEN entries targeting this task's agent

---

## Step 3 — Advisor consultation and human checkpoint

**Advisor** — read `workflow.require_advisor` from `devteam.config.yml`:
- `never` — skip the Advisor entirely.
- `always` — consult the Advisor for every task.
- `high_risk` (default) — consult the Advisor only if the task involves any of:
  - Changes to shared contracts (models, schemas, types)
  - New public API endpoints
  - Database schema changes
  - Authentication or permissions
  - Shared infrastructure changes

**Human checkpoint** — read `workflow.human_checkpoint` from `devteam.config.yml`:
- `before_code` (default) or `both` — present the plan below and **wait for explicit confirmation before writing any code**. Do not proceed until confirmed.
- `before_pr` — the approval gate is deferred to `/prepare-pr`. Present the plan below for visibility, but you may proceed to Step 4 without waiting.

Present to the human:

```
Task: T-XXX — [title]
Agent: [agent name] | Size: [S/M/L] | Phase: [N]

Plan:
- [what will be implemented — 3-5 bullets at file/function level]
- [key structural decisions]
- [non-obvious choices]

[If open discoveries affect this task:]
⚠️ Open discovery: [summary from context/discoveries.md]

[If Advisor was consulted:]
Advisor recommends: [one-sentence summary]

Questions: [genuine ambiguities, or "None"]
```

If `human_checkpoint` includes a pre-code gate (`before_code` or `both`): **wait for explicit human confirmation. Do not proceed until confirmed.**

If the human redirects, return to Step 2 with the new direction.

---

## Step 4 — Claim the task (atomic)

Run the claim script — it sets `status: in-progress`, creates the atomic lock branch, sets up the worktree, and records IN_PROGRESS on main in one reliable step:

```bash
bash scripts/dt-claim.sh T-XXX
```

**If it exits non-zero** (message "already claimed"): another agent got there first. Go back to Step 1 and pick a different task.

On success, all implementation work happens in the worktree it created (`../[project-name]-T-XXX/`). The main repo stays on main.

---

## Step 5 — Implement

Work in the worktree. Follow strictly:
- Only write to the folders listed in `folders:` in the task frontmatter
- Follow patterns established in `design.md` and `context/decisions.md`
- Do not modify shared contracts without explicit human approval
- Do not touch files outside assigned folders — even if you see an improvement

**Write tests as you implement**, not after — following the **Testing strategy in `design.md`** for this module (it defines which test types this module needs and whether it's a critical module):
- Unit tests for every new function
- The test types the strategy assigns to this module (integration, e2e, property-based as applicable) — critical modules get the stricter set
- Put fixtures/test doubles where the strategy says (e.g. `tests/fixtures/`); tests must not make real network calls

If you discover something that affects another module, write it to `context/discoveries.md` — do not touch the other module.

If you make a non-obvious decision, write it to `context/decisions.md`.

---

## Step 6 — Verify

Run all checks from the worktree. All must pass:

```bash
# Tests
[test command from devteam.config.yml or detected from stack]
# e.g.: pytest --cov=src --cov-fail-under=70
# e.g.: npm test -- --coverage

# Linting
[lint command]
# e.g.: ruff check . && ruff format --check .
# e.g.: npm run lint

# Type checking
[type check command]
# e.g.: mypy src/
# e.g.: npx tsc --noEmit
```

Fix ALL failures before continuing. Do not commit failing code.

---

## Step 7 — Commit and push

```bash
cd ../[project-name]-T-XXX
git add [specific files — never git add -A]
git commit -m "T-XXX: [short description of what was implemented]"
git push origin feature/T-XXX-short-slug
```

---

## Step 8 — Mark READY_FOR_PR and clean up

1. First append the **Completed** section to the task file in `tasks/in-progress/T-XXX-slug.md` (the script preserves this content when it moves the file):

```markdown
## Completed
- [what was implemented exactly]
- [what changed from the original plan, if anything]
- [decisions made and why]
```

2. **Return to the main repo before running the script** — `dt-ready.sh` uses `git rev-parse --show-toplevel` to locate the repo; running it from inside the worktree points it at the wrong directory and breaks `sync_main()`:

```bash
cd ../[project-name]          # ← back to main repo, not the worktree
bash scripts/dt-ready.sh T-XXX
```

3. Report to human and **STOP**:
```
T-XXX is READY_FOR_PR.
Branch: feature/T-XXX-short-slug
[Any notes from implementation worth flagging]

Next: run /prepare-pr T-XXX when you're ready to review.
```

---

## Rules

- **Never open a PR** — that is `/prepare-pr`'s job
- **Never work directly on main** — always use a worktree on the feature branch
- **Never use `git add -A` or `git add .`** — stage specific files only
- **Never skip the human checkpoint** when `workflow.human_checkpoint` includes a pre-code gate (`before_code` or `both`) — not even for small tasks
- **Never touch files outside assigned folders** — write to `context/discoveries.md` instead
- **Always write tests in the same PR** as the implementation
