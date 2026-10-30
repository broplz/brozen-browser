#!/usr/bin/env bash
# triage_log.py ignores mach's terminal-notifier line but still reports real errors.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

NOTIFIER="Notification center failed: Install terminal-notifier to get a notification when the build finishes."

fail() { echo "FAIL: $1"; exit 1; }
triage() { python3 "$ROOT/scripts/agents/triage_log.py" "$1" --context 0; }

printf '%s\n%s\n%s\n' "$NOTIFIER" "ordinary text" "error: real failure here" > "$T/mixed.log"
OUT="$(triage "$T/mixed.log")"
echo "$OUT" | grep -q "real failure here" || fail "real error missing"
echo "$OUT" | grep -q "Notification center failed" && fail "notifier line reported"

printf '%s\n%s\n' "ordinary text" "$NOTIFIER" > "$T/noise.log"
OUT="$(triage "$T/noise.log")"
echo "$OUT" | grep -q "0 error lines, 0 distinct" || fail "want 0 error lines, got: $OUT"
echo "$OUT" | grep -q "no error lines matched" || fail "want 'no error lines matched'"

echo "triage_log_test: OK"
