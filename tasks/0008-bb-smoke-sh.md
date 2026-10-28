---
id: 0008
title: scripts/bb/smoke.sh + scripts/bb/smoke.d/e0.txt — smoke checklist v1 with y/n prompts
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: approved
base: feat/layer
branch: task/0008-bb-smoke-sh
depends_on: [0002]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/bb/smoke.sh
  - scripts/bb/smoke.d/e0.txt
  - scripts/bb/tests/smoke_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4--runbook-ребейза
returns: 1
sessions: 0
reviewed_sha: e940ab86467492f796dacc6d45c4b124f2118299
qa_sha: e940ab86467492f796dacc6d45c4b124f2118299
blocked_reason:
---
## Goal
Create `scripts/bb/smoke.sh <Y>` (ADR-0002 Решение 4, step 10 and "Smoke-чеклист v1"): it copies the working profile to
`/tmp/bb-smoke-<Y>`, launches the build on that copy, then prints the checklist items one at a time and waits for `y/n`.
The answers go to stdout in a fixed format, so rebase.sh (0011) captures them in the rebase log and report.sh (0009)
puts them in the report. The checklist is assembled from `scripts/bb/smoke.d/<eN>.txt`; this task ships `e0.txt`
with checklist v1.

## Definition of Done
1. `bash -n scripts/bb/smoke.sh` → exit 0, no output.
2. `/bin/bash scripts/bb/tests/smoke_test.sh` → last line `PASS`, exit 0 (macOS bash 3.2).
3. The test runs everything under `mktemp -d` with `BB_SMOKE_DIR` (fixture checklist files), `BB_SMOKE_TMP=$T`,
   `BB_SMOKE_PROFILE` (a fixture profile dir with one file) and `BB_SMOKE_BIN` (a stub that writes its argv to `$T/argv`).
   Answers are fed on stdin. It asserts, with a message on failure:
   a. fixture `e0.txt` (2 items, plus a `# comment` and a blank line) and `e3.txt` (1 item), answers `y y y` → exit 0; stdout has
      `smoke: y e0 <item1>`, `smoke: y e0 <item2>`, `smoke: y e3 <item>` in that order and the last line `smoke: result 3/3`;
   b. answers `y n y` → exit 1, `smoke: n e0 <item2>`, last line `smoke: result 2/3`;
   c. an invalid answer is re-asked: stdin `x`, `y`, `y`, `y` → exit 0, `smoke: result 3/3`;
   d. stdin ends before the last item → exit 1, stderr `smoke: aborted`;
   e. `$T/bb-smoke-<Y>/` contains the fixture profile file (a stale file put there before the run is gone), and `$T/argv`
      contains `-profile $T/bb-smoke-<Y>`;
   f. `--no-launch` → the stub is not called (`$T/argv` absent), checklist still runs;
   g. no `BB_SMOKE_BIN` and no build found (`BB_ROOT`-relative glob matches nothing, use `BB_ENGINE_DIR=$T/none`) without
      `--no-launch` → exit 1 with `smoke: no build found` on stderr;
   h. no `<Y>` argument or an unknown option → usage on stderr, exit 2.
4. `grep -c -v -E "^(#|$)" scripts/bb/smoke.d/e0.txt` → `5`.
5. The test writes only under its `mktemp -d` and removes it.
6. `scripts/agents/diff.sh tasks/0008-bb-smoke-sh.md --names` lists only the three allowed_paths.

## Notes from teamlead
- Usage: `smoke.sh [--no-launch] <Y>`. Exit 0 all `y` · 1 any `n`, aborted, or no build · 2 usage.
- Source `scripts/bb/lib.sh` for `BB_ROOT`. Overrides (env wins): `BB_SMOKE_DIR` (default `$BB_ROOT/scripts/bb/smoke.d`),
  `BB_SMOKE_TMP` (default `/tmp`), `BB_SMOKE_PROFILE` (source profile; unset → empty profile dir and a warning
  `smoke: BB_SMOKE_PROFILE not set, using an empty profile` on stderr), `BB_ENGINE_DIR` (default `$BB_ROOT/engine`),
  `BB_SMOKE_BIN` (default: first match of `$BB_ENGINE_DIR/obj-*/dist/*.app/Contents/MacOS/zen`; `binaryName` is `zen`).
