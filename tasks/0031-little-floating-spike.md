---
id: 0031
title: Spike — BB patch e3-little-bb/floating-window adds the chrome-only window feature bbfloating (CHROME_BB_FLOATING → InitData.mBBFloating → nsCocoaWindow), plus the R8 focus report
epic: e3-little-bb
prefix: e3
kind: patch
role: developer-hard
size: M
status: ready
base: feat/layer
branch: task/0031-little-floating-spike
depends_on: []
build: full
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/patches/e3-little-bb/**
  - src/bb/layer.yaml
  - docs/reports/e3-01-spike.md
  - engine/**
spec: docs/adr/0001-little-bb-floating-window.md#решение-1--уровень-окна-и-spaces-на-macos
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0001 v2, Решение 1, variant C′ (plan item e3-01). After this task the BB patch
`src/bb/patches/e3-little-bb/floating-window/floating-window.patch` with its `README.md` adds a chrome-only window
feature `bbfloating`: `nsWindowWatcher` maps it to `nsIWebBrowserChrome::CHROME_BB_FLOATING`, `nsAppShellService`
maps the flag to `InitData.mBBFloating`, and `nsCocoaWindow::CreateNativeWindow` gives such a window the MediaPiP
configuration (nonactivating panel, full-screen auxiliary, no full-screen primary) plus `NSFloatingWindowLevel` and
`MoveToActiveSpace`, without `CanJoinAllSpaces`. The window then floats over another app's native fullscreen Space
(F1), stays on the Space where it was opened (F2), does not switch Space (F3) and never becomes its own fullscreen
window (F6). `alwaysontop` and `mediapip` keep their semantics (N2); on other platforms the flag is ignored. The task
also measures focus/activity of the new window against the stock PiP player (risk R8) in
`docs/reports/e3-01-spike.md`.

## Definition of Done
1. `src/bb/patches/e3-little-bb/floating-window/` holds `floating-window.patch` and `README.md`. The README
   frontmatter has `epic: e3-little-bb`, `adr: docs/adr/0001-little-bb-floating-window.md`,
   `files:` (exactly the files the patch touches), `upstream: none`, `rebuild: full`, and the body has the four
   ADR-0002 sections (Why / What it changes / How to verify / What usually breaks on rebase).
2. The patch touches only these files, each change additive (the actual paths are confirmed by Grep first):
   - `toolkit/components/browser/nsIWebBrowserChrome.idl` — new constant `CHROME_BB_FLOATING` on a free bit;
   - `toolkit/components/windowwatcher/nsWindowWatcher.cpp` — `CalculateChromeFlagsForSystem`: feature
     `bbfloating` → `CHROME_BB_FLOATING`, next to feature `mediapip` (~:2024), same chrome-only gate;
   - `widget/InitData.h` — `bool mBBFloating = false;`;
   - `xpfe/appshell/nsAppShellService.cpp` — `JustCreateTopWindow`: `CHROME_BB_FLOATING` → `mBBFloating = true`,
     next to the `CHROME_MEDIA_PIP` line (~:504);
   - `widget/cocoa/nsCocoaWindow.mm` — `CreateNativeWindow`, next to the MediaPiP block (~:5389): for `mBBFloating`
     `NSWindowStyleMaskNonactivatingPanel`, `FullScreenAuxiliary | FullScreenDisallowsTiling`, no
     `FullScreenPrimary` (as MediaPiP, ~:5420–5436), plus level `NSFloatingWindowLevel`, plus
     `NSWindowCollectionBehaviorMoveToActiveSpace`, and never `CanJoinAllSpaces`.
3. `scripts/bb/patches.sh check` → OK for `e3-little-bb/floating-window`, i.e. the patch applies both to clean Firefox
   and to Firefox + Zen's patches of the same files.
4. `alwaysontop` and `mediapip` branches unchanged: `grep -nE "AlwaysOnTop|alwaysontop|MediaPiP|CHROME_MEDIA_PIP|CanJoinAllSpaces" src/bb/patches/e3-little-bb/floating-window/floating-window.patch`
   shows only context lines (no line starting with `+` or `-` among them).
5. `scripts/agents/build.sh full` → `BUILD RESULT: OK`.
6. `scripts/agents/test.sh lint` → OK; `python3 scripts/agents/layer_lint.py tasks/0031-little-floating-spike.md` → 0 fail.
7. `scripts/agents/diff.sh tasks/0031-little-floating-spike.md --names` lists only files under
   `src/bb/patches/e3-little-bb/`, `src/bb/layer.yaml` (if changed), `docs/reports/e3-01-spike.md` and this task file.
8. `docs/reports/e3-01-spike.md` exists and, for the `bbfloating` window and for the stock PiP player
   (`toolkit/components/pictureinpicture/content/player.xhtml`, opened from a playing video), gives the Browser
   Console values of `Services.focus.activeWindow === win`, `win.document.hasFocus()` and `win.windowState` — read
   while the window floats over another app's fullscreen Space, before and after a click into the window — and
   describes the difference (material for R8 and hypotheses (а)/(б)/(в) of Решение 1).
9. [human] In the built BB, Browser Console:
   `setTimeout(() => window.openDialog("chrome://browser/content/browser.xhtml","_blank","chrome,dialog=no,resizable,titlebar,bbfloating,suppressinitialfullscreen,width=900,height=700"), 5000)`,
   then within 5 s switch to a Space with another app in native fullscreen. All five must hold:
   1. the window appears over the fullscreen app (F1);
   2. swiping to another Space — the window does not follow (F2);
   3. the Space did not switch to BB (F3);
   4. the green button zooms, it does not enter fullscreen (F6);
   5. clicking the address bar and typing an address works over the fullscreen app (F4).
10. If any [human] item of DoD 9 is red, the task is not done: `status: blocked`, `blocked_reason` = "R8" (input,
    item 5) or "R9" (Space behaviour, items 1–3) with a link to `docs/reports/e3-01-spike.md`.

## Notes from teamlead
- ADR-0001 v2 is the only source of requirements. Where the code and the ADR disagree: status blocked with a question
  to the owner in ## Handoff, no improvisation.
- Before writing the patch read the code (Grep + Read with offset/limit in `engine/`) and confirm every line above:
  `nsWindowWatcher.cpp:2018,2024`, `nsAppShellService.cpp:504`, `nsCocoaWindow.mm:5383–5436`, `InitData.h`
  (`mPiPType`), the free bit in `nsIWebBrowserChrome.idl`. If the trace differs (other function, other field
  name), repeat the actual MediaPiP pattern, and list the confirmed `file:line` in ## Result.
- Do not change a single line of the `alwaysontop` or `mediapip` behaviour (N2). The new branch is a separate
  `if (aInitData.mBBFloating)` (or the actual equivalent) — not a rewrite of the MediaPiP condition. If the MediaPiP
  code can only be reused by touching its lines, stop and ask (blocked).
- Non-macOS: the flag is set in the cross-platform code but only `widget/cocoa` reads it — no stubs in other
  backends (Решение 1 rejects variant D).
- `engine/` is a draft only (ADR-0002, class 1): edit there, then `scripts/bb/patches.sh export
  src/bb/patches/e3-little-bb/floating-window`. Never `npm run export` for these files — the hunks would go into
  Zen's patches. If a hunk overlaps a Zen hunk (`patches.sh check` fails only against Firefox + Zen), stop: blocked,
  `allow_zen_patch` is false.
- `src/bb/layer.yaml`: per ADR-0002 a patch under `src/bb/patches/` is registered by its directory and README;
  `layer.yaml` gets an entry only for hooks, Zen edits or `zen_patches`. Expected: no change; if you do add one,
  say why in ## Result.
- `suppressinitialfullscreen` stays in the test features (ADR, F6); `mediapip` is intentionally absent from the
  [human] command: `bbfloating` reproduces the MediaPiP native configuration itself.
- The [human] check needs a full build in this engine: run it once the build is green, before review.
- If DoD 9 is red: no workarounds without the owner's decision — neither C″ (adding `CanJoinAllSpaces` and removing
  it after the first `orderFront`) nor E4 (`bb-little.xhtml`), nor `canBecomeKeyWindow`/`NSPanel` subclassing
  (hypothesis (а)). Measure, write the report (add `isKeyWindow` and `collectionBehavior` if you can read them),
  set blocked.
- R11 (`AXFrontmost`): `grep -rn AXFrontmost engine/widget/cocoa/ | head` and put the result into the report; no
  code change for it here.
- Strikes: 2 failed full builds → stop per CLAUDE.md rule 5.

## Handoff

## Result

## Review

## QA
