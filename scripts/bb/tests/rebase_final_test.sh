#!/usr/bin/env bash
# Tests for scripts/bb/rebase.sh steps 10-11. Run: /bin/bash scripts/bb/tests/rebase_final_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rebase="$here/../rebase.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
. "$here/rebase_fixture.sh"
stub_env
unset BB_POST_STEPS # the whole of steps 5-11

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
eq() { [ "$1" = "$2" ]; }
has() { grep -qF -- "$1" <<<"$2"; } # has <needle> <text>
calls_has() { grep -qxF -- "$1" "$CALLS"; }
calls_lack() { ! calls_has "$1"; }
calls_grep() { grep -qF -- "$1" "$CALLS"; }
rev() { git -C "$R" rev-parse "$1"; }
orev() { git --git-dir="$O" rev-parse "$1"; }

# fixture <name> — upstream, clone, bare origin; sets R (clone) O (origin) LOGS MAIN_SHA
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
  MAIN_SHA="$(rev main)"
  : >"$CALLS"
  make_engine
  rm -rf "$T/Applications"
  STUB_FAIL_SMOKE= STUB_FAIL_BUILD=
}

# run_rb — sets RC ERR LOG
run_rb() {
  RC=0
  /bin/bash "$rebase" 1.0.1b >"$T/out" 2>"$T/err" || RC=$?
  ERR="$(cat "$T/err")"
  LOG="$(cat "$LOGS"/rebase-1.0.1b-*.log 2>/dev/null)"
}

# footers — "name exit=N" of every step footer in the log, in order, on one line
footers() { grep '^<== step: ' <<<"$LOG" | cut -d' ' -f3,4 | tr '\n' ' '; }
main_same() { eq "$(rev main)" "$MAIN_SHA"; }
failed_report() { # failed_report <blocker>
  grep -qxF -- "- status: failed" "$R/docs/rebase/1.0.1b.md" && grep -qxF -- "- blocker: $1" "$R/docs/rebase/1.0.1b.md"
}

# (a) happy path
fixture a
run_rb
check "a: exit 0 (stderr: $ERR)" eq "$RC" 0
check "a: footers after lint" has "lint exit=0 smoke exit=0 package exit=0 install exit=0 finalize exit=0 publish exit=0 " "$(footers)"
check "a: smoke lines in the log" has "smoke: result 1/1" "$LOG"
check "a: npm run package" calls_has "npm run package"
check "a: app installed" test -e "$T/Applications/BB.app/x"
check "a: hdiutil detach" calls_grep "hdiutil detach"
# (b) the commit
check "b: subject" eq "$(git -C "$R" log -1 --format=%s main)" "rebase: Zen 1.0.1b (Firefox 151.0)"
check "b: files" eq "$(git -C "$R" diff-tree --no-commit-id --name-status -r main | tr '\n\t' '  ')" "A docs/rebase/1.0.1b.md M docs/rebase/README.md M src/bb/layer.yaml "
layer="$(git -C "$R" show main:src/bb/layer.yaml)"
check "b: layer zen" has "  zen: 1.0.1b" "$layer"
check "b: layer firefox" has "  firefox: 151.0" "$layer"
check "b: layer commit" has "  commit: $(git -C "$R" rev-parse --short 1.0.1b)" "$layer"
check "b: layer rest kept" has "hooks: []" "$layer"
check "b: report ok" has "- status: ok" "$(git -C "$R" show main:docs/rebase/1.0.1b.md)"
check "b: README row" has "| 1.0.1b |" "$(git -C "$R" show main:docs/rebase/README.md)"
# (c) refs
check "c: tag at Y" eq "$(rev 'bb/base/1.0.1b^{commit}')" "$(rev '1.0.1b^{commit}')"
check "c: origin main" eq "$(orev main)" "$(rev main)"
check "c: origin tag" test -n "$(git --git-dir="$O" tag --list bb/base/1.0.1b)"
check "c: no upstream tag pushed" test -z "$(git --git-dir="$O" tag --list 1.0.1b)"
check "c: rebase branch gone" eq "$(git -C "$R" branch --list 'rebase/*')" ""
check "c: on main" eq "$(git -C "$R" symbolic-ref --short HEAD)" main

# (d) smoke fails
fixture d
ORIGIN_SHA="$(orev main)"
STUB_FAIL_SMOKE=1 run_rb
check "d: exit 1" eq "$RC" 1
check "d: main unchanged" main_same
check "d: origin unchanged" eq "$(orev main)" "$ORIGIN_SHA"
check "d: rebase branch kept" test -n "$(git -C "$R" branch --list 'rebase/*')"
check "d: failed report" failed_report smoke
check "d: no package" calls_lack "npm run package"

# (e) build fails
fixture e
STUB_FAIL_BUILD=1 run_rb
check "e: exit 1" eq "$RC" 1
check "e: main unchanged" main_same
check "e: failed report" failed_report build

# (f) origin moved before publish
fixture f
cat >"$T/bump-smoke.sh" <<'EOF'
#!/bin/sh
git clone -q "$BB_PUSH_REMOTE" "$BUMP_DIR" && git -C "$BUMP_DIR" commit -q --allow-empty -m other &&
  git -C "$BUMP_DIR" push -q origin HEAD:main
echo "smoke: y e0 window"
echo "smoke: result 1/1"
EOF
BB_SMOKE="$T/bump-smoke.sh" BUMP_DIR="$T/bump" run_rb
check "f: exit 1" eq "$RC" 1
check "f: publish footer" has "<== step: publish exit=1" "$LOG"
check "f: stop on stderr" has "stop: publish" "$ERR"
check "f: main restored" main_same
check "f: no local tag" test -z "$(git -C "$R" tag --list bb/base/1.0.1b)"
check "f: rebase branch kept" test -n "$(git -C "$R" branch --list 'rebase/*')"
check "f: origin has the other commit" eq "$(git --git-dir="$O" log -1 --format=%s main)" other
check "f: origin has no tag" test -z "$(git --git-dir="$O" tag --list bb/base/1.0.1b)"

# (g) fetch fails on main: no report is left behind, the tree stays clean for a re-run
fixture g
git -C "$R" remote set-url upstream "$T/g/no-such.git"
run_rb
check "g: exit 1" eq "$RC" 1
check "g: tree clean" eq "$(git -C "$R" status --porcelain)" ""
check "g: main unchanged" main_same

# (h) a stale local tag bb/base/Y: publish fails, main is untouched
fixture h
git -C "$R" tag bb/base/1.0.1b 1.0.0b
run_rb
check "h: exit 1" eq "$RC" 1
check "h: publish footer" has "<== step: publish exit=1" "$LOG"
check "h: main unchanged" main_same
check "h: rebase branch kept" test -n "$(git -C "$R" branch --list 'rebase/*')"

if [ "$failed" = 0 ]; then echo PASS; else echo FAIL; exit 1; fi
