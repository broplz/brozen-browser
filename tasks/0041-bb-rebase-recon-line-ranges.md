---
id: 0041
title: rebase.sh recon reports an expected conflict only when the layer's and upstream's hunks are near each other
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: done
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
returns: 1
sessions: 0
reviewed_sha: 800de19642e378ccf60e5b5a1d21466acf88b2b1
qa_sha: 800de19642e378ccf60e5b5a1d21466acf88b2b1
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
Round 2 (Review items 1-5)
- 1: new `bb_patch_targets` ("<patch> <epic> <target> <zen patch>"); `patch_pairs` and `bb_patch_hunks` use it.
- 2: `epic_of` uses `registry_pairs | first_epic`.
- 3: `do_recon` builds `reg`/`pat` once; `first_epic` reads them.
- 4: `2>/dev/null` on the `g show` of the Zen patch at Y.
- 5: `local n c l` in rebase_recon_test.sh.
- Verified: rebase_recon_test, rebase_test, rebase_post_test, rebase_continue_test, report_test pass.
  final/brand/display_version tests not re-run (code they exercise is unchanged this round).

Round 1
- rebase.sh: recon reports `expected-conflict` only when old-side hunk ranges of the layer and of upstream lie
  within `BB_RECON_MARGIN` (default 3, documented in the header). Helpers `hunk_ranges` (parse `@@`) and
  `ranges_near` (nearness); `registered_near` (layer vs upstream `git diff -U0`), `patch_near` (changed Zen patch
  hunks vs BB patch hunks via `bb_patch_hunks`). Missing `bb/base/<x>` → `recon: no bb/base/<x>, file-level`.
  Log line format unchanged.
- New tests/rebase_recon_test.sh (cases a–f); rebase_test.sh case a now asserts the line is absent.
- Verified: rebase_recon_test, rebase_test, rebase_post_test, rebase_continue_test, rebase_final_test,
  rebase_brand_test, rebase_display_version_test, report_test all pass. Did not run diff.sh/layer_lint.
- Open: none.

## Review
APPROVE
Round 2: items 1-5 are fixed.
- 1: `bb_patch_targets` (scripts/bb/rebase.sh:83-94) is now the only loop. `patch_pairs` (l.97) and `bb_patch_hunks`
  (l.160-165) both read from it, and the `patch_pairs` output format did not change.
- 2: `epic_of` (l.107) uses `first_epic`.
- 3: `reg`/`pat` are built once (l.186-187), and the loop reads them through here-strings.
- 4: both `g show` calls in `patch_near` (l.177-180) send stderr to /dev/null.
- 5: `local n c l` (rebase_recon_test.sh:26).
Checklist: spec matches DoD 1-5 (no change from round 1). Only allowed_paths are touched. layer_lint: 0 fail.
The log line format did not change. Round 2 did not touch the code that the final/brand/display_version tests
exercise; qa runs all of them.
Nit, no action: `not_has` is now defined in both rebase_test.sh:22 and rebase_recon_test.sh:22. That matches the
existing copy of `has`/`check`. A shared test helper would belong in a backlog item, not in this task.

---
Round 1: REQUEST_CHANGES
1. scripts/bb/rebase.sh:157-168 `bb_patch_hunks` copies the `patch_pairs` loop (l.80-91): the same glob, `-f` guard,
   `grep '^+++ b/' | cut -c7- | while read` and the `src/${t%/*}/${nm//./-}.patch` name mapping. This breaks the owner's
   no-duplicates rule and the teamlead note "No copy-pasted parsing". Move it into one helper, e.g.
   `bb_patch_targets` → "<bb patch> <epic> <target> <zen patch>". `patch_pairs` prints columns 4 and 2 of it (its
   output format stays the same) and `bb_patch_hunks` filters on column 4 and runs the `+++`/`@@` awk on column 1.
2. scripts/bb/rebase.sh:154 `first_epic` is the same awk as the one in `epic_of` (l.101). Make `epic_of` use
   `registry_pairs | first_epic "$1"`.
3. scripts/bb/rebase.sh:201,205: the loop runs `registry_pairs` and (for unregistered files) `patch_pairs` again for
   every file upstream changed. A Zen release touches hundreds of files, and `patch_pairs` starts grep/cut for every BB
   patch each time. The old code built the pairs once. Build them once before the loop (e.g. two locals
   `reg="$(registry_pairs)"`, `pat="$(patch_pairs)"`) and have `first_epic` read from them.
4. scripts/bb/rebase.sh:182 `g show "refs/tags/$Y:$2"` has no `2>/dev/null` (l.179 has one). When upstream deletes a
   Zen patch, a `fatal: path ... does not exist` line goes into the rebase log. Treat both sides the same way.
5. scripts/bb/tests/rebase_recon_test.sh:28 `f_txt` loops over `l` but does not declare it: add it to `local n c`.

Checked, no action: DoD cases a–f map 1:1 to the scenarios (a: [1,1]/[10,10] far; b: 5/7 near at M=3, far at M=0;
e: [20,21] vs [21,23] near, [300,302] far; the unchanged Zen hunk at -100 is dropped by `grep -vxF`). An empty `$old`
(Zen patch new at Y) keeps every header. The file-level fallback via `near=true` prints the documented line. The log
line format is unchanged. The header documents BB_RECON_MARGIN. Only allowed_paths are touched. layer_lint: 0 fail.
I did not run the tests myself (the hook blocks rebase commands for the reviewer); qa runs them.

## QA
PASS
1. rebase_recon_test.sh → exit 0, `rebase_recon_test: OK`.
2. rebase_test.sh → PASS.
3. rebase_post, rebase_continue, rebase_final, rebase_brand, rebase_display_version, report tests → all pass.
4. rebase.sh header l.11-12 lists BB_RECON_MARGIN (default 3).
5. diff.sh --names lists only rebase.sh, rebase_recon_test.sh, rebase_test.sh. (`git diff feat/layer --name-only` also shows two `.claude/agent-memory/reviewer/` files from the reviewer session; not developer output, not counted by diff.sh.)
6. Build none (skipped). `test.sh lint` OK (0 problems), layer_lint 0 fail.
