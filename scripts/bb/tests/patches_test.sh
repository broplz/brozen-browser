#!/usr/bin/env bash
# Test for scripts/bb/patches.sh on a throwaway fixture under mktemp -d. Last line: PASS | FAIL.
# Only -u: the assert helpers and "cmd; rc=$?" captures rely on non-zero statuses not aborting.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../patches.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/bb-patches-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
ENG="$T/engine"
SRC="$T/src"
FAILS=0

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }

# assert_has <text> <pattern> <message>   (extended regex)
assert_has() { echo "$1" | grep -q -E -- "$2" || fail "$3 (wanted /$2/ in: $1)"; }
assert_lacks() { echo "$1" | grep -q -E -- "$2" && fail "$3 (unexpected /$2/ in: $1)"; return 0; }
assert_eq() { [ "$1" = "$2" ] || fail "$3 (got '$1', want '$2')"; }

run() { TMPDIR="$T" BB_ENGINE_DIR="$ENG" BB_SRC_DIR="$SRC" /bin/bash "$SCRIPT" "$@"; }

eg() { git -C "$ENG" "$@"; }

# edit <file> <sed-expr> — rewrite a file in the engine work tree
edit() { sed "$2" "$ENG/$1" > "$ENG/$1.new" && mv "$ENG/$1.new" "$ENG/$1"; }

# bbpatch <name> <file> — README + patch (= current engine diff of <file> against HEAD)
bbpatch() {
  local d="$SRC/bb/patches/layer/$1"
  mkdir -p "$d"
  printf -- '---\nepic: layer\nfiles:\n  - %s\nupstream: none\n---\n# Why\n' "$2" > "$d/README.md"
  eg diff --src-prefix=a/ --dst-prefix=b/ --full-index -- "$2" > "$d/$1.patch"
}

mkdir -p "$ENG/a/b" "$SRC/a/b" "$SRC/external-patches/ext"
eg init -q
seq 1 40 | sed 's/^/line /' > "$ENG/a/b/foo.sys.mjs"
seq 1 40 | sed 's/^/line /' > "$ENG/a/b/ext.sys.mjs"
eg add -A
eg commit -q -m firefox
ROOT="$(eg rev-list --max-parents=0 HEAD)"

# Zen's patches: flat one for foo.sys.mjs, external-patches one for ext.sys.mjs
edit a/b/foo.sys.mjs 's/^line 20$/line 20 zen/'
eg diff --src-prefix=a/ --dst-prefix=b/ -- a/b/foo.sys.mjs > "$SRC/a/b/foo-sys-mjs.patch"
eg checkout -q -- .
edit a/b/ext.sys.mjs 's/^line 20$/line 20 zen/'
eg diff --src-prefix=a/ --dst-prefix=b/ -- a/b/ext.sys.mjs > "$SRC/external-patches/ext/ext.patch"
eg checkout -q -- .

# BB patches made on clean Firefox
edit a/b/foo.sys.mjs 's/^line 35$/line 35 bb/'
bbpatch far a/b/foo.sys.mjs
eg checkout -q -- .
edit a/b/foo.sys.mjs 's/^line 20$/line 20 bb/'
bbpatch overlap a/b/foo.sys.mjs
eg checkout -q -- .
edit a/b/ext.sys.mjs 's/^line 20$/line 20 bb/'
bbpatch extoverlap a/b/ext.sys.mjs
eg checkout -q -- .

# BB patch whose context comes from Zen's line: build on Firefox + Zen, commit, diff, reset
eg apply "$SRC/a/b/foo-sys-mjs.patch"
eg commit -q -a -m zen
edit a/b/foo.sys.mjs 's/^line 21$/line 21 bb/'
bbpatch zenonly a/b/foo.sys.mjs
eg reset -q --hard "$ROOT"

