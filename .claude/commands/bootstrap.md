You are executing the `/bootstrap` command for dev-team.

Your job is to guide the user from their current starting point to a fully configured project: design approved, plan approved, tasks generated, agents specialized, and infrastructure created.

This is a **conversation**, not a one-shot command. You pause at each checkpoint and wait for the human's response before continuing.

---

## Pre-flight check — idempotency guard

Before anything else, check if `design.md` exists in the working directory.

If `design.md` exists, stop and show this message, then wait for input:

```
design.md already exists. This project has already been initialized.

- To update requirements or add modules: run /refine
- To add a new task without changing the spec: run /add-task
- To wipe all generated files and start completely over: type RESET (destructive — cannot be undone)

What would you like to do?
```

Only continue with bootstrap if the user types RESET. Otherwise, stop here.

---

## Step 0 — Detect mode

Analyze what files exist in the project:

| Files present | Mode |
|--------------|------|
| Nothing / only IDEA.md with minimal content | **Mode 1 — Ideation** |
| IDEA.md complete, no design.md | **Mode 2 — Design** |
| design.md exists, no tasks/ | **Mode 3 — Planning** |
| tasks/ populated, no code | **Mode 4 — Execution** |
| Existing code | **Mode 5 — Brownfield** |

If `$ARGUMENTS` contains `--mode=brownfield`, go directly to Mode 5.

Tell the user which mode was detected and ask for confirmation:
```
Detected: [mode and reason]
→ Starting from [phase].

Is this correct, or do you want to start from a different point?
  A) From scratch — explore my idea first
  B) Design — I have a clear idea, need architecture
  C) Planning — I have a design, need tasks
  D) Execution — everything is ready
  E) Existing codebase — I have code already
```

Wait for confirmation.

---

## Step 1 — Assess expertise level

Ask once, early:

```
One quick question before we start — this helps me calibrate how I explain things:

How would you describe your technical background?
  A) Developer experienced with system design and architecture
  B) Developer, less experienced with architecture decisions
  C) I have the idea but I'm not very technical

(This changes how I guide you, not what we build)
```

Wait for response. Store level internally as A, B, or C.

**Level A**: Concise, technical, offer 2-3 options with trade-offs, minimal explanation.
**Level B**: Explained with analogies, offer 2 options with recommendation, justify choices.
**Level C**: Guided, one recommended path explained simply, Advisor works in background and you translate.

---

## Step 2 — Run the appropriate mode

### MODE 1 — Ideation

Check if `IDEA.md` exists. If it does not exist, create it with this template:

```markdown
# Project Idea

<!-- Describe your project here — the problem it solves, who it's for, and what must work on day one. -->
<!-- Be as vague or as specific as you want; aim for at least a sentence or two of real content. -->
```

Then tell the user:

```
IDEA.md didn't exist — I've created a template. Fill it in with a description of your project idea (at least a sentence or two), then re-run /bootstrap.
```

Stop here. Do not continue bootstrap until the user re-runs the command.

If `IDEA.md` exists, read it. If it's empty or very sparse, run the ideation conversation.

Ask (adapt language to expertise level):
```
Tell me about your idea. What problem does it solve?
(Don't worry about being technical — describe the frustration or opportunity)
```

After the first response, dig deeper with 2-3 targeted questions:
- "What does the user do today without this tool?"
- "Who is the first user — you, a team, the public?"
- "What's the one thing that must work perfectly on day one?"

**Gate**: Do not move to Mode 2 until there's a clear answer to "what does the user do today without this tool?". If the answer is vague, ask again differently.

Once ideation is complete, update `IDEA.md` with a clean summary of what was discussed, then proceed to Mode 2.

---

### MODE 2 — Design

Read `IDEA.md`. Count the non-whitespace words, excluding HTML comments (`<!-- ... -->`). If fewer than 20 non-whitespace words remain, stop and tell the user:

