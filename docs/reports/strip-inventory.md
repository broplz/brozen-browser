# Strip inventory (task 0024) — ADR-0003 Решение 3, step 0

Read-only inventory, base Zen 1.23.4b / Firefox 158. Q1–Q9 answered from the source, followed by
the ADR-0003 claim table, proposed task changes, and the "Not found" and "Still open" lists.
`yaml:N` = `prefs/<dir>/<file>.yaml:N`; `ff.js` = `engine/browser/app/profile/firefox.js`.

## Q1 Mods
**Answer.** Zen has no pref that turns Mods off. `zen.mods.*` only tune updates. Mods is loaded by one
line in the script array; the window instance is `window.gZenMods`.
**Evidence.**
- `prefs/zen/mods.yaml:5,8,11` — `zen.mods.updated-value-observer`, `zen.mods.auto-update-days`, `zen.mods.auto-update` (no `zen.mods.enabled`).
- `src/zen/common/ZenPreloadedScripts.js:21` — `"chrome://browser/content/zen-components/ZenMods.mjs",` inside `let scripts = [...]` (l.15-33); BBStartup is last at l.32.
- `src/zen/mods/ZenMods.mjs:769` — `window.gZenMods = new nsZenMods();`
- `src/zen/moz.build:18` (`"mods"` in DIRS), `src/browser/base/content/zen-assets.jar.inc.mn:9` (`#include ../../../zen/mods/jar.inc.mn`).
- Users of the instance: `src/zen/mods/actors/ZenModsMarketplaceParent.sys.mjs:11`, `src/browser/components/preferences/zen-settings.js:31-32,41,156-172` (Marketplace pane).
- Mods entry in about:preferences: `category-zen-marketplace` / `paneZenMarketplace` in `src/browser/components/preferences/preferences-xhtml.patch:33-37`, content `zenMarketplace.inc.xhtml` (pref `zen.mods.auto-update`, l.28).
**Consequence.** L3. Two options: (a) delete line 21 behind `bb.strip.mods` — but it is a flat array entry, so a
hook needs a filter such as `scripts = scripts.filter(...)` (~4 lines, class 2, `src/zen/common/ZenPreloadedScripts.js`);
(b) fallback R2: BBStartup replaces `window.gZenMods` (the file is imported with `{global:"current"}`, so BBStartup,
loaded last, can override the instance). The pane (`category-zen-marketplace`) is in a Zen *patch*, so hiding it
is CSS in `src/bb/strip/strip.css` (`#category-zen-marketplace {display:none}`), not a patch edit. Hook ≈ 4-6 lines.

## Q2 Boosts
**Answer.** A pref exists: `zen.boosts.enabled` (default true). Zen itself checks it in some places only.
**Evidence.**
- `prefs/zen/boosts.yaml:5` — `zen.boosts.enabled` = true.
- Read by: `src/zen/common/sys/ZenActorsManager.sys.mjs:92` (`enablePreference: "zen.boosts.enabled"` — actor registration), `src/zen/urlbar/ZenUBGlobalActions.sys.mjs:155` (global action), `src/browser/themes/shared/zen-icons/icons.css:960` (`@media -moz-pref("zen.boosts.enabled", false)`).
- Not gated by it: `ZenSiteDataPanel.sys.mjs` (calls `gZenBoostsManager` at 138,246,773…) and `ZenLibraryBoostsSection.mjs` (l.68…). Boosts are not in `ZenPreloadedScripts.js` (no match); loaded via `src/zen/moz.build:10` and `zen-assets.jar.inc.mn:21`.
**Consequence.** L2 for the main switch: `bb.strip.boosts` ⇄ `zen.boosts.enabled` (translation in BBStrip.mjs). Still open (runtime check, 0027):
whether the urlbar site-data panel boost button and the Library section hide at `false` — likely need CSS in `strip.css`
(L3, class 1 CSS, no Zen edit). No `.patch` needed.

