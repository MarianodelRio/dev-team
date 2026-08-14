You are executing the `/status` command for dev-team.

Your job: display a clear, complete status board of the project.

---

## Step 1 — Gather data

Regenerate the index (it fetches, reads every task's frontmatter, marks claimed tasks from remote branches, and precomputes `unblocks` + `critical_path_next`), then read it:

```bash
bash scripts/dt-board.sh --print
```

`.dt-index.json` now holds the full board. Read from it instead of re-scanning `tasks/` by hand — the `⭐` critical-path task and each task's `unblocks`/`claimed_remote` are already computed.

The board covers these 7 standard task folders (fixed — the `tasks.status_folders` config key is not used; folders are not configurable):

| Folder | Meaning |
|--------|---------|
| `tasks/available` | Ready to work on; all dependencies satisfied |
| `tasks/blocked` | Waiting for one or more dependencies |
| `tasks/in-progress` | Currently being worked on by an agent |
| `tasks/pr-open` | PR open on GitHub |
| `tasks/ready-for-pr` | Escape hatch; not processed by /orchestrate Phase 4 |
| `tasks/done` | Merged into main |
| `tasks/cancelled` | Abandoned; hidden from the board by default |

---

## Filter flags (optional)

If `$ARGUMENTS` contains a recognized flag, apply it before rendering the board. Essential for projects with 50+ tasks where the full board is too long to scan quickly:

| Flag | What it shows |
|------|--------------|
| `--active` | Only `in-progress` and `pr-open` tasks |
| `--phase N` | Only tasks whose frontmatter has `phase: N` |
| `--agent NAME` | Only tasks whose frontmatter has `agent: NAME` |
| `--blocked` | Only blocked tasks, each listing its unresolved blocking dependencies |

Examples: `/status --active` · `/status --phase 2` · `/status --agent backend` · `/status --blocked`

If no flag is present, show the full board.

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
[- T-XXX — title → run /prepare-pr T-XXX (escape hatch — task was not processed by /orchestrate Phase 4)]

### 🔧 In Progress ([N])
[- T-XXX — title (branch: feature/T-XXX-slug, elapsed: 2h)]

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
- **Elapsed time for in-progress tasks:** find the git commit that first placed the file in `tasks/in-progress/`:
  `git log --all --diff-filter=A -- "tasks/in-progress/T-XXX.md" --format="%ci" | head -1`
  Compute the difference from that timestamp to now. Format as `"2h"`, `"1d 4h"`, or `"3d"`. Append inline: `(branch: feature/T-XXX-slug, elapsed: 2h)`. If git history is unavailable or the commit cannot be found, omit the elapsed field.
- **Filter flags:** when `$ARGUMENTS` contains `--active`, `--phase N`, `--agent NAME`, or `--blocked`, render only the matching subset of the board instead of the full view.
