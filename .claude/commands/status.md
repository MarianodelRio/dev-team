You are executing the `/status` command for dev-team.

Your job: display a clear, complete status board of the project.

---

## Step 1 — Gather data

```bash
git fetch origin
```

Count files in each `tasks/` subfolder. Read frontmatter from each task file.

Check remote branches for in-progress tasks:
```bash
git branch -r | grep "origin/feature/"
```

---

## Step 2 — Output the status board

```
## dev-team Status Board
[Project name from devteam.config.yml] — [timestamp]

### ✅ Done ([N]/[total])
[- T-XXX — title (merged: PR #NN)]

### 🔍 PR Open ([N])
[- T-XXX — title (PR #NN, opened Xh ago)]

### 🛎 Ready for PR ([N])
[- T-XXX — title → run /prepare-pr T-XXX]

### 🔧 In Progress ([N])
[- T-XXX — title (branch: feature/T-XXX-slug)]

### 🟢 Available Now ([N])
[⭐ T-XXX — title [unblocks N tasks] ← critical path]
[- T-XXX — title]

### 🔴 Blocked ([N])
[- T-XXX — title [waiting for: T-YYY (in-progress), T-ZZZ (available)]]

### 🐛 Active Bugs ([N])
[Only show if any B-XXX files exist in in-progress/, ready-for-pr/, or pr-open/]
[- B-XXX — symptom (status: in-progress | ready-for-pr | pr-open)]

### ⚠️ Stale ([N])
[Tasks with a remote branch but still status: available — may indicate a crashed agent]
[Run /restart T-XXX to recover]

---
Phase breakdown:
  Phase 0: [X/Y] | Phase 1: [X/Y] | Phase 2: [X/Y] | ...

Overall: [X]/[total] tasks complete ([X]%)

Critical path next: T-XXX — [title]
Suggested next /orchestrate target: T-XXX (unblocks the most)
```

---

## Rules

- Always `git fetch` first — stale remote branch data causes wrong available/claimed status
- Mark stale tasks clearly — a branch that exists but task is still `available` means something crashed → suggest /restart
- Highlight the critical path next task with ⭐
- Show the Bugs section only when active bugs exist — don't show an empty section
- Cancelled tasks (status: cancelled) are hidden from the board by default
