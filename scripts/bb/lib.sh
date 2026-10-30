# shellcheck shell=bash
# Shared library for BB product scripts. Source it; it never changes the caller's shell options.

BB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BB_LOG_DIR="${BB_LOG_DIR:-$BB_ROOT/../logs}"

# bb_log_open <basename> — start a run log, export BB_LOG, print its path.
bb_log_open() {
  mkdir -p "$BB_LOG_DIR"
  BB_LOG="$BB_LOG_DIR/$1-$(date +%Y%m%d-%H%M%S).log"
  export BB_LOG
  echo "$BB_LOG"
}

# step "<name>" <cmd> [args…] — run cmd with header/footer, tee into $BB_LOG, return cmd's exit code.
step() {
  local name="$1" rc start
  shift
  if [ -z "${BB_LOG:-}" ]; then
    echo "step: BB_LOG is not set (call bb_log_open first)" >&2
    return 2
  fi
  start=$SECONDS
  echo "==> $(date '+%Y-%m-%d %H:%M:%S') step: $name" | tee -a "$BB_LOG"
  # && / || list keeps a caller's set -e / pipefail from aborting before the footer.
  "$@" 2>&1 | tee -a "$BB_LOG" && rc=${PIPESTATUS[0]} || rc=${PIPESTATUS[0]}
  echo "<== step: $name exit=$rc duration=$((SECONDS - start))s" | tee -a "$BB_LOG"
  return "$rc"
}
