// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// ADR-0001 v2, Решение 2: the Little BB window is a full browser.xhtml that
// Zen must not treat as one more synced window.

// The only place that says whether a window is Little BB.
export function isLittleWindow(win) {
  // TODO(0031): replace with chromeFlags & CHROME_BB_FLOATING once 0031 lands.
  return win.name === "bb-little";
}

// Per window, called from BBStartup.mjs. BBStartup is the last script of
// ZenPreloadedScripts.js, so it runs before MozBeforeInitialXULLayout
// (ZenStartup.mjs:213 -> gZenStartup.init -> gZenWorkspaces.init) and before
// "browser-window-before-show" (browser-init.js:341 -> ZenWindowSync.sys.mjs:209).
export function initWindow(win) {
  if (!Services.prefs.getBoolPref("bb.little.enabled", false)) {
    return;
  }
  if (!isLittleWindow(win)) {
    return;
  }
  win.document.documentElement.setAttribute("bb-little", "true");
  // Zen's own "unsynced window" input instead of replacing gZenWorkspaces
  // (its class has #private state, a stand-in object would break it). Every
  // consumer below reads the flag, then the attribute Zen derives from it:
  // - ZenWindowSync.sys.mjs:232-255 (#onWindowBeforeShow): sets
  //   zen-unsynced-window, registers only TabOpen, never sets
  //   window.gZenWindowSync, so the window sends no sync events;
  // - ZenSpaceManager.mjs:761-771 (currentWindowIsSyncing,
  //   privateWindowOrDisabled): true for this window, so
  //   ZenWindowSync.sys.mjs:151 (#browserWindows) skips it as a target and
  //   ZenSessionManager.sys.mjs:909 (restoreNewWindow) clones no tabs into it;
  // - ZenPinnedTabManager.mjs:136 and ZenSpaceManager.mjs:1530: pinned,
  //   essentials and workspaces propagation are off for it.
  win._zenStartupSyncFlag = "unsynced";
}
