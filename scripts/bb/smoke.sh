#!/usr/bin/env bash
# smoke.sh [--no-launch] <Y> — copy the working profile, launch the build on the copy, run the smoke checklist.
# stdout: "smoke: <y|n> <epic> <item>" per item, then "smoke: result <yes>/<total>". Exit 0 all y · 1 n/abort/no build · 2 usage.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  echo "usage: smoke.sh [--no-launch] <Y>" >&2
  exit 2
}

launch=1
year=""
for arg in "$@"; do
  case "$arg" in
    --no-launch) launch=0 ;;
    -*) usage ;;
    *) [ -z "$year" ] || usage; year="$arg" ;;
  esac
done
[ -n "$year" ] || usage

smoke_dir="${BB_SMOKE_DIR:-$BB_ROOT/scripts/bb/smoke.d}"
tmp_dir="${BB_SMOKE_TMP:-/tmp}"
engine_dir="${BB_ENGINE_DIR:-$BB_ROOT/engine}"
profile="$tmp_dir/bb-smoke-$year"

if [ "$launch" = 1 ]; then
  bin="${BB_SMOKE_BIN:-}"
  if [ -z "$bin" ]; then
    for cand in "$engine_dir"/obj-*/dist/*.app/Contents/MacOS/zen; do
      [ -x "$cand" ] || continue
      bin="$cand"
      break
    done
  fi
  if [ -z "$bin" ]; then
    echo "smoke: no build found" >&2
    exit 1
  fi
  rm -rf "$profile"
  mkdir -p "$profile"
  if [ -n "${BB_SMOKE_PROFILE:-}" ]; then
    cp -R "$BB_SMOKE_PROFILE/." "$profile"
  else
    echo "smoke: BB_SMOKE_PROFILE not set, using an empty profile" >&2
  fi
  "$bin" -profile "$profile" -no-remote > "$profile.log" 2>&1 &
  echo "smoke: browser output in $profile.log" >&2
fi

yes_count=0
total=0
for file in "$smoke_dir"/*.txt; do
  [ -f "$file" ] || continue
  epic="$(basename "$file" .txt)"
  while IFS= read -r item <&3; do
    case "$item" in
      "" | "#"*) continue ;;
    esac
    while true; do
      printf '[%s] %s [y/n] ' "$epic" "$item" >&2
      IFS= read -r answer || { echo "smoke: aborted" >&2; exit 1; }
      case "$answer" in
        y | n) break ;;
      esac
    done
    total=$((total + 1))
    [ "$answer" = y ] && yes_count=$((yes_count + 1))
    echo "smoke: $answer $epic $item"
  done 3< "$file"
done

echo "smoke: result $yes_count/$total"
[ "$yes_count" = "$total" ]
