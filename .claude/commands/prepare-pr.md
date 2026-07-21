You are executing the `/prepare-pr` command for dev-team.

**Input:** `$ARGUMENTS` — task ID (e.g., `T-026`)

Your job: review the implementation thoroughly using specialized sub-agents, fix trivial issues, and open the PR. You never mark tasks DONE — that is `/done`'s job.

---

## Step 1 — Load context

Read:
- `tasks/ready-for-pr/T-XXX-slug.md` (or find it if not in ready-for-pr/)
- The assigned agent file in `.claude/agents/`
- `design.md` — relevant sections for this task's modules
- `context/decisions.md` — entries from this task

If the task is not in `status: ready-for-pr`, warn:
```
⚠️ T-XXX is currently [status], not ready-for-pr.
Are you sure you want to prepare a PR for it?
```
Wait for explicit confirmation.

---

## Step 2 — Fetch and rebase

```bash
git fetch origin
git checkout feature/T-XXX-short-slug
git rebase origin/main
```

**If merge conflicts:**
- Mechanical conflicts (whitespace, non-overlapping additions, import order) → resolve automatically
- Design conflicts (shared contracts, business logic, schema) → **STOP**:
  ```
  ⚠️ Merge conflict in [file] requires a design decision.
  [Describe the conflict]
  How should this be resolved?
  ```
  Wait for human direction.

---

## Step 3 — Run full verification

```bash
# Tests + coverage
[test command from devteam.config.yml]

# Lint + format
[lint command]

# Type check
[type check command]
```

If anything fails:
- **Trivial** (unused import, missing type annotation, formatting) → fix automatically
- **Behavioral** (test failure, logic error) → **STOP** and report the specific failure

---

## Step 4 — Launch review sub-agents in parallel

Invoke all sub-agents simultaneously. Each runs independently.

**4a. Code Quality Agent**
Review: scope adherence, patterns from `design.md`, no business logic in HTTP layer, no magic numbers, functions ≤ ~50 lines, error handling at boundaries only.

**4b. Adversarial Agent**
Actively look for what the other reviewers might have missed. If all other agents approve, this agent's job is to find the flaw. Check: edge cases not covered by tests, hidden assumptions, subtle logic errors, performance issues under load.

**4c. Security Agent**
Check the diff against OWASP Top 10 relevant to this stack:
- Injection (SQL, command, path traversal)
- Broken authentication / exposed credentials
- Sensitive data exposure (secrets in logs, responses)
- Broken access control
- Security misconfiguration
- Insecure deserialization
Report severity: BLOCKER | WARNING | INFO

**4d. Smoke Test Agent**
Using `smoke_test_mode` from `devteam.config.yml`:
- Spin up the application
- Execute each acceptance criterion from the task file against the running app
- For external APIs: use sandbox fixtures or live test credentials per config
- Report: PASS / FAIL per criterion

**4e. Mutation Test Agent** (only if `require_mutation_tests: true` OR this task touches critical modules)
- Introduce deliberate minimal bugs in the changed code
- Re-run tests
- Report mutation score
- Flag tests that did not catch mutations

---

## Step 5 — Synthesize results

Collect all sub-agent outputs. Determine overall verdict:

**BLOCKER** — do not open PR:
- Any test failure not fixed in Step 3
- Security Agent finds BLOCKER severity issue
- Smoke Test Agent: acceptance criterion FAIL
- Mutation score below threshold (if applicable)

**WARNING** — open PR but flag prominently:
- Security Agent finds WARNING severity issue
- Mutation score below ideal but above minimum

**APPROVED** — proceed:
- All checks pass
- No blockers
- Adversarial Agent either found nothing or found only cosmetic issues

If there are BLOCKERs, report them and **STOP**:
```
⛔ PR blocked — issues must be resolved first:

[Blocker 1]: [description + file:line]
[Blocker 2]: [description + file:line]

Suggested fixes:
- [fix 1]
- [fix 2]

Fix these in the feature branch and run /prepare-pr again.
```

---

## Step 6 — Open the PR

**Human checkpoint** — read `workflow.human_checkpoint` from `devteam.config.yml`:
- `before_pr` or `both` — present the synthesized result (what was implemented + the sub-agent verdicts from Step 5) and **wait for explicit confirmation before opening the PR**.
- `before_code` — the approval gate already happened in `/orchestrate`; proceed directly.

Check `pr_mode` in `devteam.config.yml`:

**If `pr_mode: automatic`:**
```bash
gh pr create \
  --title "T-XXX: [task title]" \
  --body "$(cat <<'EOF'
## Summary
[3 bullets: what was implemented]

## Changes
[modules/files touched and why]

## Acceptance criteria
- [x] criterion 1
- [x] criterion 2

## Review notes
[From Code Quality Agent: ...]
[From Security Agent: ...]
[From Smoke Test Agent: all criteria PASS]
[Adversarial Agent: [found nothing / found X — already fixed]]

## Risks
[Any warnings or non-obvious risks flagged by sub-agents]

🤖 Generated with [dev-team](https://github.com/MarianodelRio/dev-team)
EOF
)"
```

**If `pr_mode: manual`:**
Print the exact `gh pr create` command for the human to run themselves.

---

## Step 7 — Update task file

Move task file: `tasks/ready-for-pr/` → `tasks/pr-open/`

Update frontmatter:
```yaml
status: pr-open
pr: "[PR URL]"
```

Append to task file:
```markdown
## PR Review Notes
- Code Quality: [summary]
- Security: [summary or "no issues found"]
- Smoke Tests: [X/Y criteria passed]
- Adversarial: [summary or "no issues found"]
```

```bash
git add tasks/pr-open/T-XXX-slug.md
git commit -m "chore(T-XXX): mark PR_OPEN — PR #[number]"
git push origin main
```

---

## Step 8 — Human review summary

Output a structured summary for the human reviewing the PR:

```
## PR Ready for Review — T-XXX

**What to focus on:**
[2-3 specific things worth human attention — edge cases, design decisions, anything sub-agents flagged as uncertain]

**Acceptance criteria:** [X/X passed in smoke tests]
**Security:** [clean / warnings: ...]
**Test quality:** [mutation score if run, or coverage delta]
**Adversarial finding:** [none / fixed: ...]

**To merge:** approve on GitHub and run /done T-XXX
```

---

## Rules

- **Never mark the task DONE** — that is `/done`'s job after the human merges
- **Never fix behavioral issues automatically** — report and stop
- **Always run all sub-agents** — do not skip any even if early ones pass
- **Adversarial Agent always runs** — it activates specifically on unanimous approval
- **Never open a PR with a BLOCKER** — fix first, then re-run /prepare-pr
