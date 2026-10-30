---
id: 0022
title: BB builds without the app updater (no polling of Zen's update.xml)
epic: e0
prefix: e0
kind: feature
role: developer-hard
size: S
status: approved
base: feat/layer
branch: task/0022-brand-disable-updater
depends_on: [0021]
build: full
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - configs/bb/mozconfig
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#границы--где-живут-брендинг-mozconfig-и-вырезание
returns: 0
sessions: 0
reviewed_sha: 600c09bfd7dcf6756e362b2e714702c6eb8b5e76
qa_sha: 600c09bfd7dcf6756e362b2e714702c6eb8b5e76
blocked_reason:
---
## Goal
The dev build polls `https://updates.zen-browser.app/updates/browser/Darwin_aarch64-gcc3/unofficial/update.xml` and logs an XML
Parsing Error. Owner answer (decisions-needed.md, "0021 — owner answers"): no update server yet, disable app updates for the
brand. ADR-0002 §Границы puts `--disable-*` build flags into `configs/bb/mozconfig`; after this task BB is built with
`--disable-updater`, so no update check runs and no update UI is shown.

## Definition of Done
1. `grep -n -- "--disable-updater" configs/bb/mozconfig` → exactly one line `ac_add_options --disable-updater`, preceded by a
   comment line containing `BB(e0)` and the reason (no update server yet).
2. `scripts/agents/build.sh full` → `BUILD RESULT: OK`.
3. `python3 scripts/agents/layer_lint.py tasks/0022-brand-disable-updater.md` → 0 fail.
4. `scripts/agents/diff.sh tasks/0022-brand-disable-updater.md --names` lists only allowed_paths.
5. [human] Browser Console after start and 1 min idle: no `update.xml` / XML Parsing Error line.
6. [human] about:preferences has no app-update section; About dialog shows no "Check for updates" button and no error.

## Notes from teamlead
- One flag, in `configs/bb/mozconfig` after the header comment and before the `. …mozconfig.macos` line. Do not touch
  `configs/common/mozconfig` or `configs/macos/mozconfig` (Zen's), surfer.json `updateHostname`, or any prefs.
- Not via prefs: `prefs/bb/*.yaml` may hold only `bb.*` names (layer_lint fails `app.update.*` there), so the ADR's
  `prefs/bb/updates.yaml` route is not used; this is noted for the owner in docs/reports/decisions-needed.md.
- If the full build fails because Zen code needs the updater (e.g. a missing `UpdateService`/`AppUpdater` import at build time),
  that is a Handoff + blocked with the triage lines, not a workaround in Zen files.
- Role developer-hard: mozconfig change → full build (≈ 40 min); 2 failed full builds = strike.

## Handoff

## Result
Round 1.
- What changed: `configs/bb/mozconfig` gets `ac_add_options --disable-updater` after the header and before the
  `. …mozconfig.macos` line, with a `# BB(e0): no BB update server yet…` comment line right above it. No other files.
  `grep -rn updater configs` showed that no Zen mozconfig turns the updater back on.
- How verified:
  1. `grep -n -- "--disable-updater" configs/bb/mozconfig` → exactly one line, `12:ac_add_options --disable-updater`;
     line 11 is the `BB(e0)` comment with the reason.
  2. `scripts/agents/build.sh full` → `BUILD RESULT: OK type=full duration=2169s`
     (logs/build-full-20261030-201259.log), 0 error lines. The objdir's `.mozconfig.json` contains `"--disable-updater"`,
     and `config.statusd/substs` has no `MOZ_UPDATER`, so the updater is off. After the build I reworded the two
     comment lines only (the flag is the same) and did not run the 40-min build again.
  3. `layer_lint.py` → 0 fail, 0 warn.
  4. `diff.sh --names` → only `configs/bb/mozconfig`.
  5–6. [human] not checked: I did not start the browser.
- For the owner: this is a build-flag change (no C++); check DoD 5–6 in the built app.

## Review
APPROVE
1. Spec: one `ac_add_options --disable-updater` in configs/bb/mozconfig:12, after the header and before the
   `. …mozconfig.macos` line, with the `BB(e0)` reason comment at :11. This matches the DoD and ADR-0002 §Границы
   (strip flags go in configs/bb/mozconfig). No prefs, surfer.json or Zen mozconfig touched.
2. Scope: the diff touches only configs/bb/mozconfig (allowed_paths). No tests changed.
3. Layer: configs/bb/ belongs to BB, so it needs no layer.yaml entry and nothing is in engine/. layer_lint reports 0 fail and 0 warn.
   F2 does not apply: this is a build flag, not a pref-gated module.
4. Correctness: `grep -rn updater configs` finds no other line that turns the updater back on. No JS or shell logic changed.
5. Verification: I re-ran DoD 1 and got exactly one line, `12:ac_add_options --disable-updater`. logs/build-full-20261030-201259.log
   contains `BUILD RESULT: OK type=full`. The comments were reworded after that build, but only the comments.
   DoD 5–6 are [human] items and are still open, as the Result says.
6. Hygiene: no issues. Nit, not blocking: the header's closing `#` at configs/bb/mozconfig:9 became a blank line.

## QA
PASS
1. DoD 1: `grep -n -B2 -- "--disable-updater" configs/bb/mozconfig` → exactly one flag line (12), comment line 11 has `BB(e0)` and the reason.
2. DoD 2: `scripts/agents/build.sh full` → `BUILD RESULT: OK type=full duration=1868s` (logs/build-full-20261030-205039.log).
3. `scripts/agents/test.sh lint` → OK, 0 problems (logs/test-lint-20261030-212153.log).
4. DoD 3: layer_lint → 0 fail, 0 warn.
5. DoD 4: `diff.sh --names` → only configs/bb/mozconfig.
For the human: DoD 5 (Browser Console: no update.xml / XML Parsing Error after 1 min idle) and DoD 6 (no app-update section in about:preferences, no "Check for updates" in About) were not checked; the browser was not started.