```
IDEA.md doesn't have enough content to generate an architecture. Please describe your project in at least a sentence or two, then re-run /bootstrap.
```

Stop here. Do not continue.

Read `devteam.config.yml`.

Ask the following questions adapted to the user's expertise level (A/B/C from Step 1).
These drive architecture decisions in Mode 2 and go into design.md:

**Level A** (technical):
```
Before proposing the architecture, I need a few data points:

Scale: expected requests/day at launch · peak load scenario?
Availability: acceptable downtime? (e.g. "a few minutes/month" vs "always on")
Latency: what's a slow response for a user of this system?
Data sensitivity: PII, payments, health data, or none?
Deployment target: where does this run? (cloud, on-prem, serverless, container)
```

**Level B**:
```
A few quick questions before the design:

How many people will use this at the same time at peak?
Can it go down for a few minutes occasionally, or must it always be available?
How fast should it respond? (under 1 second, a few seconds, doesn't matter)
Does it handle personal data, payments, or health information?
Where will it run? (I can suggest if you're unsure)
```

**Level C**:
```
Before we design, I need to understand how the system will be used:

How many people will use it simultaneously?
What happens if it's unavailable for 5 minutes?
Does it need to respond instantly, or can it take a few seconds?
Will it store personal information, payments, or medical data?
```

Wait for response. Store the answers internally as NFRs:
  nfr.scale, nfr.availability, nfr.latency, nfr.data_sensitivity, nfr.deployment

These MUST appear in design.md (see the generated design.md spec below).

Consult the Advisor agent for the architecture if the project has:
- External API integrations
- A database
- Authentication
- More than 2 distinct user-facing features
- ML or data processing components

**Security boundaries (required when any of the following apply):**
- Authentication or authorization
- Payments or financial data
- PII, health data, or other sensitive data
- Multi-tenant architecture

When any of these apply, the design.md must include a "Security boundaries" section:
  - What data is sensitive and how it is classified
  - What traverses each module boundary and what is never allowed to cross
  - Encryption requirements: in transit and at rest
  - Who can call what (trust model between modules)

The Architect (not the Orchestrator) is responsible for validating the
"Security boundaries" section in every Phase 1 analysis for tasks touching these modules.

Present architecture proposal (adapt detail to expertise level):

```
## Proposed Architecture

**Stack:** [detected or recommended]
**Project type:** [rest-api / cli / library / data-ml / frontend / mixed — inferred, confirm with the user]
**Structure:** [monolith / modular monolith / microservices — with reasoning]

**Modules:**
- [module name] — [what it does, what it owns]
- [...]

**Key decisions:**
1. [Decision A — brief justification]
2. [Decision B — brief justification]

**Open questions:**
- [Genuine ambiguity that needs your input]

Does this match your vision, or should we adjust anything?
```

The **project type** drives the Testing strategy and the Documentation plan below, so confirm it explicitly. Write the confirmed value to `project.type` in `devteam.config.yml`.

Wait for response. Iterate until approved.

Once approved, generate `design.md` using these exact top-level section headings — `orchestrate.md` extracts slices by these names and agents receive empty context if they are missing or renamed:

```markdown
## Architecture
## Module Contracts
## Testing Strategy
## Documentation Plan
```

Distribute the content across these sections:
- **`## Architecture`** — architecture overview, stack, structure, module list with folder ownership, tech stack, key constraints and non-negotiables
- **`## Module Contracts`** — shared contracts (data models, API schemas), plus the NFRs (the scale, availability, latency, and data sensitivity answers from the NFR conversation) and their architectural implications (e.g. "peak 500 req/s → stateless services behind load balancer", "PII present → encryption at rest, no plaintext in logs")
- **`## Testing Strategy`** — see testing strategy section below
- **`## Documentation Plan`** — see documentation plan section below

### Testing strategy (section in design.md)

