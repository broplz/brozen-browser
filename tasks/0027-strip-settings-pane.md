---
id: 0027
title: about:preferences category "BROzen" injected by a BB actor (variant A; about:brozen as fallback B) with five switches bound to bb.strip.*
epic: e1-strip
prefix: e1
kind: feature
role: developer
size: M
status: approved
base: feat/layer
branch: task/0027-strip-settings-pane
depends_on: [0026]
build: ui
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/strip/**
  - src/bb/BBComponents.manifest
  - src/bb/BBStartup.mjs
  - src/bb/jar.inc.mn
  - src/bb/moz.build
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#27-панель-brozen--инъекция-из-своего-кода
returns: 1
sessions: 0
reviewed_sha: 1bc55a495afe252cb0f5398bbfddab05f6d09551
qa_sha: 1bc55a495afe252cb0f5398bbfddab05f6d09551
blocked_reason:
---
## Goal
ADR-0003 v2 S6 and 2.7, variant A: all strip switches in one place without touching Zen or Firefox files. After this
task a BB window actor (registered from `src/bb/`) catches the load of `about:preferences` and injects a
`moz-page-nav-button` "BROzen" and its pane: five switches (EME, AI, Sync, Mods, Boosts) bound to `bb.strip.*`, a
one-line explanation each, a "restart required" note on EME and Sync, and one "Restart" button. The same injection
hides `#category-zen-marketplace` while `bb.strip.mods=true` (ADR 2.5). If variant A cannot find its mount point
(R2), fallback B: the same pane as a page `about:brozen`.

## Definition of Done
1. `scripts/agents/diff.sh tasks/0027-strip-settings-pane.md --names` lists only allowed_paths — no Zen or Firefox
   file, no `.patch`, no `layer.yaml` entry (S2; variants C and D are rejected).
2. The actor is registered once per process from BB code (`BBComponents.manifest` and/or BBStrip/BBStartup) with
   `matches` limited to `about:preferences*`/`about:settings*`; its files live under `src/bb/strip/`
   (`brozen-pane.*`, actor `*.sys.mjs`) and are packaged by `src/bb/jar.inc.mn` / `src/bb/moz.build`.
3. The pane builds its rows from BBStrip's exported switch list (0026 DoD 3); the only prefs it reads or writes are
   the five `bb.strip.*` — `grep -rnE "media\.|browser\.ml|identity\.|zen\.|extensions\." src/bb/strip/brozen-pane.*`
   → no output.
4. EME and Sync rows show the restart note (from the list's `restart` flag); one "Restart" button restarts the browser
   the standard way (`Services.startup.quit` with restart flags after the `quit-application-requested` check).
5. Strings come from a Fluent file under `src/bb/strip/` (en-US; ru if the l10n setup of ADR-0002 "Кэш" carries it),
   loaded by the injected markup; no hard-coded UI text in JS/markup.
6. Marketplace: the injected stylesheet hides `#category-zen-marketplace` under an attribute the actor sets from
   `bb.strip.mods`; with `bb.strip.mods=false` the category is back (F2).
7. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`; `scripts/agents/test.sh lint` → OK.
8. `python3 scripts/agents/layer_lint.py tasks/0027-strip-settings-pane.md` → 0 fail.
9. [human] Fresh profile: about:preferences shows the "BROzen" category with five switches; the Zen Marketplace
   category is absent; toggling Mods off shows it again.
10. [human] Toggle AI off → about:config shows `bb.strip.ai=false` and every `browser.ml.*` of the 0026 table back at
    its Firefox default without restart; toggle on → back to `false`.
11. [human] Toggle EME → the restart note is visible; "Restart" restarts; after restart
    `media.gmp-widevinecdm.enabled`, `.visible`, `browser.eme.ui.enabled` are `true`.
12. [human] Browser Console: no `BBStrip`, `gZenMods`, `ZenMods`, `Marketplace` errors in the first 30 s, nor when
    opening about:preferences (ADR R1 — the 0026 stub).

## Notes from teamlead
- Variant A (ADR 2.7, recommended): a JSWindowActor child on `DOMContentLoaded` of about:preferences (parent process,
  privileged) adds the nav button next to Zen's (`moz-page-nav-button` ids per report Q7:
  `category-zen-looks` … `category-zen-marketplace`, before `category-sync`) and the pane body; the category must
  survive Firefox's `gotoPref`/hash navigation (`#brozen`). Zen's own categories are registered by `register_module`
  in a Zen patch (report Q7) — we cannot call that hunk; read how `preferences.js` routes categories and hook from
  our side (e.g. a listener on the nav, or `register_module` if it is reachable on the window) — no edit to their
  files.
- Fallback B (R2): only if A has no stable mount point. Record the evidence (`file:line` of what is missing) in
  ## Result, then build `about:brozen` from the same pane files (an `nsIAboutModule` registered from `src/bb/`).
  Both stay inside allowed_paths; anything outside → ## Handoff, status blocked.
- How Zen registers actors for reference: `src/zen/common/sys/ZenActorsManager.sys.mjs` (`ActorManagerParent`
  tables). Ours is separate; do not add to Zen's tables.
- Icon: reuse an existing Firefox/Zen category icon; a BB icon is E0 work.
- No `lockPref`, no policies (S3).
- Write what you learn about injecting into about:preferences into `docs/notes/` (scope-free) — rebases will need it
  (the ADR's main cost of variant A is DOM drift).

## Handoff

## Result
Round 2 (review items 1-2):
- `BBStrip.mjs` registers `DOMContentLoaded: { capture: true }`, so the actor runs before the page's `init_all`;
  the child comment and docs/notes/about-preferences-injection.md now match. Ordering is no longer an open
  assumption in code; [human] DoD 9 still checks the `#brozen` deep link at runtime. Not rebuilt (one-line change).

Round 1 (variant A, no fallback needed):
- `BBStrip.mjs` registers once per process the `BBStripPane` window actor (`matches` about:preferences*/about:settings*)
  and an `L10nFileSource` over `chrome://browser/content/bb/strip/l10n/{locale}/` (en-US, ru).
