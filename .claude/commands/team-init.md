You are executing the `/team-init` command for dev-team.

Your job: configure this project and show its current state. This is a setup and orientation command — not a design session. Keep it fast (under 5 minutes) and conversational.

`/team-init` is safe to run multiple times. It never overwrites existing content without asking.

---

## Step 1 — Read current state

Read the following files (if they exist):
- `devteam.config.yml`
- `IDEA.md`
- `design.md`
- `plan.md`
- All files in `tasks/available/`, `tasks/in-progress/`, `tasks/done/`

Count tasks per folder. Note which fields in `devteam.config.yml` are empty or default (project.name == "" is a reliable signal of a fresh install).

---

## Step 2 — Show current state

Print a state card before asking anything:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  dev-team /team-init
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: [name from config, or "not set"]
Stack:   [stack from config, or "not set"]
Type:    [project.type from config, or "not set"]
Stage:   [see stage rules below]

Docs
  IDEA.md     [empty / has content]
  design.md   [missing / exists] [· testing strategy ✓/✗ · doc plan ✓/✗ if design.md exists]
  spec.md     [missing / exists]
  plan.md     [missing / exists]

Tasks
  Available:   N
  In progress: N
  Done:        N / total

Config
  Models:      reasoning=[model] · implementation=[model] · fast=[model]
  PR mode:     [automatic / manual]
  Checkpoint:  [before_code / before_pr / both]
  Parallel:    [orchestration.max_parallel_tasks from config, default: 5]
  Quality:     coverage=[N]% · security=[on/off] · smoke=[on/off] · mutation=[on/off] · spec-coverage=[on/off]
  Memory:      retrospective=[on/off]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Stage rules** (derive from what exists):

| State | Label |
|-------|-------|
| config empty, IDEA.md empty | `Fresh install — not configured` |
| config set, IDEA.md has content, no design.md | `Idea defined — ready for /bootstrap` |
| design.md exists, no spec.md, no tasks | `Design done — run /bootstrap to generate spec + tasks` |
| design.md exists, spec.md exists, no tasks | `Spec ready — run /bootstrap to generate tasks` |
| tasks exist, none in-progress or done | `Planned — ready for /orchestrate` |
| tasks in-progress or done > 0 | `In progress — N/total complete` |
| all tasks done | `Complete` |

---

## Step 2b — Validate configuration

After displaying the state card, check these two config values and warn inline if they are invalid. Run silently — only print output when a problem is found.

**`review_profile`** must be one of `full`, `fast`, or `auto`:
```bash
CFG_REVIEW_PROFILE=$(grep -E '^  review_profile:' devteam.config.yml | awk '{print $2}')
```
If the value is not empty and not one of the three valid options, print:
```
⚠️  WARNING: review_profile '[value]' is not valid. Accepted values: full | fast | auto
```

Skip this check if the field is empty, `~`, or absent from the config.

---

## Step 3 — Ask what to configure

```
What would you like to configure?

  A) Everything — walk me through full setup
  B) Project basics — name, stack, idea
  C) Workflow — PR mode, checkpoints, parallelism
  D) Quality gates — coverage, security, smoke tests, mutation tests, spec coverage
  E) Models — which AI models to use
  F) Memory — retrospective lessons across tasks
  G) Nothing — just show me the state above

[or type what you want to change directly]
```

Wait for response. If the user says G or presses enter without input, skip to Step 5.

If the user types something free-form (e.g. "set pr to manual and parallelism to 5"), interpret it directly and apply the changes without going through the menu.

---

## Step 4 — Configure the selected sections

Run only the sections the user selected. Each section is a short conversation.

---

### Section B — Project basics

Ask:
```
Project name: [current value or blank]
Stack (python / typescript / go / rust / mixed): [current value or blank]
```

If IDEA.md is empty or has less than 2 sentences:
```
Describe what you're building in 1-3 sentences.
(This goes into IDEA.md — you can expand it later with /bootstrap)
```

Write responses to `devteam.config.yml` and `IDEA.md` immediately. Confirm:
```
✓ Project name set to "[name]"
✓ Stack set to "[stack]"
✓ IDEA.md updated
```

---

### Section C — Workflow

Present current values and ask for changes:

```
PR mode
  automatic — agent opens the PR directly
  manual    — agent prepares everything, you run the gh command
  Current: [value]  →  keep or change?

Human checkpoint
  before_code — approve the plan before the agent writes any code  ← recommended
  before_pr   — approve the result before the PR is opened
  both        — checkpoint at both points
  Current: [value]  →  keep or change?

Advisor (uses the reasoning model — more powerful but slower)
  high_risk — consult for shared contracts, schema changes, architecture  ← recommended
  always    — consult for every task
  never     — skip Advisor entirely
  Current: [value]  →  keep or change?

Auto-merge (merge low-risk PRs automatically once checks pass)
  off — you merge every PR manually  ← recommended default
  on  — auto-merge after all checks pass (needs pr_mode: automatic)
  Current: [value]  →  keep or change?
```

Accept answers one question at a time or all at once. Write to `devteam.config.yml`.

---

### Section D — Quality gates