Decide, based on the project type and modules:
- **Test types per module** — unit, integration, e2e, property-based, smoke (not every module needs all).
- **Critical modules** — the ones where a bug is expensive (auth, payments, ML inference, data integrity, core calculations). These get mutation testing and a higher coverage bar. Write this list to `quality.critical_modules` in `devteam.config.yml`.
- **Test structure** — where tests live (`tests/` layout) and where fixtures/test doubles go (`tests/fixtures/`).
- **Per-module coverage expectations** — the global threshold plus any stricter bar for critical modules.

### Documentation plan (section in design.md)

Decide, based on the project type, which docs this project keeps current and who maintains them:
- `rest-api` → `docs/api.md` (endpoint reference)
- `cli` → `docs/cli.md` (commands, flags, examples)
- `library` → `docs/usage.md` (public API, install, quickstart)
- `data-ml` → `docs/pipeline.md` (stages, inputs/outputs) + a data dictionary
- `frontend` → `docs/ui.md` (screens/flows) or component docs
- Always: `README.md` (audience + setup), ADRs in `docs/adr/` for architectural decisions.

Name the **primary doc file** for this project explicitly — tasks and review agents reference it instead of assuming `docs/api.md`.

Then proceed to Mode 3.

---

### MODE 3 — Planning

Read `design.md`.

Generate phases and task dependency graph. Present for approval:

```
## Implementation Plan

**Phase 0 — Bootstrap** (sequential, ~X tasks)
Sets up shared contracts and infrastructure. Must complete before Phase 1.

**Phase 1 — Core** (~X tasks, parallel)
[What phase 1 delivers]

**Phase 2 — [Name]** (~X tasks, parallel)
[What phase 2 delivers]

[...]

**Dependency graph highlights:**
- Critical path: T-001 → T-002 → ... → T-XXX
- Can run in parallel: [task pairs]

Does this phasing make sense? Any task missing or scope wrong?
```

After computing the dependency graph, calculate and present:

```
Critical path: T-001 → T-003 → T-007 → T-012 (4 sequential tasks)
Minimum time to completion (max parallelism): N sessions
Time with no parallelism (all sequential): M sessions

Maximum parallel tasks at peak: K (at phase [N])
Tasks that could run in parallel but are sequenced:
  T-004 and T-005 share no dependencies — could run simultaneously
  [or: "None found — dependency graph is already optimally parallel"]
```

If there are tasks that could be parallelized but aren't:
```
⚠️ I found [N] tasks that have no dependency between them but are
sequenced. If you want to maximize speed, I can adjust the plan.
Would you like me to maximize parallelism?
```

Wait for response on this before asking for general plan approval.

Wait for approval.

**Step 3b — Generate spec.md**

Using the approved design and plan, generate `spec.md`. For each module write:
- What it does (1-2 sentences — the "what", not the "how")
- Non-obvious logic: business rules, edge cases, how failures are handled
- Interface: inputs (source + format), outputs (destination + format), errors raised
- Out of scope: what this module deliberately does not handle

Then add a "Cross-module flows" section tracing each significant user-facing flow step-by-step through the modules it touches.

Present for approval:
```
## Implementation Specification Draft

[spec.md content]

Does this correctly capture the expected behavior of each module?
Any business rules, edge cases, or failure modes missing?
```

Wait for response. Iterate if needed. Once approved, write `spec.md`.

