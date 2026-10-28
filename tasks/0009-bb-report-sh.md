---
id: 0009
title: scripts/bb/report.sh + docs/rebase/README.md — per-rebase report and the summary table
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: ready
base: feat/layer
branch: task/0009-bb-report-sh
depends_on: [0002]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/bb/report.sh
  - scripts/bb/tests/report_test.sh
  - docs/rebase/README.md
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4--runbook-ребейза
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Create `scripts/bb/report.sh`, the maintenance-cost metric of ADR-0002 Решение 4 ("Метрика"). From one rebase log it
writes `docs/rebase/<Y>.md` and upserts one row in `docs/rebase/README.md`. A row holds the tag, date, Firefox,
conflicts in total and by epic, hours and status. Conflicts are counted in the three ADR kinds: git conflict in the
rebase, BB patch did not apply, Zen patch hunk had to be edited. The script reads only the log; it never runs git.

## Definition of Done
1. `bash -n scripts/bb/report.sh` → exit 0, no output.
2. `/bin/bash scripts/bb/tests/report_test.sh` → last line `PASS`, exit 0 (macOS bash 3.2).
3. The test writes a fixture log under `mktemp -d` in the formats from ## Notes and runs the script with
   `BB_REBASE_DOCS=$T/rebase` (a copy of the real `docs/rebase/README.md`). It asserts, with a message on failure:
   a. a log with step headers at `2026-11-08 10:00:00` and the last header at `2026-11-08 11:20:00` with `duration=600s` → `$T/rebase/1.0.1b.md`
      has `- hours: 1.5`, `- date: 2026-11-08`, `- status: ok`, `- zen: 1.0.0b -> 1.0.1b`, `- firefox: 150.0 -> 151.0`;
   b. log lines `conflict: git src/zen/moz.build layer`, `conflict: git src/browser/base/content/browser-js.patch e3-little-bb`,
      `FAIL e3-little-bb/session-skip: zen error: patch failed` → the conflicts table has the kinds `git`, `zen-patch`,
      `bb-patch` respectively; the by-epic table has `layer` total 1 and `e3-little-bb` total 2;
   c. the steps table lists every `<== step:` footer in log order with exit and duration;
   d. `smoke: y|n …` lines appear under `## Smoke`, with the `smoke: result` line;
   e. README.md gets a row starting `| 1.0.1b | 2026-11-08 | 151.0 | 3 | e3-little-bb:2, layer:1 | 1.5 | ok |`;
      running again with `failed "build broke"` replaces that row (still one `| 1.0.1b |` row) and `1.0.1b.md` has
      `- status: failed` and `- blocker: build broke`;
   f. a log without conflicts → `0` and `-` in the row, and both conflict tables say `none`;
   g. missing log file → exit 1; wrong arg count or a status other than `ok|failed` → usage on stderr, exit 2.
4. `docs/rebase/README.md` exists, explains the metric in 3-6 English lines (what a row means, the three conflict kinds,
   the January hard-fork checkpoint) and ends with the table header
   `| tag | date | firefox | conflicts | by epic | hours | status |` and its `|---|…` separator line.
5. The test writes only under its `mktemp -d` and removes it; the real `docs/rebase/` is unchanged after it.
6. `scripts/agents/diff.sh tasks/0009-bb-report-sh.md --names` lists only the three allowed_paths.

## Notes from teamlead
- Usage: `report.sh <Y> <log> <ok|failed> [<blocker>]`. `BB_REBASE_DOCS` default `$BB_ROOT/docs/rebase` (source lib.sh).
  Exit 0 ok · 1 missing log · 2 usage. Overwrite `<Y>.md`; upsert the README row keyed by `| <Y> |`, else append it after
  the last table line.
- Log formats (contract with lib.sh, 0007, 0014, 0008, 0011 — parse exactly these, ignore all other lines):
  - lib.sh header `==> YYYY-MM-DD HH:MM:SS step: <name>`; footer `<== step: <name> exit=<rc> duration=<n>s`;
  - `recon: zen <X> -> <Y>` · `recon: firefox <fx> -> <fy>` · `recon: upstream-commits <n>` · `recon: toolchain-changed <file>`
    (0 or more) · `recon: expected-conflict <file> <epic>` (0 or more);
  - `conflict: git <file> <epic>` (rebase step);
  - patches.sh check output `FAIL <epic>/<name>: <clean|zen> <reason>` (patches step);
  - `smoke: <y|n> <epic> <item>` and `smoke: result <k>/<n>` (smoke.sh).
- Conflict kinds (ADR Метрика): a `conflict: git` line whose file matches `src/**.patch` and is not under `src/bb/` →
  `zen-patch` (a Zen patch hunk had to be edited); other `conflict: git` → `git`; each `FAIL <epic>/<name>:` → `bb-patch`
  with file `<epic>/<name>` and epic `<epic>`. The epic is always taken from the line; never re-derive it.
- date = the date of the first header. hours = (epoch of the last header + its footer's duration − epoch of the first header)
  / 3600, one decimal. It is wall time, so human conflict time across `--continue` counts (ADR: hours of cost). Parse with BSD
  `date -j -f '%Y-%m-%d %H:%M:%S' … +%s`. firefox in the row = `<fy>`; `-` if the recon line is missing.
- `<Y>.md` layout, in this order: `# Rebase <Y>`, bullet lines `- status:`, `- blocker:` (failed only), `- date:`, `- zen:`,
  `- firefox:`, `- upstream commits:`, `- toolchain changed:` (comma list or `none`), `- hours:`; then sections `## Steps`
  (`| step | exit | duration |`), `## Conflicts` (`| kind | epic | file |`), `## Conflicts by epic`
  (`| epic | git | bb-patch | zen-patch | total |`, sorted by epic), `## Expected conflicts` (bullets or `none`), `## Smoke`
  (the smoke lines without the `smoke: ` prefix, or `not run`).
- by-epic in the README row: `<epic>:<total>` joined by `, `, sorted by epic name; `-` when none.
- awk is fine for parsing; bash 3.2 (no associative arrays in bash — use awk for counting); `set -euo pipefail`.

## Handoff

## Result

## Review

## QA
