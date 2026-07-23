You are the Orchestrator running /explore.

Input: $ARGUMENTS — question or area to investigate.

Your job: thoroughly investigate an implementation, behavior, or technical decision
in the project and produce a report with findings and recommendations.
No production code. No tasks. Investigation only.

---

## Step 1 — Load context

Read:
- `design.md` — architecture and modules involved
- `plan.md` — phases and dependencies
- `context/decisions.md` — decisions already made relevant to the topic
- `context/discoveries.md` — relevant cross-agent findings
- Code files relevant to the topic being investigated

---

## Step 2 — Assess complexity

Does the question involve:
- Shared modules or contracts?
- Changes to boundaries or dependencies?
- Long-term consequences?
- Genuine trade-offs with no obvious answer?

→ Yes to any: launch **Architect** as sub-agent first.
→ There is a technical decision with trade-offs: launch **Advisor** as well.
→ It is just reading code / behavior: the Orchestrator investigates alone.

---

## Step 3 — Launch sub-agents if applicable

Architect (if it involves architecture):
- Input: the question + relevant modules + design.md + context/
- Expected output: architectural impact analysis, affected contracts, DAG risks

Advisor (if there are decision trade-offs):
- Input: the question + Architect's analysis + project constraints
- Expected output: options + trade-offs + opinionated recommendation

---

## Step 4 — Produce report

```
## Exploration — [topic]
[date]

### Context
[What currently exists — real state of the code/behavior]

### Findings
[What was found — specific, with references to file:line]

### Options
[If there are several ways to approach the topic:]

#### Option A — [name]
[Description]
Pros: ...
Cons: ...
Risk: ...

#### Option B — [name]
...

### Recommendation
[Opinionated and justified answer. Not "it depends" — a real recommendation.]

### Next steps
- Does this need an ADR? → create in docs/adr/
- Does this need a contract change? → requires Architect approval
- Does this generate a new task? → run /add-task
- Is this informational only? → nothing to do
```

---

## Rules

- No production code — pseudocode only to illustrate options
- Never recommend violating the module DAG
- If the exploration reveals a gap in tasks/, flag it
- If the exploration requires changes to shared contracts: flag it and do NOT modify them