- Child (`BBStripPaneChild.sys.mjs`, DOMContentLoaded) calls `injectPane` from `brozen-pane.mjs`: adds the stylesheet,
  a `moz-page-nav-button#category-brozen` (view `paneBrozen`, before `#category-sync`), the pane in `#mainPrefPane`, and
  `win.register_module("paneBrozen", …)`. Mount point evidence: `preferences.js` `register_module` (function decl,
  global), `gotoPref` lookup by `view`, `search()` by `data-category` — see docs/notes/about-preferences-injection.md.
- Parent (`BBStripPaneParent.sys.mjs`) serves the SWITCHES state, sets only known `bb.strip.*` prefs, restarts via
  `quit-application-requested` + `Services.startup.quit(eAttemptQuit|eRestart)`.
- Marketplace hidden by `:root[bb-strip-mods] #category-zen-marketplace` in `brozen-pane.css`.
- Verified: `build.sh ui` OK, `test.sh lint` OK (layer_lint 0 fail), DoD 3 grep empty.
- Not run: [human] items 9-12 (no UI session). Ordering assumption (actor's DOMContentLoaded runs before the page's
  `init_all`) is untested at runtime — if `#brozen` deep-link falls back to Sync, that is where to look.
- Open question: DoD 10 says "toggle on → back to `false`"; I read the switch as the `bb.strip.*` value itself
  (on = stripped = true, matching BBStrip.mjs), so labels are "Remove X".

## Review
APPROVE
1. Round-1 item 1 fixed: src/bb/strip/BBStrip.mjs:166 now registers `DOMContentLoaded: { capture: true }`.
2. Round-1 item 2 fixed: BBStripPaneChild.sys.mjs:6-7, docs/notes/about-preferences-injection.md:9-11 and ## Result
   agree with the registration; the deep link stays a [human] check under DoD 9.

