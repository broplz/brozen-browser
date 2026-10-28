#!/usr/bin/env bash
# BB rebase runbook (ADR-0002 Решение 4), steps 1-4: preflight, fetch, recon, rebase/<tag>.
#   rebase.sh <zen-tag>              run steps 1-4
#   rebase.sh --continue <zen-tag>   resume after the conflicts of step 4 were resolved
# Exit: 0 ok · 1 failure · 2 usage · 3 stopped on a git conflict.
# Env overrides: BB_REPO_DIR BB_MAIN_BRANCH BB_UPSTREAM_REMOTE BB_MIN_FREE_GB BB_GTAR BB_LOG_DIR.
# Never touches the main branch, never publishes anything, never deletes branches.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"

BB_REPO_DIR="${BB_REPO_DIR:-$BB_ROOT}"
BB_MAIN_BRANCH="${BB_MAIN_BRANCH:-main}"
BB_UPSTREAM_REMOTE="${BB_UPSTREAM_REMOTE:-upstream}"
BB_MIN_FREE_GB="${BB_MIN_FREE_GB:-60}"
BB_GTAR="${BB_GTAR:-gtar}"

LAYER_YAML="$BB_REPO_DIR/src/bb/layer.yaml"
BUILD_CONFIG="surfer.json"
TOOLCHAIN_FILES=".nvmrc rust-toolchain.toml package-lock.json requirements.txt"

usage() {
  echo "usage: rebase.sh <zen-tag> | rebase.sh --continue <zen-tag>" >&2
  exit 2
}

g() { git -C "$BB_REPO_DIR" "$@"; }

# Inside step functions errexit is disabled (lib.sh runs them in a && / || list):
# report with `say_fail "<reason>"; return 1`. The last "rebase:" log line becomes the stderr reason.
say_fail() { echo "rebase: $*"; }

tag_exists() { g rev-parse -q --verify "refs/tags/$1" >/dev/null; }

rebase_in_progress() {
  local d p
  for d in rebase-merge rebase-apply; do
    p="$(g rev-parse --git-path "$d")"
    case "$p" in /*) ;; *) p="$BB_REPO_DIR/$p" ;; esac
    [ -e "$p" ] && return 0
  done
  return 1
}

# base_zen — X, the Zen tag the layer sits on
base_zen() {
  awk '/^base:/{b=1;next} b&&/^[^ ]/{b=0} b&&/^ +zen:/{print $2; exit}' "$LAYER_YAML"
}

# registry_pairs — "<file> <epic>" for every `- file:` entry of layer.yaml
registry_pairs() {
  awk '/^ *- file:/{f=$3} /^ +epic:/{if(f!=""){print f, $2; f=""}}' "$LAYER_YAML"
}

# patch_pairs — "<zen patch of a BB patch target> <epic>"
patch_pairs() {
  local root="$BB_REPO_DIR/src/bb/patches" p epic t nm
  for p in "$root"/*/*/*.patch; do
    [ -f "$p" ] || continue
    epic="${p#"$root"/}"
    epic="${epic%%/*}"
    { grep '^+++ b/' "$p" || true; } | cut -c7- | while read -r t; do
      nm="${t##*/}"
      echo "src/${t%/*}/${nm//./-}.patch $epic"
    done
  done
}

# epic_of <file> — owner epic by ADR-0002 Решение 2
epic_of() {
  local rest e
  case "$1" in
    src/bb/patches/*) rest="${1#src/bb/patches/}"; echo "${rest%%/*}" ;;
    src/bb/*/*) rest="${1#src/bb/}"; echo "${rest%%/*}" ;;
    src/bb/*) echo layer ;;
    *)
      e="$(registry_pairs | awk -v f="$1" '$1==f{print $2; exit}')"
      echo "${e:-unregistered}"
      ;;
  esac
}

# tag_firefox <tag> — Firefox version from the "version": { block of the build-config JSON
tag_firefox() {
  g show "refs/tags/$1:$BUILD_CONFIG" |
    awk '/"version"[ \t]*:[ \t]*\{/{blk=1;next} blk&&/"version"[ \t]*:/{gsub(/.*:[ \t]*"/,""); gsub(/".*/,""); print; exit}'
}

# ---- step 1 -------------------------------------------------------------------------------
do_preflight() {
  local x cur free
  if [ -n "$(g status --porcelain)" ]; then say_fail "working tree is not clean"; return 1; fi
  cur="$(g symbolic-ref --short -q HEAD || true)"
  if [ "$cur" != "$BB_MAIN_BRANCH" ]; then say_fail "current branch is '$cur', expected '$BB_MAIN_BRANCH'"; return 1; fi
  free="$(df -g "$BB_REPO_DIR" | awk 'NR==2{print $4}')"
  if [ "${free:-0}" -lt "$BB_MIN_FREE_GB" ]; then say_fail "free space ${free:-0} GB < $BB_MIN_FREE_GB GB"; return 1; fi
  if ! command -v "$BB_GTAR" >/dev/null; then say_fail "$BB_GTAR not found"; return 1; fi
  x="$(base_zen)"
  if [ -z "$x" ]; then say_fail "no 'base: zen:' in src/bb/layer.yaml"; return 1; fi
  if [ "$x" = "$Y" ]; then say_fail "target $Y equals the current base"; return 1; fi
  g config rerere.enabled true
  echo "preflight: base $x, target $Y"
}

