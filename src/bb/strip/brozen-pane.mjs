// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// ADR-0003 2.7: the BROzen category of about:preferences. Rows come from the
// switch list BBStrip exports; every pref is read and written by the parent
// actor, so this file only knows the five bb.strip.* switch names it is given.

const CATEGORY = "paneBrozen";
const STYLESHEET = "chrome://browser/content/bb/strip/brozen-pane.css";
const MODS_SWITCH = "bb.strip.mods";
const MODS_ATTRIBUTE = "bb-strip-mods";

const l10nId = pref => pref.replaceAll(".", "-");

function create(doc, tag, attributes = {}) {
  const el = doc.createElement(tag);
  for (const [name, value] of Object.entries(attributes)) {
    el.setAttribute(name, value);
  }
  return el;
}

function addStylesheet(doc) {
  doc.head.append(
    create(doc, "link", { rel: "stylesheet", href: STYLESHEET })
  );
}

function addNavButton(doc) {
  const button = create(doc, "moz-page-nav-button", {
    id: "category-brozen",
    view: CATEGORY,
    iconsrc: "chrome://browser/skin/preferences/category-privacy-security.svg",
    "data-l10n-id": "bb-pane-title",
  });
  const sync = doc.getElementById("category-sync");
  sync.before(button);
}

function buildRow(doc, { pref, restart, value }, actions) {
  const row = create(doc, "div", { class: "bb-strip-row" });
  const toggle = create(doc, "moz-toggle", { "data-l10n-id": l10nId(pref) });
  // The switch reads "feature enabled"; the pref keeps "true = stripped".
  toggle.pressed = !value;
  toggle.addEventListener("toggle", () => {
    const stripped = !toggle.pressed;
    actions.setPref(pref, stripped);
    if (pref === MODS_SWITCH) {
      doc.documentElement.toggleAttribute(MODS_ATTRIBUTE, stripped);
    }
  });
  row.append(toggle);
  if (restart) {
    row.append(
      create(doc, "p", {
        class: "bb-strip-restart-note text-deemphasized",
        "data-l10n-id": "bb-restart-note",
      })
    );
  }
  return row;
}

function buildPane(doc) {
  const pane = create(doc, "div", {
    id: "bbStripPane",
    "data-category": CATEGORY,
    hidden: "true",
  });
  pane.append(create(doc, "h1", { "data-l10n-id": "bb-pane-title" }));
  return pane;
}

async function fillPane(doc, pane, actions) {
  const state = await actions.getState();
  const mods = state.find(({ pref }) => pref === MODS_SWITCH);
  doc.documentElement.toggleAttribute(MODS_ATTRIBUTE, !!mods?.value);
  for (const entry of state) {
    pane.append(buildRow(doc, entry, actions));
  }
  const restart = create(doc, "moz-button", {
    type: "primary",
    "data-l10n-id": "bb-restart-button",
  });
  restart.addEventListener("click", () => actions.restart());
  pane.append(restart);
}

// Called on DOMContentLoaded, before about:preferences' init_all.
export function injectPane(win, actions) {
  const doc = win.document;
  if (doc.getElementById("bbStripPane")) {
    return;
  }
  doc.l10n.addResourceIds(["brozen-pane.ftl"]);
  addStylesheet(doc);
  addNavButton(doc);
  const pane = buildPane(doc);
  doc.getElementById("mainPrefPane").append(pane);
  win.register_module(CATEGORY, { init() {} });
  fillPane(doc, pane, actions).catch(console.error);
}
