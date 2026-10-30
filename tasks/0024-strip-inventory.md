---
id: 0024
title: Strip inventory report — every ADR-0003 "[не нашёл подтверждения]" answered from the source
epic: e1-strip
prefix: e1
kind: docs
role: developer
size: S
status: ready
base: feat/layer
branch: task/0024-strip-inventory
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - docs/reports/strip-inventory.md
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#решение-3--проверка
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0003 Решение 3 step 0: before any strip work, read the Zen/Firefox sources and answer every claim the ADR
tags **[не нашёл подтверждения]**, so that 0025–0028 can be specified with real pref names, files and
mechanisms (L2 / L3 / patch). Read-only: no build, no code change. The result is one report,
`docs/reports/strip-inventory.md`.

## Definition of Done
1. `docs/reports/strip-inventory.md` exists and has one section per question Q1–Q9 below, each with:
   **Answer** (one or two sentences), **Evidence** (`file:line` or the exact command and its trimmed output),
   **Consequence** (the ADR-0003 level L2 / L3 / L4 and the files a later task will touch).
2. Every pref name the report proposes for 0025/0026 is quoted with the `file:line` where it is defined
   (Zen `prefs/**/*.yaml` or `engine/browser/app/profile/firefox.js` / `engine/modules/libpref/init/StaticPrefList.yaml`).
   A name with no definition found is listed under "Not found" and is not proposed.
3. The report ends with a table "ADR-0003 claim → confirmed | refuted | still open", one row per
   `[не нашёл подтверждения]` in the ADR (lines 26, 27, 28, 70, 82, 94, 110 of the ADR at this commit),
   plus a section "Proposed task changes" for 0025–0028 (allowed_paths, level, needs_approval).
4. `scripts/agents/diff.sh tasks/0024-strip-inventory.md --names` lists only `docs/reports/strip-inventory.md`
   and this task file.

## Notes from teamlead
Questions (each one a report section):
- **Q1 Mods** (ADR 2.5, R2): is there a Zen pref that turns Mods off (any `zen.mods.*`)? How does `src/zen/mods/` get
  loaded — a line in `src/zen/common/ZenPreloadedScripts.js`, `src/zen/ZenComponents.manifest`, `src/zen/moz.build`,
  a `.sys.mjs` imported elsewhere? Is there a window instance (`gZenMods…`) that BBStartup could replace? Where is
  the Mods entry in about:preferences (file:line)? Estimate the hook size in lines.
- **Q2 Boosts** (ADR 2.6): the same questions for `src/zen/boosts/`.
- **Q3 Zen Sync** (ADR 2.3, R4): what `src/zen/sync/` does — Sync engines on top of FxA, its own UI, or something
  loaded unconditionally? Does it still run or draw anything when `identity.fxaccounts.enabled=false`?
- **Q4 AI** (ADR 2.2, R3): does any Zen `prefs/**/*.yaml` set `browser.ml.*`, `extensions.ml.*`,
  `browser.tabs.groups.smart.*`, `browser.search.visualSearch.*`? Full list of `browser.ml.*` names defined in
  Firefox 158 (`firefox.js`, `StaticPrefList.yaml`), and which of the 17 names in ADR 2.2 exist / are missing /
  are new. Is there a build flag for ML in `moz.configure` files (`grep -rn "ml" --include=moz.configure` limited)?
- **Q5 Telemetry** (ADR 2.1): which of the ADR 2.1 prefs Zen already sets (file:line, value) and which are only
  Firefox defaults. Same for `datareporting.*`.
- **Q6 EME** (ADR 2.4): which of `media.eme.enabled`, `media.gmp-widevinecdm.enabled`, `media.gmp-widevinecdm.visible`,
  `browser.eme.ui.enabled` are set by Zen prefs or by `--enable-eme` (where in firefox.js, under which `#if`).
- **Q7 Settings pane** (ADR 2.7, R1): how Zen adds its own about:preferences categories — flat files under `src/zen/`
  or `src/browser/components/preferences/`, or `.patch` files on `preferences.xhtml` / `preferences.js`? Name every
  file a BB category "BROzen" would have to hook, its class (2 flat / 3 patch per ADR-0002), and whether an
  `#include`-style one-line hook is possible. Where do Zen's settings strings live (Fluent files)?
- **Q8 Prefs placement** (ADR-0002 Решение 1/2 vs ADR-0003 Решение 1): for every non-`bb.*` pref the ADR wants
  changed, does Zen already define it in `prefs/zen/*.yaml` / `prefs/firefox/` / `prefs/fastfox/` /
  `prefs/privatefox/` (then the ADR-0002 rule is "edit Zen's line") or nowhere in `prefs/` (then it is a
  Firefox default only)? Report counts per group. Context: `scripts/agents/layer_lint.py:127-130` fails any
  non-`bb.*` pref in `prefs/bb/`, so the ADR's `prefs/bb/strip.yaml` with Firefox names cannot pass lint as is.
- **Q9 Build check inputs** (ADR Решение 3 strip-check): in the existing objdir, where `MOZ_TELEMETRY_REPORTING`,
  `MOZ_DATA_REPORTING`, `MOZ_SERVICES_HEALTHREPORT`, `MOZ_CRASHREPORTER` show up (`config.statusd/substs/`,
  `config.status`, `mozinfo.json`) — the exact path strip-check.sh must read; and confirm the generated
  `engine/browser/app/profile/zen.js` / `zen-static-prefs.inc` format strip-check will parse.

Starting commands (from ADR-0003 Решение 3; one command per Bash call, no chaining):
```
grep -rn "browser.ml\|fxaccounts\|telemetry\|datareporting\|eme\|widevine\|mods\|boosts" prefs/zen prefs/firefox prefs/fastfox prefs/privatefox
grep -n "mods\|boosts\|sync" src/zen/common/ZenPreloadedScripts.js src/zen/ZenComponents.manifest src/zen/moz.build
ls src/zen/mods src/zen/boosts src/zen/sync
grep -rn "zen-settings\|category-zen\|preferences.xhtml" src/zen src/browser | head -30
grep -rn "browser.ml" engine/browser/app/profile/firefox.js | head
```
- engine/ only via Grep/grep with a narrow path and head; Read with offset/limit. No build, no `test.sh`.
- Do not invent pref names: a name enters the report only with its `file:line`.
- The report is English. Keep it under ~250 lines; evidence trimmed to the relevant lines.
- Anything outside these questions goes to tasks/backlog.md "Found by agents" (one line), not into the report.

## Handoff

## Result

## Review

## QA
