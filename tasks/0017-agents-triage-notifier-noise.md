---
id: 0017
title: triage_log.py no longer reports `Notification center failed: Install terminal-notifier` as an error
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: done
base: feat/layer
branch: task/0017-agents-triage-notifier-noise
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/agents/triage_log.py
  - scripts/agents/tests/triage_log_test.sh
spec: tasks/backlog.md
returns: 0
sessions: 0
reviewed_sha: 0eaf17c874e8526af504c3cd2e8b41737828ce31
qa_sha: 0eaf17c874e8526af504c3cd2e8b41737828ce31
blocked_reason: 
---
## Goal
Night log 2026-10-29: every build log triage shows a false error for mach's line
`Notification center failed: Install terminal-notifier to get a notification when the build finishes.`
(`ERROR_RE` matches `\bFAILED\b` case-insensitively). After this task triage_log.py ignores that
line and still reports real errors. Backlog 0017, first half only (the `.claude/settings.json` half
is owner work — see docs/reports/decisions-needed.md).

## Definition of Done
1. `/bin/bash scripts/agents/tests/triage_log_test.sh` → exit 0, last line `triage_log_test: OK`.
2. The test builds a temp log (mktemp) containing the exact notifier line above plus
   `error: real failure here` and asserts on `python3 scripts/agents/triage_log.py <log>` output:
   the notifier line is absent, `real failure here` is present.
3. A second temp log with only the notifier line (plus ordinary text) → output reports 0 errors
   (whatever the script's zero-error wording is — assert on it exactly).
4. `scripts/agents/diff.sh 0017 --names` lists only `scripts/agents/triage_log.py`,
   `scripts/agents/tests/triage_log_test.sh` and `tasks/0017-agents-triage-notifier-noise.md`.
5. `git diff feat/layer -- scripts/agents/triage_log.py` changes only `IGNORE_RE` (one added
   alternative), no other line.

## Notes from teamlead
- The fix is one alternative in the existing `IGNORE_RE` (scripts/agents/triage_log.py:18), e.g.
  `Notification center failed`. Do not touch `ERROR_RE` and do not add a second ignore list.
- Test style: like scripts/agents/tests/build_preflight_test.sh (bash, mktemp -d, trap cleanup,
  `check` helper, prints `triage_log_test: OK` and exits 0 only when all asserts pass).
- `.claude/settings.json` (allow `Bash(grep *)`, `bash -n`) is protected; do not attempt it.

## Result
Round 1: added `Notification center failed` as one alternative to `IGNORE_RE` in
scripts/agents/triage_log.py (ERROR_RE untouched). Added scripts/agents/tests/triage_log_test.sh
(mixed log: real error kept, notifier line absent; noise-only log: `0 error lines, 0 distinct` and
`no error lines matched`). Verified: `/bin/bash scripts/agents/tests/triage_log_test.sh` → `triage_log_test: OK`.
Did not run diff.sh. No open questions.

## Review
APPROVE
Checklist:
1. Spec: DoD 1–5 hold. Reviewer ran `/bin/bash scripts/agents/tests/triage_log_test.sh` → `triage_log_test: OK`.
   triage_log.py diff is one line, one added alternative in `IGNORE_RE` (triage_log.py:19); `ERROR_RE` untouched.
   The asserted zero-error strings (`0 error lines, 0 distinct`, `no error lines matched`) exist at triage_log.py:57,72.
   Without the fix, the mixed log would report the notifier line (it matches `\bFAILED\b`), so the test really guards the change.
2. Scope: diff --stat shows only the two allowed_paths, plus the task file. No existing tests touched.
3. Layer: no Zen/Firefox files. layer_lint: 0 fail, 0 warn.
4. Correctness: `set -uo pipefail`, `mktemp -d`, and trap cleanup all match build_preflight_test.sh. Exit code is 0 only when all asserts pass.
5. Result: the claimed test run is real. The developer admits not running diff.sh; the reviewer checked DoD 4 from diff --stat.
6. Hygiene: clean, English, no TODOs.
Non-blocking nits (no change required):
1. scripts/agents/tests/triage_log_test.sh:10: the helper is named `fail` rather than the `check` the teamlead suggested. Behaviour is equivalent.

## QA
PASS
1. Build type none: skipped. `scripts/agents/test.sh lint` → OK (0 problems); layer_lint 3 files, 1 production line, 0 fail, 0 warn.
2. DoD 1: `/bin/bash scripts/agents/tests/triage_log_test.sh` → `triage_log_test: OK`, exit 0.
3. DoD 2–3: test content covers mixed log (notifier line absent, `real failure here` present) and noise-only log (`0 error lines, 0 distinct`). The test passes.
4. DoD 4: `diff.sh 0017 --names` needs the task path (it crashed on the bare id). `git diff --stat feat/layer` shows only triage_log.py and triage_log_test.sh, plus the task file.
5. DoD 5: `git diff feat/layer -- scripts/agents/triage_log.py` changes only the `IGNORE_RE` line (one alternative added, `Notification center failed`); `ERROR_RE` is untouched.
