You are executing the `/guide` command for dev-team.

Your job: produce a clear, readable snapshot of the current state of the project — what's built, how to run it, and what's next. Useful for onboarding, orientation after a break, or understanding what can be tested right now.

---

## Step 1 — Gather information

Regenerate the index first for a fast, consistent snapshot of task state:

```bash
bash scripts/dt-board.sh
```

Read (using `.dt-index.json` for status/progress, files for detail):
- All tasks in `tasks/done/` — what has been implemented
- All tasks in `tasks/in-progress/` and `tasks/ready-for-pr/` — what's about to land
- `design.md` — the intended architecture, plus its Testing strategy and Documentation plan
- the primary doc file from the Documentation plan (`docs/api.md`, `docs/cli.md`, `docs/usage.md`, …) — available surface
- `context/decisions.md` — key decisions made
- `README.md` — setup instructions
- `devteam.config.yml` — stack and configuration
- Any `docker-compose.yml` or startup scripts

---

## Step 2 — Output the guide

```
## Project Guide — [Project name]
Last updated: [date based on most recent done task]

---

### What's working right now

[For each major feature/module that's DONE:]
**[Feature name]**
- [What it does in plain language]
- [How to access/use it]

---

### How to run the project

[Exact commands based on detected stack and docker config:]
1. [setup step]
2. [run step]
3. [verify it's working step]

---

### How to test it

[From the Testing strategy in design.md — how to run each test type present:]
- [unit: command] · [integration: command] · [e2e/smoke: command]

---

### Available endpoints / features
[If API project:]
| Method | Path | What it does |
|--------|------|-------------|
| GET    | /... | ...         |

[If CLI:]
[commands and what they do]

[If UI:]
[pages/screens and what they do]

---

### Known limitations right now
[What's NOT working yet that a tester might expect:]
- [feature X not implemented — coming in T-XXX]
- [edge case Y not handled yet]

---

### What's in progress
[Tasks currently being worked on with their branches]

### What's coming next
[Next 3-5 available/blocked tasks in priority order]

---

### For contributors
Next task to pick up: T-XXX — [title]
Run: /orchestrate
```

---

## Rules

- Keep it readable for both technical and non-technical readers
- Focus on what's **observable and testable now** — not what's planned
- Be honest about limitations — don't describe planned features as working
- If nothing is done yet, say so clearly and point to `/orchestrate` as the next step
