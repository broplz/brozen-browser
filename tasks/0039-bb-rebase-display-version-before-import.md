---
id: 0039
title: rebase.sh writes brands.bb displayVersion before import, so build, DMG and About carry the target tag
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: ready
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
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
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

## Review

## QA
