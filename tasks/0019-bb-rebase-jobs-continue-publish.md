---
id: 0019
title: rebase.sh — build jobs from BB_JOBS; `--continue` after a failed publish re-runs publish only
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: approved
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
reviewed_sha: 8cd376cddc9584aec6e385fdcb08cb0555bc41b7
qa_sha: 8cd376cddc9584aec6e385fdcb08cb0555bc41b7
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

## Result
Round 1:
- rebase.sh: `BB_JOBS` (default 6) used by `do_build`; `finalize_subject` helper shared by
  `do_finalize` and the new `finalized` check; `--continue` runs `publish` only when HEAD of
  `rebase/<tag>` is the finalize commit (logs `continue: finalize commit found, publish only`),
  otherwise `post_rebase` as before. Header lists `BB_JOBS` and the new `--continue` behaviour.
- New scripts/bb/tests/rebase_continue_test.sh (cases a, b, c) → `rebase_continue_test: OK`.
- `rebase_test.sh` → PASS.
- Open: `rebase_final_test.sh` and `rebase_post_test.sh` FAIL in this session only because the
  session environment exports `BB_JOBS=10`, and those tests (which I may not edit) expect
  `--jobs 6`. I could not rerun them with `env -u BB_JOBS` (Bash denied it), so DoD 2 is
  unverified for those two; run them with `BB_JOBS` unset. Failing checks are exactly the
  `--jobs 6` ones (post a/f, final e). Suggest the tests `unset BB_JOBS` in a follow-up task.

## QA
PASS
1. lint: OK (0 problems); layer_lint 0 fail, 0 warn (log logs/test-lint-20261030-171504.log).
2. DoD 1: `rebase_continue_test.sh` → exit 0, `rebase_continue_test: OK`.
3. DoD 2: `rebase_test.sh` → PASS. `rebase_final_test.sh` and `rebase_post_test.sh` fail only on
   the checks the developer named (final e; post a, f), because the agent env exports
   `BB_JOBS=10` (.claude/settings.json) and those tests expect `--jobs 6`. QA could not unset it
   (`env -u` denied). Failing set is exactly the `--jobs 6` family; it is an environment
   conflict, not this diff (as the reviewer noted). Run them with BB_JOBS unset.
4. DoD 3: header lines 7 and 10 of rebase.sh list `BB_JOBS` and the `--continue` publish resume.
5. DoD 4: diff names are rebase.sh and rebase_continue_test.sh only (`diff.sh 0019 --names`
   needs a task path, it errors on bare `0019`; the plain run shows the two files).

For the human: (a) run rebase_final_test.sh and rebase_post_test.sh with BB_JOBS unset;
(b) follow-up task: make the existing rebase tests `unset BB_JOBS`.

## Review
APPROVE
Checklist: (1) Spec — matches DoD 1-4 and the teamlead notes: `BB_JOBS` default sits with the other
defaults (rebase.sh:25) and is used by do_build (rebase.sh:231); one `finalize_subject` helper
(rebase.sh:277) is used by both do_finalize (rebase.sh:292) and `finalized` (rebase.sh:280); the
`--continue` branch logs the required line and runs `run_step publish post`, otherwise calls
`post_rebase` (rebase.sh:363-369). Header updated (rebase.sh:7,10). (2) Scope — only the 2 allowed
files; existing tests untouched. (3) Layer — no Zen/Firefox files; layer_lint: 0 fail, 0 warn.
(4) Correctness — after a failed publish, publish_rollback leaves HEAD on rebase/<tag>, so the
existing branch check passes and `finalized` sees the finalize commit; publish needs no node, so
skipping use_node is fine. (5) Result — the BB_JOBS claim is real: .claude/settings.json:126 exports
`BB_JOBS=10` to every agent session. (6) Hygiene — clean.

Notes (not blocking):
1. For qa: DoD 2 must run `rebase_final_test.sh` and `rebase_post_test.sh` with `BB_JOBS` unset.
   The agent env exports `BB_JOBS=10` (.claude/settings.json:126), and those tests expect `--jobs 6`.
   The failure comes from the environment, not from this diff. If qa cannot unset the var, it is a
   DoD/environment conflict for the teamlead, not a reason to FAIL this code.
2. For teamlead: add a follow-up so the existing rebase tests `unset BB_JOBS`, like
   rebase_continue_test.sh does at line 79.
3. rebase.sh:365 `cd "$BB_REPO_DIR"` repeats post_rebase:319. A shared helper is possible but not
   worth another round.
