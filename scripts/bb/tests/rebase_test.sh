#!/usr/bin/env bash
# Tests for scripts/bb/rebase.sh steps 1-4. Run: /bin/bash scripts/bb/tests/rebase_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rebase="$here/../rebase.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
eq() { [ "$1" = "$2" ]; }
has() { grep -qF -- "$1" <<<"$2"; } # has <needle> <text>
cfg() { printf '{\n  "version": {\n    "product": "firefox",\n    "version": "%s"\n  }\n}\n' "$1"; }

# fixture <name> <ok|conflict> — upstream, clone and env for one case; sets R (clone) and LOGS
fixture() {
  local d="$T/$1" w
  w="$d/w"
  R="$d/repo"
  LOGS="$d/logs"
  mkdir -p "$w/src/zen"
  git -C "$w" init -q -b main
  cfg 150.0 >"$w/surfer.json"
  echo 22 >"$w/.nvmrc"
  printf 'l1\nl2\nl3\nl4\nl5\n' >"$w/src/zen/moz.build"
  git -C "$w" add -A
  git -C "$w" commit -qm base
  git -C "$w" tag 1.0.0b
  git clone -q "$w" "$R"
  git -C "$R" remote rename origin upstream
  git -C "$R" tag bb/base/1.0.0b

  mkdir -p "$R/src/bb/patches/layer/x"
  printf 'base:\n  zen: 1.0.0b\nhooks:\n  - file: src/zen/moz.build\n    line: hook\n    epic: layer\n    why: x\nedits: []\nzen_patches: []\n' >"$R/src/bb/layer.yaml"
  printf -- '--- a/browser/base/content/browser.js\n+++ b/browser/base/content/browser.js\n@@ -1 +1 @@\n-a\n+b\n' >"$R/src/bb/patches/layer/x/x.patch"
  if [ "$2" = conflict ]; then
    printf 'bb\nl2\nl3\nl4\nl5\n' >"$R/src/zen/moz.build"
  else
    printf 'hook\n' >>"$R/src/zen/moz.build"
  fi
  git -C "$R" add -A
  git -C "$R" commit -qm bb

  cfg 151.0 >"$w/surfer.json"
  echo 24 >"$w/.nvmrc"
  printf 'up\nl2\nl3\nl4\nl5\n' >"$w/src/zen/moz.build"
  git -C "$w" commit -qam upstream
  git -C "$w" tag 1.0.1b
  git clone -q --bare "$w" "$d/up.git"
  git -C "$R" remote set-url upstream "$d/up.git"

  export BB_REPO_DIR="$R" BB_LOG_DIR="$LOGS" BB_MIN_FREE_GB=0 BB_GTAR=sh
  MAIN_SHA="$(git -C "$R" rev-parse main)"
}

# run_rb <args…> — sets OUT (stdout), ERR (stderr), RC
run_rb() {
  RC=0
  OUT="$(/bin/bash "$rebase" "$@" 2>"$T/err")" || RC=$?
  ERR="$(cat "$T/err")"
}

main_same() { eq "$(git -C "$R" rev-parse main)" "$MAIN_SHA"; }
no_rebase_branch() { eq "$(git -C "$R" branch --list 'rebase/*')" ""; }
logs() { ls "$LOGS"/rebase-"$1"-*.log 2>/dev/null; }
count_logs() { logs "$1" | wc -l | tr -d ' '; }

# (a) happy path
fixture a ok
run_rb 1.0.1b
check "a: exit 0 (stderr: $ERR)" eq "$RC" 0
check "a: BB commit sits on 1.0.1b" eq "$(git -C "$R" rev-parse rebase/1.0.1b^)" "$(git -C "$R" rev-parse 1.0.1b)"
check "a: BB commit kept layer.yaml" git -C "$R" cat-file -e rebase/1.0.1b:src/bb/layer.yaml
check "a: one log" eq "$(count_logs 1.0.1b)" 1
log="$(cat "$LOGS"/rebase-1.0.1b-*.log)"
for line in "recon: zen 1.0.0b -> 1.0.1b" "recon: firefox 150.0 -> 151.0" "recon: upstream-commits 1" \
  "recon: toolchain-changed .nvmrc" "recon: expected-conflict src/zen/moz.build layer"; do
  check "a: log has '$line'" has "$line" "$log"
done
for s in preflight fetch recon rebase; do
  check "a: log has $s exit=0" has "<== step: $s exit=0" "$log"
done
check "a: main unchanged" main_same

# (b) conflict, then --continue ; (c) --continue while in progress
fixture b conflict
run_rb 1.0.1b
check "b: exit 3" eq "$RC" 3
check "b: stdout conflict line" has "conflict: git src/zen/moz.build layer" "$OUT"
check "b: log conflict line" has "conflict: git src/zen/moz.build layer" "$(cat "$LOGS"/rebase-1.0.1b-*.log)"
run_rb --continue 1.0.1b
check "c: --continue in progress exits 1" eq "$RC" 1
check "c: stderr says in progress (stderr: $ERR)" has "in progress" "$ERR"
printf 'merged\nl2\nl3\nl4\nl5\n' >"$R/src/zen/moz.build"
git -C "$R" add src/zen/moz.build
GIT_EDITOR=true git -C "$R" rebase --continue >/dev/null 2>&1
run_rb --continue 1.0.1b
check "b: --continue exit 0 (stderr: $ERR)" eq "$RC" 0
check "b: still one log" eq "$(count_logs 1.0.1b)" 1
check "b: post-rebase in log" has "post-rebase:" "$(cat "$LOGS"/rebase-1.0.1b-*.log)"
check "b: main unchanged" main_same

# (d) preflight failures
preflight_fails() { # preflight_fails <name>
  check "d $1: exit 1" eq "$RC" 1
  check "d $1: one-line reason" eq "$(wc -l <<<"$ERR" | tr -d ' ')" 1
  check "d $1: reason not empty" test -n "$ERR"
  check "d $1: no rebase branch" no_rebase_branch
  check "d $1: main unchanged" main_same
}
fixture d ok
echo dirty >"$R/untracked"
run_rb 1.0.1b
preflight_fails "dirty tree"
rm "$R/untracked"

git -C "$R" switch -q -c other
run_rb 1.0.1b
preflight_fails "not main"
git -C "$R" switch -q main

BB_MIN_FREE_GB=999999 run_rb 1.0.1b
preflight_fails "free space"

BB_GTAR=no-such-gtar-xyz run_rb 1.0.1b
preflight_fails "gtar"

run_rb 1.0.0b
preflight_fails "target equals base"

# (e) unknown tag
run_rb 9.9.9b
check "e: exit 1" eq "$RC" 1
check "e: reason on stderr" test -n "$ERR"
check "e: no rebase branch" no_rebase_branch
check "e: main unchanged" main_same

# (f) usage
run_rb
check "f: no args exit 2" eq "$RC" 2
check "f: usage on stderr" has "usage" "$ERR"
run_rb --bogus
check "f: unknown option exit 2" eq "$RC" 2
check "f: usage on stderr (option)" has "usage" "$ERR"
check "f: main unchanged" main_same

if [ "$failed" = 0 ]; then echo PASS; else echo FAIL; exit 1; fi
