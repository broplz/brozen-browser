// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

console.info(
  `BBStartup: bb.layer.version=${Services.prefs.getIntPref("bb.layer.version", 0)}`
);

// Shared global: one BBStrip per process, applied once at import.
const { initWindow } = ChromeUtils.importESModule(
  "chrome://browser/content/bb/strip/BBStrip.mjs"
);
initWindow(window);

const { initWindow: initLittleWindow } = ChromeUtils.importESModule(
  "chrome://browser/content/bb/little/BBLittle.mjs"
);
initLittleWindow(window);
