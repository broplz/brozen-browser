#!/usr/bin/env bash
# Tests for scripts/bb/l10n.sh. Run: /bin/bash scripts/bb/tests/l10n_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/../l10n.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || { echo "FAIL: $msg"; failed=1; }
}
eq() { [ "$1" = "$2" ]; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

# upstream: two commits, pinned = the first
git init -q "$T/up"
git -C "$T/up" config uploadpack.allowAnySHA1InWant true
for d in en-US ru nb-NO de; do
  mkdir -p "$T/up/$d"
  echo one >"$T/up/$d/a.ftl"
done
git -C "$T/up" add -A
git -C "$T/up" commit -q -m first
hash="$(git -C "$T/up" rev-parse HEAD)"
echo two >"$T/up/ru/a.ftl"
git -C "$T/up" commit -q -am second

# fake repo
mkdir -p "$T/repo/build/firefox-cache" "$T/repo/locales"
printf '%s' "$hash" >"$T/repo/build/firefox-cache/l10n-last-commit-hash"
printf 'ru\r\nnb\r\n' >"$T/repo/locales/supported-languages"
printf 'nb:nb-NO' >"$T/repo/locales/language-maps"
export BB_REPO_DIR="$T/repo" BB_L10N_CACHE="$T/cache" BB_L10N_URL="$T/up" BB_LOG_DIR="$T/logs"
co="$T/repo/locales/firefox-l10n"

# (a) first run
out="$(/bin/bash "$script" 2>"$T/err")"; rc=$?
check "a: first run exit 0 (got $rc)" eq "$rc" 0
check "a: cache is bare" eq "$(git -C "$T/cache" rev-parse --is-bare-repository)" true
dirs="$(cd "$co" && for d in */; do echo "${d%/}"; done | sort | tr '\n' ' ')"
check "a: dirs are en-US nb-NO ru (got: $dirs)" eq "$dirs" "en-US nb-NO ru "
check "a: HEAD is the pinned hash" eq "$(git -C "$co" rev-parse HEAD)" "$hash"
check "a: stdout has fetched" has "$out" "l10n: fetched $hash"

# (d) log footer for run (a)
logs="$(cat "$T"/logs/l10n-*.log 2>/dev/null)"
check "d: log footer exit=0" has "$logs" "<== step: l10n exit=0"

# (b) cached, upstream unreachable
out="$(BB_L10N_URL="$T/nowhere" /bin/bash "$script" 2>"$T/err")"; rc=$?
check "b: second run exit 0 (got $rc)" eq "$rc" 0
check "b: stdout has cached" has "$out" "l10n: cached $hash"
check "b: same HEAD" eq "$(git -C "$co" rev-parse HEAD)" "$hash"

# (c) unknown commit
bad=1111111111111111111111111111111111111111
printf '%s' "$bad" >"$T/repo/build/firefox-cache/l10n-last-commit-hash"
/bin/bash "$script" >/dev/null 2>"$T/err"; rc=$?
check "c: unknown hash exit 1 (got $rc)" eq "$rc" 1
check "c: stderr names the hash" has "$(cat "$T/err")" "$bad"

if [ "$failed" = 0 ]; then echo PASS; else echo FAIL; exit 1; fi