# a-d: check
OUT="$(run check)"
RC=$?
assert_eq "$RC" 1 "check exit code with failing patches"
assert_has "$OUT" '^OK layer/far$' "a: far patch is OK"
assert_has "$OUT" '^FAIL layer/overlap: zen ' "b: overlapping patch fails on zen"
assert_has "$OUT" '^FAIL layer/zenonly: clean ' "c: zen-only patch fails on clean"
assert_has "$OUT" '^FAIL layer/extoverlap: zen ' "d: external-patches Zen patch is applied for the zen base"

OUT="$(run check layer/far)"
assert_eq "$?" 0 "check of a good patch exits 0"
assert_eq "$OUT" "OK layer/far" "check with an id argument checks only that patch"

# e-g: engine work tree = Firefox + Zen patch + BB edit
eg apply "$SRC/a/b/foo-sys-mjs.patch"
edit a/b/foo.sys.mjs 's/^line 35$/line 35 bb/'
mkdir -p "$SRC/bb/patches/layer/exp"
cp "$SRC/bb/patches/layer/far/README.md" "$SRC/bb/patches/layer/exp/README.md"

state() { echo "$(eg status --porcelain)|$(shasum "$ENG/.git/index" | cut -d' ' -f1)"; }
BEFORE="$(state)"
run check > /dev/null
OUT="$(run status)"
assert_eq "$(state)" "$BEFORE" "h: check/status leave porcelain and index unchanged"
assert_has "$OUT" '^applied layer/far$' "g: status sees the applied patch"
assert_has "$OUT" '^not-applied layer/overlap$' "g: status sees a not-applied patch"

OUT="$(run export "$SRC/bb/patches/layer/exp")"
assert_eq "$?" 0 "export exits 0"
EXP="$SRC/bb/patches/layer/exp/exp.patch"
CONTENT="$(cat "$EXP" 2>/dev/null)"
assert_has "$CONTENT" '^\+line 35 bb$' "e: exported patch has the BB hunk"
assert_lacks "$CONTENT" 'zen' "e: exported patch has no Zen lines"
assert_has "$CONTENT" '^diff --git a/a/b/foo.sys.mjs b/a/b/foo.sys.mjs$' "e: diff --git header"
assert_has "$CONTENT" '^index [0-9a-f]{40}\.\.[0-9a-f]{40}' "e: full-index line"

# f: round trip on Firefox + Zen
git clone -q "$ENG" "$T/rt"
git -C "$T/rt" apply --ignore-space-change --ignore-whitespace "$SRC/a/b/foo-sys-mjs.patch"
git -C "$T/rt" apply --ignore-space-change --ignore-whitespace "$EXP" || fail "f: exported patch does not apply on Firefox + Zen"

# export with nothing to export leaves the file untouched
eg checkout -q -- .
eg apply "$SRC/a/b/foo-sys-mjs.patch"
SUM="$(shasum "$EXP")"
run export "$SRC/bb/patches/layer/exp" > /dev/null 2>&1
assert_eq "$?" 1 "export of an empty diff exits 1"
assert_eq "$(shasum "$EXP")" "$SUM" "export of an empty diff leaves the file untouched"

# i: no BB patches
mkdir -p "$T/empty"
OUT="$(TMPDIR="$T" BB_ENGINE_DIR="$ENG" BB_SRC_DIR="$T/empty" /bin/bash "$SCRIPT" check)"
assert_eq "$?" 0 "i: check without patches exits 0"
assert_eq "$OUT" "no BB patches" "i: message"

# j: usage
ERR="$(run bogus 2>&1 >/dev/null)"
assert_eq "$?" 2 "j: unknown command exits 2"
assert_has "$ERR" 'usage' "j: usage on stderr"
ERR="$(run export 2>&1 >/dev/null)"
assert_eq "$?" 2 "j: export without dir exits 2"
assert_has "$ERR" 'usage' "j: export usage on stderr"

if [ "$FAILS" -eq 0 ]; then echo PASS; else echo "FAIL ($FAILS)"; exit 1; fi
