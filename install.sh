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

if [ ! -d "$SCRIPT_DIR/.claude" ]; then
  echo "Error: run this script from the dev-team repository root." >&2
  exit 1
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

# IDEA.md
copy_if_missing "$SCRIPT_DIR/IDEA.md" "$TARGET/IDEA.md"

# ── Create directory structure ─────────────────────────────────────────────

echo ""
info "Creating task folders..."

for dir in available in-progress ready-for-pr pr-open done blocked; do
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
