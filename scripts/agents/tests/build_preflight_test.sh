#!/usr/bin/env bash
# build.sh preflight: wrong Node major or missing gnu-tar → exit 2, no npm call, no lock.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/logs"
printf '#!/bin/sh\necho "$@" >> "%s/calls"\n' "$T" > "$T/bin/npm"
chmod +x "$T/bin/npm"

fail() { echo "FAIL: $1"; exit 1; }
stub_node() { printf '#!/bin/sh\necho %s\n' "$1" > "$T/bin/node"; chmod +x "$T/bin/node"; }
run_build() { OUT="$(PATH="$T/bin:$PATH" BB_LOG_DIR="$T/logs" BB_GTAR="$T/no-such-gtar" "$ROOT/scripts/agents/build.sh" ui 2>&1)"; RC=$?; }
check_refused() {  # <label> <needle...>
  local label="$1" needle; shift
  [ "$RC" = "2" ] || fail "$label: exit $RC, want 2"
  for needle in "$@"; do
    echo "$OUT" | grep -q "$needle" || fail "$label: output lacks '$needle'"
  done
  [ ! -e "$T/calls" ] || fail "$label: npm was called"
  [ ! -e "$T/logs/.build.lock" ] || fail "$label: lock left behind"
}

WANT="$(head -n 1 "$ROOT/.nvmrc")"
stub_node v25.1.0
run_build
check_refused "wrong node" "Node $WANT" "nvm use"

stub_node "v$WANT.11.0"
run_build
check_refused "no gtar" "gnu-tar" "brew install gnu-tar"

echo PASS
