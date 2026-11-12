#!/usr/bin/env bash
# Tests for rebase.sh finalize: brands.bb displayVersion = the Zen tag, in the finalize commit.
# Run: /bin/bash scripts/bb/tests/rebase_display_version_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rebase="$here/../rebase.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
. "$here/rebase_fixture.sh"
stub_env

CFG="$(printf 'sur%s.json' fer)" # the build config's name, never typed whole

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
eq() { [ "$1" = "$2" ]; }
has() { grep -qF -- "$1" <<<"$2"; } # has <needle> <text>
rgit() { git -C "$R" "$@"; }

# fixture <name> — upstream, clone, bare origin, then the rebase up to rebase/1.0.1b (steps 1-4 + lint)
fixture() {
  local d="$T/$1" w
  w="$d/w"
  R="$d/repo"
  O="$d/origin.git"
  mkdir -p "$w/src/zen"
  git -C "$w" init -q -b main
  ff_cfg 150.0 >"$w/$CFG"
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

  ff_cfg 151.0 >"$w/$CFG"
  echo 24 >"$w/.nvmrc"
  printf 'up\nl2\nl3\nl4\nl5\n' >"$w/src/zen/moz.build"
  git -C "$w" commit -qam upstream
  git -C "$w" tag 1.0.1b
  git clone -q --bare "$w" "$d/up.git"
  git -C "$R" remote set-url upstream "$d/up.git"

  git init -q --bare -b main "$O"
  git -C "$R" push -q "$O" main refs/tags/bb/base/1.0.0b

  export BB_REPO_DIR="$R" BB_LOG_DIR="$d/logs" BB_MIN_FREE_GB=0 BB_GTAR=sh BB_PUSH_REMOTE="$O"
  : >"$CALLS"
  make_engine
  rm -rf "$T/Applications"
  BB_POST_STEPS=lint /bin/bash "$rebase" 1.0.1b >"$T/out" 2>"$T/err" || echo "FAIL: $1: setup rebase: $(cat "$T/err")"
}

# finalize_rb — --continue with the finalize step only; sets RC ERR
finalize_rb() {
  RC=0
  BB_POST_STEPS=finalize /bin/bash "$rebase" --continue 1.0.1b >"$T/out" 2>"$T/err" || RC=$?
  ERR="$(cat "$T/err")"
}

# (a) finalize ok
fixture a
finalize_rb
check "a: exit 0 (stderr: $ERR)" eq "$RC" 0
files="$(rgit show --name-only --format= HEAD)"
check "a: config in the commit" has "$CFG" "$files"
check "a: layer.yaml in the commit" has "src/bb/layer.yaml" "$files"
check "a: report in the commit" has "docs/rebase/1.0.1b.md" "$files"
cfg="$(cat "$R/$CFG")"
check "a: bb displayVersion" has '"displayVersion": "1.0.1b"' "$(grep -A3 '"bb"' <<<"$cfg")"
check "a: release displayVersion kept" has '"displayVersion": "9.9.9"' "$(grep -B3 '"bb"' <<<"$cfg")"
diffl="$(rgit diff HEAD~1 HEAD -- "$CFG" | grep -E '^[-+][^-+]')"
check "a: one - and one + line" eq "$(wc -l <<<"$diffl" | tr -d ' ')" 2
check "a: the - line is the old value" has '-        "displayVersion": "0.0.0"' "$diffl"
check "a: the + line is the tag" has '+        "displayVersion": "1.0.1b"' "$diffl"

# (b) no bb brand: nothing is touched
fixture b
printf '{\n  "brands": {\n    "release": {\n      "release": {\n        "displayVersion": "9.9.9"\n      }\n    }\n  },\n  "version": {\n    "version": "151.0"\n  }\n}\n' >"$R/$CFG"
rgit commit -qam "no bb brand"
head_before="$(rgit rev-parse HEAD)"
finalize_rb
check "b: exit 1" eq "$RC" 1
check "b: stderr names displayVersion" has displayVersion "$ERR"
check "b: HEAD unchanged" eq "$(rgit rev-parse HEAD)" "$head_before"
check "b: config and layer.yaml untouched" eq "$(rgit status --porcelain -- "$CFG" src/bb/layer.yaml)" ""

if [ "$failed" = 0 ]; then echo "rebase_display_version_test: OK"; else echo "rebase_display_version_test: FAIL"; exit 1; fi
