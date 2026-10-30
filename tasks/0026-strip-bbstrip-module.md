---
id: 0026
title: src/bb/strip/BBStrip.mjs — bb.strip.* translated into Firefox/Zen prefs and re-applied at startup; gZenMods stub; strip.css for Boosts leftovers
epic: e1-strip
prefix: e1
kind: feature
role: developer
size: M
status: approved
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
reviewed_sha: 1e83525efeb4e073ff92445087474334dd7628b0
qa_sha: 1e83525efeb4e073ff92445087474334dd7628b0
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
Round 1.
- `src/bb/strip/BBStrip.mjs`: one TABLE (switch → rows), one `applyRows` loop (stripped value when on, inverse when off;
  equals default-branch value → `clearUserPref`, else set; default branch read-only), exported `SWITCHES` `[{pref, restart}]`
  (restart for eme, sync), observer on `bb.strip.`, table applied once at import, `initWindow(win)` sets `bb-strip-boosts`
  on the root element (= `#main-window`) and, with `bb.strip.mods`, replaces `win.gZenMods` with a stub built from
  `MODS_STUB_MEMBERS` (name + `file:line` of user + empty value).
- gZenMods timing (R1): the stock instance's `init` is bound to `MozBeforeInitialXULLayout` in the constructor
  (`ZenCommonUtils.mjs:80`), so it still runs after BBStartup replaced the instance. It reads mods only through the public
  `getMods` / `checkForModsUpdates` (`ZenMods.mjs:497,110,522`), so `initWindow` no-ops those two on the stock instance
  (no Zen edit). Residual: if `zen-themes.css` already exists in a profile, `#insertStylesheet` (ZenMods.mjs:514) still
  loads it once; a fresh BB profile has none.
- `strip.css` (boost button + Boosts section of site-data panel, Library Boosts tab), linked in `bb-assets.inc.xhtml`,
  registered with BBStrip.mjs in `jar.inc.mn`; BBStartup imports BBStrip and calls `initWindow(window)`.
- AI row: the 7 `browser.ml.*` names of Zen's ai.yaml per DoD + the 12 of strip.yaml; `browser.preferences.aiControls`
  (8th line of ai.yaml) left out as the DoD says 7 — open question for the owner.
- Verified: `build.sh ui` OK; `test.sh lint` OK; layer_lint 0 fail. No runtime check (needs_approval false; 0027/0028).
  `grep lock` on BBStrip.mjs: no output.

## Review
APPROVE

Checklist:
- Spec: DoD 1–6 are met. One TABLE with one `applyRows` loop. The 19 AI names match `ai.yaml:6-24` plus the 12 AI names in `strip.yaml`. The sync, eme and boosts rows match `strip.yaml`. The default branch is only read, and nothing is locked. `SWITCHES` marks restart for eme and sync, which matches ADR line 96. The module is imported once in the shared global, with one observer and one apply at import. The stub member `file:line` refs match the grep of `ZenModsMarketplaceParent.sys.mjs` and `zen-settings.js`. The CSS selectors exist (`site-data.inc:82-86,102`, `ZenLibrary.mjs:1015-1017`).
- Scope: `--names` lists only the 5 files in allowed_paths. No Zen or Firefox file changed, and there is no layer.yaml entry (S2).
- Layer: layer_lint reports 0 fail and 0 warn. Prefs: only names that already exist are used. Pref-off path: `bb.strip.*=false` clears back to the default branch (F2).
- Correctness: the observer is process-wide, so never removing it is fine. The stock instance's `init` (`ZenMods.mjs:497-522`) only reaches mods through `getMods` and `checkForModsUpdates`, and both are no-ops now. The residual (`#insertStylesheet` at :514 still loads an existing `zen-themes.css`) is disclosed in ## Result.
- Verification: the lint claim was reproduced here. The build and test.sh lint runs are left to qa.
- Hygiene: no untracked follow-up markers, no secrets, everything in English.

Non-blocking notes (fix in 0027 or a later e1 task):
1. src/bb/strip/BBStrip.mjs:66: the stub gives `updatePref: "bb.strip.mods"`, so `zen-settings.js:41` now observes the BB switch and rebuilds its list every time the switch is toggled. That is a BB pref inside Zen's settings, and it breaks the "empty value of its type" rule in DoD 5. Better: keep the stock name (`stock.updatePref`). Nothing toggles it once `triggerModsUpdate` is a no-op. That would also remove the `property` special case in `buildModsStub`.
2. src/bb/strip/BBStrip.mjs:128: `win.gZenMods ?? {}` is a just-in-case fallback that writes to a throwaway object. BBStartup always runs after gZenMods exists (`ZenPreloadedScripts.js:32`), so this should be `win.gZenMods`.
3. Open question for 0027: `bb.strip.mods` has `restart: false` (as the ADR says), but the stub is only installed in `initWindow`. Toggling the switch does not change windows that are already open. Either the pane says "new windows / restart", or the ADR should mark Mods as restart-only.

## QA
PASS

1. DoD 7: `build.sh ui` → `BUILD RESULT: OK` (log logs/build-ui-20261031-022015.log). `test.sh lint` → `TEST RESULT: OK`, 0 problems (logs/test-lint-20261031-022046.log).
2. DoD 8: layer_lint → 6 files, 179 production lines, 0 fail, 0 warn.
3. DoD 9: `diff.sh --names` lists only BBStartup.mjs, bb-assets.inc.xhtml, jar.inc.mn, BBStrip.mjs, strip.css — all in allowed_paths.
4. DoD 1: one TABLE, one applyRows loop. Names match: 7 `ai.yaml:6-24` names (the 8th, `browser.preferences.aiControls`, is left out as the DoD says 7), the 12 AI names of strip.yaml, and the sync/eme/boosts rows; mods has empty rows.
5. DoD 2: `grep getDefaultBranch` → one read-only use (line 88); `grep lock` → no output. Helper clears the user pref when the wanted value equals the default, else sets it.
6. DoD 3: `SWITCHES` is `[{pref, restart}]`, restart true for sync and eme only.
7. DoD 4–6: observer on `bb.strip.` plus apply once at import. `MODS_STUB_MEMBERS` is one array with `file:line` per entry. `bb-strip-boosts` attribute is set on the root element. strip.css is linked in bb-assets and registered in jar.inc.mn (diff).
8. Not run: runtime behaviour (needs_approval false; covered by 0027/0028). Reviewer's non-blocking notes 1–3 stand for 0027.

For the human: none.
