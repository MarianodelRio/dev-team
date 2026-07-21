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

Read all files in `tasks/available/`. For each:
- Check `depends_on` in frontmatter — all must be `done` (file must be in `tasks/done/`)
- Check that no remote branch `origin/feature/T-XXX-*` exists for it

```bash
git branch -r | grep "origin/feature/"
```

If a remote branch exists for a task, it's claimed — skip it.

**Selection criteria** (in order):
1. All dependencies DONE
2. No remote branch (unclaimed)
3. Prefer the task that unblocks the most others
4. Prefer smaller size (S before M before L)

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

1. Update the task file frontmatter: `status: in-progress`
2. Move the file: `tasks/available/T-XXX-slug.md` → `tasks/in-progress/T-XXX-slug.md`
3. Create and push the branch:

```bash
git checkout -b feature/T-XXX-short-slug
git add tasks/in-progress/T-XXX-slug.md
git commit -m "chore(T-XXX): claim [IN_PROGRESS]"
git push -u origin feature/T-XXX-short-slug
```

**If push fails**: another agent claimed this task. Go back to Step 1 and pick a different task.

4. Create a git worktree for isolated development:

```bash
git worktree add ../[project-name]-T-XXX feature/T-XXX-short-slug
```

All implementation work happens in `../[project-name]-T-XXX/`. The main repo stays on main.

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

1. Remove the worktree:
```bash
cd ../[project-name]
git worktree remove ../[project-name]-T-XXX
```

2. Update task status on main:
```bash
git checkout main
git pull origin main --ff-only
```

Edit the task file:
- Update frontmatter: `status: ready-for-pr`
- Move file: `tasks/in-progress/T-XXX-slug.md` → `tasks/ready-for-pr/T-XXX-slug.md`
- Append the **Completed** section:

```markdown
## Completed
- [what was implemented exactly]
- [what changed from the original plan, if anything]
- [decisions made and why]
```

```bash
git add tasks/ready-for-pr/T-XXX-slug.md
git commit -m "chore(T-XXX): mark READY_FOR_PR"
git push origin main
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
