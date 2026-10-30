---
id: 0026
title: src/bb/strip/BBStrip.mjs — bb.strip.* translated into Firefox/Zen prefs and re-applied at startup; gZenMods stub; strip.css for Boosts leftovers
epic: e1-strip
prefix: e1
kind: feature
role: developer
size: M
status: ready
base: feat/layer
branch: task/0026-strip-bbstrip-module
depends_on: [0025]
build: ui
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/strip/BBStrip.mjs
  - src/bb/strip/strip.css
  - src/bb/BBStartup.mjs
  - src/bb/jar.inc.mn
  - src/bb/bb-assets.inc.xhtml
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#27-панель-brozen--инъекция-из-своего-кода
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0003 v2 Решение 1 (last paragraph), 2.2–2.6 and the 2.7 translation table: one module owns the contract between
the user switches `bb.strip.*` and the internal prefs, so the pane (0027) never names an internal pref. After this
task `BBStrip.mjs` applies the translation when a switch changes and once per process at startup (an update that
flips a translated pref does not survive the next BB start); with `bb.strip.mods=true` BBStartup replaces
`window.gZenMods` with a no-op stub (2.5); with `bb.strip.boosts=true` the Boosts UI Zen does not gate is hidden by
`strip.css` (2.6). No file of Zen or Firefox changes (S2).

## Definition of Done
1. `src/bb/strip/BBStrip.mjs` holds the translation as one table — switch → list of `[pref, value when stripped]` —
   and one loop applies it; no per-switch branches. Rows (ADR 2.7):
   - `bb.strip.ai`: the 7 Zen names from `prefs/firefox/ai.yaml` (report Q4) + the 12 AI names of `strip.yaml` → `false`;
   - `bb.strip.sync`: `identity.fxaccounts.enabled` → `false`;
   - `bb.strip.eme`: `media.gmp-widevinecdm.enabled`, `media.gmp-widevinecdm.visible`, `browser.eme.ui.enabled` → `false`;
   - `bb.strip.boosts`: `zen.boosts.enabled` → `false`;
   - `bb.strip.mods`: no pref (stub + CSS only).
   Every table name is a name from `prefs/bb/strip.yaml` or one the report gives with `file:line`; nothing else.
2. Apply rule (one helper): for each `[pref, stripped]` the wanted value is `stripped` when the switch is true,
   `!stripped` when false; if it equals the default-branch value → `clearUserPref`, else set the user pref. So
   `bb.strip.<x>=false` restores stock Zen/Firefox for prefs whose stock value is "on" (F2), and no default branch is
   written from JS (ADR Решение 1: defaults live in yaml). `grep -n "getDefaultBranch" src/bb/strip/BBStrip.mjs` →
   read-only uses only; `grep -n "lock" src/bb/strip/BBStrip.mjs` → no output (S3).
3. BBStrip exports the switch list for the pane — `[{pref, restart}]`, `restart: true` for `bb.strip.eme` and
   `bb.strip.sync` (ADR 2.3, 2.4, R6) — so 0027 builds its rows from it and no second list of switches exists.
4. Once per process: BBStrip is a chrome ESM imported with `ChromeUtils.importESModule` (shared global) from
   BBStartup; it registers one `Services.prefs` observer on `bb.strip.` and applies the table once at import.
   BBStartup (per window) only calls into it.
5. Mods (2.5): with `bb.strip.mods=true` BBStartup replaces `window.gZenMods` with a stub object that has every method
   and property that `src/zen/mods/actors/ZenModsMarketplaceParent.sys.mjs` and
   `src/browser/components/preferences/zen-settings.js` use (report Q1 lines), each a no-op returning the empty value
   of its type. The stub's member list is one array in BBStrip/BBStartup, each entry with the `file:line` of its user.
6. Boosts (2.6): BBStrip sets/removes attribute `bb-strip-boosts` on `#main-window` per `bb.strip.boosts`;
   `src/bb/strip/strip.css` hides, under `#main-window[bb-strip-boosts]`, the site-data panel boost button and the
   Library Boosts section (report Q2: `ZenSiteDataPanel.sys.mjs`, `ZenLibraryBoostsSection.mjs` — selectors by Grep);
   `strip.css` is linked from `src/bb/bb-assets.inc.xhtml` and registered in `src/bb/jar.inc.mn`.
7. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`; `scripts/agents/test.sh lint` → OK.
8. `python3 scripts/agents/layer_lint.py tasks/0026-strip-bbstrip-module.md` → 0 fail.
9. `scripts/agents/diff.sh tasks/0026-strip-bbstrip-module.md --names` lists only allowed_paths.

## Notes from teamlead
- S2: no Zen/Firefox file, no `layer.yaml` entry. The hook lines from 0013 (`ZenPreloadedScripts.js` → BBStartup,
  `zen-assets.inc.xhtml` → bb-assets) already give everything this task needs.
- gZenMods timing (R1): BBStartup loads last in the same window (`ZenPreloadedScripts.js:32`, ZenMods with
  `{global:"current"}`, report Q1). Before writing the stub read `nsZenMods`'s constructor/init in
  `src/zen/mods/ZenMods.mjs`: if it already applies mod styles or starts work before BBStartup runs, the stub must also
  undo that through the instance's own API. If that is impossible without editing Zen, stop: ## Handoff with the
  `file:line` evidence, status blocked — the ADR fallback (filter hook in `ZenPreloadedScripts.js`) needs the owner's
  approval and a separate task.
- Marketplace category in about:preferences (`#category-zen-marketplace`, ADR 2.5): `strip.css` is loaded into
  browser.xhtml, not into about:preferences, so that rule belongs to the pane stylesheet 0027 injects — not here.
- Boosts default is "not stripped" (`bb.strip.boosts=false`): with that default the table leaves `zen.boosts.enabled`
  without a user value — stock Zen.
- Restart-only prefs: BBStrip sets all three EME prefs together and `identity.fxaccounts.enabled` immediately;
  telling the user to restart is 0027's job.
- No runtime check here (needs_approval false): the human checks of BBStrip behaviour run in 0027 and in the e1 smoke
  (0028).

## Handoff

## Result

## Review

## QA
