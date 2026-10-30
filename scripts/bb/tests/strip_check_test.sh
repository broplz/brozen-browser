#!/usr/bin/env bash
# Tests for scripts/bb/strip-check.sh on fixtures only. Run: /bin/bash scripts/bb/tests/strip_check_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_sh="$here/../strip-check.sh"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $1"; failed=1; }
check() { # check <message> <command…>
  local msg="$1"
  shift
  "$@" || fail "$msg"
}

root="$T/root"
engine="$T/engine"
profile="$engine/browser/app/profile"
mkdir -p "$root/prefs/bb" "$root/prefs/firefox/sub" "$root/scripts/bb" "$engine/obj-test" "$profile"

printf -- '# strip\n- name: bb.strip.ai\n  value: true\n\n- name: browser.ml.chat.page\n  value: false\n' \
  > "$root/prefs/bb/strip.yaml"
printf -- '- name: browser.ml.chat.enabled\n  value: false\n' > "$root/prefs/firefox/sub/ai.yaml"

# fixture <name> <content> — (re)write one fixture file from printf %b content.
fixture() { printf '%b' "$2" > "$1"; }
clean() {
  fixture "$engine/obj-test/config.status" "substs = {\n    'MOZ_CRASHREPORTER': '',\n    'MOZ_EME_MODULES': ['widevine'],\n}\n"
  fixture "$profile/zen.js" '#if defined(XP_MACOSX)\npref("bb.strip.ai", true);\n#endif\n\npref("browser.ml.chat.page", false);\n'
  fixture "$profile/firefox.js" 'pref("browser.ml.chat.page", true);\n  pref("browser.ml.chat.enabled", true);\npref("other.pref", 1);\n#include zen.js\n'
  fixture "$root/scripts/bb/strip-allow.txt" '# reasons\n'
}

run() { # sets rc; stdout+stderr in $T/out
  rc=0
  BB_ROOT="$root" BB_ENGINE_DIR="$engine" /bin/bash "$check_sh" > "$T/out" 2>&1 || rc=$?
}
expect() { # expect <case> <rc> <text in output>
  check "$1: exit $2" test "$rc" = "$2"
  check "$1: output has '$3'" grep -qF -- "$3" "$T/out"
}

# (a) all clean; (f) browser.ml.chat.enabled is known only to the Zen yaml
clean
run
check "a: exit 0" test "$rc" = 0
expected_a() { printf 'strip-check: build OK\nstrip-check: prefs OK\nstrip-check: drift OK\n'; }
check "a: three OK lines" diff <(expected_a) "$T/out"

# (b) crash reporter built in
clean
fixture "$engine/obj-test/config.status" "substs = {\n    'MOZ_CRASHREPORTER': '1',\n}\n"
run
expect b 1 "strip-check: build FAIL MOZ_CRASHREPORTER='1'"
check "b: stops at build" test "$(grep -c "OK" "$T/out")" = 0

# (c) strip.yaml name missing in zen.js
clean
fixture "$profile/zen.js" 'pref("browser.ml.chat.page", false);\n'
run
expect c 1 "strip-check: prefs FAIL bb.strip.ai"

# (d) strip.yaml name with another value in zen.js
clean
fixture "$profile/zen.js" 'pref("bb.strip.ai", true);\npref("browser.ml.chat.page", true);\n'
run
expect d 1 "strip-check: prefs FAIL browser.ml.chat.page"

# (e) unknown browser.ml.* in firefox.js, then allow-listed
clean
fixture "$profile/firefox.js" 'pref("browser.ml.chat.provider", "https://x");\npref("browser.ml.chat.page", true);\n'
run
expect e 1 "strip-check: drift FAIL browser.ml.chat.provider"
fixture "$root/scripts/bb/strip-allow.txt" '# a URL, not a switch\nbrowser.ml.chat.provider\n'
run
check "e: allow-listed exit 0" test "$rc" = 0

# (g) no objdir
clean
rm -f "$engine/obj-test/config.status"
run
expect g 1 "strip-check: build FAIL no"

if [ "$failed" = 0 ]; then
  echo PASS
else
  echo FAILED
  exit 1
fi
