---
id: 0031
title: Spike — BB patch e3-little-bb/floating-window adds the chrome-only window feature bbfloating (CHROME_BB_FLOATING → InitData.mBBFloating → nsCocoaWindow), plus the R8 focus report
epic: e3-little-bb
prefix: e3
kind: patch
role: developer-hard
size: M
status: blocked
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
sessions: 1
reviewed_sha:
qa_sha:
blocked_reason: "human: R8 focus measurements (DoD 8) and DoD 9 checks need the GUI; see docs/reports/e3-01-spike.md; also accept nsCocoaWindow.h in the patch"
---
## Goal
ADR-0001 v2, Решение 1, variant C′ (plan item e3-01). After this task the BB patch
`src/bb/patches/e3-little-bb/floating-window/floating-window.patch` with its `README.md` adds a chrome-only window
feature `bbfloating`: `nsWindowWatcher` maps it to `nsIWebBrowserChrome::CHROME_BB_FLOATING`, `nsAppShellService`
maps the flag to `InitData.mBBFloating`, and `nsCocoaWindow::CreateNativeWindow` adds only `NSFloatingWindowLevel`
and `MoveToActiveSpace` for it, without `CanJoinAllSpaces`. Little BB is opened with `mediapip,bbfloating`: the
nonactivating panel, full-screen auxiliary and no full-screen primary come from the stock `mediapip` branch and are
not duplicated. The window then floats over another app's native fullscreen Space
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
     only `mWindow.level = NSFloatingWindowLevel` and
     `collectionBehavior |= NSWindowCollectionBehaviorMoveToActiveSpace`. `NonactivatingPanel`,
     `FullScreenAuxiliary | FullScreenDisallowsTiling` and the `FullScreenPrimary` exclusion (~:5434) come from
     `mediapip` and are not duplicated.
3. `scripts/bb/patches.sh check` → OK for `e3-little-bb/floating-window`, i.e. the patch applies both to clean Firefox
   and to Firefox + Zen's patches of the same files.
4. `alwaysontop` and `mediapip` branches unchanged: `grep -nE "AlwaysOnTop|alwaysontop|MediaPiP|CHROME_MEDIA_PIP|CanJoinAllSpaces" src/bb/patches/e3-little-bb/floating-window/floating-window.patch`
   shows only context lines (no line starting with `+` or `-` among them). The nsCocoaWindow.mm hunks add neither
   `CanJoinAllSpaces` nor `FullScreenPrimary`:
   `grep -nE "^\+.*(CanJoinAllSpaces|FullScreenPrimary)" src/bb/patches/e3-little-bb/floating-window/floating-window.patch`
   → no output.
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
   `setTimeout(() => window.openDialog("chrome://browser/content/browser.xhtml","_blank","chrome,dialog=no,resizable,titlebar,mediapip,bbfloating,suppressinitialfullscreen,width=900,height=700"), 5000)`,
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
- The [human] check needs a full build in this engine: run it once the build is green, before review.
- If DoD 9 is red: no workarounds without the owner's decision — neither C″ (adding `CanJoinAllSpaces` and removing
  it after the first `orderFront`) nor E4 (`bb-little.xhtml`), nor `canBecomeKeyWindow`/`NSPanel` subclassing
  (hypothesis (а)). Measure, write the report (add `isKeyWindow` and `collectionBehavior` if you can read them),
  set blocked.
- R11 (`AXFrontmost`): `grep -rn AXFrontmost engine/widget/cocoa/ | head` and put the result into the report; no
  code change for it here.
- Strikes: 2 failed full builds → stop per CLAUDE.md rule 5.

## Handoff
Session 1 (developer-hard). Blocked on things only a human can do; all agent-checkable DoD items are green.

Done (commit `e3: floating-window patch…` + this commit):
- DoD 1–3: patch + README in `src/bb/patches/e3-little-bb/floating-window/`; `scripts/bb/patches.sh check
  e3-little-bb/floating-window` → `OK`. No Zen hunk overlap (Zen's nsCocoaWindow hunks are at 87/1333/3908/3924/4978
  and external 70/5597/6948+; ours are around 5170 and 5405).
- DoD 4: the grep only shows context lines; the `^\+.*(CanJoinAllSpaces|FullScreenPrimary)` grep returns nothing.
- DoD 5: `scripts/agents/build.sh full` → `BUILD RESULT: OK type=full duration=1440s`
  (logs/build-full-20261031-043811.log).
- DoD 6: `test.sh lint` → OK; `layer_lint.py` → 0 fail, 0 warn, NEEDS APPROVAL (C++/ObjC/IDL), exit 3.
- DoD 7: only files under `src/bb/patches/e3-little-bb/`, `docs/reports/e3-01-spike.md` and the task file.
  `layer.yaml` is unchanged.

Not done:
- DoD 8: `docs/reports/e3-01-spike.md` has the procedure, the code-derived expectations, the window
  difference (the player is `orderFront` only; bbfloating goes through `makeKeyAndOrderFront` as a
  nonactivating panel) and R11 (`AXFrontmost`: no matches). The measured Browser Console values are
  empty: the agent cannot drive native fullscreen Spaces, clicks and the Browser Console.
- DoD 9: [human], not run.

Deviation from DoD 2 for the owner to accept: the patch also touches `widget/cocoa/nsCocoaWindow.h` (one member,
`bool mBBFloating`). `CreateNativeWindow` has no `aInitData`. It reads members (`mAlwaysOnTop`, `mPiPType`), and it is
called again on window recreation (nsCocoaWindow.mm ~:6314, HideWindowChrome). So the flag has to live on the widget,
just like `mAlwaysOnTop` (nsCocoaWindow.h:682, copied in `Create` at .mm:5169). The README `files:` lists it.

Next: the owner runs the procedure in the report on this build, fills in the table and DoD 9. If everything is
green → status review. If anything is red → blocked_reason R8/R9 per DoD 10.

## Result

## Review

## QA
