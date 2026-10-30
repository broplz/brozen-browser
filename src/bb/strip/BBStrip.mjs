// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// ADR-0003 2.7: the contract between the user switches bb.strip.* and the
// internal prefs. The preferences pane builds its rows from SWITCHES and never
// names an internal pref.

// switch -> [internal pref, value when stripped]. Names: prefs/bb/strip.yaml
// or docs/reports/strip-inventory.md (Q4: prefs/firefox/ai.yaml:6-24).
const TABLE = [
  {
    pref: "bb.strip.ai",
    restart: false,
    rows: [
      ["browser.ml.chat.enabled", false],
      ["browser.ml.chat.shortcuts", false],
      ["browser.ml.chat.shortcuts.custom", false],
      ["browser.ml.chat.sidebar", false],
      ["browser.ml.enable", false],
      ["browser.ml.chat.menu", false],
      ["browser.ml.linkPreview.enabled", false],
      ["browser.ml.chat.page", false],
      ["browser.ml.chat.page.footerBadge", false],
      ["browser.ml.chat.page.menuBadge", false],
      ["browser.ml.chat.shortcuts.smartwindow", false],
      ["browser.ml.linkPreview.optin", false],
      ["browser.ml.pageAssist.enabled", false],
      ["browser.tabs.groups.smart.enabled", false],
      ["browser.tabs.groups.smart.userEnabled", false],
      ["browser.tabs.groups.smart.optin", false],
      ["browser.tabs.groups.smart.searchTopicEnabled", false],
      ["browser.search.visualSearch.featureGate", false],
      ["extensions.ml.enabled", false],
    ],
  },
  {
    pref: "bb.strip.sync",
    restart: true,
    rows: [["identity.fxaccounts.enabled", false]],
  },
  {
    pref: "bb.strip.eme",
    restart: true,
    rows: [
      ["media.gmp-widevinecdm.enabled", false],
      ["media.gmp-widevinecdm.visible", false],
      ["browser.eme.ui.enabled", false],
    ],
  },
  {
    pref: "bb.strip.boosts",
    restart: false,
    rows: [["zen.boosts.enabled", false]],
  },
  // Mods: no pref, only the gZenMods stub (initWindow).
  { pref: "bb.strip.mods", restart: false, rows: [] },
];

export const SWITCHES = TABLE.map(({ pref, restart }) => ({ pref, restart }));

// Members of window.gZenMods used outside ZenMods.mjs, each with its user
// (docs/reports/strip-inventory.md Q1) and the empty value of its type.
// A function value is returned as is; `property` members are plain values.
const MODS_STUB_MEMBERS = [
  { name: "updatePref", user: "zen-settings.js:41", property: "bb.strip.mods" },
  { name: "requestMod", user: "ZenModsMarketplaceParent.sys.mjs:18", empty: null },
  { name: "getMods", user: "ZenModsMarketplaceParent.sys.mjs:24", empty: {} },
  { name: "updateMods", user: "ZenModsMarketplaceParent.sys.mjs:27", empty: undefined },
  { name: "removeMod", user: "ZenModsMarketplaceParent.sys.mjs:40", empty: undefined },
  { name: "checkForModsUpdates", user: "ZenModsMarketplaceParent.sys.mjs:48", empty: [] },
  { name: "triggerModsUpdate", user: "zen-settings.js:156", empty: undefined },
  { name: "disableMod", user: "zen-settings.js:166", empty: undefined },
  { name: "enableMod", user: "zen-settings.js:172", empty: undefined },
  { name: "sanitizeModName", user: "zen-settings.js:299", empty: "" },
  { name: "getModPreferences", user: "zen-settings.js:443", empty: [] },
  { name: "debounce", user: "zen-settings.js:606", empty: () => {} },
  { name: "isModInstalled", user: "ZenMods.mjs:761 (public API)", empty: false },
];

// Neutralised on the stock instance: its init() is already bound to
// MozBeforeInitialXULLayout (ZenCommonUtils.mjs:80) and cannot be removed, but
// it reads mods through these public methods (ZenMods.mjs:497,110,522).
const STOCK_INSTANCE_NEUTRALISED = ["getMods", "checkForModsUpdates"];

function applyRows(switchPref, rows) {
  const on = Services.prefs.getBoolPref(switchPref, false);
  const defaults = Services.prefs.getDefaultBranch("");
  for (const [pref, stripped] of rows) {
    const wanted = on ? stripped : !stripped;
    if (wanted === defaults.getBoolPref(pref, !wanted)) {
      Services.prefs.clearUserPref(pref);
    } else {
      Services.prefs.setBoolPref(pref, wanted);
    }
  }
}

function setBoostsAttribute(win) {
  // The root element of browser.xhtml is #main-window; it exists before the
  // rest of the document is parsed.
  win.document.documentElement.toggleAttribute(
    "bb-strip-boosts",
    Services.prefs.getBoolPref("bb.strip.boosts", false)
  );
}

function forEachBrowserWindow(fn) {
  for (const win of Services.wm.getEnumerator("navigator:browser")) {
    fn(win);
  }
}

function buildModsStub() {
  const stub = {};
  for (const { name, property, empty } of MODS_STUB_MEMBERS) {
    stub[name] = property ?? (() => empty);
  }
  return stub;
}

// Per window, called from BBStartup.mjs.
export function initWindow(win) {
  setBoostsAttribute(win);
  if (!Services.prefs.getBoolPref("bb.strip.mods", false)) {
    return;
  }
  const stock = win.gZenMods ?? {};
  for (const name of STOCK_INSTANCE_NEUTRALISED) {
    const member = MODS_STUB_MEMBERS.find(m => m.name === name);
    stock[name] = () => member.empty;
  }
  win.gZenMods = buildModsStub();
}

const observer = {
  observe(subject, topic, data) {
    const entry = TABLE.find(({ pref }) => pref === data);
    if (!entry) {
      return;
    }
    applyRows(entry.pref, entry.rows);
    if (data === "bb.strip.boosts") {
      forEachBrowserWindow(setBoostsAttribute);
    }
  },
};

// Once per process: this module is imported into the shared global.
for (const { pref, rows } of TABLE) {
  applyRows(pref, rows);
}
Services.prefs.addObserver("bb.strip.", observer);
