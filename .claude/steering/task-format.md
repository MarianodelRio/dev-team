---
inclusion: always
---

# Task file format reference

## Frontmatter field types

| Field | Type | Valid values |
|---|---|---|
| `id` | string | `T-NNN` or `B-NNN` (three-digit number) |
| `phase` | integer | `0`, `1`, `2`, … (project phase number) |
| `agent` | string | agent name matching a file in `.claude/agents/` |
| `depends_on` | YAML array | `[]` or `[T-001, T-002]` |
| `status` | string | `available`, `in-progress`, `ready-for-pr`, `pr-open`, `done`, `blocked`, `cancelled` |
| `folders` | YAML array | relative paths the agent may modify, e.g. `[apps/api/, libs/auth/]` |
| `outputs` | YAML array | see format below |
| `size` | string | `S`, `M`, `L` |
| `branch` | string | branch name (e.g. `feature/T-001-slug`), or `~` when not yet created |
| `pr` | string | full GitHub PR URL (e.g. `https://github.com/org/repo/pull/123`), or `~` when none |

## `outputs:` format

```yaml
outputs:
  - "POST /api/resource → {id: string}"          # REST endpoint
  - "fn name(args) → ReturnType | ErrorType"      # function or method
  - "event: name.occurred → {field: type}"        # domain event
```

## Bug task frontmatter

Bug tasks use `B-NNN` IDs and **must** include the `phase:` field:

```markdown
---
id: B-001
phase: 0
agent: [agent name]
depends_on: []
status: available
folders: [...]
outputs: [...]
size: S
branch: ~
pr: ~
---
```

## "Done when" checklist structure

Separate implementation criteria from process criteria:

```markdown
**Implementation done when:**
- [ ] feature is built and works
- [ ] tests written and passing

**Task done when (post-review):**
- [ ] PR merged into main
- [ ] primary doc updated
```