## Q3 Zen Sync
**Answer.** `src/zen/sync/` is Sync *engines* (`ZenSpacesSync*.sys.mjs`: sync / applier / model) for Spaces, built on Firefox Sync;
it has no UI files of its own. It is registered as a Sync engine by a Zen patch
(`src/services/sync/modules/service-sys-mjs.patch:9-12`: `result.Spaces = {module: "resource:///modules/zen/ZenSpacesSync.sys.mjs", symbol: "ZenSpacesSyncEngine"}`
in `getEngineModules()`), and the engine class extends Firefox's `SyncEngine` (`ZenSpacesSync.sys.mjs:123`). Like every Sync engine it runs
only when Sync is signed in to FxA. UI references: `zenTabsManagement.inc.xhtml` and `account-sync-mjs.patch` mention the spaces engine.
**Evidence.**
- `ls src/zen/sync`: `moz.build ZenSpacesSync.sys.mjs ZenSpacesSyncApplier.sys.mjs ZenSpacesSyncModel.sys.mjs`.
- `grep -rl "ZenSpacesSync\|spaces-sync" src/zen` → only the four files in `sync/`.
- `prefs/zen/sync.yaml:5` `services.sync.engine.spaces` (value `@cond`, `@IS_TWILIGHT@`); sync.yaml also holds ~25 `services.sync.prefs.sync.zen.*` entries.
- `identity.fxaccounts.enabled` = true: `ff.js:2481`; no Zen prefs/ file sets it (the Q-grep over all four prefs dirs has no `fxaccounts` hit).
- Zen patches touch the Sync UI: `src/browser/components/preferences/config/account-sync-mjs.patch`, `dialogs/syncChooseWhatToSync-xhtml.patch`.
**Consequence.** L2 only: `bb.strip.sync` ⇄ `identity.fxaccounts.enabled` (ff.js:2481). Without an FxA account the engine
has nothing to sync; no L3 hook is expected. Proposed smoke point: with the pref false, no Sync pane and no `spaces` engine activity.

## Q4 AI
**Answer.** Refuted: Zen *does* set AI defaults, in `prefs/firefox/ai.yaml`. There is no build flag for ML in the
`moz.configure` files I checked; only ONNX Runtime (`engine/toolkit/moz.configure:4520-4544`, `--with-onnx-runtime`, a location option, not a switch).
**Evidence — Zen sets** (all `value: false`, not locked): `prefs/firefox/ai.yaml:6` `browser.ml.chat.enabled`, `:9` `…chat.shortcuts`,
`:12` `…chat.shortcuts.custom`, `:15` `…chat.sidebar`, `:18` `browser.ml.enable`, `:21` `…chat.menu`, `:24` `browser.ml.linkPreview.enabled`;
plus `browser.preferences.aiControls` (last entry of the same file). No Zen yaml sets `extensions.ml.*`, `browser.tabs.groups.smart.*`, `browser.search.visualSearch.*`.
**ADR 2.2 names (17) vs Firefox 158 defaults:**
| status | names (ff.js line) |
|---|---|
| exist in ff.js | `browser.ml.chat.enabled` 2338 · `chat.menu` 2341 · `chat.page` 2342 · `chat.page.footerBadge` 2343 · `chat.page.menuBadge` 2344 · `chat.shortcuts` 2351 · `chat.shortcuts.custom` 2352 · `chat.sidebar` 2357 · `linkPreview.enabled` 2362 · `pageAssist.enabled` 2375 (default false) · `browser.tabs.groups.smart.enabled` 1190 · `…smart.userEnabled` 1219 · `browser.search.visualSearch.featureGate` 1015 |
| exists elsewhere | `extensions.ml.enabled` = true at `engine/modules/libpref/init/all.js:1784` |
| Zen-only | `browser.ml.enable` (defined by Zen, ai.yaml:18; no Firefox default) |
| not found (Not found list) | `browser.ml.chat.hideFromLabs`, `browser.ml.chat.hideLabsShortcuts` (grep of `modules/libpref/init`, `browser/app/profile`, `browser/components/genai`, `toolkit/components/ml`: no hit) |
Only `browser.ml.chat.hideLocalhost` (2339) is a near-match. New in 158 and not in the ADR: `browser.ml.chat.shortcuts.smartwindow` (2353), `browser.tabs.groups.smart.optin` (1205), `…searchTopicEnabled` (1217), `browser.ml.linkPreview.optin` (2367).
**Consequence.** L2. Do not propose the two "not found" names (DoD 2) until located in a further read (StaticPrefList / toolkit JS); 0025 should
use the 13 ff.js names + `extensions.ml.enabled` (all.js:1784) + `browser.ml.enable` (defined by Zen) and cover Zen's existing lines by editing them in place
(see Q8). `strip-check` should diff `browser.ml.*` of ff.js (≈ 38 names at l.805-806, 2338-2375).