```
Test coverage threshold (0–100, default 70)
  Current: [value]%  →  keep or change?

Review profile (controls which review sub-agents the review-coordinator runs)
  full — all applicable agents  ·  fast — code quality + security  ·  auto — scales to the diff  ← recommended
  (protected files / contracts always force full; spec-coverage runs when spec_coverage_enabled: true regardless of profile)
  Current: [value]  →  keep or change?

Security scan on every PR (OWASP Top 10 + AI/agentic risks)
  Current: [on/off]  →  keep or change?

Smoke tests (spin up app, test acceptance criteria)
  Current: [on/off]
  Mode: sandbox (fixtures) / live (real API with .env.test)
  →  keep or change?

Mutation testing (verifies tests catch real bugs — expensive, for critical modules)
  Current: [on/off]
  Threshold if on: [value]%
  →  keep or change?
```

If the user asks what any of these does, explain briefly before continuing.

Write to `devteam.config.yml`.

---

### Section E — Models

```
Three model slots, each can be any Claude model or an alternative:

  reasoning     → architecture, Advisor, design decisions, task coordination
                  (applies to: advisor.md, architect.md, orchestrator.md)
  Current: [value]

  implementation → writing code, implementing tasks
                   (applies to: planner.md, coder.md, code-quality.md,
                    adversarial.md, security.md, smoke-tester.md, mutation-tester.md)
  Current: [value]

  fast          → project-specific agents generated by /bootstrap
  Current: [value]

Available Claude models:
  claude-fable-5     — default reasoning model (current default for Orchestrator, Architect)
  claude-opus-4-8    — high-capability alternative
  claude-sonnet-4-6  — balanced
  claude-haiku-4-5   — fastest

Alternatives (if you use other providers):
  openai/gpt-4o | openai/gpt-4o-mini | google/gemini-2.5-pro | local/ollama:[model]

Change any or all three:
```

Write each changed value to `devteam.config.yml`. Then **also update the `model:` field in the matching agent frontmatter files** — Claude Code reads the model from the frontmatter, not from the config:

| Slot | Agent files to update |
|------|-----------------------|
| `reasoning` | `.claude/agents/advisor.md`, `.claude/agents/architect.md`, `.claude/agents/orchestrator.md` |
| `implementation` | `.claude/agents/planner.md`, `.claude/agents/coder.md`, `.claude/agents/review-coordinator.md`, `.claude/agents/code-quality.md`, `.claude/agents/adversarial.md`, `.claude/agents/security.md`, `.claude/agents/smoke-tester.md`, `.claude/agents/mutation-tester.md`, `.claude/agents/spec-coverage.md` |
| `fast` | any `[module].md` agents generated by `/bootstrap` for this project |

For each file: open it, find the `model: [old-value]` line inside the `---` frontmatter block, replace it with `model: [new-value]`. Confirm to the user which files were updated.

---

### Section F — Memory

```
Retrospective memory — persist lessons learned from completed tasks
  When enabled, /done extracts non-trivial lessons from each task's ## Completed section,
  decisions, and discoveries, writing them to context/retrospectives/{coder,planner,architect}.md.
  /orchestrate injects the relevant role's lessons into each sub-agent's prompt.
  Lessons require a verbatim Signal quote from source documents to prevent confabulation.
  Max 25 entries per role; lowest-weight entries pruned when limit is reached.

  Current: [on/off]  →  keep or change?
```

Write to `devteam.config.yml` under `memory.retrospective_memory_enabled` (true/false).

---

## Step 5 — Show next steps

After applying changes (or immediately if user chose F), print:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  What's next
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then print **exactly one** of these blocks based on the current stage:

**Fresh install — not configured:**
```
  1. Fill in your idea: edit IDEA.md or run /team-init again (option B)
  2. Run /bootstrap — design session → architecture + tasks generated
```

**Idea defined — ready for /bootstrap:**
```
  → Run /bootstrap to generate architecture, plan, and tasks
```

**Design done — run /bootstrap to generate spec + tasks:**
```
  → Run /bootstrap (it will detect your design.md, generate spec.md, then generate tasks)
```

**Spec ready — run /bootstrap to generate tasks:**
```
  → Run /bootstrap (it will detect your spec.md and go straight to task generation)
```

**Planned — ready for /orchestrate:**
```
  → Run /orchestrate — agents will start implementing tasks
  Available now: T-XXX — [first available task title]
```

**In progress:**
```
  N tasks complete · M in progress · K available
  → Run /orchestrate to pick up the next available task
  → Run /status for the full board
```

**Complete:**
```
  All tasks done. Project complete.
  → Run /guide to see what was built and how to run it
```

---

## Rules

- Never skip Step 2 — always show the state card first, even if the user passed arguments
- Never overwrite IDEA.md content that already has more than a title — ask first
- Never change model names unless the user explicitly types one — don't suggest replacements unprompted
- Write config changes immediately after each section, before moving to the next
- If `$ARGUMENTS` is passed (e.g. `/team-init workflow`), jump directly to that section after showing the state card
- Keep the whole interaction under 10 back-and-forths for a full setup
