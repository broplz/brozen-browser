---
id: 0027
title: about:preferences category "BROzen" injected by a BB actor (variant A; about:brozen as fallback B) with five switches bound to bb.strip.*
epic: e1-strip
prefix: e1
kind: feature
role: developer
size: M
status: ready
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
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
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

## Review

## QA
