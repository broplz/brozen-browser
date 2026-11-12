#!/usr/bin/env bash
# Tests for the step-3 recon of scripts/bb/rebase.sh: an expected conflict only when a layer hunk and
# an upstream hunk lie within BB_RECON_MARGIN lines. Run: /bin/bash scripts/bb/tests/rebase_recon_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rebase="$here/../rebase.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
. "$here/rebase_fixture.sh"
stub_env
make_engine

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
has() { grep -qF -- "$1" <<<"$2"; } # has <needle> <text>
not_has() { ! has "$@"; }

# f_txt <changed line…> — 10 lines "l<n>", the listed ones are "X<n>"
f_txt() {
  local n c l
  for n in 1 2 3 4 5 6 7 8 9 10; do
    c=l
    for l in "$@"; do [ "$l" = "$n" ] && c=X; done
    echo "$c$n"
  done
}

# zen_patch [<extra hunk header>] — the Zen patch of a/b.js
zen_patch() {
  printf -- '--- a/a/b.js\n+++ b/a/b.js\n@@ -100,3 +100,3 @@\n-a\n+b\n'
  [ -z "$1" ] || printf '%s\n-c\n+d\n' "$1"
}

# scenario <name> <layer lines> <upstream lines> <upstream zen-patch hunk> — runs rebase.sh, sets LOG
# (lines are the changed lines of src/zen/f.txt, e.g. "1" or "5 6"; empty = unchanged)
scenario() {
  local d="$T/$1" w R
  w="$d/w"
  R="$d/repo"
  mkdir -p "$w/src/zen" "$w/src/a"
  git -C "$w" init -q -b main
  echo '{ "version": { "version": "150.0" } }' >"$w/surfer.json"
  f_txt >"$w/src/zen/f.txt"
  zen_patch >"$w/src/a/b-js.patch"
  git -C "$w" add -A
  git -C "$w" commit -qm base
  git -C "$w" tag 1.0.0b
  git clone -q "$w" "$R"
  git -C "$R" remote rename origin upstream
  git -C "$R" tag bb/base/1.0.0b

  mkdir -p "$R/src/bb/patches/layer/x"
  printf 'base:\n  zen: 1.0.0b\nhooks:\n  - file: src/zen/f.txt\n    line: hook\n    epic: layer\n    why: x\nedits: []\nzen_patches: []\n' >"$R/src/bb/layer.yaml"
  printf -- '--- a/a/b.js\n+++ b/a/b.js\n@@ -20,2 +20,2 @@\n-a\n+b\n' >"$R/src/bb/patches/layer/x/x.patch"
  # shellcheck disable=SC2086
  f_txt $2 >"$R/src/zen/f.txt"
  git -C "$R" add -A
  git -C "$R" commit -qm bb

  echo '{ "version": { "version": "151.0" } }' >"$w/surfer.json"
  # shellcheck disable=SC2086
  f_txt $3 >"$w/src/zen/f.txt"
  zen_patch "$4" >"$w/src/a/b-js.patch"
  git -C "$w" commit -qam upstream
  git -C "$w" tag 1.0.1b
  git clone -q --bare "$w" "$d/up.git"
  git -C "$R" remote set-url upstream "$d/up.git"

  export BB_REPO_DIR="$R" BB_LOG_DIR="$d/logs" BB_MIN_FREE_GB=0 BB_GTAR=sh
  /bin/bash "$rebase" 1.0.1b >/dev/null 2>&1
  LOG="$(cat "$d"/logs/rebase-1.0.1b-*.log)"
}

F="recon: expected-conflict src/zen/f.txt layer"
P="recon: expected-conflict src/a/b-js.patch layer"

scenario a 1 10 ""
check "a: layer top, upstream end: no line" not_has "recon: expected-conflict" "$LOG"

scenario b 5 7 ""
check "b: 2 lines apart: line" has "$F" "$LOG"

scenario c 5 5 ""
check "c: same line: line" has "$F" "$LOG"

BB_RECON_MARGIN=0 scenario d 5 7 ""
check "d: margin 0: no line" not_has "recon: expected-conflict" "$LOG"

scenario e1 "" "" "@@ -300,3 +300,3 @@"
check "e: far Zen hunk: no line" not_has "recon: expected-conflict" "$LOG"

scenario e2 "" "" "@@ -21,3 +21,3 @@"
check "e: overlapping Zen hunk: line" has "$P" "$LOG"

scenario f "" 5 ""
check "f: layer does not change the file: no line" not_has "recon: expected-conflict" "$LOG"

if [ "$failed" = 0 ]; then echo "rebase_recon_test: OK"; else echo "rebase_recon_test: FAIL"; exit 1; fi
