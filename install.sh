#!/usr/bin/env bash
# install.sh — install dev-team into an existing project
# Usage: bash install.sh [target-directory]
# If no target directory is given, installs into the current directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(pwd)}"

# ── Helpers ────────────────────────────────────────────────────────────────

info()    { echo "[dev-team] $*"; }
success() { echo "[dev-team] ✓ $*"; }
skip()    { echo "[dev-team] — $* (already exists, skipped)"; }

copy_if_missing() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    skip "$dst"
  else
    cp -r "$src" "$dst"
    success "Copied $(basename "$dst")"
  fi
}

# ── Validate ───────────────────────────────────────────────────────────────

if [ ! -d "$TARGET" ]; then
  echo "Error: target directory '$TARGET' does not exist." >&2
  exit 1
fi

# Locate the framework source.
# - Local clone: SCRIPT_DIR already holds the framework files.
# - `curl ... | bash`: there is no checkout next to the script, so fetch one.
REPO_URL="https://github.com/MarianodelRio/dev-team.git"
CLONED_TMP=""

cleanup() {
  if [ -n "$CLONED_TMP" ] && [ -d "$CLONED_TMP" ]; then
    rm -rf "$CLONED_TMP"
  fi
}
trap cleanup EXIT

if [ ! -d "$SCRIPT_DIR/.claude" ]; then
  info "No local checkout found — fetching dev-team from $REPO_URL"
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is required to install dev-team remotely." >&2
    echo "Install git, or clone the repo and run 'bash install.sh' from its root." >&2
    exit 1
  fi
  CLONED_TMP="$(mktemp -d)"
  if ! git clone --depth 1 "$REPO_URL" "$CLONED_TMP" >/dev/null 2>&1; then
    echo "Error: failed to clone $REPO_URL" >&2
    exit 1
  fi
  SCRIPT_DIR="$CLONED_TMP"
fi

info "Installing dev-team into: $TARGET"
echo ""

# ── Copy framework files ───────────────────────────────────────────────────

# .claude/ — commands and agent definitions
if [ -d "$TARGET/.claude" ]; then
  info ".claude/ already exists — merging commands/ and agents/ only"
  mkdir -p "$TARGET/.claude/commands" "$TARGET/.claude/agents"
  for f in "$SCRIPT_DIR/.claude/commands/"*; do
    dst="$TARGET/.claude/commands/$(basename "$f")"
    copy_if_missing "$f" "$dst"
  done
  for f in "$SCRIPT_DIR/.claude/agents/"*; do
    dst="$TARGET/.claude/agents/$(basename "$f")"
    copy_if_missing "$f" "$dst"
  done
else
  cp -r "$SCRIPT_DIR/.claude" "$TARGET/.claude"
  success "Copied .claude/"
fi

# devteam.config.yml
copy_if_missing "$SCRIPT_DIR/devteam.config.yml" "$TARGET/devteam.config.yml"

# CLAUDE.md — the framework rulebook agents rely on.
# /bootstrap later specializes it for the project; copy_if_missing never
# overwrites an existing project CLAUDE.md.
copy_if_missing "$SCRIPT_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"

# scripts/ — the dt-* helpers the commands call. Without these, /orchestrate,
# /done, /cancel, /restart and /status break in an installed project.
if [ -d "$TARGET/scripts" ]; then
  mkdir -p "$TARGET/scripts"
  for f in "$SCRIPT_DIR/scripts/"*; do
    copy_if_missing "$f" "$TARGET/scripts/$(basename "$f")"
  done
else
  cp -r "$SCRIPT_DIR/scripts" "$TARGET/scripts"
  success "Copied scripts/"
fi

# docs/WORKFLOWS.md — the flow cheatsheet reference.
mkdir -p "$TARGET/docs"
copy_if_missing "$SCRIPT_DIR/docs/WORKFLOWS.md" "$TARGET/docs/WORKFLOWS.md"

# IDEA.md — write the standard template (matches the framework's own IDEA.md)
if [ -f "$TARGET/IDEA.md" ]; then
  skip "IDEA.md"
