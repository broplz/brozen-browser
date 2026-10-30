---
id: 0025
title: prefs/bb/strip.yaml (bb.strip.* + Firefox-only names) + crash reporter off in dev builds + scripts/bb/strip-check.sh (build, prefs, drift)
epic: e1-strip
prefix: e1
kind: script
role: developer-hard
size: M
status: ready
base: feat/layer
branch: task/0025-strip-prefs-check
depends_on: [0029]
build: full
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - prefs/bb/strip.yaml
  - configs/bb/mozconfig
  - scripts/bb/strip-check.sh
  - scripts/bb/strip-allow.txt
  - scripts/bb/smoke.sh
  - scripts/bb/tests/strip_check_test.sh
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#29-проверка
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0003 v2 Решение 1, 2.1–2.4, 2.9 and R4: the strip list becomes data plus one executable check, with zero edits
to Zen or Firefox files (S2). After this task `prefs/bb/strip.yaml` holds the five `bb.strip.*` switches and the
stripped defaults of the Firefox-only prefs (names Zen's yaml does not define — 0029 lints that),
`configs/bb/mozconfig` turns the crash reporter off in dev builds too, `scripts/bb/strip-check.sh` checks build,
prefs and drift, `smoke.sh` runs it first, and the result of a fresh full build settles R4
(`MOZ_DATA_REPORTING=1` in the objdir).

## Definition of Done
1. `prefs/bb/strip.yaml` has exactly these entries, none `locked` (S3: `grep -n "locked" prefs/bb/strip.yaml` → no
   output), grouped by `#` section comments citing the ADR section:
   - switches (2.7 table): `bb.strip.eme=true`, `bb.strip.ai=true`, `bb.strip.sync=true`, `bb.strip.mods=true`,
     `bb.strip.boosts=false` (true = stripped);
   - 2.1: `browser.discovery.enabled=false`;
   - 2.2: `browser.ml.chat.page`, `browser.ml.chat.page.footerBadge`, `browser.ml.chat.page.menuBadge`,
     `browser.ml.chat.shortcuts.smartwindow`, `browser.ml.linkPreview.optin`, `browser.ml.pageAssist.enabled`,
     `browser.tabs.groups.smart.enabled`, `browser.tabs.groups.smart.userEnabled`, `browser.tabs.groups.smart.optin`,
     `browser.tabs.groups.smart.searchTopicEnabled`, `browser.search.visualSearch.featureGate`,
     `extensions.ml.enabled` — all `false`;
   - 2.3: `identity.fxaccounts.enabled=false`;
   - 2.4: `media.gmp-widevinecdm.enabled=false`, `media.gmp-widevinecdm.visible=false`, `browser.eme.ui.enabled=false`.
   No other name. `media.eme.enabled` is not there (ADR 2.4: Zen's line stays).
2. `python3 scripts/agents/layer_lint.py tasks/0025-strip-prefs-check.md` → 0 fail (0029's exception accepts the
   Firefox-only names; a Zen-defined name would fail with «Zen задаёт этот pref: не дублировать»).
3. `grep -n -- "--disable-crashreporter" configs/bb/mozconfig` → exactly one unconditional
   `ac_add_options --disable-crashreporter` line with a `# BB(e1-strip)` comment line above it, after the
   `--disable-updater` block and before the `. …mozconfig.macos` line.
4. `scripts/agents/build.sh full` → `BUILD RESULT: OK`. The build re-runs configure (mozconfig changed):
   `engine/obj-aarch64-apple-darwin/config.status` is newer than this task's first commit.
5. R4 (ADR 2.1, 2.9): after that build `grep -n "MOZ_CRASHREPORTER\|MOZ_DATA_REPORTING\|MOZ_SERVICES_HEALTHREPORT\|MOZ_TELEMETRY_REPORTING" engine/obj-aarch64-apple-darwin/config.status`
   → no `'1'` value for any of the four. If `MOZ_DATA_REPORTING`/`MOZ_SERVICES_HEALTHREPORT` were still `1`, the fix
   is in `configs/bb/mozconfig` only (see Notes) and ## Result has a "R4" paragraph: what config.status showed
   before, which form fixed it, why (one line each).
6. Every overridden Firefox default actually wins: ## Result quotes `grep -n "#include.*zen" engine/browser/app/profile/firefox.js`
   and the ff.js line of each name from DoD 1 (report 0024 gives them); the include comes after every one of them.
7. `scripts/bb/strip-check.sh` with no args, after the build → exit 0 and exactly three lines:
   `strip-check: build OK`, `strip-check: prefs OK`, `strip-check: drift OK`.
8. `/bin/bash scripts/bb/tests/strip_check_test.sh` → exit 0; on fixture files only (no real engine) it covers:
   a `'MOZ_CRASHREPORTER': '1'` in config.status → exit 1 naming it; a name from `strip.yaml` missing or with another
   value in the fixture `zen.js` → exit 1 naming it; an unknown `browser.ml.*` in the fixture `firefox.js` → exit 1
   naming it; the same name listed in `strip-allow.txt` → exit 0; a name known only to a fixture Zen yaml → exit 0;
   all clean → exit 0.
9. `scripts/bb/smoke.sh` runs `strip-check.sh` before the checklist loop and exits 1 when it fails;
   `/bin/bash scripts/bb/tests/smoke_test.sh` → exit 0 with that test file unchanged.
10. `scripts/agents/diff.sh tasks/0025-strip-prefs-check.md --names` lists only allowed_paths.

## Notes from teamlead
- S2: no file of Zen or Firefox is touched — not `prefs/{zen,firefox,fastfox,privatefox}`, not
  `configs/{common,macos}/mozconfig`, no `.patch`, no `layer.yaml` entry. Values Zen already sets (7 `browser.ml.*`,
  telemetry in `privacy.yaml`, `media.eme.enabled`, `zen.boosts.enabled`) stay Zen's; BBStrip (0026) flips them as
  user prefs.
- Names and ff.js lines: report `docs/reports/strip-inventory.md` Q4–Q6, Q9. Check each value type against its ff.js
  line (all are booleans per the report; if one is not, stop and write it into ## Handoff instead of guessing).
- strip-check.sh parts (ADR 2.9):
  - build: `engine/obj-*/config.status`, format `'KEY': 'value'` (report Q9); `MOZ_CRASHREPORTER`,
    `MOZ_DATA_REPORTING`, `MOZ_SERVICES_HEALTHREPORT`, `MOZ_TELEMETRY_REPORTING` absent or empty. The four names are
    one array.
  - prefs: generated `engine/browser/app/profile/zen.js` (`pref("name", value[, locked]);`, `#if` blocks kept,
    report Q9) — every entry of `strip.yaml` is present with the same value. Skip lines starting with `#`.
  - drift: every `browser.ml.*`, `browser.tabs.groups.smart.*`, `identity.fxaccounts.*`, `media.gmp-widevinecdm.*`,
    `browser.eme.*` name in `engine/browser/app/profile/firefox.js` must be known to `strip.yaml`, to any
    `prefs/{zen,firefox,fastfox,privatefox}/**/*.yaml`, or to `scripts/bb/strip-allow.txt` (one name per line, `#`
    comments); unknown → exit 1 with the name. The prefixes are one array. Seed `strip-allow.txt` with the names the
    first real run reports that are not on/off switches (e.g. `browser.ml.chat.hideLocalhost`, provider URLs), each
    with a one-line `#` reason; a switch-like name goes to ## Result as an open question, not to the allow-list.
  - Paths overridable by env (`BB_ENGINE_DIR` like smoke.sh l.27, plus `BB_ROOT` for prefs/) so the test uses
    fixtures. Source `scripts/bb/lib.sh` like the other scripts; reuse its helpers. Stop at the first failing part.
- R4 fix forms, in this order, only in `configs/bb/mozconfig`, only if DoD 5 fails after the first full build:
  `mk_add_options MOZ_DATA_REPORTING=` + `MOZ_SERVICES_HEALTHREPORT=` is what Zen already does (report Q9:
  `configs/common/mozconfig:95-100`) — so first check whether the objdir simply predated Zen's lines (config.status
  older than them); otherwise `export MOZ_DATA_REPORTING=` / `export MOZ_SERVICES_HEALTHREPORT=`. ADR 2.1: no copy
  of Zen's form — only a form that works where Zen's does not. A second full build for R4 counts toward the strike.
- smoke.sh: one call before the checklist loop. `scripts/bb/tests/smoke_test.sh` may not be edited here; if the call
  cannot keep it green unchanged, stop with a Handoff (the teamlead adds a kind: test task) rather than weakening
  strip-check.
- Telemetry has no switch (S3): no `bb.strip.telemetry`.
- Role developer-hard: mozconfig change → full build (≈ 40 min); 2 failed full builds = strike.

## Handoff

## Result

## Review

## QA
