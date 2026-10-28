---
id: 0002
title: scripts/bb/lib.sh — step wrapper with header, tee into $BB_LOG_DIR, duration, exit code
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: approved
base: feat/layer
branch: task/0002-bb-lib-step
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/bb/lib.sh
  - scripts/bb/tests/lib_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4--runbook-ребейза
returns: 0
sessions: 0
reviewed_sha: 2da2e6482c7b227c95745eb42141a003c3fe612f
qa_sha: 2da2e6482c7b227c95745eb42141a003c3fe612f
blocked_reason: 
---
## Goal
Create `scripts/bb/lib.sh`, the shared shell library every BB product script sources
(rebase.sh, patches.sh, smoke.sh, report.sh, l10n.sh). It provides log-file setup and the
`step "<name>" <command…>` wrapper from ADR-0002 Решение 4 "Логирование": a timestamped header,
`2>&1 | tee -a` into the run's log, duration and exit code — so long steps never look hung (N3)
and report.sh can later read step timings from the log.

## Definition of Done
1. `bash -n scripts/bb/lib.sh` → exit 0, no output.
2. `/bin/bash scripts/bb/tests/lib_test.sh` → last line `PASS`, exit 0 (macOS bash 3.2).
3. The test covers, each as its own assertion with a message on failure:
   a. `step ok true` returns 0; the log contains the header line and a footer with `exit=0`;
   b. `step fail false` returns 1; footer has `exit=1`;
   c. `step echo echo hello` — `hello` is both on stdout and in the log;
   d. a caller running `set -euo pipefail` survives `step fail false || rc=$?`, footer printed, rc=1;
   e. with `BB_LOG_DIR` unset, after sourcing lib.sh `BB_LOG_DIR` equals `<repo root>/../logs`
      (string check only — the test must not create that directory);
   f. `bb_log_open rebase-x` creates `$BB_LOG_DIR/rebase-x-<YYYYmmdd-HHMMSS>.log` and sets `BB_LOG`;
   g. footer `duration=` value is an integer followed by `s`.
