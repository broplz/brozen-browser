#!/usr/bin/env bash
# strip-check.sh — ADR-0003 2.9: check the strip list against a built engine/, in three parts.
# stdout: "strip-check: <part> OK" per part; on the first failing part "strip-check: <part> FAIL <what>" lines.
# Exit 0 all parts OK · 1 a part failed. Env: BB_ENGINE_DIR (engine/), BB_ROOT (repo with prefs/ and scripts/bb/).
set -euo pipefail

root_override="${BB_ROOT:-}"
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
BB_ROOT="${root_override:-$BB_ROOT}"

engine_dir="${BB_ENGINE_DIR:-$BB_ROOT/engine}"
strip_yaml="$BB_ROOT/prefs/bb/strip.yaml"
allow_list="$BB_ROOT/scripts/bb/strip-allow.txt"
zen_pref_dirs=(zen firefox fastfox privatefox)
# MOZ_DATA_REPORTING, MOZ_SERVICES_HEALTHREPORT: derived from implied project_flags; sending is gated by Zen-locked prefs
build_keys=(MOZ_CRASHREPORTER MOZ_TELEMETRY_REPORTING)
drift_prefixes=(browser.ml. browser.tabs.groups.smart. identity.fxaccounts. media.gmp-widevinecdm. browser.eme.)

# fail <part> <what…> — print one FAIL line per <what> and exit 1.
fail() {
  local part="$1" what
  shift
  for what in "$@"; do
    echo "strip-check: $part FAIL $what"
  done
  exit 1
}

# yaml_prefs <file…> — "name value" per `- name:` / `value:` pair.
yaml_prefs() {
  awk '/^- name:/ { name = $3 } /^  value:/ && name != "" { print name, $2; name = "" }' "$@"
}

# js_prefs <file> — "name value" per pref("name", value…) line; # lines skipped.
js_prefs() {
  sed -nE 's/^[[:space:]]*pref\("([^"]+)",[[:space:]]*([^,)]*[^,) ]).*/\1 \2/p' "$1"
}

check_build() {
  local status="" cand key value
  for cand in "$engine_dir"/obj-*/config.status; do
    [ -f "$cand" ] || continue
    status="$cand"
    break
  done
  [ -n "$status" ] || fail build "no $engine_dir/obj-*/config.status"
  for key in "${build_keys[@]}"; do
    value="$(grep -m 1 -oE "'$key': '[^']*'" "$status" | cut -d "'" -f 4 || true)"
    [ -z "$value" ] || fail build "$key='$value'"
  done
  echo "strip-check: build OK"
}

check_prefs() {
  local zen_js="$engine_dir/browser/app/profile/zen.js" built name value bad=()
  [ -f "$zen_js" ] || fail prefs "no $zen_js"
  built="$(js_prefs "$zen_js")"
  while read -r name value; do
    grep -qxF -- "$name $value" <<< "$built" && continue
    bad+=("$name (want $value)")
  done < <(yaml_prefs "$strip_yaml")
  [ "${#bad[@]}" = 0 ] || fail prefs "${bad[@]}"
  echo "strip-check: prefs OK"
}

check_drift() {
  local ff_js="$engine_dir/browser/app/profile/firefox.js" known name prefix bad=()
  [ -f "$ff_js" ] || fail drift "no $ff_js"
  known="$(
    yaml_prefs "$strip_yaml" | cut -d " " -f 1
    for dir in "${zen_pref_dirs[@]}"; do
      [ -d "$BB_ROOT/prefs/$dir" ] || continue
      find "$BB_ROOT/prefs/$dir" -name "*.yaml" -exec grep -h "^- name:" {} + | awk '{ print $3 }'
    done
    [ -f "$allow_list" ] && grep -vE "^[[:space:]]*(#|$)" "$allow_list"
    true
  )"
  while read -r name; do
    for prefix in "${drift_prefixes[@]}"; do
      [[ "$name" == "$prefix"* ]] || continue
      grep -qxF -- "$name" <<< "$known" || bad+=("$name")
      break
    done
  done < <(js_prefs "$ff_js" | cut -d " " -f 1 | sort -u)
  [ "${#bad[@]}" = 0 ] || fail drift "${bad[@]}"
  echo "strip-check: drift OK"
}

check_build
check_prefs
check_drift
