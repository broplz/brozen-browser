---
id: 0033
title: rebase.sh selects the brand before import/package, runs the en-US packs step, watches .python-version
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: done
base: feat/layer
branch: task/0033-bb-rebase-brand-en-us-packs
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_brand_test.sh
  - scripts/bb/tests/rebase_fixture.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4
returns: 0
sessions: 0
reviewed_sha: c57f7887ee07521b1c2ac00fc60f0bec2a602dc6
qa_sha: c57f7887ee07521b1c2ac00fc60f0bec2a602dc6
blocked_reason: 
---
## Goal
Before the owner's rebase to 1.24.1b (decisions-needed, "Owner answers (2026-11-12)"), scripts/bb/rebase.sh
(ADR-0002 Решение 4, steps 3 and 8-10) must do what `scripts/agents/build.sh` already does (tasks 0016, 0023):
(1) select the brand `${BB_BRAND:-bb}` before `import` and before `package`; (2) run the en-US packs step
`python3 scripts/update_en_US_packs.py` right after `import` (without it the UI has empty strings and no
shortcuts); (3) report `.python-version` as a toolchain change in recon. Also the shared test fixture stops
inheriting `BB_JOBS`/`BB_BRAND` from the agent environment, so the existing rebase tests pass in agent sessions
(follow-up from 0019's review and QA).

## Definition of Done
1. `/bin/bash scripts/bb/tests/rebase_brand_test.sh` → exit 0, last line `rebase_brand_test: OK`. The test sources
   `rebase_fixture.sh`, calls `stub_env`, adds a `python3` stub to `$T/stubs/bin` that appends `python3 $*` to
   `$CALLS` and exits 1 when `STUB_FAIL_PY` is set, and runs rebase.sh via `--continue` on `rebase/<tag>` like
   `rebase_continue_test.sh` does. Cases:
   a. `BB_BRAND` unset, `BB_POST_STEPS="import en_us_packs build package"` → `$CALLS` has, in this order:
      `npm run surfer -- set brand bb`, `npm run import`, `python3 scripts/update_en_US_packs.py`,
      `npm run build -- --jobs 6`, `npm run surfer -- set brand bb`, `npm run package`; exit 0.
   b. `BB_BRAND=release`, same steps → both brand lines are `npm run surfer -- set brand release`.
   c. `STUB_FAIL_PY=1`, same steps → exit 1, stderr contains `stop: en_us_packs`, `$CALLS` has no `npm run build`.
   d. `grep -q 'TOOLCHAIN_FILES=.*\.python-version' "$here/../rebase.sh"` succeeds.
2. Existing tests pass in an agent session (no manual `unset`): `/bin/bash scripts/bb/tests/rebase_test.sh`,
   `rebase_post_test.sh`, `rebase_final_test.sh`, `rebase_continue_test.sh` (all under `scripts/bb/tests/`) → exit 0.
3. Header comment of rebase.sh: step list line names `en_us_packs`; "Env overrides" lists `BB_BRAND (default bb)`.
4. `scripts/agents/diff.sh tasks/0033-bb-rebase-brand-en-us-packs.md --names` lists only allowed_paths and the task file.

## Notes from teamlead
- Brand: one helper `set_brand() { npm_or_fail "set brand" npm run surfer -- set brand "$BB_BRAND"; }` with
  `BB_BRAND="${BB_BRAND:-bb}"` next to `BB_JOBS` (rebase.sh:25). `do_import` and `do_package` call it first
  (`set_brand || return 1`), then their npm command. Same command form as build.sh (task 0023 Notes); do not
  check that the brand exists in the build config: the command fails on its own and the step reports it.
- en-US packs: a new step `en_us_packs` → `do_en_us_packs() { npm_or_fail "en-US packs" python3 scripts/update_en_US_packs.py; }`
  (cwd is the repo: post_rebase cds there). Insert it into the default `BB_POST_STEPS` right after `import`:
  `deps engine patches import en_us_packs build lint smoke package install finalize publish`. Step names
  map to `do_<name>`, hence underscores (no hyphen).
- `TOOLCHAIN_FILES` (rebase.sh:40): append `.python-version` (the file exists at the repo root).
- rebase_fixture.sh: one line at the top of `stub_env`: `unset BB_JOBS BB_BRAND` (the agent env exports
  `BB_JOBS=10`, .claude/settings.json; existing tests expect `--jobs 6`). Do not change anything else there;
  do not edit the other test files. `rebase_continue_test.sh` sets `BB_JOBS=3` after `stub_env`, so it keeps working.
- Hooks: never type the word `surfer` in a Bash command (it lives only inside rebase.sh and the test file).
  No agent role but rebaser may run a command naming `scripts/bb/rebase.sh` — tests reach it via
  `$here/../rebase.sh`, which is allowed. macOS bash 3.2: no arrays, no `${x,,}`.
- Out of scope: `do_finalize`/the build config `displayVersion` (task 0034), the driver's own en-US step (0036).

## Handoff

## Result
Round 1:
- rebase.sh: `BB_BRAND` (default bb) + `set_brand` called first in `do_import` and `do_package`; new step
  `do_en_us_packs` after `import` in the default `BB_POST_STEPS`; `.python-version` in `TOOLCHAIN_FILES`; header updated.
- rebase_fixture.sh: `stub_env` unsets `BB_JOBS BB_BRAND`. Also added a logging `python3` stub in `stub_env`
  (beyond the one-line brief): without it rebase_final_test and rebase_continue_test run the new default
  `en_us_packs` step with the real python3 and fail (no script in the fixture repo).
- New rebase_brand_test.sh (cases a-d).
- Verified: rebase_brand_test, rebase_test, rebase_post_test, rebase_final_test, rebase_continue_test all pass.

## Review
APPROVE
Checklist: (1) spec — set_brand before import/package with `${BB_BRAND:-bb}`, `en_us_packs` step after import
in the default BB_POST_STEPS, `.python-version` in TOOLCHAIN_FILES, header names `en_us_packs` and `BB_BRAND (default bb)`;
DoD 1a-d are covered by rebase_brand_test.sh. (2) scope — only allowed_paths; the existing test files are untouched.
(3) layer — no Zen/Firefox files touched; layer_lint shows 0 fail, 0 warn. (4) correctness — no other python3 use in rebase.sh,
so the fixture stub doesn't hide anything; npm_or_fail reports failures, `|| return 1` stops before import/package;
the step runs from the repo cwd. bash 3.2: no arrays (process substitution is fine). (5) I could not run the tests:
the reviewer sandbox blocks commands that name rebase.sh, so QA must confirm DoD 1-2.
(6) hygiene is OK.
Notes (non-blocking):
1. scripts/bb/tests/rebase_fixture.sh:37 — this goes beyond the one-line brief. The change was declared openly and
   is justified: without it, the new default step runs the real python3 in the final/continue tests.
2. scripts/bb/tests/rebase_brand_test.sh:16-21 overwrites the fixture's python3 stub with a near-copy, as DoD 1 asks.
   If the fixture stub honoured `STUB_FAIL_PY` (like `STUB_FAIL_NVM`), the copy could go. Leave this for a future cleanup.

## QA
PASS
1. build none; `test.sh lint` OK (0 problems), layer_lint 0 fail / 0 warn.
2. DoD 1: rebase_brand_test.sh → `rebase_brand_test: OK` (cases a-d; 1d TOOLCHAIN_FILES line 42 has .python-version).
3. DoD 2: rebase_test, rebase_post_test, rebase_final_test, rebase_continue_test all pass in the agent session.
4. DoD 3: header line 3 names `en_us_packs`; line 11 `BB_BRAND (default bb)`.
5. DoD 4: diff.sh --names lists only rebase.sh, rebase_brand_test.sh, rebase_fixture.sh (task file is the branch's own).