- Profile: `rm -rf "$BB_SMOKE_TMP/bb-smoke-<Y>"`, then `cp -R "$BB_SMOKE_PROFILE/." <that dir>` (ADR: a copy of the working
  profile, never the profile itself).
- Launch: `"$BB_SMOKE_BIN" -profile "$BB_SMOKE_TMP/bb-smoke-<Y>" -no-remote &` — in the background, do not wait and do not
  kill it; the human closes it after the checklist.
- Checklist: every `$BB_SMOKE_DIR/*.txt` in sorted order; each line that is not blank and not starting with `#` is one item;
  the epic is the file's base name without `.txt`. Prompt `[<epic>] <item> [y/n] ` on stderr, read one line from stdin;
  accept only `y` or `n`, re-ask otherwise; EOF → `smoke: aborted` on stderr, exit 1.
- stdout format, fixed (report.sh 0009 greps the rebase log for it): `smoke: <y|n> <epic> <item>` per item, then
  `smoke: result <yes-count>/<total>`. Nothing else on stdout.
- `e0.txt` = the five ADR checklist-v1 items for E0–E2, one per line in English, in the ADR's order:
  1. launch from a copy of the working profile: window draws, compact mode without borders, no new errors in Browser Console in the first 30 s (compare with the previous report);
  2. workspaces switch, a new tab lands in its workspace's container, essentials are in place;
  3. glance, split, folders: open and close each once;
  4. about:buildconfig shows the flags from configs/bb/mozconfig; about:config shows bb.* prefs with expected values;
  5. stripped features are absent per ADR-0003 (AI buttons, telemetry, sync, Zen Mods).
  A `# ` header comment line is fine. The uBlock (E10) and Little BB restart (E3) items are NOT added: their epics add
  `e10.txt` / `e3.txt` when they exist (ADR: "E3+ добавят свои").
- bash 3.2, `set -euo pipefail`, `read -r` with `IFS=`. No `step` here: rebase.sh wraps smoke.sh in `step` (0011).

## Handoff

## Result
Round 2 (review items 1–4):
- 1: the browser's stdout/stderr go to `<profile>.log` (path printed on stderr); the stub now echoes `noise`, and case (e) asserts stdout has only `smoke: ` lines.
- 2: case (a) is one `diff` of the whole stdout against the expected 4 lines.
- 3: case (e) checks `rc` = 0.
- 4: find bin → copy profile → launch is one `if [ "$launch" = 1 ]` block.
- Verified: `/bin/bash scripts/bb/tests/smoke_test.sh` → `PASS`. `bash -n` not run separately (the test parses the script).

Round 1:
- Added `scripts/bb/smoke.sh`, `scripts/bb/smoke.d/e0.txt` (5 items), `scripts/bb/tests/smoke_test.sh`.
- Verified: `/bin/bash scripts/bb/tests/smoke_test.sh` → `PASS`; `grep -c -v -E "^(#|$)" e0.txt` → 5.
- NOT run: `bash -n scripts/bb/smoke.sh` — the guard hook blocks any developer command containing "smoke". The test run parses the script, so syntax is fine.
- Test note: cases a–d use `--no-launch` so no stray background stubs overwrite `$T/argv` before case e (an earlier version failed e that way).
- Not run: `diff.sh --names` (only the three allowed paths plus this task file were changed).

## Review
APPROVE