else
  cat > "$TARGET/IDEA.md" <<'EOF'
# My Idea

<!--
Welcome to dev-team.

You don't need to be technical to fill this in.
Answer what you can — we'll figure out the rest together in /bootstrap.
The more honest and specific you are, the better the result.
-->

## What problem does this solve?

<!--
Describe the frustration, gap, or opportunity.
Example: "I spend hours every week manually copying data between two systems that don't talk to each other."
Example: "There's no simple tool for X that doesn't require Y."
-->



## Who uses it?

<!--
Who is the main user? How often? In what context?
Example: "Me and my team of 3, daily, during morning standup."
Example: "Small restaurant owners who aren't technical."
-->



## How does it work at a high level?

<!--
Describe the core flow in plain language. What does the user do? What does the system do?
Example: "User logs in, uploads a CSV, the system processes it and sends an email with the results."
-->



## Is there anything technical you already know you want?

<!--
Optional. Only fill this if you have specific technical requirements or preferences.
Example: "It needs to work on mobile." / "Must integrate with Slack." / "I already have an API for X."
-->



## What is definitely NOT part of this?

<!--
Optional but very useful. What should this never do or include?
Example: "No subscriptions — it must be a one-time purchase." / "No cloud — everything runs locally."
-->
EOF
  success "IDEA.md (template)"
fi

# ── Create directory structure ─────────────────────────────────────────────

echo ""
info "Creating task folders..."

for dir in available in-progress ready-for-pr pr-open done blocked cancelled; do
  mkdir -p "$TARGET/tasks/$dir"
  if [ ! -f "$TARGET/tasks/$dir/.gitkeep" ]; then
    touch "$TARGET/tasks/$dir/.gitkeep"
  fi
done
success "tasks/ with subfolders"

info "Creating context files..."

mkdir -p "$TARGET/context"

if [ ! -f "$TARGET/context/decisions.md" ]; then
  cat > "$TARGET/context/decisions.md" <<'EOF'
# Decisions

Log of technical decisions made during implementation.

## Format

```
## YYYY-MM-DD — T-XXX [Agent name]
Decided: [what]
Why: [reason]
Affects: [files/modules]
Discarded: [alternative and why not]
```
EOF
  success "context/decisions.md"
else
  skip "context/decisions.md"
fi

if [ ! -f "$TARGET/context/discoveries.md" ]; then
  cat > "$TARGET/context/discoveries.md" <<'EOF'
# Discoveries

Cross-agent alerts. When an agent finds something that affects another module, it writes here.

## Format

```
## OPEN — YYYY-MM-DD [Source agent → Target agent]
[What was found and what action is needed]
Status: open / resolved in T-XXX
```
EOF
  success "context/discoveries.md"
else
  skip "context/discoveries.md"
fi

info "Creating docs/adr/ folder..."
mkdir -p "$TARGET/docs/adr"
if [ ! -f "$TARGET/docs/adr/.gitkeep" ]; then
  touch "$TARGET/docs/adr/.gitkeep"
fi
success "docs/adr/"

# The smoke-test agent assumes tests/fixtures/ exists. Create the skeleton now;
# /bootstrap fills in the real layout from design.md's Testing strategy.
info "Creating test folders..."
mkdir -p "$TARGET/tests/fixtures"
for dir in tests tests/fixtures; do
  if [ ! -f "$TARGET/$dir/.gitkeep" ]; then
    touch "$TARGET/$dir/.gitkeep"
  fi
done
success "tests/ with fixtures/"

# ── Done ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────────────────────"
echo "  dev-team installed successfully in: $TARGET"
echo "────────────────────────────────────────────────────────────"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Edit IDEA.md — describe what you want to build"
echo "  2. Edit devteam.config.yml — set your project name and stack"
echo "  3. Open Claude Code in $TARGET"
echo "  4. Run /bootstrap — design session → tasks generated"
echo "  5. Run /orchestrate — agents start implementing"
echo ""
echo "  Full docs: https://github.com/marianodelrio/dev-team"
echo ""
