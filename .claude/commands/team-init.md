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
  plan.md     [missing / exists]

Tasks
  Available:   N
  In progress: N
  Done:        N / total

Config
  Models:      reasoning=[model] · implementation=[model] · fast=[model]
  PR mode:     [automatic / manual]
  Checkpoint:  [before_code / before_pr / both]
  Parallel:    [max_parallel_tasks]
  Quality:     coverage=[N]% · security=[on/off] · smoke=[on/off] · mutation=[on/off]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Stage rules** (derive from what exists):

| State | Label |
|-------|-------|
| config empty, IDEA.md empty | `Fresh install — not configured` |
| config set, IDEA.md has content, no design.md | `Idea defined — ready for /bootstrap` |
| design.md exists, no tasks | `Design done — needs planning` |
| tasks exist, none in-progress or done | `Planned — ready for /orchestrate` |
| tasks in-progress or done > 0 | `In progress — N/total complete` |
| all tasks done | `Complete` |

---

## Step 3 — Ask what to configure

```
What would you like to configure?

  A) Everything — walk me through full setup
  B) Project basics — name, stack, idea
  C) Workflow — PR mode, checkpoints, parallelism
  D) Quality gates — coverage, security, smoke tests, mutation tests
  E) Models — which AI models to use
  F) Nothing — just show me the state above

[or type what you want to change directly]
```

Wait for response. If the user says F or presses enter without input, skip to Step 5.

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

Max parallel tasks (each needs its own git worktree)
  Current: [value]  →  keep or change? (1–5 recommended)
```

Accept answers one question at a time or all at once. Write to `devteam.config.yml`.

---

### Section D — Quality gates

```
Test coverage threshold (0–100, default 70)
  Current: [value]%  →  keep or change?

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

  reasoning     → used for architecture, Advisor, design decisions
  Current: [value]

  implementation → used for writing code and tests
  Current: [value]

  fast          → used for status checks, lint, simple lookups
  Current: [value]

Available Claude models:
  claude-opus-4-8    — most capable, slower, expensive
  claude-sonnet-4-6  — balanced, recommended for implementation
  claude-haiku-4-5   — fastest, cheapest, good for simple tasks

Alternatives (if you use other providers):
  openai/gpt-4o | openai/gpt-4o-mini | google/gemini-2.5-pro | local/ollama:[model]

Change any or all three:
```

Write to `devteam.config.yml`.

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

**Design done — needs planning:**
```
  → Run /bootstrap (it will detect your design.md and go straight to planning)
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
