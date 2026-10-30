---
id: 0019
title: rebase.sh — build jobs from BB_JOBS; `--continue` after a failed publish re-runs publish only
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: ready
base: feat/layer
branch: task/0019-bb-rebase-jobs-continue-publish
depends_on: [0011]
build: none
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_continue_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Two gaps in scripts/bb/rebase.sh (backlog 0019, ADR-0002 Решение 4 steps 9 and 11):
(1) `do_build` hardcodes `--jobs 6` (rebase.sh:229); after this task the job count comes from
`BB_JOBS` (default 6). (2) `--continue <tag>` always re-runs `post_rebase` (steps 5-11); after a
failed `publish` the finalize commit is already on `rebase/<tag>`, so a resume would build again and
`do_finalize` would make a second commit. After this task `--continue` detects that state and runs
the `publish` step only.

## Definition of Done
1. `/bin/bash scripts/bb/tests/rebase_continue_test.sh` → exit 0, last line `rebase_continue_test: OK`.
   Cases (fixture from scripts/bb/tests/rebase_fixture.sh, stubs from `stub_env`, like
   rebase_final_test.sh):
   a. `BB_JOBS=3`, build step → the stub call log has `npm run build -- --jobs 3`;
      unset `BB_JOBS` → `--jobs 6`.
   b. publish fails (origin rejects: point `BB_PUSH_REMOTE` at a missing remote), then
      `--continue <tag>` with a working remote → only step `publish` runs (no `npm` calls in the stub
      log for the second run), exactly one commit with subject `rebase: Zen <tag> (Firefox …)` on
      main, tag `bb/base/<tag>` on origin, branch `rebase/<tag>` deleted.
   c. `--continue <tag>` on `rebase/<tag>` without a finalize commit (the step-4 conflict case)
      → behaves as before: steps from `BB_POST_STEPS` run (assert `deps` runs).
2. Existing tests still pass: `/bin/bash scripts/bb/tests/rebase_final_test.sh`,
   `/bin/bash scripts/bb/tests/rebase_post_test.sh`, `/bin/bash scripts/bb/tests/rebase_test.sh` → exit 0.
3. Header comment of rebase.sh lists `BB_JOBS` in "Env overrides" and the usage line for
   `--continue` says it resumes at publish when the finalize commit exists.
4. `scripts/agents/diff.sh 0019 --names` lists only the two allowed files and the task file.

## Notes from teamlead
- `BB_JOBS="${BB_JOBS:-6}"` next to the other defaults (rebase.sh:19-35); `do_build` uses `--jobs "$BB_JOBS"`.
- Finalize-commit detection: HEAD of `rebase/<tag>` has subject starting `rebase: Zen $Y (` (exact
  format from `do_finalize`, rebase.sh:284) — put that format in one variable/helper used by both
  `do_finalize` and the detection; do not duplicate the string.
- On detection: log `continue: finalize commit found, publish only` into $BB_LOG and call
  `run_step publish post`; otherwise call `post_rebase` as now. No other behaviour change.
- After a failed publish `publish_rollback` already returned to `rebase/<tag>`, restored main and
  deleted the local `bb/base/<tag>` tag, so the existing `--continue` branch check passes. If the
  tag still exists locally (rollback failed), let `do_publish` fail as it does now — no auto-repair.
- Hook: no agent role but rebaser may run a command naming `scripts/bb/rebase.sh` (so no
  `bash -n scripts/bb/rebase.sh`). Tests reach it via `$here/../rebase.sh` — that is allowed. Do not
  edit the existing test files; add the new one.
