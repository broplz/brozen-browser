#!/usr/bin/env bash
# Tests for scripts/bb/lib.sh. Run: /bin/bash scripts/bb/tests/lib_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib="$here/../lib.sh"
repo_root="$(cd "$here/../../.." && pwd)"
failed=0

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
eq() { [ "$1" = "$2" ]; }

# (e) default BB_LOG_DIR, string check only
( unset BB_LOG_DIR; . "$lib"; eq "$BB_LOG_DIR" "$repo_root/../logs" ) || { echo "FAIL: default BB_LOG_DIR"; failed=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export BB_LOG_DIR="$tmp/logs"
. "$lib"

# (f) bb_log_open
bb_log_open rebase-x >/dev/null
check "bb_log_open sets BB_LOG pattern" bash -c '[[ "$1" =~ ^'"$BB_LOG_DIR"'/rebase-x-[0-9]{8}-[0-9]{6}\.log$ ]]' _ "$BB_LOG"
check "bb_log_open creates the log dir" test -d "$BB_LOG_DIR"

# (a)
: > "$BB_LOG"
step ok true >/dev/null; rc=$?
check "step ok true returns 0" eq "$rc" 0
check "log has header for ok" grep -qE '^==> [0-9-]+ [0-9:]+ step: ok$' "$BB_LOG"
check "log has footer exit=0" grep -q '^<== step: ok exit=0 duration=' "$BB_LOG"

# (b)
step fail false >/dev/null; rc=$?
check "step fail false returns 1" eq "$rc" 1
check "log has footer exit=1" grep -q '^<== step: fail exit=1 duration=' "$BB_LOG"

# (c)
out="$(step echo echo hello)"
check "hello on stdout" grep -q '^hello$' <<<"$out"
check "hello in log" grep -q '^hello$' "$BB_LOG"

# (d) caller with strict options
out="$(bash -c 'set -euo pipefail; . "$1"; bb_log_open strict >/dev/null; rc=0; step fail false || rc=$?; echo "rc=$rc"' _ "$lib")"
check "strict caller: footer printed" grep -q '^<== step: fail exit=1' <<<"$out"
check "strict caller: rc=1" grep -q '^rc=1$' <<<"$out"

# (g)
check "duration is integer + s" grep -qE '^<== step: ok exit=0 duration=[0-9]+s$' "$BB_LOG"

# step without BB_LOG
( unset BB_LOG; step x true >/dev/null 2>&1 ); rc=$?
check "step without BB_LOG returns 2" eq "$rc" 2

if [ "$failed" = 0 ]; then echo PASS; else echo FAIL; exit 1; fi
