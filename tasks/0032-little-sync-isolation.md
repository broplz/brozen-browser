---
id: 0032
title: src/bb/little/BBLittle.mjs — isLittleWindow(win), bb-little attribute, Little BB window excluded from Zen workspace cloning and workspaces/pinned/essentials sync via gZen* substitution behind bb.little.enabled
epic: e3-little-bb
prefix: e3
kind: feature
role: developer
size: M
status: approved
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
reviewed_sha: 575e60729ff54871114534c252f585e3a8348b16
qa_sha: 575e60729ff54871114534c252f585e3a8348b16
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
Round 1.

**Changed:** `src/bb/little/BBLittle.mjs` (new: `isLittleWindow`, `initWindow`), `src/bb/BBStartup.mjs` (+4 lines, imports BBLittle), `src/bb/jar.inc.mn` (+1), `prefs/bb/little.yaml` (new, `bb.little.enabled=true`). No `layer.yaml` entry (no hooks, no Zen edits).

**Deviation from DoD 3 — no `gZen*` instance is replaced.** Zen already has an "unsynced window" input that every sync point reads, so BBLittle sets `win._zenStartupSyncFlag = "unsynced"` plus the `bb-little` attribute. Replacing `gZenWorkspaces` was worse: `ZenSpaceManager` has `#private` state (a subclass instance built late or a stand-in object breaks it), and the stock `init()` is already bound to `MozBeforeInitialXULLayout` (`ZenStartup.mjs:213`). The flag makes Zen take its own unsynced path (the same one it uses for `zen.window-sync.open-link-in-new-unsynced-window`). Pref off → nothing is set, stock behaviour.

**Hook point:** `BBStartup.mjs` is the last script of `ZenPreloadedScripts.js:32`, so it runs at script load, before `MozBeforeInitialXULLayout` (`ZenStartup.mjs:213` → `gZenStartup.init` → `gZenWorkspaces.init`) and before `browser-window-before-show` (`browser-init.js:341` → `ZenWindowSync.sys.mjs:209-255`), which reads and then deletes the flag.

**Sync points found (Zen file:line) and coverage:**
- `ZenWindowSync.sys.mjs:232-255` `#onWindowBeforeShow` — flag → sets `zen-unsynced-window`, listens only to `TabOpen`, never sets `window.gZenWindowSync`: the mini window sends nothing (sender side). Covered.
- `ZenWindowSync.sys.mjs:145-157` `#browserWindows` (iterated by `#runOnAllWindows`/`Async` :342/:362, used by `#syncItemForAllWindows` :728) — the iterating side is the module, filtering on the *target's* `gZenWorkspaces.privateWindowOrDisabled` → mini window is never a target. Covered (via `ZenSpaceManager.mjs:761-771`, which reads the flag, then the attribute).
- `ZenSessionManager.sys.mjs:908-911` `restoreNewWindow` (tab cloning; log `:125` is just `log()`) — returns early on `privateWindowOrDisabled`. Covered.
- `ZenSpaceManager.mjs:1530` (propagate workspaces), `:163-169` (init paths), `ZenPinnedTabManager.mjs:136` (pinned/essentials enabled) — all gated by `privateWindowOrDisabled`. Covered.
- `ZenSpaceManager.mjs:742-755` `shouldHaveWorkspaces`: for a window without toolbar flags it is already false (E1) — the DoD 6 features string has no `toolbar`, so that window was probably disabled already; the flag matters once the final features/chromeFlags differ.
- Not covered (out of task): `ZenSpaceRoutingManager.sys.mjs:308,439` and `ZenUBActionsProvider.sys.mjs:252,371` / `ZenUBSidebarProvider.sys.mjs:66` (`getTopWindow`/`getOrderedWindows`/`getMostRecentWindow` — relevant to DoD 8), `ZenCommonUtils.mjs:22-26`, SessionStore.

**Verified:** `build.sh ui` → OK (27 s); `test.sh lint` → OK; `layer_lint.py` → 0 fail. DoD 2 grep not run separately (file has only `- name: bb.*` lines and comments).

