#!/usr/bin/env bash
# dt-verify.sh — run the configured test/lint/type_check commands.
#
#   dt-verify.sh [--worktree <path>] [--dry-run]
#
# Reads commands.test, commands.lint, commands.type_check from devteam.config.yml.
# Runs each command with bash -c in the specified directory (default: current directory).
# Skips any command that is empty or not configured — does not fail on unconfigured steps.
# Exits 0 if all configured commands pass, 1 if any fail.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dt-common.sh"

DIR=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) shift; DIR="${1:-}" ;;
    --dry-run)  DRY=1 ;;
    *)          die "unknown argument: $1" ;;
  esac
  shift
done

[ -z "$DIR" ] && DIR="$(pwd)"
[ -d "$DIR" ] || die "directory not found: $DIR"

# ── Read commands from config ─────────────────────────────────────────────────
TEST_CMD="$(dt_config commands.test)"
LINT_CMD="$(dt_config commands.lint)"
TYPE_CMD="$(dt_config commands.type_check)"

if [ "$DRY" -eq 1 ]; then
  log "DRY-RUN verify in: $DIR"
  log "  test:       ${TEST_CMD:-"(not configured — will skip)"}"
  log "  lint:       ${LINT_CMD:-"(not configured — will skip)"}"
  log "  type_check: ${TYPE_CMD:-"(not configured — will skip)"}"
  exit 0
fi

# ── Run each configured command ───────────────────────────────────────────────
FAILED=0
PASSED=0
SKIPPED=0
RESULT_TEST="skipped"
RESULT_LINT="skipped"
RESULT_TYPE="skipped"

run_check() {
  local name="$1" cmd="$2" result_var="$3"
  if [ -z "$cmd" ]; then
    log "verify: $name — skipped (not configured)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  log "verify: $name → $cmd"
  local t0 rc output
  t0=$(date +%s)
  output=$(cd "$DIR" && bash -c "$cmd" 2>&1) && rc=0 || rc=$?
  local elapsed=$(( $(date +%s) - t0 ))

  if [ "$rc" -eq 0 ]; then
    ok "$name (${elapsed}s)"
    PASSED=$((PASSED + 1))
    eval "$result_var=pass"
  else
    echo "[dt] ✗ $name — exit $rc" >&2
    echo "$output" >&2
    FAILED=$((FAILED + 1))
    eval "$result_var=fail"
  fi
}

run_check "test"       "$TEST_CMD" RESULT_TEST
run_check "lint"       "$LINT_CMD" RESULT_LINT
run_check "type_check" "$TYPE_CMD" RESULT_TYPE

# ── Structured output (parseable by the Orchestrator) ─────────────────────────
echo ""
echo "VERIFY_TEST=$RESULT_TEST"
echo "VERIFY_LINT=$RESULT_LINT"
echo "VERIFY_TYPE_CHECK=$RESULT_TYPE"

if [ "$FAILED" -gt 0 ]; then
  err "$FAILED/$((PASSED + FAILED)) configured checks failed"
  echo "VERIFY_RESULT=fail"
  exit 1
else
  SKIPPED_MSG=""
  [ "$SKIPPED" -gt 0 ] && SKIPPED_MSG=" ($SKIPPED skipped)"
  ok "$PASSED/$((PASSED + FAILED)) configured checks passed$SKIPPED_MSG"
  echo "VERIFY_RESULT=pass"
  exit 0
fi
