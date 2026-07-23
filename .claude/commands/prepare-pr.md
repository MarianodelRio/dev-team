You are the Orchestrator running /prepare-pr in escape hatch mode.

⚠️ This command is an escape hatch. In the normal dev-team v2 flow,
reviewers run automatically at the end of /orchestrate.
Use this only for tasks that reached ready-for-pr manually
(tasks migrated from v1, recovered orphaned worktrees, etc.).

Input: $ARGUMENTS — task ID (T-XXX or B-XXX)

Your job: complete the review and open the PR for a task that is already
implemented in its branch.

---

## Step 1 — Verify task

Read `tasks/ready-for-pr/T-XXX-slug.md` (or find it if not in ready-for-pr/).

If the task is not in `status: ready-for-pr`, warn:
```
⚠️ T-XXX is currently in [status], not ready-for-pr.
Do you want to prepare the PR anyway?
```
Wait for explicit confirmation.

---

## Step 2 — Rebase

```bash
git fetch origin
git checkout feature/T-XXX-short-slug
git rebase origin/main
```

If there are conflicts:
- Mechanical (whitespace, unrelated imports, context/ append): resolve alone
- Design (contracts, business logic, schema): stop and present to the user:
  ```
  ⚠️ Design conflict in [file:line]
  
  In main ([T-YYY already merged]):
  [code]
  
  In this branch (T-XXX):
  [code]
  
  This implies [concrete trade-off]. How should we resolve it?
  ```
  Wait for direction. Apply. Continue rebase.

---

## Step 3 — Verification

```bash
[test command from devteam.config.yml]
[lint command from devteam.config.yml]
[type_check command from devteam.config.yml]
```

If anything fails: report the specific error and stop. Do not fix behavioral failures automatically.

---

## Step 4 — Reviewers in parallel

Read `quality.review_profile` in `devteam.config.yml`. Inspect the diff:

```bash
git diff --name-only origin/main
```

- `full` → all sub-agents (4a–4e)
- `fast` → code-quality + security only
- `auto` → if only docs/config changed → fast; if any code changed → full

Safety override: if the diff touches protected files or shared contracts → force full.

Launch in parallel:

**4a. code-quality** — scope, patterns from design.md, architecture, clarity

**4b. adversarial** — finds what the others missed; activates on unanimous approval

**4c. security** — OWASP Top 10 on the diff. Severity: BLOCKER | WARNING | INFO

**4d. smoke-tester** — "Done when" criteria from the task file against the running app

**4e. mutation-tester** — ONLY if `require_mutation_tests: true` OR touches critical modules

---

## Step 5 — Synthesis

BLOCKER (do not open PR):
- Any test failure not fixed in Step 3
- security: BLOCKER
- smoke-tester: criterion FAIL
- mutation score below threshold (if applicable)

WARNING (open PR with flags):
- security: WARNING
- mutation score below ideal but above minimum

APPROVED: proceed.

If there are BLOCKERs, report and stop:
```
⛔ PR blocked — resolve these before continuing:

[Blocker 1]: [description + file:line]
[Blocker 2]: [description + file:line]

Suggested fixes:
- [fix 1]
- [fix 2]

Fix in the branch and run /prepare-pr T-XXX again
```

---

## Step 6 — Open PR

Read `pr_mode` in `devteam.config.yml`.

If `pr_mode: automatic`:
```bash
gh pr create \
  --title "T-XXX: [task title]" \
  --body "$(cat <<'EOF'
## Summary
- [what was implemented — bullet 1]
- [what was implemented — bullet 2]
- [what was implemented — bullet 3]

## Acceptance criteria
- [x] criterion 1
- [x] criterion 2

## Review notes
[Code Quality: ...]
[Security: ...]
[Smoke Tests: X/Y criteria PASS]
[Adversarial: found nothing / found X — already fixed]

## Risks
[flagged warnings or "None"]

🤖 Generated with dev-team
EOF
)"
```

If `pr_mode: manual`: print the exact command for the user to run.

---

## Step 7 — Update task file

Move `tasks/ready-for-pr/` → `tasks/pr-open/`.

Update frontmatter:
```yaml
status: pr-open
pr: "[PR URL]"
```

```bash
git add tasks/pr-open/T-XXX-slug.md
git commit -m "chore(T-XXX): mark PR_OPEN — PR #[number]"
git push origin main
```

---

## Step 8 — Human reviewer summary

```
## PR Ready for Review — T-XXX

What to review:
[2-3 specific points that deserve human attention]

Acceptance criteria: [X/X passed]
Security: [clean / warnings: ...]
Adversarial: [no findings / fixed: ...]

To merge: approve on GitHub and run /done T-XXX
```

---

## Rules

- Never mark the task DONE — that is /done's job
- Never fix behavioral failures automatically — report and stop
- Never open a PR with an unresolved BLOCKER
- Diffs touching protected files or contracts always force full review
