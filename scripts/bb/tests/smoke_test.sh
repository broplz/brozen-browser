#!/usr/bin/env bash
# Tests for scripts/bb/smoke.sh. Run: /bin/bash scripts/bb/tests/smoke_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke="$here/../smoke.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $1"; failed=1; }
check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || fail "$msg"
}
has_line() { grep -qxF -- "$2" "$1"; }

mkdir -p "$T/dir" "$T/prof"
printf '# comment\nitem one\n\nitem two\n' > "$T/dir/e0.txt"
printf 'item three\n' > "$T/dir/e3.txt"
echo data > "$T/prof/pfile"
printf '#!/bin/sh\necho noise\necho "$*" > "%s/argv"\n' "$T" > "$T/stub"
chmod +x "$T/stub"

export BB_SMOKE_DIR="$T/dir" BB_SMOKE_TMP="$T" BB_SMOKE_PROFILE="$T/prof" BB_SMOKE_BIN="$T/stub"

run() { # run <stdin> <args…> — sets rc; stdout in $T/out, stderr in $T/err
  local input="$1"
  shift
  rc=0
  printf '%b' "$input" | /bin/bash "$smoke" "$@" > "$T/out" 2> "$T/err" || rc=$?
}

# (a) all yes, order, result
run 'y\ny\ny\n' --no-launch 2030
check "a: exit 0" test "$rc" = 0
expected_a() { printf 'smoke: y e0 item one\nsmoke: y e0 item two\nsmoke: y e3 item three\nsmoke: result 3/3\n'; }
check "a: stdout lines and order" diff <(expected_a) "$T/out"

# (b) one no
run 'y\nn\ny\n' --no-launch 2030
check "b: exit 1" test "$rc" = 1
check "b: n line" has_line "$T/out" "smoke: n e0 item two"
check "b: last line" test "$(tail -n 1 "$T/out")" = "smoke: result 2/3"

# (c) invalid answer re-asked
run 'x\ny\ny\ny\n' --no-launch 2030
check "c: exit 0" test "$rc" = 0
check "c: result" test "$(tail -n 1 "$T/out")" = "smoke: result 3/3"

# (d) EOF before the last item
run 'y\ny\n' --no-launch 2030
check "d: exit 1" test "$rc" = 1
check "d: aborted" grep -qF "smoke: aborted" "$T/err"

# (e) profile copy and launch args
mkdir -p "$T/bb-smoke-2031"
echo stale > "$T/bb-smoke-2031/stale"
rm -f "$T/argv"
run 'y\ny\ny\n' 2031
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  grep -qF -- "bb-smoke-2031" "$T/argv" 2>/dev/null && break
  sleep 0.2
done
check "e: exit 0" test "$rc" = 0
check "e: only smoke lines on stdout" test "$(grep -c -v '^smoke: ' "$T/out")" = 0
check "e: profile file copied" test -f "$T/bb-smoke-2031/pfile"
check "e: stale file gone" test ! -e "$T/bb-smoke-2031/stale"
check "e: argv" grep -qF -- "-profile $T/bb-smoke-2031" "$T/argv"

# (f) --no-launch
rm -f "$T/argv"
run 'y\ny\ny\n' --no-launch 2032
sleep 0.5
check "f: exit 0" test "$rc" = 0
check "f: stub not called" test ! -e "$T/argv"
check "f: checklist ran" test "$(tail -n 1 "$T/out")" = "smoke: result 3/3"

# (g) no build found
rc=0
printf 'y\ny\ny\n' | env -u BB_SMOKE_BIN BB_ENGINE_DIR="$T/none" /bin/bash "$smoke" 2030 > "$T/out" 2> "$T/err" || rc=$?
check "g: exit 1" test "$rc" = 1
check "g: message" grep -qF "smoke: no build found" "$T/err"

# (h) usage
run ''
check "h: no arg exit 2" test "$rc" = 2
check "h: usage" grep -q "usage" "$T/err"
run '' --bogus 2030
check "h: unknown option exit 2" test "$rc" = 2
check "h: unknown option usage" grep -q "usage" "$T/err"

if [ "$failed" = 0 ]; then
  echo PASS
else
  echo FAILED
  exit 1
fi