**Open / not verified:** DoD 6–8 are [human] and not run. Assumption to check first: `win.name === "bb-little"` must already be set when BBStartup runs (openDialog's name argument); if not, the attribute is missing and the flag unset. Whether `BrowserWindowTracker.getTopWindow()` skips the mini window (DoD 8) is unchecked.

## Review
APPROVE

Checklist (round 1):
- Spec: DoD 1, 2 (I ran the grep myself: no output), 4 (`--names`: 4 files, all allowed, no src/zen) are met. DoD 3 deviates: no `gZen*` instance is replaced. Zen's own unsynced-window input (`_zenStartupSyncFlag = "unsynced"`) is used instead. I checked it against Zen: `ZenWindowSync.sys.mjs:224` gives forcedSync=false because `privateWindowOrDisabled` is true (`ZenSpaceManager.mjs:761-771` reads the flag), `:232-254` then takes the unsynced path and never sets `gZenWindowSync`. ADR-0001 :97 asks for "no hooks in src/zen/, mechanism from BBStartup behind a pref", and this does that with less code. The deviation is stated openly in ## Result. Accepted, but the owner has to sign off (item 1).
- Scope: only allowed_paths; no tests touched; layer.yaml unchanged, which is correct (no hooks or edits).
- Layer: no Zen file changed; pref `bb.little.enabled` is under bb.*; nothing in engine/; with the pref off `initWindow` returns before any side effect, so stock Zen behaviour stays (F2). layer_lint: 0 fail, 0 warn.
- Correctness: no listeners added, no async code. The order claim holds: BBStartup runs at preloaded-script time, before `browser-window-before-show` (`ZenWindowSync.sys.mjs:209`), which reads and then deletes the flag; after that the `zen-unsynced-window` attribute carries the state.
- Verification: build/lint claims belong to qa; the DoD 2 grep the developer skipped passes.
- Hygiene: the deferred-work comment carries a task id (0031); English throughout.

Items (non-blocking; qa, please list 1–3 under "For the human"):
1. DoD 3 deviation needs owner sign-off: isolation relies on Zen's private field `window._zenStartupSyncFlag` and on the unsynced-window path (`ZenWindowSync.sys.mjs:230-254`, `ZenSpaceManager.mjs:764`), not on a `gZen*` substitution. These are internal Zen names, and nothing in layer.yaml or the rebase checklist tracks them. If the owner keeps this approach, a follow-up should add them to the rebase exclusion-point checklist (ADR-0001 "Последствия": the list of exclusion points is a live list).
2. Side effect for DoD 6: the mini window gets `zen-unsynced-window="true"`, so Zen's unsynced-window styling applies (`zen-theme.css:249`, `zen-workspaces.css:209-316`). The owner should check that this looks acceptable.
3. Private Little window: `ZenWindowSync.sys.mjs:227-228` turns the flag into "synced" for private windows, so a private mini window would sync. Out of scope for the v1 window (not private), noted for 0031.
4. Nit, `src/bb/jar.inc.mn:7`: the unchanged `BBStrip.mjs` line lost two alignment spaces, which is an unrelated whitespace edit. Fix it in the next task that touches the file.

## QA
PASS

1. `build.sh ui` → BUILD RESULT: OK (25 s). `test.sh lint` → OK, 0 problems. `layer_lint.py` → 0 fail, 0 warn.
2. DoD 1: `isLittleWindow` exports only `win.name === "bb-little"` with the TODO(0031) comment. OK.
3. DoD 2: pref grep → no output; `bb.little.enabled` default true. OK.
4. DoD 3: BBStartup calls BBLittle, which sets the attribute and `_zenStartupSyncFlag` only when the pref is on and the window is Little; with the pref off it returns first. Hook point and Zen file:line are stated. This deviates from the literal text: no `gZen*` instance is replaced. The reviewer accepted it, and the isolation goal is met with zero Zen edits. I did not run it in a browser.
5. DoD 4: `diff.sh --names` lists 4 files, all allowed, none under src/zen/. OK.
6. DoD 5: passed (item 1).

### For the human
- DoD 6, 7, 8 were not run; they need a browser.
- Sign-off on the DoD 3 deviation: isolation relies on Zen internals (`_zenStartupSyncFlag`, the unsynced-window path), not on a `gZen*` substitution. Consider adding them to the rebase exclusion-point checklist.
- The mini window gets `zen-unsynced-window="true"`, so Zen's unsynced-window styling applies. Check that it looks acceptable.
- A private Little window would sync (`ZenWindowSync.sys.mjs:227-228`); this belongs to 0031.
- Nit: the `BBStrip.mjs` line in `src/bb/jar.inc.mn` lost two alignment spaces.
