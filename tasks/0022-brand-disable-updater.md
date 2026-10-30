---
id: 0022
title: BB builds without the app updater (no polling of Zen's update.xml)
epic: e0
prefix: e0
kind: feature
role: developer-hard
size: S
status: ready
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
reviewed_sha:
qa_sha:
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

## Review

## QA
