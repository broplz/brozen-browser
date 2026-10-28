---
id: 0002
title: scripts/bb/lib.sh — step wrapper with header, tee into $BB_LOG_DIR, duration, exit code
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: ready
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
reviewed_sha:
qa_sha:
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
6. `git diff --name-only feat/layer` lists only the two allowed files plus this task file.

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

## Handoff

## Result

## Review

## QA
