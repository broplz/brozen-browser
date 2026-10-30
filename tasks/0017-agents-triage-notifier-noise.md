---
id: 0017
title: triage_log.py no longer reports `Notification center failed: Install terminal-notifier` as an error
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: ready
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
reviewed_sha:
qa_sha:
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
