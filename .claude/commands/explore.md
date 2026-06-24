You are executing the `/explore` command for dev-team.

**Input:** `$ARGUMENTS` — a design question or topic to explore

Your job: evaluate options and produce a clear recommendation before any code is written. No production code output.

---

## Step 1 — Load context

Read:
- `design.md` — current architecture and constraints
- `plan.md` — module ownership
- `CLAUDE.md` — folder rules and protected files
- Relevant agent files for modules involved

---

## Step 2 — Assess complexity

**Standard implementation decision** (known pattern, no module boundary impact, no contract changes):
→ Proceed to Step 3 with your own analysis.

**Architectural impact** (changes module boundaries, affects shared contracts, involves long-term consequences, genuine trade-offs):
→ Invoke the Advisor agent first:
```
Agent(
  subagent_type: "advisor",
  prompt: "Context: [modules involved, current constraints]\nQuestion: [specific decision]\nOutput: options + trade-offs + recommendation"
)
```

---

## Step 3 — Output

```
## Question
[Restate clearly]

## Context
[What's already fixed — contracts, module boundaries, constraints from design.md]

## Options

### Option A — [name]
[Description]
Pros: ...
Cons: ...

### Option B — [name]
[Description]
Pros: ...
Cons: ...

## Recommendation
[Clear, opinionated answer with justification]

## Next steps
- Does this need an ADR? → create in docs/adr/
- Does this need a contract change? → requires Architect approval
- Does this need a new task? → run /add-task
```

---

## Rules

- No production code — pseudocode only to illustrate an option
- Never recommend a violation of the module DAG
- If an ADR is warranted (significant architectural decision), say so explicitly
- If this reveals a gap in tasks/, flag it
