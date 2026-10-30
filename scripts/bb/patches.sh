#!/usr/bin/env bash
# BB patch tool (ADR-0002, Решение 2): check | export <dir> | status. Git only; never writes the
# engine's real index or work tree (export/check use a temporary index).
set -euo pipefail

# shellcheck source=scripts/bb/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BB_ENGINE_DIR="${BB_ENGINE_DIR:-$BB_ROOT/engine}"
BB_SRC_DIR="${BB_SRC_DIR:-$BB_ROOT/src}"
PATCH_ROOT="$BB_SRC_DIR/bb/patches"
APPLY_FLAGS="--ignore-space-change --ignore-whitespace"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/bb-patches.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

usage() {
  echo "usage: patches.sh check [<epic>/<name>…] | export <patch-dir> | status [<epic>/<name>…]" >&2
  exit 2
}

egit() { git -C "$BB_ENGINE_DIR" "$@"; }

FIREFOX="$(egit rev-list --max-parents=0 HEAD 2>/dev/null | head -n 1 || true)"
[ -n "$FIREFOX" ] || { echo "patches.sh: no root commit in $BB_ENGINE_DIR" >&2; exit 1; }
ERR=""

# resolve <id-or-dir> → patch dir
resolve_dir() {
  if [ -d "$1" ]; then (cd "$1" && pwd); else echo "$PATCH_ROOT/$1"; fi
}

# patch_dirs [<id>…] → one patch dir per line (all of them without args)
patch_dirs() {
  local d
  if [ $# -gt 0 ]; then
    for d in "$@"; do resolve_dir "$d"; done
    return 0
  fi
  for d in "$PATCH_ROOT"/*/*/; do
    d="${d%/}"
    if [ -f "$d/$(basename "$d").patch" ]; then echo "$d"; fi
  done
}

patch_id() { echo "$(basename "$(dirname "$1")")/$(basename "$1")"; }

patch_file() { echo "$1/$(basename "$1").patch"; }

# targets <patch> → files named by "+++ b/<path>"
targets() { grep '^+++ b/' "$1" | cut -c7- || true; }

# readme_files <dir> → README frontmatter "files:" entries
readme_files() {
  awk '
    /^files:/ { on = 1; next }
    on && /^  - / { sub(/^  - /, ""); print; next }
    on { exit }
  ' "$1/README.md"
}

# zen_patches <file…> → Zen patches touching these files (flat patch + external-patches scan)
zen_patches() {
  local f flat
  for f in "$@"; do
    flat="$BB_SRC_DIR/$(dirname "$f")/$(basename "$f" | tr . -).patch"
    if [ -f "$flat" ]; then echo "$flat"; fi
    if [ -d "$BB_SRC_DIR/external-patches" ]; then
      grep -rl --include='*.patch' -Fx "+++ b/$f" "$BB_SRC_DIR/external-patches" || true
    fi
  done | sort -u
}

# make_index <clean|zen> <file…> → sets GIT_INDEX_FILE to a fresh temp index; returns 1 on failure
# (message in $ERR). zen with no Zen patches returns 3.
make_index() {
  local base="$1" p
  shift
  GIT_INDEX_FILE="$TMP/index.$base"
  export GIT_INDEX_FILE
  rm -f "$GIT_INDEX_FILE"
  ERR="$(egit read-tree "$FIREFOX" 2>&1)" || return 1
  [ "$base" = zen ] || return 0
  local patches
  patches="$(zen_patches "$@")"
  [ -n "$patches" ] || return 3
  while IFS= read -r p; do
    ERR="$(egit apply --cached $APPLY_FLAGS "$p" 2>&1)" || { ERR="zen patch $(basename "$p"): $ERR"; return 1; }
  done <<EOF
$patches
EOF
}

first_line() { echo "$1" | head -n 1; }

cmd_check() {
  local d id pf files base rc fail=0 found=0
  while IFS= read -r d; do
    found=1
    id="$(patch_id "$d")"
    pf="$(patch_file "$d")"
    files="$(targets "$pf")"
    ERR=""
    for base in clean zen; do
      rc=0
      # shellcheck disable=SC2086
      make_index "$base" $files || rc=$?
      if [ "$rc" -eq 3 ]; then continue; fi
      if [ "$rc" -eq 0 ]; then
        ERR="$(egit apply --cached --check $APPLY_FLAGS "$pf" 2>&1)" || rc=1
      fi
      unset GIT_INDEX_FILE
      if [ "$rc" -ne 0 ]; then
        echo "FAIL $id: $base $(first_line "$ERR")"
        fail=1
        continue 2
      fi
    done
    echo "OK $id"
  done < <(patch_dirs "$@")
  [ "$found" -eq 1 ] || echo "no BB patches"
  return "$fail"
}

cmd_export() {
  [ $# -eq 1 ] || usage
  local d name files out rc=0
  d="$(resolve_dir "$1")"
  name="$(basename "$d")"
  [ -f "$d/README.md" ] || { echo "export: no README.md in $d" >&2; return 1; }
  files="$(readme_files "$d")"
  [ -n "$files" ] || { echo "export: README.md has no files: list" >&2; return 1; }
  # shellcheck disable=SC2086
  make_index zen $files || rc=$?
  case $rc in 0 | 3) ;; *) echo "export: $ERR" >&2; return 1 ;; esac
  # git add -N: a file the BB patch creates is not in the Firefox tree yet; show it in the diff
  # shellcheck disable=SC2086
  egit add -N -- $files 2>/dev/null || true
  # shellcheck disable=SC2086
  out="$(egit diff --src-prefix=a/ --dst-prefix=b/ --full-index -- $files)"
  unset GIT_INDEX_FILE
  [ -n "$out" ] || { echo "export: empty diff for $name; patch left untouched" >&2; return 1; }
  printf '%s\n' "$out" > "$d/$name.patch"
  echo "exported $(patch_id "$d")"
}

cmd_status() {
  local d pf
  while IFS= read -r d; do
    pf="$(patch_file "$d")"
    if egit apply --check -R $APPLY_FLAGS "$pf" >/dev/null 2>&1; then
      echo "applied $(patch_id "$d")"
    else
      echo "not-applied $(patch_id "$d")"
    fi
  done < <(patch_dirs "$@")
}

[ $# -ge 1 ] || usage
cmd="$1"
shift
case "$cmd" in
  check) cmd_check "$@" ;;
  export) cmd_export "$@" ;;
  status) cmd_status "$@" ;;
  *) usage ;;
esac
