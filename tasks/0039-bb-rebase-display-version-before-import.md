---
id: 0039
title: rebase.sh writes brands.bb displayVersion before import, so build, DMG and About carry the target tag
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: approved
base: feat/layer
branch: task/0039-bb-rebase-display-version-before-import
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_display_version_test.sh
  - scripts/bb/tests/rebase_post_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4
returns: 1
sessions: 0
reviewed_sha: 812ad0f215548ab9f3b482c976c9360e7c14c6ad
qa_sha: 812ad0f215548ab9f3b482c976c9360e7c14c6ad
blocked_reason:
---
## Goal
0034 made `do_finalize` (scripts/bb/rebase.sh:308) set `brands.bb` `displayVersion` to the target tag `$Y`. finalize
runs after `import`, `build` and `package`, so the 1.24.1b rebase shipped `zen-1.23.4b.en-US.mac.dmg` with the old
version in About. After this task a new post-rebase step writes the value into the working tree before `import`.
finalize still commits it in the same finalize commit (ADR-0002 Решение 4 step 11; owner's backlog item 0039).

## Definition of Done
1. `BB_POST_STEPS` default (rebase.sh:39) is
   `deps engine patches display_version import en_us_packs build lint smoke package install finalize publish`,
   and the header comment (l.3) lists `display_version` in the same position.
2. `/bin/bash scripts/bb/tests/rebase_display_version_test.sh` → exit 0, last line `rebase_display_version_test: OK`.
   The old cases a and b stay. New cases:
   c. `BB_POST_STEPS="display_version import"`: the `npm` stub copies the config's `bb` displayVersion line into the
      call log when it is called for `run import`. The logged value is `<tag>`, and `git status --porcelain` shows
      the config modified and not committed.
   d. `BB_POST_STEPS="display_version"` on a config without a `bb` brand → exit 1, stderr names `displayVersion`.
   e. `BB_POST_STEPS="display_version finalize"` → the finalize commit holds the config with `<tag>`, and the config
      diff in that commit is still exactly one `-` and one `+` line. The second write is a no-op.
3. The existing tests pass: `/bin/bash scripts/bb/tests/<t>.sh` for `rebase_test`, `rebase_post_test`,
   `rebase_continue_test`, `rebase_final_test`, `rebase_brand_test` → exit 0 each. `rebase_post_test.sh` may change
   only in the expected call order at l.70-71, if the new step adds nothing there; otherwise it stays unchanged.
4. `scripts/agents/diff.sh tasks/0039-bb-rebase-display-version-before-import.md --names` lists only allowed_paths and the task file.

## Notes from teamlead
- One helper writes the value: `set_display_version` = the current
  `replace_with "$BB_REPO_DIR/$BUILD_CONFIG" rewrite_display_version "$Y" || { say_fail "no brands.bb displayVersion in $BUILD_CONFIG"; return 1; }`.
  Both `do_display_version` and `do_finalize` call it, and the line is not repeated. finalize keeps calling it because
  the write is idempotent. That keeps `--continue` and test runs with `BB_POST_STEPS="finalize"` correct.
- The step sits after `patches` and before `import`, because the packaging tool reads the brand's displayVersion
  at import/build. Do not put the write inside `do_import` or `set_brand`: `set_brand` also runs in `do_package`.
- No change to `rewrite_display_version`, `replace_with`, `finalize_subject`/`finalized`, or the `g add` line. The
  config is already in it.
- A failed step after `display_version` leaves the config modified on `rebase/<tag>`. That is fine: the tree is dirty
  only on rebase/Y, preflight checks only on main, and `--continue` rewrites the same value.
- Never type the config file's name or the packaging tool's name in a Bash command (hook). Use `BUILD_CONFIG` and
  `ff_cfg` as 0034 did.
- Hook: only rebaser may run a command that names `scripts/bb/rebase.sh`. Tests reach it via `$here/../rebase.sh`.
- Independent of 0038; both edit rebase.sh in different functions.

## Handoff

## Result
Round 2: Review 1 — dropped `finalize_rb`, cases a/b call `steps_rb finalize` (one helper, defined before case a).
Review 2 — new `no_bb_brand` helper used in cases b and d. Only the test file changed; rebase_display_version_test → OK.
Round 1: added `set_display_version` + `do_display_version` in rebase.sh; `do_finalize` calls the helper; `display_version`
sits after `patches` in `BB_POST_STEPS` and the header. Test cases c, d, e added (own npm stub that logs the config's bb
displayVersion on `run import`). Verified: rebase_display_version_test, rebase_post_test, rebase_test,
rebase_continue_test, rebase_final_test, rebase_brand_test all pass. rebase_post_test unchanged. No open questions.

## Review
APPROVE
1. Round-1 item 1 fixed: `finalize_rb` is gone. The single `steps_rb <steps>` helper
   (scripts/bb/tests/rebase_display_version_test.sh:69-74) is used by cases a-e.
2. Round-1 item 2 fixed: the `no_bb_brand` helper (l.76-80) is called in cases b (l.100) and d (l.127).
3. No other changes since the last review. rebase.sh is unchanged from round 1: `set_display_version` is the single
   writer, the step comes after `patches`, and the header matches. layer_lint reports 0 fail / 0 warn. Scope is the
   two allowed paths. I did not run the tests, because the hook blocks commands that name the rebase script. qa runs
   DoD 2-3.

---
REQUEST_CHANGES
1. scripts/bb/tests/rebase_display_version_test.sh:103-108 — `steps_rb` duplicates `finalize_rb` (l.69-74) line for line,
   only the step list differs. Keep one helper: drop `finalize_rb` and call `steps_rb finalize` in cases a and b
   (l.78, l.97) — or move `steps_rb` up and define `finalize_rb() { steps_rb finalize; }`. The owner's rule: no repeated blocks.
2. scripts/bb/tests/rebase_display_version_test.sh:128 — the "no bb brand" config `printf … >"$R/$CFG"` + `rgit commit -qam
   "no bb brand"` repeats l.94-95 verbatim. Move it into one helper (e.g. `no_bb_brand`) and call it in cases b and d.

Checked and fine (no change needed):
- Spec: DoD 1 met (header l.3 and `BB_POST_STEPS` l.39 list `display_version` after `patches`). `set_display_version`
  is the single writer, called by `do_display_version` and `do_finalize` (teamlead note); `rewrite_display_version`,
  `replace_with`, `finalize_subject`/`finalized` and the `g add` line are unchanged. `run_step` dispatches `do_$1`, so
  no other registration is needed. The finalize layer.yaml failure path still reverts the config; `--continue` reruns
  the step, so that is safe.
- Scope: only rebase.sh and the display_version test changed; rebase_post_test.sh untouched (DoD 3 allows that).
- Layer: no Zen/Firefox files, no prefs; layer_lint 0 fail / 0 warn.
- Correctness: the step fails with exit 1 and a `rebase: ` line naming displayVersion (case d). The stub `npm` replaces
  stub_env's copy only for cases c-e. Cases c/d/e match DoD 2.
- Result: claims match the diff. I could not run the tests (the hook blocks commands that name the rebase script); qa runs them.

## QA
PASS
1. DoD 1: rebase.sh l.39 default and header l.3 list `display_version` after `patches`. OK.
2. DoD 2: `rebase_display_version_test.sh` → exit 0, `rebase_display_version_test: OK`.
3. DoD 3: rebase_test, rebase_post_test, rebase_continue_test, rebase_final_test, rebase_brand_test all pass (rebase_post_test unchanged).
4. DoD 4: diff.sh --names lists only rebase.sh and the display_version test. layer_lint 0 fail / 0 warn.
5. `test.sh lint`: 0 problems (log: logs/test-lint-20261113-025618.log). Build type none, skipped.