## Q5 Telemetry
**Answer.** Zen already sets most of ADR 2.1 in `prefs/privatefox/privacy.yaml`, mostly `locked: true`. Not set by Zen:
`browser.discovery.enabled` (ff.js:3082, default true) and `dom.private-attribution.submission.enabled` (not found in ff.js).
**Evidence (privacy.yaml:line, value).** `datareporting.policy.dataSubmissionEnabled` :6 false locked · `datareporting.healthreport.uploadEnabled` :10 false locked ·
`toolkit.telemetry.unified` :14 · `.enabled` :18 · `.server` :22 `"data:,"` · `.archive.enabled` :26 · `.newProfilePing.enabled` :30 · `.shutdownPingSender.enabled` :34 ·
`.updatePing.enabled` :38 · `.bhrPing.enabled` :42 · `.firstShutdownPing.enabled` :46 (all false, locked) · `browser.ping-centre.telemetry` :74 false (unlocked) ·
`app.shield.optoutstudies.enabled` :83 false locked · `app.normandy.enabled` :87 false (unlocked) · `app.normandy.api_url` :90 `""` locked.
**Consequence.** The ADR's L2 telemetry block is mostly redundant — Zen has done it. 0025 should add only a strip-check that reads these and
drop `strip.yaml` entries for them; `browser.discovery.enabled=false` is the only candidate addition (source of the `true` default: ff.js:3082).
Note: the 13th ADR item `dom.private-attribution.submission.enabled` is **Not found** and not proposed.

