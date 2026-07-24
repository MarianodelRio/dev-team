You are executing the `/cheatsheet` command for dev-team.

**Input:** `$ARGUMENTS` — optional task ID (e.g. `T-004`). If empty, run global mode.

Your job: tell the human exactly what to do next, contextualised to the current
board. This is orientation, not a status dump — be short and action-first.

---

## Step 1 — Refresh the board

```bash
bash scripts/dt-board.sh
```

Read `.dt-index.json`. `docs/WORKFLOWS.md` is the static reference behind the
state → command mapping used below.

---

## Step 2 — Answer

### Global mode (`/cheatsheet` with no argument)

For each non-empty bucket, list the tasks and the single command to move them
forward. Keep it to what's actionable now:

```
Right now on this project:

  🟢 Free to start: [available + claimed_remote:false ids]   → /orchestrate
  🛎 Ready for PR:  [ready-for-pr ids]                        → /prepare-pr <id>
  🔍 PR open:       [pr-open ids]                             → merge on GitHub, then /done <id>
  🔧 In progress (maybe other chats): [in-progress ids + branch]
  🔴 Blocked:       [N] tasks waiting on dependencies

Suggested next: [critical_path_next] — [title]
```

Omit any bucket that's empty. If nothing is available and nothing is in flight,
say so and point at `/status` or `/bootstrap`.

### Task mode (`/cheatsheet T-XXX`)

Look up the task in the index and print its position in the cycle and the one
command that advances it:

```
T-XXX — [title]
  Status: [folder]
  Branch: [branch or "—"]
  → Next: [the single command for this state]
  [one-line reminder relevant to that step]
```

State → next command (see `docs/WORKFLOWS.md`):
- `available`   → `/orchestrate` (it will pick the best one; or claim this specifically)
- `in-progress` → finish the work in the worktree; /orchestrate moves it to pr-open when done (`/restart T-XXX` if stuck)
- `ready-for-pr`→ `/prepare-pr T-XXX`
- `pr-open`     → merge the PR on GitHub, then `/done T-XXX`
- `done`        → nothing — it's merged
- `blocked`     → wait for its dependencies (list them); or `/cancel T-XXX` if abandoning

If the ID isn't found, say so and suggest `/status`.

---

## Rules

- **Action-first** — lead with the command, not the explanation.
- **Never mutate state** — this command only reads the board.
- **Respect parallel chats** — in-progress tasks may be owned by another chat; flag them, don't touch them.
