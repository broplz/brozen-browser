#!/usr/bin/env bash
# The only build entry point for agents: import + build, serialized, logged, triaged.
#
#   scripts/agents/build.sh [auto|ui|full] [--no-import] [--jobs N]
#
# auto (default): ui unless the task's diff touches C/C++/ObjC/IDL/Rust/moz.build/mozconfig
#                 (patch targets included) — then full.
# ui   ≈ 3 min (surfer build --ui)      full ≈ 40 min on M1 Pro (surfer build --jobs N)
# One build at a time (logs/.build.lock). Output: logs/build-<type>-<stamp>.log; the triage is
# printed at the end so nobody needs the raw log. Exit: build exit code; 3 = full build required
# but this role may not run it; 4 = another build is running;
# 2 = bad argument or wrong environment (Node major != .nvmrc, gnu-tar missing).
# After import, the Zen en-US packs are copied (scripts/update_en_US_packs.py).
# Compatible with macOS bash 3.2: no arrays, no mapfile, no `timeout`.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
LOG_DIR="${BB_LOG_DIR:-$ROOT/logs}"; mkdir -p "$LOG_DIR"
TYPE="auto"; IMPORT=1; JOBS="${BB_JOBS:-6}"
while [ $# -gt 0 ]; do
  case "$1" in
    auto|ui|full) TYPE="$1" ;;
    --no-import) IMPORT=0 ;;
    --jobs) JOBS="$2"; shift ;;
    --full) TYPE="full" ;;
    --ui) TYPE="ui" ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

preflight() {  # wrong environment must fail fast, before the lock
  local want found
  want="$(head -n 1 "$ROOT/.nvmrc")"
  found="$(node --version 2>/dev/null | sed 's/^v//; s/\..*//')"
  if [ "$found" != "$want" ]; then
    echo "Node ${found:-missing} but .nvmrc wants $want: run nvm use (Node 25 breaks surfer import); expected Node $want"
    return 2
  fi
  command -v "${BB_GTAR:-gtar}" >/dev/null 2>&1 && return 0
  echo "gnu-tar not found (${BB_GTAR:-gtar}): run brew install gnu-tar"
  return 2
}
preflight || exit 2

FULL_RE='\.(c|cc|cpp|cxx|m|mm|h|hpp|idl|webidl|ipdl|rs|toml|configure|build)$|(^|/)moz\.build$|mozconfig|(^|/)Cargo\.lock$'
needs_full() {
  local base changed f
  base="${BB_BASE:-}"
  if [ -z "$base" ] && [ -n "${BB_TASK:-}" ]; then base="$(python3 scripts/agents/taskfile.py get "$BB_TASK" base)"; fi
  [ -z "$base" ] && base="$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD)"
  changed="$( (git diff --name-only "$base"...HEAD 2>/dev/null; git status --porcelain | cut -c4-) | sort -u)"
  [ -z "$changed" ] && return 1
  echo "$changed" | grep -Eq "$FULL_RE" && return 0
  for f in $(echo "$changed" | grep -E '\.patch$'); do
    [ -f "$f" ] && grep -E '^\+\+\+ ' "$f" | grep -Eq "$FULL_RE" && return 0
  done
  return 1
}

if [ "$TYPE" = "auto" ]; then
  if needs_full; then TYPE="full"; else TYPE="ui"; fi
  echo "build type (from diff): $TYPE"
fi
case "${BB_ROLE:-human}" in
  developer|reviewer|teamlead|log-triage|architect)
    if [ "$TYPE" = "full" ]; then
      echo "FULL BUILD REQUIRED (C++/ObjC/IDL/Rust/moz.build/mozconfig in the diff) but role '${BB_ROLE}' may only run ui builds."
      echo "This is a developer-hard task: write ## Handoff, set status: blocked, commit, end."
      exit 3
    fi ;;
esac

LOCK="$LOG_DIR/.build.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  OLD="$(cat "$LOCK/pid" 2>/dev/null || echo 0)"
  if [ "$OLD" != "0" ] && kill -0 "$OLD" 2>/dev/null; then
    echo "another build is running (pid $OLD, since $(cat "$LOCK/since" 2>/dev/null)). Wait with: sleep 120, then retry once."
    exit 4
  fi
  rm -rf "$LOCK"; mkdir "$LOCK" || exit 4
fi
echo $$ > "$LOCK/pid"; date '+%F %T' > "$LOCK/since"
trap 'rm -rf "$LOCK"' EXIT INT TERM

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/build-$TYPE-$STAMP.log"
START=$(date +%s)
RC=0
step() {  # step <name> <command...>   — header, tee into the log, duration, exit code
  local name="$1"; shift
  local t0 t1 rc
  t0=$(date +%s)
  printf '\n===== %s  [%s]  %s =====\n' "$name" "$(date '+%F %T')" "$*" | tee -a "$LOG"
  "$@" 2>&1 | tee -a "$LOG"
  rc=${PIPESTATUS[0]}
  t1=$(date +%s)
  printf '===== %s: exit %s after %ss =====\n' "$name" "$rc" "$((t1 - t0))" | tee -a "$LOG"
  return "$rc"
}
CAF=""; command -v caffeinate >/dev/null 2>&1 && CAF="caffeinate -dims"

echo "log: $LOG"
if [ "$IMPORT" = "1" ]; then
  step "import" npm run import || RC=$?
  if [ "$RC" = "0" ]; then step "en-US-packs" python3 scripts/update_en_US_packs.py || RC=$?; fi
fi
if [ "$RC" = "0" ]; then
  if [ "$TYPE" = "full" ]; then
    step "build-full" $CAF npm run build -- --jobs "$JOBS" || RC=$?
  else
    step "build-ui" $CAF npm run build:ui || RC=$?
  fi
fi
END=$(date +%s)
if [ "$RC" = "0" ]; then RES="OK"; else RES="FAIL"; fi
printf '\nBUILD RESULT: %s type=%s duration=%ss exit=%s log=%s\n' "$RES" "$TYPE" "$((END - START))" "$RC" "$LOG" | tee -a "$LOG"
echo "--- triage (python3 scripts/agents/triage_log.py $LOG) ---"
python3 scripts/agents/triage_log.py "$LOG" --max-lines 80
exit "$RC"
