# Discoveries

Cross-agent alerts. When an agent finds something during implementation that affects another module, it writes here instead of touching the other module.

**Format:**
```
## OPEN — YYYY-MM-DD [Source agent → Target agent]
[What was found and what action is needed]
Task where this should be addressed: T-XXX (or "unassigned")
Status: open
```

When resolved, update status:
```
Status: resolved in T-XXX
```

The Orchestrator reads this file before starting each task. Open items affecting the current task are surfaced at the human checkpoint.

---

<!-- Discoveries will be appended below this line -->
