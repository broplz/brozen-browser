#!/usr/bin/env bash
# BB rebase runbook (ADR-0002 Решение 4): steps 1-4 preflight, fetch, recon, rebase/<tag>;
# steps 5-11 deps, engine, patches, import, build, lint, smoke, package, install, finalize, publish
# (post_rebase).
#   rebase.sh <zen-tag>              run steps 1-11
#   rebase.sh --continue <zen-tag>   resume after the conflicts of step 4 were resolved
# Exit: 0 ok · 1 failure · 2 usage · 3 stopped on a git conflict.
# Env overrides: BB_REPO_DIR BB_MAIN_BRANCH BB_UPSTREAM_REMOTE BB_MIN_FREE_GB BB_GTAR BB_LOG_DIR
#   BB_ENGINE_DIR BB_TARBALL_DIR BB_PATCHES NVM_DIR
#   BB_SMOKE (smoke.sh) BB_REPORT (report.sh) BB_DIST_DIR (<repo>/dist, where the DMG is)
#   BB_APPS_DIR (/Applications) BB_PUSH_REMOTE (origin) BB_POST_STEPS (steps 5-11; tests shorten it).
# The main branch moves only in `publish`, after smoke, package, install and finalize succeeded;
# a failed step writes a `failed` report and leaves main untouched.
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
BB_ENGINE_DIR="${BB_ENGINE_DIR:-$BB_REPO_DIR/engine}"
BB_TARBALL_DIR="${BB_TARBALL_DIR:-$BB_REPO_DIR/.$(basename "$BUILD_CONFIG" .json)/engine}"
BB_PATCHES="${BB_PATCHES:-$BB_ROOT/scripts/bb/patches.sh}"
BB_SMOKE="${BB_SMOKE:-$BB_ROOT/scripts/bb/smoke.sh}"
BB_REPORT="${BB_REPORT:-$BB_ROOT/scripts/bb/report.sh}"
BB_DIST_DIR="${BB_DIST_DIR:-$BB_REPO_DIR/dist}"
BB_APPS_DIR="${BB_APPS_DIR:-/Applications}"
BB_PUSH_REMOTE="${BB_PUSH_REMOTE:-origin}"
BB_POST_STEPS="${BB_POST_STEPS:-deps engine patches import build lint smoke package install finalize publish}"
BB_REBASE_DOCS="$BB_REPO_DIR/docs/rebase"
export BB_ENGINE_DIR
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

# npm (and nvm) run with the repo as cwd; every npm call reports its own failure
npm_or_fail() { # npm_or_fail <what> <cmd…>
  local what="$1"
  shift
  "$@" || { say_fail "$what failed"; return 1; }
}

# ---- step 5 -------------------------------------------------------------------------------
# nvm changes PATH, so it runs in the main shell (a step runs in a pipe subshell); output goes to the log.
use_node() {
  local x rc=0
  x="$(base_zen)"
  [ "$(g show "refs/tags/$x:.nvmrc" 2>/dev/null)" = "$(g show "refs/tags/$Y:.nvmrc" 2>/dev/null)" ] && return 0
  echo "deps: .nvmrc changed, nvm use"
  set +eu
  . "$NVM_DIR/nvm.sh" && nvm use
  rc=$?
  set -eu
  return "$rc"
}

do_deps() {
  [ "${NVM_RC:-0}" = 0 ] || { say_fail "nvm use failed"; return 1; }
  npm_or_fail "npm ci" npm ci
}

# ---- step 6 -------------------------------------------------------------------------------
# prune_tarballs — keep the 2 newest Firefox source tarballs
prune_tarballs() {
  local f
  { ls -t "$BB_TARBALL_DIR"/firefox-*.source.tar.xz 2>/dev/null || true; } | tail -n +3 | while read -r f; do
    rm -f "$f"
  done
}

do_engine() {
  local fx fy
  fx="$(tag_firefox "$(base_zen)")"
  fy="$(tag_firefox "$Y")"
  if [ "$fx" = "$fy" ]; then
    echo "engine: firefox $fx unchanged, reset in place (objdir kept)"
    git -C "$BB_ENGINE_DIR" reset -q &&
      git -C "$BB_ENGINE_DIR" checkout -q -- . &&
      git -C "$BB_ENGINE_DIR" clean -fdxq -e 'obj-*' || { say_fail "engine reset failed"; return 1; }
    return 0
  fi
  echo "engine: firefox $fx -> $fy, re-download"
  rm -rf "$BB_ENGINE_DIR" || { say_fail "cannot remove $BB_ENGINE_DIR"; return 1; }
  npm_or_fail "npm run download" npm run download || return 1
  [ "${fx%%.*}" = "${fy%%.*}" ] || npm_or_fail "npm run bootstrap" npm run bootstrap || return 1
  prune_tarballs
}

# ---- step 7 -------------------------------------------------------------------------------
do_patches() {
  bash "$BB_PATCHES" check || {
    say_fail "stop: BB patch check failed — fix with git apply --reject in engine/, patches.sh export, check again"
    return 1
  }
}

# ---- steps 8-9 ----------------------------------------------------------------------------
do_import() { npm_or_fail "npm run import" npm run import; }
do_build() { npm_or_fail "npm run build" caffeinate -dims npm run build -- --jobs 6; }
do_lint() { npm_or_fail "npm run lint" npm run lint; }

# ---- step 10 ------------------------------------------------------------------------------
do_smoke() { bash "$BB_SMOKE" "$Y"; }

do_package() { npm_or_fail "npm run package" npm run package; }

