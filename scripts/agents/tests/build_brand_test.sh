#!/usr/bin/env bash
# build.sh selects the surfer brand (BB_BRAND, default bb) before import, and only with import.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/logs"

fail() { echo "FAIL: $1"; exit 1; }
stub() {  # <name> <script body>
  printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"
  chmod +x "$T/bin/$1"
}
WANT="$(head -n 1 "$ROOT/.nvmrc")"
stub node "echo v$WANT.11.0"
stub gtar "exit 0"
stub python3 "exit 0"
stub caffeinate 'shift; exec "$@"'
stub npm "echo \"\$@\" >> \"$T/calls\"; [ \"\$2\" = surfer ] && [ -n \"\${STUB_NPM_FAIL:-}\" ] && exit 1; exit 0"

run_build() {  # <build.sh args...>; env passes through
  rm -f "$T/calls"
  OUT="$(PATH="$T/bin:$PATH" BB_LOG_DIR="$T/logs" BB_GTAR="$T/bin/gtar" "$ROOT/scripts/agents/build.sh" "$@" 2>&1)"
  RC=$?
}
call_line() { sed -n "${1}p" "$T/calls"; }

run_build ui
[ "$RC" = "0" ] || fail "default: exit $RC, want 0"
[ "$(call_line 1)" = "run surfer -- set brand bb" ] || fail "default: line 1 is '$(call_line 1)'"
[ "$(call_line 2)" = "run import" ] || fail "default: line 2 is '$(call_line 2)'"

BB_BRAND=release run_build ui
[ "$(call_line 1)" = "run surfer -- set brand release" ] || fail "BB_BRAND=release: line 1 is '$(call_line 1)'"

STUB_NPM_FAIL=1 run_build ui
[ "$RC" != "0" ] || fail "brand failure: exit 0, want non-zero"
grep -q '^run import$' "$T/calls" && fail "brand failure: import still ran"
echo "$OUT" | grep -q 'BUILD RESULT: FAIL' || fail "brand failure: no BUILD RESULT: FAIL"

run_build ui --no-import
grep -q 'set brand' "$T/calls" && fail "--no-import: brand was set"

echo PASS
