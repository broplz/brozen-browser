#!/usr/bin/env bash
# Tests for rebase.sh: BB_JOBS and `--continue` after a failed publish.
# Run: /bin/bash scripts/bb/tests/rebase_continue_test.sh
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
calls_has() { grep -qxF -- "$1" "$CALLS"; }
calls_lack() { ! calls_has "$1"; }
calls_no_npm() { ! grep -q '^npm ' "$CALLS"; }
rev() { git -C "$R" rev-parse "$1"; }

# fixture <name> — upstream, clone, bare origin; sets R O LOGS
fixture() {
  local d="$T/$1" w
  w="$d/w"
  R="$d/repo"
  O="$d/origin.git"
  LOGS="$d/logs"
  mkdir -p "$w/src/zen"
  git -C "$w" init -q -b main
  ff_cfg 150.0 >"$w/surfer.json"
  echo 22 >"$w/.nvmrc"
  printf 'l1\nl2\nl3\nl4\nl5\n' >"$w/src/zen/moz.build"
  git -C "$w" add -A
  git -C "$w" commit -qm base
  git -C "$w" tag 1.0.0b
  git clone -q "$w" "$R"
  git -C "$R" remote rename origin upstream
  git -C "$R" tag bb/base/1.0.0b

  mkdir -p "$R/src/bb" "$R/docs/rebase"
  printf 'base:\n  zen: 1.0.0b\n  firefox: 150.0\n  commit: 0000000\nhooks: []\nedits: []\nzen_patches: []\n' >"$R/src/bb/layer.yaml"
  printf '| tag | date |\n|---|---|\n' >"$R/docs/rebase/README.md"
  printf 'hook\n' >>"$R/src/zen/moz.build"
  git -C "$R" add -A
  git -C "$R" commit -qm bb

  ff_cfg 151.0 >"$w/surfer.json"
  echo 24 >"$w/.nvmrc"
  printf 'up\nl2\nl3\nl4\nl5\n' >"$w/src/zen/moz.build"
  git -C "$w" commit -qam upstream
  git -C "$w" tag 1.0.1b
  git clone -q --bare "$w" "$d/up.git"
  git -C "$R" remote set-url upstream "$d/up.git"

  git init -q --bare -b main "$O"
  git -C "$R" push -q "$O" main refs/tags/bb/base/1.0.0b

  export BB_REPO_DIR="$R" BB_LOG_DIR="$LOGS" BB_MIN_FREE_GB=0 BB_GTAR=sh BB_PUSH_REMOTE="$O"
  : >"$CALLS"
  make_engine
  rm -rf "$T/Applications"
  STUB_FAIL_SMOKE= STUB_FAIL_BUILD=
}

# run_rb [args…] — sets RC ERR; default args: the tag
run_rb() {
  RC=0
  /bin/bash "$rebase" "${@:-1.0.1b}" >"$T/out" 2>"$T/err" || RC=$?
  ERR="$(cat "$T/err")"
}

# (a) BB_JOBS
fixture a
unset BB_JOBS
BB_POST_STEPS=build run_rb
check "a: default jobs (stderr: $ERR)" calls_has "npm run build -- --jobs 6"
fixture a2
BB_JOBS=3 BB_POST_STEPS=build run_rb
check "a: BB_JOBS=3 (stderr: $ERR)" calls_has "npm run build -- --jobs 3"
check "a: no jobs 6" calls_lack "npm run build -- --jobs 6"

# (b) publish fails, --continue publishes only
fixture b
unset BB_POST_STEPS
GOOD_REMOTE="$BB_PUSH_REMOTE"
BB_PUSH_REMOTE="$T/b/missing.git" run_rb
check "b: first run fails" eq "$RC" 1
check "b: on rebase branch" eq "$(git -C "$R" symbolic-ref --short HEAD)" rebase/1.0.1b
: >"$CALLS"
BB_PUSH_REMOTE="$GOOD_REMOTE" run_rb --continue 1.0.1b
check "b: continue exit 0 (stderr: $ERR)" eq "$RC" 0
check "b: no npm calls" calls_no_npm
check "b: one finalize commit" eq "$(git -C "$R" log --format=%s main | grep -cxF 'rebase: Zen 1.0.1b (Firefox 151.0)')" 1
check "b: subject" eq "$(git -C "$R" log -1 --format=%s main)" "rebase: Zen 1.0.1b (Firefox 151.0)"
check "b: origin tag" test -n "$(git --git-dir="$O" tag --list bb/base/1.0.1b)"
check "b: origin main" eq "$(git --git-dir="$O" rev-parse main)" "$(rev main)"
check "b: rebase branch gone" eq "$(git -C "$R" branch --list 'rebase/*')" ""

# (c) no finalize commit: the post steps run
fixture c
BB_POST_STEPS=lint run_rb
: >"$CALLS"
BB_POST_STEPS=deps run_rb --continue 1.0.1b
check "c: continue exit 0 (stderr: $ERR)" eq "$RC" 0
check "c: deps ran" calls_has "npm ci"
check "c: still on rebase branch" eq "$(git -C "$R" symbolic-ref --short HEAD)" rebase/1.0.1b

if [ "$failed" = 0 ]; then echo "rebase_continue_test: OK"; else echo "rebase_continue_test: FAIL"; exit 1; fi
