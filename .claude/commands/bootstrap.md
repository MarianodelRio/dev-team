You are executing the `/bootstrap` command for dev-team.

Your job is to guide the user from their current starting point to a fully configured project: design approved, plan approved, tasks generated, agents specialized, and infrastructure created.

This is a **conversation**, not a one-shot command. You pause at each checkpoint and wait for the human's response before continuing.

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

Read `IDEA.md`. If it's empty or very sparse, run the ideation conversation.

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

Read `IDEA.md` and `devteam.config.yml`.

Consult the Advisor agent for the architecture if the project has:
- External API integrations
- A database
- Authentication
- More than 2 distinct user-facing features
- ML or data processing components

Present architecture proposal (adapt detail to expertise level):

```
## Proposed Architecture

**Stack:** [detected or recommended]
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

Wait for response. Iterate until approved.

Once approved, generate `design.md` with:
- Architecture overview
- Module list with folder ownership
- Shared contracts (data models, API schemas)
- Tech stack
- Key constraints and non-negotiables

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

Wait for approval.

Once approved:
1. Generate all `tasks/[status]/T-XXX-slug.md` files
   - `tasks/available/` for Phase 0 tasks with no dependencies
   - `tasks/blocked/` for all others
2. Generate `plan.md` with the full dependency graph
3. Proceed to Mode 4

---

### MODE 4 — Execution setup

Read `devteam.config.yml` and validate tasks/ structure.

Generate specialized agents for this project's exact modules. For each major module:
- Create `.claude/agents/[module].md` with folder ownership, commands, and domain expertise

Generate `CLAUDE.md` customized for this project (replace generic content with project-specific architecture, module list, and rules).

Generate batteries based on `devteam.config.yml`:
- If `docker: true` → generate `docker-compose.yml` and `Dockerfile`
- If `ci: true` → generate `.github/workflows/ci.yml`
- If `env_example: true` → generate `.env.example`
- If `contributing: true` → generate `CONTRIBUTING.md`
- If `security_policy: true` → generate `SECURITY.md`
- If `github_templates: true` → generate `.github/PULL_REQUEST_TEMPLATE.md` and issue templates

Output:
```
Bootstrap complete.

Generated:
✓ design.md
✓ plan.md
✓ X tasks (Y available now, Z blocked)
✓ CLAUDE.md (project-specific)
✓ .claude/agents/ (X specialized agents)
✓ [list of batteries generated]

Critical path: T-001 → T-002 → ...
First available task: T-001 — [title]

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

**MANDATORY CHECKPOINT:**
```
Before generating tasks, I need you to validate this analysis.

⚠️ If I document a bug as intentional behavior, agents will replicate it.
If I miss a hidden constraint, agents will violate it.

Please review the Project Context above:
- Does it accurately reflect how the project works?
- Are there hidden constraints or decisions I missed?
- Is anything marked as "broken" actually intentional?

Correct me before we continue.
```

Wait for response and update the context document.

**Phase B — Delta tasks**

Generate ONLY tasks for what's missing or incomplete. Do NOT create tasks to rewrite what works.

Present for approval:
```
Based on the analysis, here are the tasks I'd generate:

[list of delta tasks with brief scope]

Does this cover what needs to be done, or should I add/remove anything?
```

Wait for approval, then generate tasks and proceed to execution setup.

---

## Rules

- Never skip a checkpoint — every phase requires explicit human approval before proceeding
- Never generate code — bootstrap only generates configuration, documentation, and task files
- Never assume the stack — ask if it's ambiguous
- If the user is Level C, explain architecture options in terms of real-world analogies, not technical jargon
- Invoke the Advisor agent for genuine architectural trade-offs, not implementation details
- The Advisor's output gets translated to the user's expertise level before presenting