4. The test writes only under a `mktemp -d` directory (it sets `BB_LOG_DIR` there) and removes it.
5. `grep -c -E "^set -" scripts/bb/lib.sh` → `0` (a library never changes the caller's shell options).
6. `scripts/agents/diff.sh tasks/0002-bb-lib-step.md --names` lists only scripts/bb/lib.sh and scripts/bb/tests/lib_test.sh.

## Notes from teamlead
- Interface (later tasks depend on these exact names):
  - `BB_ROOT` — repo root, derived from lib.sh's own location (`scripts/bb/` → `../..`), not from `$PWD`.
  - `BB_LOG_DIR` — default `$BB_ROOT/../logs` (ADR: "по умолчанию `../logs/`, как сейчас" — the
    directory next to the repo, NOT the repo's git-ignored `logs/`, which belongs to the agent
    pipeline). An existing value from the environment wins.
  - `bb_log_open <basename>` — `mkdir -p "$BB_LOG_DIR"`, sets and exports
    `BB_LOG=$BB_LOG_DIR/<basename>-<date +%Y%m%d-%H%M%S>.log`, prints the path.
  - `step "<name>" <cmd> [args…]` — requires `BB_LOG` (if unset, print an error to stderr and return 2).
- Line formats, fixed (report.sh will parse them; both go to terminal and log):
  - header: `==> <date '+%Y-%m-%d %H:%M:%S'> step: <name>`
  - footer: `<== step: <name> exit=<code> duration=<seconds>s`
- Exit code of the command, not of `tee`: `PIPESTATUS[0]`. Run the pipeline so a caller's
  `set -e`/`pipefail` cannot abort before the footer is written; `step` returns the command's code.
- Must run on /bin/bash 3.2: no associative arrays, no `${var,,}`, no `mapfile`, no `$EPOCHREALTIME`;
  use `$SECONDS` or `date +%s` for duration.
- Shebang-less library (`# shellcheck shell=bash` header comment is fine); the test has
  `#!/usr/bin/env bash` and sources `scripts/bb/lib.sh` by path relative to itself.
- Out of scope: `caffeinate`, git `--progress`, colors, rebase logic — later tasks (0007).
- Nothing else in lib.sh yet; no helpers "for later".
- Unblock 2026-10-28: escalated, not split or re-spec'd. The code is approved and the only
  blockers are outside an agent's reach: the reviewer-committed `.claude/agent-memory/` files
  in the diff, and the denied Bash commands for DoD 1–2. See docs/reports/decisions-needed.md.
- Re-spec 2026-10-28: the owner resolved both blockers in f43e42814 (`bash -n` and `/bin/bash`
  scripts are allowed; DoD scope is checked with diff.sh, which ignores `.claude/agent-memory/`).
  The code is approved, so do not change lib.sh or lib_test.sh. Next session: run DoD 1, 2, 5 and 6
  exactly as written, record the outputs in ## Result, then set status `review`. The reviewer's two
  non-blocking items (`"$BASH" -c`, escaped prefix) are optional. They fit inside allowed_paths.
  QA item 1 used `git diff --name-only`, so it does not apply. DoD 6 (diff.sh) is the check.

## Handoff
Done: lib.sh and lib_test.sh are complete and unchanged (review APPROVE; QA items 4–6 pass).
Failed: QA item 1 — the branch diff contains `.claude/agent-memory/reviewer/MEMORY.md` and `feedback_shell_tests.md` (added by a reviewer session, commit 2234bf58b/744ce5873). Removing them needs `git rm` (denied in this sandbox) or editing `.claude/` (forbidden by CLAUDE.md).
Also: QA items 2–3 (`bash -n`, `/bin/bash …lib_test.sh`) need Bash permission for those commands; not runnable here.
Next: the owner/driver must drop those two `.claude/` files from the branch (`git rm` them and commit), and grant Bash permission for the DoD 1–2 commands. No code change is needed.

## Result
Round 2 (no code change): ran the DoD exactly as written.
- DoD 1 `bash -n scripts/bb/lib.sh` → exit 0, no output.
- DoD 2 `/bin/bash scripts/bb/tests/lib_test.sh` → `PASS`.
- DoD 5 `grep -c -E "^set -" scripts/bb/lib.sh` → `0`.
- DoD 6 `scripts/agents/diff.sh tasks/0002-bb-lib-step.md --names` → only scripts/bb/lib.sh and scripts/bb/tests/lib_test.sh.
The reviewer's two optional items were not applied.

Round 1: added `scripts/bb/lib.sh` (BB_ROOT, BB_LOG_DIR, `bb_log_open`, `step`) and `scripts/bb/tests/lib_test.sh` (assertions a–g, plus step-without-BB_LOG → 2).
Verified: `bash scripts/bb/tests/lib_test.sh` → `PASS`; `grep -c -E "^set -" scripts/bb/lib.sh` → 0.
Not run: `bash -n scripts/bb/lib.sh` was denied by the sandbox (the lib is sourced successfully by the test, so it parses), and I did not run it under `/bin/bash` by that path (the call was denied; the test ran via `bash`, which may not be 3.2). Not checked: `git diff --name-only`.
Open: `step` uses `&& rc=… || rc=…` so a caller's `set -e` cannot abort before the footer.

## Review
APPROVE

Round 2 (re-review; the code is unchanged since round 1, head 2da2e6482):
1. Spec: the code is unchanged, so the round-1 spec check still applies. It meets the DoD and ADR-0002 Решение 4 "Логирование".
2. Scope: `scripts/agents/diff.sh … --names` lists only scripts/bb/lib.sh and scripts/bb/tests/lib_test.sh (DoD 6, re-run by the reviewer). The `.claude/agent-memory/` files no longer show up in the diff.
3. Layer rules: n/a (no Zen/Firefox files, prefs or engine/). layer_lint: 5 files, 29 production lines, 0 fail, 0 warn.
4. Correctness: no change since round 1.
5. Verification: the reviewer re-ran every claim in Result round 2 and got the same outputs. `bash -n scripts/bb/lib.sh` gave exit 0 and no output. `/bin/bash scripts/bb/tests/lib_test.sh` printed `PASS`. `grep -c -E "^set -"` printed `0`. diff.sh `--names` listed the two files.
6. Hygiene: OK. The two optional round-1 items are still open and still non-blocking.

---
Round 1:

Checklist:
- Spec: matches ADR-0002 Решение 4 "Логирование" (header with time, `2>&1 | tee -a`, duration, exit code) and the teamlead interface (BB_ROOT from the lib's own location, BB_LOG_DIR default `$BB_ROOT/../logs` with the env value taking priority, bb_log_open, step returns 2 without BB_LOG, fixed header/footer formats). Nothing extra: no caffeinate/colors/helpers.
- Scope: `git diff --name-only feat/layer` → lib.sh, tests/lib_test.sh, task file only (DoD 6, re-run by reviewer). layer_lint: 0 fail, 0 warn.
- Layer rules: no Zen/Firefox files, no prefs, nothing in engine/ — n/a.
- Correctness: `"$@" 2>&1 | tee -a … && rc=${PIPESTATUS[0]} || rc=${PIPESTATUS[0]}` gives the command's code with and without pipefail, and set -e cannot fire inside an &&/|| list. No `set -` in the library (DoD 5). Only bash 3.2 constructs ($SECONDS, PIPESTATUS, local).
- Verification: the reviewer could not run `bash -n` or the test (sandbox denied). `which -a bash` → only `/bin/bash`, so the developer's `bash` run was bash 3.2. QA must run DoD 1 and DoD 2.
- Hygiene: no secrets, no TODOs, English.

Non-blocking (fix only if the file is touched again):
1. scripts/bb/tests/lib_test.sh:46 — (d) uses `bash -c` from PATH. On a machine with Homebrew bash this tests bash 5, not the 3.2 the DoD targets. Use `"$BASH" -c`. Line 25 has the same issue.
2. scripts/bb/tests/lib_test.sh:25 — `$BB_LOG_DIR` is put into the regex unescaped (the `.` in mktemp paths matches any character). Comparing a prefix (`[ "${BB_LOG#$BB_LOG_DIR/}" != "$BB_LOG" ]`) plus a pattern only on the basename would be exact.

## QA
PASS

1. DoD 1: `bash -n scripts/bb/lib.sh` → exit 0, no output.
2. DoD 2: `/bin/bash scripts/bb/tests/lib_test.sh` → `PASS`.
3. DoD 3 and 4: read lib_test.sh. Assertions a–g are each separate with a failure message. The test writes only under `mktemp -d` and removes it via trap. The default-BB_LOG_DIR check (e) runs in a subshell and only compares strings.
4. DoD 5: `grep -c -E "^set -" scripts/bb/lib.sh` → `0`.
5. DoD 6: `scripts/agents/diff.sh tasks/0002-bb-lib-step.md --names` → only scripts/bb/lib.sh and scripts/bb/tests/lib_test.sh.
6. `scripts/agents/test.sh lint`: `npm run lint` skipped (no engine/); layer_lint 5 files, 29 production lines, 0 fail, 0 warn.
7. Build `none` and `tests:` empty, so no build or mochitests were run.
