#!/usr/bin/env bash
# Tests for scripts/bb/rebase.sh steps 5-9. Run: /bin/bash scripts/bb/tests/rebase_post_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rebase="$here/../rebase.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
. "$here/rebase_fixture.sh"
stub_env

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
eq() { [ "$1" = "$2" ]; }
has() { grep -qF -- "$1" <<<"$2"; } # has <needle> <text>
calls_has() { grep -qxF -- "$1" "$CALLS"; }
calls_lack() { ! calls_has "$1"; }
# in_order <line…> — the lines appear in $CALLS in this order (other lines may sit between)
in_order() {
  local l n=0 pos
  for l in "$@"; do
    pos="$(tail -n +$((n + 1)) "$CALLS" | grep -nxF -- "$l" | head -n 1 | cut -d: -f1)"
    [ -n "$pos" ] || return 1
    n=$((n + pos))
  done
}
# next_line <line> — the line right after <line> in $CALLS
next_line() { grep -xF -A1 -- "$1" "$CALLS" | sed -n 2p; }

# fixture <name> <ffx> <ffy> <nvmx> <nvmy> — repo on branch rebase/1.0.1b, X=1.0.0b, Y=1.0.1b; sets R LOGS
fixture() {
  R="$T/$1/repo"
  LOGS="$T/$1/logs"
  mkdir -p "$R/src/bb"
  git -C "$R" init -q -b main
  printf 'base:\n  zen: 1.0.0b\n' >"$R/src/bb/layer.yaml"
  ff_cfg "$2" >"$R/surfer.json"
  echo "$4" >"$R/.nvmrc"
  git -C "$R" add -A
  git -C "$R" commit -qm x
  git -C "$R" tag 1.0.0b
  ff_cfg "$3" >"$R/surfer.json"
  echo "$5" >"$R/.nvmrc"
  git -C "$R" commit -qam y --allow-empty
  git -C "$R" tag 1.0.1b
  git -C "$R" switch -q -c rebase/1.0.1b
  export BB_REPO_DIR="$R" BB_LOG_DIR="$LOGS"
  : >"$CALLS"
  make_engine
  STUB_FAIL_BUILD=
}

run_rb() {
  RC=0
  /bin/bash "$rebase" --continue 1.0.1b >"$T/out" 2>"$T/err" || RC=$?
  ERR="$(cat "$T/err")"
  LOG="$(cat "$LOGS"/rebase-1.0.1b-*.log 2>/dev/null)"
}

# (a) Firefox changed within one major, .nvmrc changed
# (the task text lists 150.0 -> 151.0 here but also calls that a major change; same-major is used)
fixture a 150.0 150.0.1 22 24
run_rb
check "a: exit 0 (stderr: $ERR)" eq "$RC" 0
check "a: calls in order" in_order "nvm use" "npm ci" "npm run download" "npm run import" \
  "caffeinate -dims npm run build -- --jobs 6" "npm run lint"
check "a: no bootstrap (same major)" calls_lack "npm run bootstrap"
check "a: engine removed before download" calls_lack "ENGINE-EXISTS"
check "a: old objdir gone" test ! -e "$BB_ENGINE_DIR/obj-x/keep"
# (g) footers
for s in deps engine patches import build lint; do
  check "g: log has $s exit=0" has "<== step: $s exit=0" "$LOG"
done

# (b) major changed -> bootstrap right after download
fixture b 150.0 151.0 22 22
run_rb
check "b: exit 0 (stderr: $ERR)" eq "$RC" 0
check "b: bootstrap right after download" eq "$(next_line "npm run download")" "npm run bootstrap"
check "b: .nvmrc unchanged, no nvm use" calls_lack "nvm use"

# (c) Firefox unchanged
fixture c 150.0 150.0 22 22
echo changed >"$BB_ENGINE_DIR/tracked.txt"
run_rb
check "c: exit 0 (stderr: $ERR)" eq "$RC" 0
check "c: no download" calls_lack "npm run download"
check "c: objdir kept" test -e "$BB_ENGINE_DIR/obj-x/keep"
check "c: junk gone" test ! -e "$BB_ENGINE_DIR/junk"
check "c: tracked edit reverted" eq "$(cat "$BB_ENGINE_DIR/tracked.txt")" orig
check "c: no nvm use" calls_lack "nvm use"
check "c: npm ci still runs" calls_has "npm ci"

# (d) only the 2 newest tarballs remain
fixture d 150.0 150.0.1 22 22
touch -t 202001010000 "$BB_TARBALL_DIR/firefox-1.source.tar.xz"
touch -t 202002010000 "$BB_TARBALL_DIR/firefox-2.source.tar.xz"
touch -t 202003010000 "$BB_TARBALL_DIR/firefox-3.source.tar.xz"
touch -t 202004010000 "$BB_TARBALL_DIR/firefox-4.source.tar.xz"
run_rb
check "d: exit 0 (stderr: $ERR)" eq "$RC" 0
check "d: two tarballs left" eq "$(ls "$BB_TARBALL_DIR" | wc -l | tr -d ' ')" 2
check "d: the newest two" eq "$(ls "$BB_TARBALL_DIR" | tr '\n' ' ')" "firefox-3.source.tar.xz firefox-4.source.tar.xz "

# (e) patch check fails
fixture e 150.0 150.0.1 22 22
printf '#!/bin/sh\necho "FAIL layer/x: zen conflict"\nexit 1\n' >"$T/stubs/fail-patches.sh"
BB_PATCHES="$T/stubs/fail-patches.sh" run_rb
check "e: exit 1" eq "$RC" 1
check "e: no import" calls_lack "npm run import"
check "e: log footer" has "<== step: patches exit=1" "$LOG"
check "e: stop on stderr" has "stop: patches" "$ERR"

# (f) build fails
fixture f 150.0 150.0.1 22 22
STUB_FAIL_BUILD=1 run_rb
check "f: exit 1" eq "$RC" 1
check "f: no lint" calls_lack "npm run lint"
check "f: build footer" has "<== step: build exit=1" "$LOG"

# (h) nvm use fails
fixture h 150.0 150.0.1 22 24
STUB_FAIL_NVM=1 run_rb
check "h: exit 1" eq "$RC" 1
check "h: no npm ci" calls_lack "npm ci"
check "h: deps footer" has "<== step: deps exit=1" "$LOG"
check "h: stop on stderr" has "stop: deps" "$ERR"

if [ "$failed" = 0 ]; then echo PASS; else echo FAIL; exit 1; fi
