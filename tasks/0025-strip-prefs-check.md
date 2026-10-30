---
id: 0025
title: prefs/bb/strip.yaml + crash reporter off in dev builds + scripts/bb/strip-check.sh (build, prefs, drift) run first by smoke.sh
epic: e1-strip
prefix: e1
kind: script
role: developer-hard
size: M
status: blocked
base: feat/layer
branch: task/0025-strip-prefs-check
depends_on: [0024]
build: full
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - prefs/bb/strip.yaml
  - configs/bb/mozconfig
  - scripts/bb/strip-check.sh
  - scripts/bb/smoke.sh
  - scripts/bb/tests/strip_check_test.sh
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#решение-3--проверка
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason: "waits for 0024 (strip inventory) and the owner's answer on where non-bb.* prefs live (see Notes)"
---
## Goal
ADR-0003 Решение 1 (L1, L2), 2.1 and Решение 3 (S4): the strip list becomes data plus one executable check.
After this task `prefs/bb/strip.yaml` holds the `bb.strip.*` switches with the ADR defaults and the L2 prefs per
component, `configs/bb/mozconfig` turns the crash reporter off in dev builds too, and `scripts/bb/strip-check.sh`
fails on the first mismatch between the build/generated prefs and `strip.yaml`; `smoke.sh` runs it as its first step.

## Definition of Done
1. `prefs/bb/strip.yaml` defines exactly five switches with these defaults: `bb.strip.eme=true`, `bb.strip.ai=true`,
   `bb.strip.sync=true`, `bb.strip.mods=true`, `bb.strip.boosts=false` (true = the component is stripped; ADR 2.2–2.6).
   None of them is locked (S3): `grep -n "locked" prefs/bb/strip.yaml` → no output.
2. `grep -n -- "--disable-crashreporter" configs/bb/mozconfig` → exactly one `ac_add_options --disable-crashreporter`
   line, unconditional, with a `# BB(e1-strip)` comment line above it (ADR 2.1 "Крэш-репортер").
3. `scripts/agents/build.sh full` → `BUILD RESULT: OK`; afterwards `MOZ_CRASHREPORTER` is not set in the objdir
   (the exact file per report 0024 Q9).
4. `scripts/bb/strip-check.sh` with no args, after the build → exit 0 and one line per part:
   `strip-check: build OK`, `strip-check: prefs OK`, `strip-check: drift OK`.
5. `/bin/bash scripts/bb/tests/strip_check_test.sh` → exit 0; it covers, on fixture files (no real engine):
   a build define present → exit 1 naming it; a pref in the generated `zen.js` that differs from `strip.yaml` → exit 1
   naming it; an unknown `browser.ml.*` name in a fixture `firefox.js` → exit 1 naming it; all clean → exit 0.
6. `scripts/bb/smoke.sh` runs `strip-check.sh` before the checklist and exits 1 when it fails;
   `/bin/bash scripts/bb/tests/smoke_test.sh` → still exit 0, the test file unchanged.
7. `python3 scripts/agents/layer_lint.py tasks/0025-strip-prefs-check.md` → 0 fail.
8. `scripts/agents/diff.sh tasks/0025-strip-prefs-check.md --names` lists only allowed_paths.

## Notes from teamlead
Blocked until both are settled; the teamlead re-specs this file (allowed_paths, DoD 1/4/5) from the report.
- **By report 0024**: the L2 pref names and values per component (ADR 2.1 telemetry, 2.2 AI, 2.3 Sync, 2.4 EME;
  Mods/Boosts per Q1/Q2), the objdir file for the build part (Q9), and the generated-prefs format. Use only names the
  report confirms with `file:line`; the ADR lists are the starting point, not the truth.
- **Owner decision (Q8)**: ADR-0003 puts Firefox/Zen pref names (`datareporting.*`, `browser.ml.*`, `media.eme.*`, …)
  into `prefs/bb/strip.yaml`, but ADR-0002 Решение 2 п.6 says Zen defaults change by editing Zen's line in
  `prefs/zen/*.yaml`, and `scripts/agents/layer_lint.py:127-130` fails any non-`bb.*` pref in `prefs/bb/`
  (task 0022 hit the same rule). Options for the owner: (a) `strip.yaml` keeps only `bb.strip.*`; prefs Zen defines
  are edited in place in `prefs/zen/*.yaml` (`# BB(e1-strip)` + `layer.yaml: edits`), the rest are set by BBStrip.mjs
  (0026) on the default branch at startup; (b) the owner allows `prefs/bb/strip.yaml` in layer_lint and the ADR
  stays as written. allowed_paths change with the answer.
- Telemetry/data reporting get no switch (S3 exception): no `bb.strip.telemetry`.
- Crash reporter: one flag, after the `--disable-updater` block and before the `. …mozconfig.macos` line. Do not
  touch Zen's `configs/common/mozconfig` or `configs/macos/mozconfig`; do not duplicate Zen's `MOZ_*=` (ADR 2.1 B).
- strip-check.sh parts (ADR Решение 3): build — the four defines absent; prefs — generated `zen.js` /
  `zen-static-prefs.inc` against `strip.yaml` line by line, plus a duplicate-name check across `prefs/**` (R5);
  drift — every `browser.ml.*`, `identity.fxaccounts.*`, `media.eme.*`, `media.gmp-widevinecdm.*` in
  `engine/browser/app/profile/firefox.js` must be known to `strip.yaml` or one allow-list array inside
  strip-check.sh; unknown name → exit 1. Paths overridable by env (`BB_ENGINE_DIR` like smoke.sh) so the test can
  use fixtures. Source `scripts/bb/lib.sh` like the other scripts; reuse its helpers, do not copy them.
- smoke.sh: one call before the checklist loop. `scripts/bb/tests/smoke_test.sh` is an existing test and may not be
  edited in this task; if the call cannot keep it green unchanged, stop with a Handoff (the teamlead adds a
  kind: test task) rather than weakening strip-check.
- Role developer-hard: mozconfig change → full build (≈ 40 min); 2 failed full builds = strike.

## Handoff

## Result

## Review

## QA