Once approved (both plan and spec):
1. Create all seven task folders (each with a `.gitkeep` so they are tracked by git) before writing any task files:
   `tasks/available/`, `tasks/blocked/`, `tasks/in-progress/`, `tasks/pr-open/`, `tasks/ready-for-pr/`, `tasks/done/`, `tasks/cancelled/`

   Then generate all `tasks/[status]/T-XXX-slug.md` files:
   - `tasks/available/` for Phase 0 tasks with no dependencies
   - `tasks/blocked/` for all others
   - Each task's **Done when** checklist references the test types the Testing strategy assigns to that module, and the specific doc file from the Documentation plan (not a hardcoded `docs/api.md`)

   **Measurability rule for "Done when" criteria**: every criterion must be
   verifiable by the smoke-tester without ambiguity. Before writing a criterion,
   ask: "Can a test script produce a PASS or FAIL on this, without human judgment?"

   Rewrite vague criteria before saving:
     ✗ "API returns the correct data"
     ✓ "POST /users returns 201 with {id: UUID, email: string} within 500ms"

     ✗ "Error handling works"
     ✓ "POST /users with missing email returns 422 with {error: 'email required'}"

     ✗ "The CLI command works correctly"
     ✓ "`mytool import sample.csv` exits 0 and prints 'Imported: 3 records'"

     ✗ "Data is saved to the database"
     ✓ "After POST /users, SELECT count(*) FROM users increases by 1"

   If you cannot write a measurable criterion, write it as a human-review item:
     "[ ] HUMAN REVIEW: [description of what needs manual inspection]"

2. Include a Phase 0 task to scaffold the test structure (`tests/` + `tests/fixtures/`) if `batteries.test_scaffold` is false or the stack needs custom setup
3. Generate `plan.md` with the full dependency graph
4. Proceed to Mode 4

---

### MODE 4 — Execution setup

Read `devteam.config.yml` and validate tasks/ structure.

Generate specialized agents for this project's exact modules.

Before creating any agent file, check the proposed name against the reserved framework agent list:
`orchestrator`, `architect`, `planner`, `coder`, `advisor`, `review-coordinator`, `code-quality`, `security`, `adversarial`, `smoke-tester`, `mutation-tester`, `spec-coverage`

If any module or service name conflicts with a reserved name, ask the user to rename the module before continuing:

```
The module name "[name]" conflicts with a reserved framework agent name and cannot be used.
Please choose a different name (e.g. "[name]-service", "app-[name]").
```

Wait for a non-conflicting name before creating that agent file.

For each approved module name:
- Create `.claude/agents/[module].md` with folder ownership, commands, and domain expertise

**Required frontmatter — the agent is not invocable without it.** Claude Code only registers a
file in `.claude/agents/` as a spawnable sub-agent type when its frontmatter carries both `name`
and `description`. A file with only `model:` is silently ignored: the spawn falls back to a
generic agent, the per-agent model routing is lost, and nothing reports an error. Every generated
agent file must start with:

```markdown
---
name: [module]                    # exactly the filename without .md — this is what invokes it
description: [one line: WHAT this agent owns and WHEN to invoke it]
model: [value of model.fast in devteam.config.yml]
---
```

`name` must match the filename character for character, because `agent:` fields in `tasks/*.md`
and every sub-agent spawn resolve by that string. `description` is not decorative — Claude Code
reads it to decide relevance, so write what the agent does and when it is invoked, not a title.

**Agent name reconciliation:** After all agent files have been generated, scan every task file in `tasks/` and update the `agent:` field to match the actual generated agent file names. This corrects any mismatches that arose because tasks were drafted before agent names were finalized (or because a name was changed to avoid a reserved-name conflict).

Generate `CLAUDE.md` customized for this project (replace generic content with project-specific architecture, module list, and rules).

Ensure `.claude/steering/` exists with all four framework steering files. These are not project-specific — copy them from the framework source and do not rewrite them:
- `always.md` — cross-cutting rules, injected into all agents
- `task-format.md` — task frontmatter schema, injected into all agents
- `context-formats.md` — context file formats, injected into orchestrator/architect/coder/planner
- `coder-complete.md` — completion obligation, injected into the coder only

Also keep `.claude/AGENTS.md` (the stub pointing to `steering/`) for backward compatibility.

Create the context directories required by all agents and scripts:
```bash
mkdir -p context/decisions context/discoveries context/retrospectives
touch context/decisions/.gitkeep context/discoveries/.gitkeep context/retrospectives/.gitkeep
```

