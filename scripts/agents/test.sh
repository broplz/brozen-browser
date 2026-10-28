#!/usr/bin/env bash
# Lint and tests for agents, logged and triaged.
#
#   scripts/agents/test.sh lint                 npm run lint (mach lint zen) + layer_lint on $BB_TASK
#   scripts/agents/test.sh <zen-test-dir>...    mochitests: npm test -- <dir> (e.g. glance), one log each
#   scripts/agents/test.sh lint glance          both
#
# Exit: first non-zero exit code. Requires a finished build (scripts/agents/build.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
LOG_DIR="${BB_LOG_DIR:-$ROOT/logs}"; mkdir -p "$LOG_DIR"
[ $# -gt 0 ] || { echo "usage: $0 lint|<zen-test-dir>..." >&2; exit 2; }
RC=0
run_logged() {  # run_logged <name> <command...>
  local name="$1"; shift
  local log="$LOG_DIR/test-$name-$(date +%Y%m%d-%H%M%S).log" t0 t1 rc
  t0=$(date +%s)
  printf '===== %s  [%s]  %s =====\n' "$name" "$(date '+%F %T')" "$*" | tee -a "$log"
  "$@" 2>&1 | tee -a "$log"
  rc=${PIPESTATUS[0]}
  t1=$(date +%s)
  printf 'TEST RESULT: %s name=%s duration=%ss exit=%s log=%s\n' "$([ "$rc" = 0 ] && echo OK || echo FAIL)" "$name" "$((t1 - t0))" "$rc" "$log" | tee -a "$log"
  python3 scripts/agents/triage_log.py "$log" --max-lines 60
  return "$rc"
}
for arg in "$@"; do
  case "$arg" in
    lint)
      if [ -d engine ]; then
        run_logged lint npm run lint || RC=$?
      else
        echo "npm run lint skipped: no engine/ (mach lint needs a downloaded engine); layer_lint still runs"
      fi
      if [ -n "${BB_TASK:-}" ]; then
        echo "===== layer_lint $BB_TASK ====="
        python3 scripts/agents/layer_lint.py "$BB_TASK"; lrc=$?
        [ "$lrc" = 1 ] && RC=1
      fi ;;
    *)
      run_logged "mochi-$(echo "$arg" | tr '/' '_')" npm test -- "$arg" || RC=$? ;;
  esac
done
exit "$RC"