# ---- step 2 -------------------------------------------------------------------------------
do_fetch() {
  if ! g fetch "$BB_UPSTREAM_REMOTE" --tags --prune --progress; then
    say_fail "fetch from '$BB_UPSTREAM_REMOTE' failed"
    return 1
  fi
  if ! tag_exists "$Y"; then say_fail "tag $Y not found after fetch"; return 1; fi
}

# ---- step 3 -------------------------------------------------------------------------------
do_recon() {
  local x f
  x="$(base_zen)"
  echo "recon: zen $x -> $Y"
  echo "recon: firefox $(tag_firefox "$x") -> $(tag_firefox "$Y")"
  echo "recon: upstream-commits $(g rev-list --count "refs/tags/$x..refs/tags/$Y")"
  # shellcheck disable=SC2086
  g diff --name-only "refs/tags/$x" "refs/tags/$Y" -- $TOOLCHAIN_FILES | while read -r f; do
    echo "recon: toolchain-changed $f"
  done
  g diff --name-only "refs/tags/$x" "refs/tags/$Y" |
    awk 'NR==FNR{if(!($1 in a))a[$1]=$2; next} ($1 in a){print "recon: expected-conflict", $1, a[$1]}' \
      <(registry_pairs; patch_pairs) -
}

# ---- step 4 -------------------------------------------------------------------------------
do_rebase() {
  local x rc=0 f files
  x="$(base_zen)"
  if g rev-parse -q --verify "refs/heads/rebase/$Y" >/dev/null; then say_fail "branch rebase/$Y already exists"; return 1; fi
  if ! tag_exists "bb/base/$x"; then say_fail "tag bb/base/$x not found"; return 1; fi
  g switch -c "rebase/$Y" "$BB_MAIN_BRANCH" || return 1
  g rebase --onto "refs/tags/$Y" "refs/tags/bb/base/$x" || rc=$?
  [ "$rc" -eq 0 ] && return 0
  files="$(g diff --name-only --diff-filter=U)"
  if [ -z "$files" ]; then say_fail "git rebase failed (exit $rc) without conflicts"; return 1; fi
  echo "$files" | while read -r f; do
    echo "conflict: git $f $(epic_of "$f")"
  done
  echo "hint: resolve the files above, 'git add' them, 'git rebase --continue', then 'scripts/bb/rebase.sh --continue $Y'"
  return 3
}

# Steps 5-9 are task 0014.
post_rebase() {
  echo "post-rebase: steps 5-9 are task 0014"
}

# run_step <name> — step "<name>" do_<name>; map its failure to the exit codes of the header
run_step() {
  local rc=0 msg
  step "$1" "do_$1" || rc=$?
  case "$rc" in
    0) return 0 ;;
    3) exit 3 ;;
  esac
  msg="$({ grep '^rebase: ' "$BB_LOG" || true; } | tail -n 1)"
  echo "${msg:-rebase: step $1 failed (exit $rc)}" >&2
  exit 1
}

# ---- main ---------------------------------------------------------------------------------
cont=0
case "${1:-}" in
  --continue) [ $# -eq 2 ] || usage; cont=1; Y="$2" ;;
  ""|-*) usage ;;
  *) [ $# -eq 1 ] || usage; Y="$1" ;;
esac

if [ "$cont" = 1 ]; then
  cur="$(g symbolic-ref --short -q HEAD || true)"
  if rebase_in_progress; then echo "rebase: a git rebase is still in progress; finish it first" >&2; exit 1; fi
  if [ "$cur" != "rebase/$Y" ]; then echo "rebase: --continue needs branch rebase/$Y, current is '$cur'" >&2; exit 1; fi
  BB_LOG="$({ ls -t "$BB_LOG_DIR"/rebase-"$Y"-*.log 2>/dev/null || true; } | head -n 1)"
  if [ -n "$BB_LOG" ]; then export BB_LOG; else bb_log_open "rebase-$Y" >/dev/null; fi
  echo "continue: $Y" | tee -a "$BB_LOG"
  post_rebase | tee -a "$BB_LOG"
  exit 0
fi

bb_log_open "rebase-$Y" >/dev/null
for n in preflight fetch recon rebase; do
  run_step "$n"
done
post_rebase | tee -a "$BB_LOG"