Add (or append) the following entries to `.gitignore` to prevent temporary framework files from being committed accidentally:
```
# dev-team framework temp files
.dt-index.json
.dt-index.json.tmp
.dt-claim-*
```

Generate the test structure and documentation from `design.md`:
- If `batteries.test_scaffold: true` → create `tests/` and `tests/fixtures/` following the layout in the Testing strategy, with a `tests/README.md` explaining the structure and how to run each test type
- Always generate `tests/fixtures/smoke_test.sh` with a basic template (the smoke-tester agent executes this during Phase 4 review). Make the file executable:
  ```bash
  #!/usr/bin/env bash
  # smoke_test.sh — generated by /bootstrap. Edit to add project-specific startup and checks.
  set -euo pipefail
  echo "=== Smoke test starting ==="
  # TODO: start the application
  # TODO: wait for readiness (e.g. poll a health endpoint)
  # TODO: run a minimal validation (e.g. curl -f http://localhost:PORT/health)
  # TODO: shut down on exit
  echo "=== Smoke test passed ==="
  ```
- Create the **primary doc file** named in the Documentation plan (e.g. `docs/api.md`, `docs/cli.md`, `docs/usage.md`, `docs/pipeline.md`) with a skeleton appropriate to the project type — do not assume `docs/api.md` for non-API projects
- Ensure `quality.critical_modules` in `devteam.config.yml` matches the critical modules listed in the Testing strategy

Generate batteries based on `devteam.config.yml`:
- If `docker: true` → generate `docker-compose.yml` and `Dockerfile`
- If `ci: true` → generate `.github/workflows/ci.yml` with these exact triggers:
  ```yaml
  on:
    pull_request:
      branches: [main]
    push:
      branches: [main]
  ```
  The same job set must run on both triggers (test, lint, type_check, build if applicable).
  This ensures CI results are visible on the PR page before merge — not just after.
  The specific commands come from `devteam.config.yml` `commands:` section; fall back
  to auto-detected commands if empty.
- If `env_example: true` → generate `.env.example`
- If `contributing: true` → generate `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`
- If `security_policy: true` → generate `SECURITY.md`
- If `github_templates: true` → generate `.github/PULL_REQUEST_TEMPLATE.md` and issue templates

**Agent registration check (run before reporting success).** Every file in `.claude/agents/` —
framework agents included — must declare `name` and `description`, and `name` must equal the
filename. Without them Claude Code never registers the sub-agent type and the whole pipeline
silently degrades to generic agents:

```bash
for f in .claude/agents/*.md; do
  n=$(basename "$f" .md)
  grep -q "^name: $n$" "$f" || echo "BROKEN: $f — missing or mismatched 'name: $n'"
  grep -q "^description: " "$f" || echo "BROKEN: $f — missing 'description:'"
done
```

Fix every file the check reports before printing the summary below.

Ensure `.claude/settings.json` exists. The review pipeline spawns sub-agents from inside a
sub-agent (review-coordinator → reviewers), which needs a spawn depth above the default:

```json
{
  "env": {
    "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH": "2",
    "CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS": "5"
  }
}
```

If the file already exists, merge these two `env` keys into it without touching anything else.

Output:
```
Bootstrap complete.

Generated:
✓ design.md
✓ spec.md (module behavioral specifications)
✓ plan.md
✓ X tasks (Y available now, Z blocked)
✓ CLAUDE.md (project-specific)
✓ .claude/steering/ (4 scoped steering files: always, task-format, context-formats, coder-complete)
✓ .claude/AGENTS.md (stub pointing to steering/)
✓ .claude/agents/ (X specialized agents, all registered with name + description)
✓ .claude/settings.json (sub-agent spawn depth and concurrency)
✓ tests/fixtures/smoke_test.sh (smoke test template — edit to add project-specific startup steps)
✓ context/decisions/, context/discoveries/, and context/retrospectives/ (agent context directories)
✓ [list of batteries generated]

Critical path: T-001 → T-002 → ...
First available task: T-001 — [title]

Scaling note: The framework runs up to 5 sub-agents concurrently by default. To increase this limit,
set the CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS environment variable and update
orchestration.max_parallel_tasks in devteam.config.yml to the same value.

Next step: run /orchestrate
```

