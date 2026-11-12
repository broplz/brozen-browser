---
id: 0038
title: rebase.sh step `package` ends with exit 0 on a --disable-updater build (DMG without the MAR)
epic: layer
prefix: layer
kind: script
role: developer-hard
size: M
status: ready
base: feat/layer
branch: task/0038-bb-rebase-package-without-mar
depends_on: []
build: none
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_package_test.sh
  - scripts/bb/tests/rebase_fixture.sh
  - docs/notes/package-without-mar.md
  - docs/notes/README.md
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0002 Решение 4 step 11: `package` → DMG → install into /Applications. Since 0022 the BB build has
`--disable-updater` (configs/bb/mozconfig:12), so `<objdir>/dist/host/bin/mar` is never built. The packaging command
copies the DMG into `dist/` and only then builds a MAR unconditionally (its `dist/commands/package.js:107`,
`createMarFile`, l.123-155), which fails, so `do_package` (scripts/bb/rebase.sh:241) exits 1 and the rebase stops
before `install`. After this task the `package` step ends with exit 0 and a fresh DMG in `$BB_DIST_DIR`, with the
updater still disabled; the owner checks it on a real build.

## Definition of Done
1. `docs/notes/package-without-mar.md` exists with the headings `## Options`, `## Chosen`, `## Evidence`. `## Options`
   covers at least the three options from the backlog item: (a) an env var or flag of the packaging command, (b) building
   only the `mar` host tool, (c) BB's own packaging step. For each option it gives a verdict `works` | `does not work` |
   `untested` and the file:line it rests on. `docs/notes/README.md` gains one line linking the note.
2. `/bin/bash scripts/bb/tests/rebase_package_test.sh` → exit 0, last line `rebase_package_test: OK`. It uses the
   fixture/stub style of `rebase_post_test.sh` (stubbed `npm`, call log). `BB_POST_STEPS="package"` runs through
   `--continue` on `rebase/<tag>`. Cases:
   a. the packaging stub puts a DMG into `$BB_DIST_DIR` and then fails the way the real MAR step fails → the step
      ends with exit 0 and the log line `package: ok`. If the chosen mechanism never runs the MAR step, the stub fails
      whenever the MAR step is invoked, and the case asserts that it was not invoked.
   b. the packaging stub fails before any DMG appears → exit 1, stderr has a `rebase: ` line naming `package`.
   c. a DMG older than the step's start is in `$BB_DIST_DIR`, and packaging fails → exit 1. A stale DMG never counts.
3. The existing tests still pass: `/bin/bash scripts/bb/tests/<t>.sh` for `rebase_test`, `rebase_post_test`,
   `rebase_continue_test`, `rebase_final_test`, `rebase_brand_test`, `rebase_display_version_test` → exit 0 each.
4. `scripts/agents/diff.sh tasks/0038-bb-rebase-package-without-mar.md --names` lists only allowed_paths and the task file.
5. [human] The owner runs the rebase on a real objdir with `BB_POST_STEPS="package install"` (rebaser/owner). Both
   steps end with exit 0, `dist/` holds a new DMG, and the installed app starts.

## Notes from teamlead
- Hard limits:
  - Keep `--disable-updater`; configs/bb/mozconfig is not in allowed_paths (0022, the owner's decision).
  - Never edit `node_modules/` and never patch the packaging tool.
  - `do_package` must still call `set_brand` first (0033).
- Do not accept "exit != 0 but some DMG exists" blindly. Success needs a DMG with mtime newer than the step's start
  (DoD 2c). If the chosen option tolerates a failing MAR step, it also needs a positive sign that the failure is the
  MAR one: the `Creating mar file` line in the step output after the copy. Name the exact markers in the note.
- Leads, read before choosing:
  - `createMarFile` honours env `MAR` (path of the mar binary) and `JUST_MAR`, and runs
    `engine/tools/update-packaging/make_full_update.sh`.
  - Check in `engine/modules/libmar/` moz.build files (Grep + head_limit) under which CONFIG the host `mar` tool is
    built. Only a mozconfig-free way is in scope. If the only way is a mozconfig change, write that in `## Chosen` as
    "needs owner" and stop with a Handoff.
  - `mach package` is a fallback only. ADR F4 keeps `npm run package` working, and agents may not run mach. Run it
    from rebase.sh only if (a) and (b) both do not work.
- Reading the tool: any Bash command that contains the tool's name is hook-blocked. Use Read with offset/limit ≤ 400 on
  `node_modules/@zen-browser/*/dist/commands/package.js`; `createMarFile` is at l.123. In rebase.sh the tool's config
  name is held in `BUILD_CONFIG`; keep the name out of the test as well.
- One helper for "newest DMG in `$BB_DIST_DIR`" if both `do_install` (rebase.sh:246) and `do_package` need it. Do not
  copy the `ls -t | head` line.
- Hook: only rebaser may run a command that names `scripts/bb/rebase.sh`. Tests reach it via `$here/../rebase.sh`.
- Size: rebase.sh ≤ ~40 changed lines. A bigger change means the wrong option; write a Handoff instead.

## Handoff

## Result

## Review

## QA
