---
id: 0009
title: scripts/bb/report.sh + docs/rebase/README.md — per-rebase report and the summary table
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: approved
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
returns: 1
sessions: 0
reviewed_sha: 29ddbb871c976554fc1da272e5320fcbdf3166bc
qa_sha: 29ddbb871c976554fc1da272e5320fcbdf3166bc
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
Round 2 (review items 1-5):
1. README upsert: missing README → error, exit 1; removed `2>/dev/null || true` and the fallback; `$tmp` is in the EXIT trap; written with `cat "$tmp" >"$README"` (keeps the file mode).
2. Removed the unused `rest()`.
3. Test calls `"$BASH" "$report"`.
4. Test asserts `none` separately under `## Conflicts` and `## Conflicts by epic`.
5. Both awk passes share one `STEPLIB` (`is_hdr`, `is_ftr`, `val`), so step-line parsing is defined once.
Verified: `/bin/bash scripts/bb/tests/report_test.sh` → PASS; `bash -n scripts/bb/report.sh` → no output. `diff.sh --names` not re-run.

Round 1: added `scripts/bb/report.sh` (awk-based log parser, upserts the README row), `scripts/bb/tests/report_test.sh`, and `docs/rebase/README.md`.
Verified: `/bin/bash scripts/bb/tests/report_test.sh` prints PASS (it ran on macOS with /bin/bash 3.2); the test writes only under mktemp. `bash -n` and `diff.sh --names` were not run separately.
Open: the README row's firefox is taken from `recon: firefox` (`<fy>`).

## Review
APPROVE
Round 2: all five items from round 1 are fixed.
1. Item 1: a missing README now gives exit 1. Nothing is swallowed, `$tmp` is in the EXIT trap, and the write uses `cat >`, so the file mode is kept (report.sh:113-125).
2. Item 2: `rest()` is gone.
3. Item 3: the test calls `"$BASH" "$report"` everywhere.
4. Item 4: the test checks `none` separately under `## Conflicts` and under `## Conflicts by epic` (report_test.sh:76-79).
5. Item 5: the step-line helpers live once, in `STEPLIB` (report.sh:20-24).

Checklist: (1) Spec: the DoD 3a-g, the row format, the `.md` layout and the conflict kinds match ## Notes and ADR-0002 Решение 4. (2) Scope: `diff.sh --names` lists only the 3 allowed_paths. (3) Layer rules: N/A, because no Zen files, engine files, prefs or patches are touched, and layer_lint reports 0 fail and 0 warn. (4) Correctness: `set -euo pipefail` is set, the temp files are cleaned up by the trap, and the exit codes are 0/1/2 as documented. (5) Verification: I ran the checks myself. `bash -n` printed nothing, `/bin/bash scripts/bb/tests/report_test.sh` printed `PASS`, and `git status` was clean afterwards, so docs/rebase is unchanged (DoD 5). (6) Hygiene: everything is in English, and there are no TODOs and no secrets.

---
REQUEST_CHANGES
1. scripts/bb/report.sh:109-122: the README upsert hides failures. `2>/dev/null || true` swallows awk errors, such as a missing or unreadable README. The `[ ! -s "$tmp" ]` fallback then writes a README that contains only the row, which wipes the explanation and the table header. Fix: if `$README` is missing, print an error and exit 1 (or seed it from the header). Remove `2>/dev/null || true`. Add `$tmp` to the EXIT trap. Write with `cat "$tmp" >"$README"` instead of `mv`, because mv carries mktemp's 0600 mode onto docs/rebase/README.md.
2. scripts/bb/report.sh:45: the awk function `rest()` is never called. It is dead code, so remove it.
3. scripts/bb/tests/report_test.sh:38,60,74,80,82,84: `bash "$report"` resolves through PATH, so on a machine with Homebrew bash 5 first on PATH, DoD 2 (bash 3.2) is not exercised. Use `"$BASH" "$report"`.
4. scripts/bb/tests/report_test.sh:76-77: the check for DoD 3f is too weak. c.log has no expected conflicts, so `## Expected conflicts` also prints `none`, and `≥ 2` passes even when one conflict table is not `none`. Assert the `none` under `## Conflicts` and under `## Conflicts by epic` separately, or require exactly 3.
5. (minor, same round) scripts/bb/report.sh:21-25 vs 46-49: two awk passes each parse the header and footer, and the duration parsing (`sub(/^duration=/…)`) is duplicated. Either make the first pass the only place that parses step lines, or share the regexes through `-v`, so the two cannot drift apart.

Checked: `bash -n` passes and prints nothing. `/bin/bash scripts/bb/tests/report_test.sh` prints PASS. `diff.sh --names` lists only the 3 allowed_paths. layer_lint reports 0 fail. Spec: the conflict kinds, the hours formula, the `.md` layout, and the row format match ## Notes and ADR-0002 Решение 4. Scope: OK. Layer rules: no Zen or engine files and no prefs, so N/A. The Result is honest that bash -n and --names were not run.

## QA
PASS
1. DoD 1: `bash -n scripts/bb/report.sh` → exit 0, no output.
2. DoD 2: `/bin/bash scripts/bb/tests/report_test.sh` → `PASS`.
3. DoD 3 (a-g): covered by the test, which passes. Reviewer read the assertions against the spec.
4. DoD 4: `docs/rebase/README.md` has 4 explanation lines and ends with the required header and `|---|…` separator.
5. DoD 5: `git status --short` is clean after the test run, so the real `docs/rebase/` is unchanged.
6. DoD 6: `diff.sh --names` lists only report.sh, report_test.sh and docs/rebase/README.md.
7. Lint: `scripts/agents/test.sh lint` → OK, 0 problems; layer_lint 0 fail, 0 warn. Build type `none`, so I did not run a build.

For the human: no `[human]` items.