Checklist: (1) spec — unchanged from round 1 apart from the fix; matches DoD 2-6. (2) scope — src/bb/strip/** +
jar.inc.mn + docs/notes/ (sanctioned by the teamlead notes). (3) layer — layer_lint 12 files, 0 fail, 0 warn; DoD 3
grep re-run, empty. (4) correctness — parent writes only KNOWN prefs; restart goes through quit-application-requested.
(5) Result claims real; the round-2 one-line change was not rebuilt, as stated — qa builds. (6) hygiene clean.

---
REQUEST_CHANGES
1. src/bb/strip/BBStrip.mjs:166 — the actor registers `events: { DOMContentLoaded: {} }` without `capture: true`, so
   it is a bubble listener on the chrome event handler. `preferences.js:549` adds `init_all` on `document` (target
   phase), which therefore runs first: `gotoPref()` reads `#brozen` / the last-used pane before `paneBrozen` is
   registered and the nav button exists, and falls back. This is exactly the untested ordering assumption in
   ## Result. Fix: `events: { DOMContentLoaded: { capture: true } }` (capture on the chrome event handler fires
   before the document's target-phase listeners).
2. src/bb/strip/BBStripPaneChild.sys.mjs:6-7 and docs/notes/about-preferences-injection.md:9-10 state "capture" as
   a fact; once item 1 is fixed they become true — keep them consistent with the registration and update the
   ## Result line on ordering (no longer an open assumption, but still [human] DoD 9 checks the deep link).

Checklist: (1) spec — variant A, rows from SWITCHES, restart via quit-application-requested + eAttemptQuit|eRestart,
Fluent en-US/ru, marketplace CSS under `:root[bb-strip-mods]` — matches DoD 2-6 except the ordering bug above.
(2) scope — src/bb/strip/** + jar.inc.mn; docs/notes/ is sanctioned by the teamlead notes. (3) layer — no Zen/Firefox
file, no patch, no pref outside bb.*; layer_lint 0 fail; DoD 3 grep empty (re-run). BBStrip.mjs is imported via
`ChromeUtils.importESModule` (shared global), so actor/L10n registration happens once per process. (4) prefs written
only in the parent and only for KNOWN switches; fillPane errors are caught. (5) ui build log
logs/build-ui-20261031-022348.log reports OK after the developer session start. (6) hygiene clean.

## QA
PASS
1. DoD 1: diff.sh --names lists 9 files: docs/notes (sanctioned), src/bb/jar.inc.mn, src/bb/strip/**. No Zen/Firefox file, no .patch, no layer.yaml.
2. DoD 2: BBStrip.mjs:166-168 registers the actor with `DOMContentLoaded: { capture: true }` and `matches` about:preferences*/about:settings*. Files are under src/bb/strip/ and packaged via jar.inc.mn.
3. DoD 3: the grep for media./browser.ml/identity./zen./extensions. over brozen-pane.* returns no output. The parent builds its rows from SWITCHES and writes only KNOWN prefs.
4. DoD 4: the restart flag comes from SWITCHES. restartBrowser() notifies quit-application-requested, then calls Services.startup.quit(eAttemptQuit|eRestart).
5. DoD 5: l10n/en-US and l10n/ru .ftl files exist; brozen-pane.mjs has no hard-coded UI text (grep empty), only data-l10n-id.
6. DoD 6: brozen-pane.css:6 hides `:root[bb-strip-mods] #category-zen-marketplace`. brozen-pane.mjs sets the attribute from the mods pref.
7. DoD 7: build.sh ui → BUILD RESULT: OK (logs/build-ui-20261031-022704.log). test.sh lint → TEST RESULT: OK, 0 problems (logs/test-lint-20261031-022735.log).
8. DoD 8: layer_lint → 12 files, 0 fail, 0 warn.

For the human: DoD 9-12 (runtime checks in a fresh profile: BROzen category, `#brozen` deep link, AI/EME toggles, Browser Console clean) are not run by QA.
