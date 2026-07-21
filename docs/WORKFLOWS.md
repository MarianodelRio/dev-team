# Workflows — dev-team cheatsheet

Quick reference for "which command do I run now?". Each task moves through folders;
the folder is the signal, the frontmatter `status` is the source of truth.

Run `/cheatsheet` any time for a version of this contextualised to the current board.

---

## The normal cycle

```
/orchestrate                 → pick + implement the best available task (opens a worktree)
/prepare-pr T-XXX            → review with sub-agents, open the PR
(merge the PR on GitHub)     → your approval
/done T-XXX                  → mark done, clean the branch, unblock dependents
```

Repeat. With parallel chats, run one cycle per chat — the branch push in `dt-claim`
guarantees two chats never grab the same task.

---

## State → next command

| Task is in… | Meaning | Your next command |
|-------------|---------|-------------------|
| `available/` | ready, deps done, unclaimed | `/orchestrate` |
| `in-progress/` | being implemented (has a worktree + branch) | finish it, then it moves itself |
| `ready-for-pr/` | implemented, tests pass | `/prepare-pr T-XXX` |
| `pr-open/` | PR is open on GitHub | merge it, then `/done T-XXX` |
| `done/` | merged | nothing |
| `blocked/` | deps not done (or `cancelled`) | nothing until deps land |

---

## Other flows

**Bug**
```
/bug "symptom"      → file + claim B-XXX, investigate, checkpoint, fix (own worktree)
/prepare-pr B-XXX   → review + PR
(merge) → /done B-XXX
```

**Recovery / maintenance**
| Situation | Command |
|-----------|---------|
| Agent crashed, task stuck in `in-progress` | `/restart T-XXX` |
| Task no longer needed | `/cancel T-XXX` |
| Add a task mid-project | `/add-task "description"` |
| See the whole board | `/status` |
| What's built + how to run/test it | `/guide` |
| Reorient to what to do now | `/cheatsheet` |

---

## Under the hood

State transitions are handled by the scripts in `scripts/` (called by the commands):

| Script | Does |
|--------|------|
| `dt-claim.sh T-XXX` | lock branch + worktree + IN_PROGRESS on main |
| `dt-ready.sh T-XXX` | remove worktree, move to `ready-for-pr/` |
| `dt-done.sh T-XXX` | move to `done/`, clean branch, unblock dependents |
| `dt-cancel.sh T-XXX` | park in `blocked/` as cancelled |
| `dt-restart.sh T-XXX` | reset a stuck task to `available/` |
| `dt-board.sh` | regenerate `.dt-index.json` (the fast board cache) |

You normally never call these directly — the slash commands do. All accept `--dry-run`.

---

## Ground rules

- `main` must be **unprotected** (status metadata is pushed to it directly).
- One worktree + one branch per task; agents only touch their assigned folders.
- Tests and docs follow the **Testing strategy** and **Documentation plan** in `design.md`.
- `.dt-index.json` is a cache — never commit it (it's git-ignored).