## Q6 EME
**Answer.** Zen sets exactly one of the four: `media.eme.enabled` = true. The other three come from Firefox.
**Evidence.** `prefs/zen/media.yaml:5` (`media.eme.enabled`, value true); `StaticPrefList.yaml:12505` (`media.eme.enabled`);
`ff.js:240,242` `browser.eme.ui.enabled` (true under `#if defined(MOZ_WIDEVINE_EME)` l.239, false in `#else` l.241);
`ff.js:2547,2548` `media.gmp-widevinecdm.visible` / `.enabled` = true, inside `#ifdef MOZ_WIDEVINE_EME` (l.2545) — they are not defined at all without `--enable-eme`; `configs/macos/mozconfig:8` `ac_add_options --enable-eme=widevine`;
objdir `config.status:477` `'MOZ_EME_MODULES': ['widevine']`.
**Consequence.** L2, but the Zen line `media.eme.enabled=true` must be *edited* (it is Zen's own, Q8), not overridden; the other three are not in `prefs/`.

## Q7 Settings pane
**Answer.** Zen adds its categories by **patches** on Firefox files plus flat files in `src/browser/components/preferences/`.
**Evidence.**
- `preferences-xhtml.patch:9` `#include zen-preferences-links.xhtml`; `:18-37` four `moz-page-nav-button` (`category-zen-looks`, `-tabs-management`, `-CKS`, `-marketplace`) placed before `category-sync`; `:45-48` four `#include zen*.inc.xhtml`.
- `preferences-js.patch:35-38` — `register_module("paneZenLooks", …)` etc.; `:26-27` a `categoryName.startsWith("paneZen")` condition.
- `jar-mn.patch:10` registers `zen-settings.js`; flat files: `zen-settings.js`, `zen-preferences-links.xhtml`, `zen*.inc.xhtml`, `src/browser/themes/shared/preferences/zen-preferences.css`.
- Strings: `engine/browser/locales/en-US/browser/preferences/zen-preferences.ftl` (loaded by `zen-preferences-links.xhtml:5`).
**Consequence.** A "BROzen" category must hook: (1) `preferences.xhtml` — nav button + pane include (Firefox file: a BB patch, class 1,
or an extra line in Zen's `preferences-xhtml.patch`, class 3, needs `allow_zen_patch`); (2) `preferences.js` — `register_module` (same two options); (3) `jar.mn` for new files (Zen `jar-mn.patch`);
(4) Fluent file of our own. A one-line `#include` hook is possible for the pane body (`#include ../../../bb/prefs/brozen.inc.xhtml` after l.48) and for the links file, but the nav button and `register_module` are separate hunks.
Cheapest: ONE BB patch `src/bb/patches/e1-strip/pref-pane/` (new hunks near but not overlapping Zen's; must pass `patches.sh check` against Zen+Firefox). Level L4, needs_approval true. Fallback (ADR 2.7 B): `about:brozen`.

## Q8 Prefs placement
Zen already defines, so ADR-0002 says *edit Zen's line*, not add to `prefs/bb/`:
| group | in ADR | defined by Zen in prefs/ | Firefox default only |
|---|---|---|---|
| telemetry/datareporting (2.1) | 13 | 11 (privatefox/privacy.yaml) | 2 (`browser.discovery.enabled`; attribution one not found) |
| AI (2.2) | 17 | 6 (ai.yaml: chat.enabled, shortcuts, shortcuts.custom, sidebar, menu, linkPreview.enabled) + `browser.ml.enable` (Zen-only) = 7 | 7 in ff.js + 1 (`extensions.ml.enabled`, all.js:1784) = 8; 2 not found (`hideFromLabs`, `hideLabsShortcuts`) |
| FxA (2.3) | 1 | 0 | 1 (`ff.js:2481`) |
| EME (2.4) | 4 | 1 (`media.eme.enabled`) | 3 |
**Consequence.** `layer_lint.py:127-130` rejects Firefox names in `prefs/bb/`, so the ADR's `prefs/bb/strip.yaml` cannot carry them. Proposed: BB
prefs hold only `bb.strip.*` (defaults); `BBStrip.mjs` (a `src/bb` module, per ADR 2.7) writes the translated values as user prefs at startup; this works for
Zen-defined and Firefox-only names alike and needs no Zen edit. Editing Zen's `media.yaml`/`ai.yaml` lines (class 2, `layer.yaml: edits`) is the alternative. Teamlead decision needed.

## Q9 Build-check inputs
**Answer.** strip-check should read `engine/obj-aarch64-apple-darwin/config.status` (Python dict of substs, one `'KEY': 'value'` per line).
**Evidence.** `config.status:96-97,119` (and again `:455,460,574`): `'MOZ_CRASHREPORTER': '1'`, `'MOZ_DATA_REPORTING': '1'`, `'MOZ_SERVICES_HEALTHREPORT': '1'`; `MOZ_TELEMETRY_REPORTING` has no match
(i.e. absent); `mozinfo.json` has none of the four. `config.statusd/defines/ALLDEFINES:96,132` also has `"MOZ_SERVICES_HEALTHREPORT": "1"`, `"MOZ_DATA_REPORTING": "1"` (JSON-style, `"KEY": "value"`); `MOZ_TELEMETRY_REPORTING` is absent there too. `config.statusd/substs/` has per-key files only for some keys (grep hits only `ACDEFINES`, `config.track`).
Generated prefs file `engine/browser/app/profile/zen.js`: plain Firefox pref syntax, one `pref("name", value[, locked]);` per line, with preprocessor `#if defined(...)` blocks kept and a blank line between prefs, sorted by name (head: `pref("app.normandy.api_url", "", locked);`, `pref("app.shield.optoutstudies.enabled", false, locked);`; it also carries `pref("bb.layer.version", 1);`). strip-check can parse it with one regex; `#if` blocks must be skipped or evaluated.
Also: `ff.js:3045-3049` `app.shield.optoutstudies.enabled` is true under `#ifdef MOZ_DATA_REPORTING`, so the build flag decides the default.
**Consequence.** Surprise: the existing objdir has `MOZ_DATA_REPORTING=1` and `MOZ_SERVICES_HEALTHREPORT=1` although `configs/common/mozconfig:95-100` empties them (`mk_add_options`, `ac_add_options`);
the objdir may predate it or the `ac_add_options X=` form does not unset substs. strip-check on current output would FAIL for those — verify on a fresh build before committing the check. Crashreporter is `1` as expected in dev (`mozconfig:90` only in release).

## ADR-0003 claims
| ADR line | claim | verdict |
|---|---|---|
| 26 | how Mods is loaded (pref / PreloadedScripts / manifest) | **confirmed**: `ZenPreloadedScripts.js:21`, no off-pref (Q1) |
| 27 | what Zen Sync does | **confirmed**: Spaces sync engine on Firefox Sync, registered by `service-sys-mjs.patch:9-12` (Q3) |
| 28 | Zen leaves `browser.ml.*` defaults alone | **refuted**: `prefs/firefox/ai.yaml:6-24` (Q4) |
| 70 | no ML build flag in moz.configure | **confirmed** for `browser/` and `toolkit/` moz.configure (ONNX location option only); other dirs not scanned |
| 82 | Zen Sync dead under FxA off / needs hook | **confirmed by reading, not by running**: engine is a plain `SyncEngine`, no FxA-independent path found; no hook expected. Runtime check belongs to the 0026 smoke test (Q3) |
| 94 | `zen.mods.enabled` pref exists | **refuted** (Q1) |
| 110 | how Zen adds settings pages | **confirmed**: patches + flat files (Q7) |

## Proposed task changes
- **0025 (prefs, L2):** change to `bb.strip.*` defaults in `prefs/bb/strip.yaml` + BBStrip.mjs translation (Q8); telemetry block reduced to a check; allowed_paths `prefs/bb/strip.yaml`, `src/bb/strip/**`, `src/bb/layer.yaml`. needs_approval false.
- **0026 (EME/AI/Sync toggles):** L2, same paths; if Zen's `media.yaml:5`/`ai.yaml` lines are edited: add `prefs/zen/media.yaml`, `prefs/firefox/ai.yaml` + layer.yaml `edits` entries. needs_approval false.
- **0027 (Mods/Boosts):** Mods L3 hook in `src/zen/common/ZenPreloadedScripts.js` (≈5 lines, marker `// BB(e1)`) + `src/bb/strip/strip.css`; Boosts L2 (`zen.boosts.enabled`) + CSS. allowed_paths add the Zen script file. needs_approval false.
- **0028 (BROzen pane):** one BB patch `src/bb/patches/e1-strip/pref-pane/` + README + `src/bb/strip/` pane files + ftl. L4, **needs_approval true**, `rebuild: ui` if no C++ (Zen's pane is JS/XHTML only).

## Not found (not proposed)
`browser.ml.chat.hideFromLabs`, `browser.ml.chat.hideLabsShortcuts`, `dom.private-attribution.submission.enabled`, `MOZ_TELEMETRY_REPORTING` (as a subst/define). (`browser.ml.enable` is defined by Zen at `ai.yaml:18`; it has no Firefox default.)

## Still open
Whether the urlbar site-data panel and Library Boost UI hide at `zen.boosts.enabled=false` (Q2): needs a runtime check in 0027. Remaining ML moz.configure dirs beyond `browser/` and `toolkit/` (claim 70).
