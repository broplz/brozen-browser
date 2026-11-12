---
id: 0041
title: rebase.sh recon reports an expected conflict only when the layer's and upstream's hunks are near each other
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: ready
base: feat/layer
branch: task/0041-bb-rebase-recon-line-ranges
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_recon_test.sh
  - scripts/bb/tests/rebase_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
`do_recon` (scripts/bb/rebase.sh:137-150) prints `recon: expected-conflict <file> <epic>` for every file that upstream
changed between `X` and `Y` and that the layer registers (layer.yaml `- file:` entries) or that is the Zen patch of a
BB patch target. For 1.24.1b it predicted 5 conflicts, and only `zen-assets.jar.inc.mn` really conflicted
(docs/rebase/1.24.1b.md). After this task a file counts as an expected conflict only when a layer hunk and an upstream
hunk in it lie within `BB_RECON_MARGIN` lines (default 3) of each other. The log line format stays as it is, so
report.sh (l.59) needs no change.

## Definition of Done
1. `/bin/bash scripts/bb/tests/rebase_recon_test.sh` → exit 0, last line `rebase_recon_test: OK`. It runs
   `rebase.sh <tag>` against an upstream fixture the way rebase_test.sh does and reads the recon lines from the
   log (the step-4 result does not matter). Cases, each checking the recon log lines:
   a. registered file, the layer hunk is at the top (line 1) and the upstream hunk at the end (line 10 of 10) →
      no `recon: expected-conflict` line for it;
   b. registered file, the two hunks are 2 lines apart → `recon: expected-conflict <file> <epic>`;
   c. registered file, the same line changed on both sides → expected-conflict;
   d. `BB_RECON_MARGIN=0` with the hunks of case b → no expected-conflict line;
   e. BB patch on `a/b.js` plus a Zen patch `src/a/b-js.patch` that upstream changed: the changed Zen hunk's
      Firefox-side range is far from the BB patch hunk → no line; the same with an overlapping range → the line
      `recon: expected-conflict src/a/b-js.patch <epic>`;
   f. upstream changed a registered file that the layer does not change at all since `bb/base/X` → no line.
2. `/bin/bash scripts/bb/tests/rebase_test.sh` → exit 0. The only change in it: case a (l.85-86) no longer expects
   `recon: expected-conflict src/zen/moz.build layer` (that fixture appends the hook after line 5 and upstream changes
   line 1, which is now "far") and asserts that the line is absent.
3. The other rebase tests pass unedited: `/bin/bash scripts/bb/tests/<t>.sh` for `rebase_post_test`,
   `rebase_continue_test`, `rebase_final_test`, `rebase_brand_test`, `rebase_display_version_test`, `report_test` →
   exit 0 each.
4. rebase.sh header (l.9-13) lists `BB_RECON_MARGIN` with its default.
5. `scripts/agents/diff.sh tasks/0041-bb-rebase-recon-line-ranges.md --names` lists only allowed_paths and the task file.

## Notes from teamlead
- Ranges are old-side (`-s,c`) ranges of `@@` headers from `git diff -U0`. A hunk `-s,c` covers `[s, s+c-1]` when
  `c > 0`, and `[s, s]` when `c = 0` (pure insertion after line s). A missing `,c` means `c = 1`. Two ranges are near
  when `a_start <= b_end + M && b_start <= a_end + M`. One awk/shell helper parses ranges and one tests nearness;
  both sides use them. No copy-pasted parsing.
- Registered files (`registry_pairs`): the layer side is `g diff -U0 refs/tags/bb/base/$x $BB_MAIN_BRANCH -- <file>`
  and the upstream side is `g diff -U0 refs/tags/$x refs/tags/$Y -- <file>`. Both are diffs from the same preimage
  (`bb/base/X` and tag `X` are the same commit, checked for 1.24.1b), so their line numbers are comparable.
- BB patch targets (`patch_pairs`): the Zen patch is a diff itself. Its "changed hunks" are the `@@` headers of the
  Zen patch at `Y` (`g show refs/tags/$Y:<zen patch>`) that do not occur verbatim in the Zen patch at `X`. Compare their
  old-side (Firefox) ranges with the old-side ranges of the BB patch's `@@` headers for the same target file. Firefox
  line numbers can move between versions; that is accepted, it is a heuristic. A Zen patch that is new at `Y` (absent
  at `X`): all its hunks count as changed.
- Fallback: when `refs/tags/bb/base/$x` does not exist, keep the old file-level rule for registered files and print
  `recon: no bb/base/<x>, file-level`. Do not fail recon (step 4 reports the missing tag itself).
- Keep the loop shape: one pass over the upstream changed files, one place where `recon: expected-conflict` is
  echoed. Positive conditions with early `continue` (owner's rule), no negated compound tests.
- Hook: only rebaser may run a command that names `scripts/bb/rebase.sh`. Tests reach it via `$here/../rebase.sh`;
  read it with the Read tool. Reuse `rebase_fixture.sh` (`stub_env`, `make_engine`) the way rebase_test.sh does.
- Do not touch report.sh, `epic_of`, `registry_pairs` or `patch_pairs` output formats.

## Handoff

## Result

## Review

## QA