# newest DMG of $BB_DIST_DIR -> $BB_APPS_DIR/<name>.app; the DMG is detached on every path
do_install() {
  local dmg mnt app dest rc=0
  dmg="$({ ls -t "$BB_DIST_DIR"/*.dmg 2>/dev/null || true; } | head -n 1)"
  if [ -z "$dmg" ]; then say_fail "no DMG in $BB_DIST_DIR"; return 1; fi
  mnt="$(mktemp -d)"
  if ! hdiutil attach -nobrowse -mountpoint "$mnt" "$dmg"; then
    rmdir "$mnt"
    say_fail "cannot attach $dmg"
    return 1
  fi
  app="$({ ls -d "$mnt"/*.app 2>/dev/null || true; } | head -n 1)"
  if [ -d "$app" ]; then
    dest="$BB_APPS_DIR/$(basename "$app")"
    mkdir -p "$BB_APPS_DIR" && rm -rf "$dest" && ditto "$app" "$dest" || rc=1
  else
    say_fail "no .app in $dmg"
    rc=1
  fi
  hdiutil detach "$mnt" || true
  rmdir "$mnt" 2>/dev/null || true
  [ "$rc" -eq 0 ] || say_fail "install from $dmg failed"
  return "$rc"
}

# ---- step 11 ------------------------------------------------------------------------------
# rewrite_base <zen> <firefox> <commit> — the three keys of the `base:` block, rest byte-identical
rewrite_base() {
  awk -v z="$1" -v f="$2" -v c="$3" '
    /^base:/ { b = 1; print; next }
    b && /^[^ ]/ { b = 0 }
    b && /^ +zen:/ { sub(/zen:.*/, "zen: " z) }
    b && /^ +firefox:/ { sub(/firefox:.*/, "firefox: " f) }
    b && /^ +commit:/ { sub(/commit:.*/, "commit: " c) }
    { print }' "$LAYER_YAML"
}

# on rebase/Y: new base in layer.yaml + the ok report, one commit
do_finalize() {
  local fy tmp
  fy="$(tag_firefox "$Y")"
  tmp="$(mktemp)"
  rewrite_base "$Y" "$fy" "$(g rev-parse --short "refs/tags/$Y^{commit}")" >"$tmp" &&
    cat "$tmp" >"$LAYER_YAML" || { rm -f "$tmp"; say_fail "cannot rewrite layer.yaml"; return 1; }
  rm -f "$tmp"
  BB_REBASE_DOCS="$BB_REBASE_DOCS" bash "$BB_REPORT" "$Y" "$BB_LOG" ok || { say_fail "report failed"; return 1; }
  g add src/bb/layer.yaml "docs/rebase/$Y.md" docs/rebase/README.md &&
    g commit -q -m "rebase: Zen $Y (Firefox $fy)" || { say_fail "commit failed"; return 1; }
}

# the only place that moves main: expects origin's main to be the one the rebase started from
do_publish() {
  local old
  old="$(g rev-parse "$BB_MAIN_BRANCH")"
  # the tag does not depend on main: create it first, so a failure here leaves main untouched
  g tag "bb/base/$Y" "refs/tags/$Y^{commit}" || { say_fail "cannot create tag bb/base/$Y"; return 1; }
  publish_rollback() {
    g switch -q "rebase/$Y" && g branch -f "$BB_MAIN_BRANCH" "$old" && g tag -d "bb/base/$Y" >/dev/null ||
      { say_fail "$1; rollback failed — restore by hand: git switch rebase/$Y; git branch -f $BB_MAIN_BRANCH $old; git tag -d bb/base/$Y"; return 1; }
    say_fail "$1, $BB_MAIN_BRANCH restored"
  }
  if ! { g branch -f "$BB_MAIN_BRANCH" "rebase/$Y" && g switch -q "$BB_MAIN_BRANCH"; }; then
    publish_rollback "cannot move $BB_MAIN_BRANCH" || true
    return 1
  fi
  if ! g push --atomic --force-with-lease="$BB_MAIN_BRANCH:$old" "$BB_PUSH_REMOTE" "$BB_MAIN_BRANCH" "refs/tags/bb/base/$Y"; then
    publish_rollback "push to '$BB_PUSH_REMOTE' rejected" || true
    return 1
  fi
  g branch -d "rebase/$Y"
}

post_rebase() {
  local n
  cd "$BB_REPO_DIR"
  echo "post-rebase: steps 5-11" | tee -a "$BB_LOG"
  NVM_RC=0
  use_node >>"$BB_LOG" 2>&1 || NVM_RC=$?
  for n in $BB_POST_STEPS; do
    run_step "$n" post
  done
}

# run_step <name> [post] — step "<name>" do_<name>; map its failure to the exit codes of the header
run_step() {
  local rc=0 msg
  step "$1" "do_$1" || rc=$?
  case "$rc" in
    0) return 0 ;;
    3) exit 3 ;;
  esac
  # the report lands in the work tree: only on rebase/Y; on main it would dirty the tree and fail the next preflight
  if [ "$(g symbolic-ref --short -q HEAD || true)" = "rebase/$Y" ]; then
    BB_REBASE_DOCS="$BB_REBASE_DOCS" bash "$BB_REPORT" "$Y" "$BB_LOG" failed "$1" || true
  else
    echo "note: no failed report for step $1 (HEAD is not rebase/$Y)" >>"$BB_LOG"
  fi
  msg="$({ grep '^rebase: ' "$BB_LOG" || true; } | tail -n 1)"
  echo "${msg:-rebase: step $1 failed (exit $rc)}" >&2
  if [ -n "${2:-}" ]; then echo "stop: $1" >&2; fi
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
  post_rebase
  exit 0
fi

bb_log_open "rebase-$Y" >/dev/null
for n in preflight fetch recon rebase; do
  run_step "$n"
done
post_rebase
