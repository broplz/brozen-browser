---
id: 0008
title: scripts/bb/smoke.sh + scripts/bb/smoke.d/e0.txt — smoke checklist v1 with y/n prompts
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: ready
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
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
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

## Review

## QA
