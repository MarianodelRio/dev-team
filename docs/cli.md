# CLI Reference

<!--
  CLI doc template — use this when project.type is `cli`. /bootstrap generates the
  primary doc for your project type from the Documentation plan in design.md.

  Maintained by agents during development.
  Every new command or flag must be documented here in the same PR that implements it.
  Format: one section per command, with a usage line, flags table, and an example.
-->

## Overview

`mytool` — [one-line description of what the tool does].

```
mytool [global flags] <command> [command flags] [args]
```

| Global flag | Description |
|-------------|-------------|
| `--help`    | Show help |
| `--version` | Print version |

<!--
## `mytool import` — [what it does]

```
mytool import <path> [--dry-run] [--format json|csv]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--dry-run` | false | Validate without writing |
| `--format`  | json  | Output format |

**Example**

```bash
mytool import ./data.csv --dry-run
```

**Exit codes**

| Code | When |
|------|------|
| 0    | Success |
| 1    | Invalid input |
| 2    | Runtime error |
-->
