---
id: 0032
title: src/bb/little/BBLittle.mjs — isLittleWindow(win), bb-little attribute, Little BB window excluded from Zen workspace cloning and workspaces/pinned/essentials sync via gZen* substitution behind bb.little.enabled
epic: e3-little-bb
prefix: e3
kind: feature
role: developer
size: M
status: ready
base: feat/layer
branch: task/0032-little-sync-isolation
depends_on: []
build: ui
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/little/**
  - src/bb/BBStartup.mjs
  - src/bb/jar.inc.mn
  - prefs/bb/little.yaml
  - src/bb/layer.yaml
spec: docs/adr/0001-little-bb-floating-window.md#решение-2--признак-окна-и-исключение-из-синхронизации-zen
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0001 v2, Решение 2, variant E2 on top of E1 (plan item e3-02, independent of 0031). After this task
`src/bb/little/BBLittle.mjs` exports `isLittleWindow(win)` — the one place that says whether a window is Little BB —
and BBStartup, behind `bb.little.enabled`, marks such a window with the attribute `bb-little` on `documentElement`
before Zen initialises and replaces the `gZen*` instances (ADR-0003 2.5 technique, ADR-0002 Решение 2 p.2) so that
the window gets no workspace tabs cloned into it on open and is skipped when Zen broadcasts workspaces / pinned /
essentials changes to other windows (F5). Until `CHROME_BB_FLOATING` exists in the build (0031) the marker is
temporary: `win.name === "bb-little"`. No file under `src/zen/**` changes.

## Definition of Done
1. `src/bb/little/BBLittle.mjs` exports `isLittleWindow(win)`; the only check inside is `win.name === "bb-little"`,
   with the comment `// TODO(0031): replace with chromeFlags & CHROME_BB_FLOATING once 0031 lands.` (or the id of
   the follow-up task, if the owner gives one).
2. `prefs/bb/little.yaml` declares `bb.little.enabled` (default `true`); `grep -vE "^\s*(#|$|- name: bb\.|  value:)" prefs/bb/little.yaml`
   → no output (only `bb.*` names).
3. With `bb.little.enabled=true`, BBStartup (via BBLittle) sets `bb-little` on `document.documentElement` of a Little
   BB window before Zen's window init reads it (state the hook point — event or call order — with `file:line` of the
   Zen code it precedes in ## Result), and replaces the `gZen*` instance(s) that clone workspace tabs on open and
   that broadcast workspaces / pinned / essentials changes, with subclasses (`extends gZenX.constructor`) or
   same-interface objects that skip Little BB windows. Each overridden method carries the `file:line` of the Zen
   method it overrides. With `bb.little.enabled=false` stock instances stay and no attribute is set.
4. Zero Zen edits: `scripts/agents/diff.sh tasks/0032-little-sync-isolation.md --names` lists only files under
   `src/bb/little/`, `src/bb/BBStartup.mjs`, `src/bb/jar.inc.mn`, `prefs/bb/little.yaml`, `src/bb/layer.yaml` and this
   task file; `grep -c "src/zen/"` on that list → `0`.
5. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`; `scripts/agents/test.sh lint` → OK;
   `python3 scripts/agents/layer_lint.py tasks/0032-little-sync-isolation.md` → 0 fail.
6. [human] Browser Console:
   `openDialog("chrome://browser/content/browser.xhtml","bb-little","chrome,dialog=no,resizable,titlebar,mediapip,alwaysontop,width=900,height=700")`
   → the mini window has no workspace tabs; the console shows no cloning log from `ZenSessionManager` /
   `ZenSpaceManager` for this window (ADR: `ZenSessionManager.sys.mjs:125`, `ZenSpaceManager.mjs:93`).
7. [human] After closing the mini window the main window's pinned tabs and essentials are unchanged.
8. [human] With the mini window open, `open -a "BROzen BROwser" https://example.com` from Terminal → the link opens
   in the main window, not in the mini window.

## Notes from teamlead
- ADR-0001 v2 is the only source of requirements. Where the code and the ADR disagree: status blocked with a question
  to the owner in ## Handoff, no improvisation.
- Zero edits of `src/zen/**` (ADR-0001 Решение 2 last paragraph; ADR-0003 S2 practice). If the exclusion cannot be
  done without a hook in a Zen file — e.g. the cloning is driven from `ZenSessionManager.sys.mjs` (a process module
  with no window instance, ADR-0002 Решение 2 p.2 last sentence) and no window-side `gZen*` method gates it — stop:
  status blocked, `blocked_reason` names the file and line where the hook would go, and ## Handoff says what you
  tried.
- Find the points by Grep in `src/zen/`: `getEnumerator("navigator:browser")`, `BrowserWindowTracker`, the
  `ZenSessionManager.sys.mjs:125` / `ZenSpaceManager.mjs:93` log lines, the pinned/essentials sync. List every point
  found with `file:line` in ## Result, marking which ones the substitution covers; the rest (SessionStore,
  `BrowserWindowTracker`, ADR Решение 2 bullets 3–4) are out of this task — add them to tasks/backlog.md
  "Found by agents" only if they break DoD 6–8.
- Substitution technique — exactly as `BBStrip.mjs` does it for `gZenMods` (ADR-0003 2.5): BBStartup runs last in
  the window (`ZenPreloadedScripts.js`), after Zen constructed its instances; anything the stock constructor already
  started must be undone through the instance's own API, or reported. Broadcast filtering must work from the
  sending window too: a change in the main window must not reach the mini window, even though the mini window's
  instance is replaced — check which side iterates the windows.
- BBLittle is a chrome ESM imported from BBStartup with `ChromeUtils.importESModule` (shared global), registered in
  `src/bb/jar.inc.mn` like `BBStrip.mjs`. BBStartup only calls into it.
- `isLittleWindow` is the only marker check in the code: other code calls it or reads the `bb-little` attribute, never
  `win.name` directly — so 0031's follow-up changes one line.
- The [human] window is ADR variant G (`mediapip,alwaysontop`, no patch). DoD 8 relies on E1: the features have no
  `toolbar`, so the window should be a popup for `BrowserWindowTracker`; if the link still lands in the mini window,
  report it in ## Result and the backlog rather than patching Firefox.
- `src/bb/layer.yaml`: no entry expected (no hooks, no Zen edits); if you add one, say why.
- needs_approval is false by the owner's decision although DoD 6–8 are [human]; qa lists them under "For the human".

## Handoff

## Result

## Review

## QA
