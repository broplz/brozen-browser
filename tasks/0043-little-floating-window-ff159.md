---
id: 0043
title: BB patch e3-little-bb/floating-window (chrome-only window feature bbfloating) carried over to Firefox 159 / Zen 1.24.1b, plus the R8 focus report
epic: e3-little-bb
prefix: e3
kind: patch
role: developer-hard
size: M
status: ready
base: feat/layer
branch: task/0043-little-floating-window-ff159
depends_on: []
build: full
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/patches/e3-little-bb/**
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
Supersedes 0031 (spike built on Firefox 158, never merged). ADR-0001 v2, Решение 1, variant C′. After this task
feat/layer holds `src/bb/patches/e3-little-bb/floating-window/{floating-window.patch,README.md}`, applying to Firefox
159.0.1 + Zen 1.24.1b. The patch adds a chrome-only window feature `bbfloating`: `nsWindowWatcher` → 
`nsIWebBrowserChrome::CHROME_BB_FLOATING` → `nsAppShellService` → `InitData.mBBFloating` → `nsCocoaWindow`
(member `mBBFloating` in nsCocoaWindow.h, accepted by the owner 2026-11-12) → `CreateNativeWindow` adds only
`NSFloatingWindowLevel` and `MoveToActiveSpace`. Plus `docs/reports/e3-01-spike.md`, the R8 focus report, with
the measurements filled in by the owner.

## Definition of Done
1. `src/bb/patches/e3-little-bb/floating-window/` holds `floating-window.patch` and `README.md`. The README
   frontmatter has `epic: e3-little-bb`, `adr: docs/adr/0001-little-bb-floating-window.md`, `files:` (exactly the
   files the patch touches), `upstream: none`, `rebuild: full`. The body has the four ADR-0002 sections, and
   "What usually breaks on rebase" names the Zen patches of the same area: `src/widget/cocoa/nsCocoaWindow-h.patch`,
   `src/widget/cocoa/nsCocoaWindow-mm.patch` (both changed in Zen 1.24).
2. The patch touches only these six files, each change additive: `toolkit/components/browser/nsIWebBrowserChrome.idl`,
   `toolkit/components/windowwatcher/nsWindowWatcher.cpp`, `widget/InitData.h`,
   `xpfe/appshell/nsAppShellService.cpp`, `widget/cocoa/nsCocoaWindow.h`, `widget/cocoa/nsCocoaWindow.mm`.
   `grep -c "^+++ b/" src/bb/patches/e3-little-bb/floating-window/floating-window.patch` → `6`.
3. `scripts/bb/patches.sh check` → OK for `e3-little-bb/floating-window` (applies to clean Firefox 159 and to
   Firefox + Zen's patches of the same files).
4. `grep -nE "^[-+].*(AlwaysOnTop|alwaysontop|MediaPiP|CHROME_MEDIA_PIP|CanJoinAllSpaces|FullScreenPrimary)" src/bb/patches/e3-little-bb/floating-window/floating-window.patch`
   → no output, apart from the `+++`/`---` file header lines.
5. `scripts/agents/build.sh full` → `BUILD RESULT: OK`.
6. `scripts/agents/test.sh lint` → OK; `python3 scripts/agents/layer_lint.py tasks/0043-little-floating-window-ff159.md`
   → 0 fail.
7. `scripts/agents/diff.sh tasks/0043-little-floating-window-ff159.md --names` lists only files under
   `src/bb/patches/e3-little-bb/`, `docs/reports/e3-01-spike.md` and this task file.
8. `docs/reports/e3-01-spike.md` exists with the procedure, the code-derived expectations for Firefox 159 (confirmed
   `file:line` of each hook point), R11 (`AXFrontmost` grep result), and an empty measurement table for the
   `bbfloating` window vs the stock PiP player: `Services.focus.activeWindow === win`, `win.document.hasFocus()`,
   `win.windowState`, before and after a click, while floating over another app's fullscreen Space. It also says
   whether Zen's new `src/dom/base/nsFocusManager-cpp.patch`/`nsFocusManager-h.patch` touch the window-raise/focus
   path the measurements depend on (Grep in the patches; one paragraph).
9. [human] The owner fills the measurement table of DoD 8 in the built BB.
10. [human] In the built BB, Browser Console:
    `setTimeout(() => window.openDialog("chrome://browser/content/browser.xhtml","_blank","chrome,dialog=no,resizable,titlebar,mediapip,bbfloating,suppressinitialfullscreen,width=900,height=700"), 5000)`,
    then within 5 s switch to a Space with another app in native fullscreen. All five must hold: (1) the window
    appears over the fullscreen app (F1); (2) swiping to another Space, the window does not follow (F2); (3) the Space
    did not switch to BB (F3); (4) the green button zooms, does not enter fullscreen (F6); (5) clicking the address bar
    and typing works over the fullscreen app (F4).

## Notes from teamlead
- Start from 0031's work, not from scratch. The files exist only on branch `task/0031-little-floating-spike`:
  patch + README in commit `20a4d5bec`, report skeleton in `47077e5e5`. Read them with
  `git show 20a4d5bec:src/bb/patches/e3-little-bb/floating-window/floating-window.patch` (and `…/README.md`,
  `git show 47077e5e5:docs/reports/e3-01-spike.md`), then recreate them with Write. Do not checkout/merge/cherry-pick
  that branch (driver owns git). Read tasks/0031-little-floating-spike.md `## Handoff` for what was learned.
- Then re-author on 159: apply the old patch to `engine/` as a draft, fix the hunks that no longer apply, and export
  with `scripts/bb/patches.sh export src/bb/patches/e3-little-bb/floating-window`. Never `npm run export`.
- The 0031 line numbers (Firefox 158: nsWindowWatcher.cpp ~2018/2024, nsAppShellService.cpp ~504,
  nsCocoaWindow.mm ~5169/5383-5436/~6314, nsCocoaWindow.h ~682) are hints only; confirm each on 159 by Grep + Read
  with offset/limit and list the confirmed `file:line` in ## Result and the report.
- ADR-0001 v2 is the only requirements source. Unchanged from 0031: no line of the `alwaysontop`/`mediapip` behaviour
  changes (N2); the new branch is a separate `if (mBBFloating)`; no stubs in non-cocoa widgets (variant D rejected);
  the flag is copied onto the widget in `Create` like `mAlwaysOnTop`, because `CreateNativeWindow` reads members and
  runs again on window recreation.
- If a BB hunk overlaps a Zen hunk (`patches.sh check` fails only against Firefox + Zen): stop, blocked;
  `allow_zen_patch` is false.
- `src/bb/layer.yaml` stays unchanged (a BB patch registers by its directory and README).
- DoD 9-10 are [human]: once the full build is green and DoD 1-8 hold, set `status: review` with the agent DoD done.
  Do not set blocked for the missing measurements (0031's mistake was an untagged GUI item). If the owner reports DoD
  10 red: no workarounds (no C″, no E4, no `canBecomeKeyWindow`/NSPanel subclass) without the owner's decision.
- Strikes: 2 failed full builds → stop per CLAUDE.md rule 5.

## Handoff

## Result

## Review

## QA
