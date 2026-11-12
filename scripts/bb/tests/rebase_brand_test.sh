#!/usr/bin/env bash
# Tests for rebase.sh: brand selection, the en-US packs step, .python-version in recon.
# Run: /bin/bash scripts/bb/tests/rebase_brand_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rebase="$here/../rebase.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
. "$here/rebase_fixture.sh"
stub_env

# python3 stub: log argv; fails when STUB_FAIL_PY is set
cat >"$T/stubs/bin/python3" <<'EOF'
#!/bin/sh
echo "python3 $*" >>"$CALLS"
[ -z "$STUB_FAIL_PY" ]
EOF
chmod +x "$T/stubs/bin/python3"

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
eq() { [ "$1" = "$2" ]; }
calls_has() { grep -qxF -- "$1" "$CALLS"; }

# fixture <name> — a repo already on rebase/1.0.1b; sets R
fixture() {
  local d="$T/$1"
  R="$d/repo"
  mkdir -p "$R/src/bb" "$R/docs/rebase"
  git -C "$R" init -q -b main
  ff_cfg 150.0 >"$R/surfer.json"
  printf 'base:\n  zen: 1.0.0b\n  firefox: 150.0\n  commit: 0000000\nhooks: []\nedits: []\nzen_patches: []\n' >"$R/src/bb/layer.yaml"
  git -C "$R" add -A
  git -C "$R" commit -qm base
  git -C "$R" switch -q -c rebase/1.0.1b
  export BB_REPO_DIR="$R" BB_LOG_DIR="$d/logs" BB_MIN_FREE_GB=0 BB_GTAR=sh
  : >"$CALLS"
  make_engine
  STUB_FAIL_PY=
}

run_rb() {
  RC=0
  /bin/bash "$rebase" --continue 1.0.1b >"$T/out" 2>"$T/err" || RC=$?
  ERR="$(cat "$T/err")"
}

STEPS="import en_us_packs build package"

# calls_in_order <line…> — every line present, in this order
calls_in_order() {
  local want
  want="$(printf '%s\n' "$@")"
  eq "$(grep -xF -f <(printf '%s\n' "$@") "$CALLS")" "$want"
}

# (a) default brand
fixture a
BB_POST_STEPS="$STEPS" run_rb
check "a: exit 0 (stderr: $ERR)" eq "$RC" 0
check "a: order" calls_in_order \
  "npm run surfer -- set brand bb" "npm run import" "python3 scripts/update_en_US_packs.py" \
  "npm run build -- --jobs 6" "npm run surfer -- set brand bb" "npm run package"
check "a: two brand lines" eq "$(grep -cxF 'npm run surfer -- set brand bb' "$CALLS")" 2

# (b) BB_BRAND=release
fixture b
BB_BRAND=release BB_POST_STEPS="$STEPS" run_rb
check "b: exit 0 (stderr: $ERR)" eq "$RC" 0
check "b: two release brand lines" eq "$(grep -cxF 'npm run surfer -- set brand release' "$CALLS")" 2
check "b: no bb brand" eq "$(grep -cxF 'npm run surfer -- set brand bb' "$CALLS")" 0

# (c) en-US packs fail
fixture c
STUB_FAIL_PY=1 BB_POST_STEPS="$STEPS" run_rb
check "c: exit 1" eq "$RC" 1
check "c: stderr stop" grep -q 'stop: en_us_packs' "$T/err"
check "c: no build" eq "$(grep -c '^npm run build' "$CALLS")" 0

# (d) recon watches .python-version
check "d: toolchain" grep -q 'TOOLCHAIN_FILES=.*\.python-version' "$here/../rebase.sh"

if [ "$failed" = 0 ]; then echo "rebase_brand_test: OK"; else echo "rebase_brand_test: FAIL"; exit 1; fi