Round 2 checklist notes: (1) Spec/DoD: all four round-1 items are fixed. smoke.sh:51 now redirects the browser to
`$profile.log` (outside the profile dir; `>` truncates the old one) and prints the path on stderr. The test case (a) is one
`diff` (test:37-38), (e) checks rc (test:64) and that stdout has only `smoke: ` lines, and the stub echoes `noise` (test:22).
Launch is one `if` block (smoke.sh:30-53). (2) Scope: diff lists only the 3 allowed_paths; e0.txt has 5 items in ADR order (DoD 4).
(3) Layer: no Zen/Firefox files; layer_lint 0 fail / 0 warn. (4) `set -euo pipefail`, `IFS= read -r`, EOF → abort exit 1,
usage exit 2. The `&&` counter is safe under -e, and the background job no longer holds `step`'s tee pipe. (5) Result is
honest: `bash -n` was not run because the hook blocks "smoke" commands, also for the reviewer. qa must run DoD 1 and 2.
(6) Hygiene is clean.

---
REQUEST_CHANGES
1. scripts/bb/smoke.sh:51: the backgrounded browser inherits smoke.sh's stdout/stderr. rebase.sh will run smoke.sh
   through `step`, which does `"$@" 2>&1 | tee -a "$BB_LOG"` (scripts/bb/lib.sh:26), so Zen keeps the pipe's write end
   open. tee never gets EOF, and rebase.sh hangs after the checklist until the human quits the browser. All of Zen's
   console output also lands on stdout, which breaks "Nothing else on stdout". Fix: send the browser's output to a file,
   e.g. `"$bin" -profile "$profile" -no-remote > "$profile.log" 2>&1 &`, and print the log path on stderr. Add a test:
   make the stub also `echo noise` to stdout, then assert in case (e) that `$T/out` has only `smoke: ` lines.
2. scripts/bb/tests/smoke_test.sh:36-42: DoD 3a asks for the three item lines "in that order". The test only counts them
   and checks the first and last lines, so it would not catch item two and item three swapped. Replace the five
   per-line checks with one comparison of the whole stdout against the expected 4 lines (`printf … | diff - "$T/out"`).
   That is a single check and it covers the order.
3. scripts/bb/tests/smoke_test.sh:65: case (e) never checks `$rc`. Add `check "e: exit 0" test "$rc" = 0`.
4. scripts/bb/smoke.sh:31-52: there are two consecutive `if [ "$launch" = 1 ]` blocks. Merge them into one block
   (find bin → copy profile → launch), so the launch path is a single branch with no repeated condition.

Checklist notes: (1) the spec and DoD are covered except for the items above. e0.txt has 5 items in the ADR's order
(DoD 4 re-run → 5). (2) Scope: only the 3 allowed_paths are touched. (3) Layer: no Zen/Firefox files; layer_lint 0 fail.
(4) The script has `set -euo pipefail`, `IFS= read -r`, EOF → abort exit 1, and usage exit 2. The `&&` counter is safe
under -e. The background job's stdin is /dev/null (non-interactive), so it does not steal answers. (5) Result is honest
that `bash -n` was not run. The hook blocks it for the reviewer too, so qa should run DoD 1 and 2. (6) Hygiene is clean.

## QA
PASS
1. DoD 1: `bash -n scripts/bb/smoke.sh` → exit 0, no output.
2. DoD 2: `/bin/bash scripts/bb/tests/smoke_test.sh` → `PASS`.
3. DoD 3: the test uses `mktemp -d` with the BB_SMOKE_* overrides (cases a–h covered by the passing run).
4. DoD 4: `grep -c -v -E "^(#|$)" scripts/bb/smoke.d/e0.txt` → 5.
5. DoD 5: the test uses `T=$(mktemp -d)` and `trap 'rm -rf "$T"' EXIT`.
6. DoD 6: `diff.sh --names` lists only smoke.d/e0.txt, smoke.sh, tests/smoke_test.sh.
7. `test.sh lint` → OK, 0 problems; layer_lint 0 fail / 0 warn. Build type none, so no build.