---

### MODE 5 — Brownfield

**Phase A — Archaeology (mandatory, not skippable)**

Scan the existing codebase:
- Detect stack, framework versions, dependencies
- Map folder structure and module boundaries
- Identify existing tests and coverage
- Find configuration files (.env.example, docker-compose, CI)

Generate a Project Context Document:

```
## Project Context

**Stack:** [detected]
**Structure:** [what you found]

**What's built:**
- [module/feature] — [status: complete / partial / broken]
- [...]

**Existing patterns:**
- [architectural pattern observed]
- [coding convention observed]
- [test approach observed]

**Invisible contracts (things the code assumes but doesn't document):**
- [assumption found]
- [...]

**What appears incomplete or broken:**
- [gap found]
- [...]
```

Generate `spec.md` from the existing code alongside the Project Context Document — document what the code actually does (not the ideal state).

For any module with no test files or no detectable test coverage, add an `## Untested behavior` subsection after that module's main spec content:

```markdown
## Untested behavior
> **WARNING: no tests found for this module.** The behavior below is inferred from reading the source code and may not reflect the intended or actual runtime behavior.
- [list each behavior observed but unverified by tests]
```

**MANDATORY CHECKPOINT:**
```
Before generating tasks, I need you to validate this analysis.

⚠️ If I document a bug as intentional behavior, agents will replicate it.
If I miss a hidden constraint, agents will violate it.

Please review:
1. The Project Context above — does it accurately reflect how the project works?
2. The spec.md draft — does it correctly capture what each module actually does?
   - Are there hidden constraints or decisions I missed?
   - Is anything marked as "broken" actually intentional?

Correct me before we continue.
```

Wait for response and update both the context document and spec.md.

**Generate design.md from the existing codebase**

Using the approved Project Context Document and spec.md, generate `design.md` with these exact section headings — `orchestrate.md` slices context by these names and agents receive empty context if they are missing or renamed:

```markdown
## Architecture
[Detected stack, structure, module boundaries, and key architectural patterns from the existing code]

## Module Contracts
[Interfaces, shared data models, and API schemas found in the codebase]

## Testing Strategy
[Existing test types and coverage, critical modules, coverage gaps identified during archaeology]

## Documentation Plan
[Existing docs found and what should be maintained going forward]
```

Present for review:

```
I've drafted design.md from the existing codebase. Please review — this document drives the context agents receive for all future tasks.

Does it accurately reflect the architecture?
```

Wait for approval before continuing.

**Phase B — Delta tasks**

Generate ONLY tasks for what's missing or incomplete. Do NOT create tasks to rewrite what works.

Present for approval:
```
Based on the analysis, here are the tasks I'd generate:

[list of delta tasks with brief scope]

Does this cover what needs to be done, or should I add/remove anything?
```

Wait for approval, then:
1. Create all seven task folders (each with a `.gitkeep`) if they do not already exist:
   `tasks/available/`, `tasks/blocked/`, `tasks/in-progress/`, `tasks/pr-open/`, `tasks/ready-for-pr/`, `tasks/done/`, `tasks/cancelled/`
2. Generate task files and proceed to execution setup.

---

## Rules

- Never skip a checkpoint — every phase requires explicit human approval before proceeding
- Never generate code — bootstrap only generates configuration, documentation, and task files
- Never assume the stack — ask if it's ambiguous
- If the user is Level C, explain architecture options in terms of real-world analogies, not technical jargon
- Invoke the Advisor agent for genuine architectural trade-offs, not implementation details
- The Advisor's output gets translated to the user's expertise level before presenting
