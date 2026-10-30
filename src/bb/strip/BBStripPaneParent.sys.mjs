// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// ADR-0003 2.7: the parent side of the BROzen pane. The page never touches
// prefs; it asks here.

import { SWITCHES } from "chrome://browser/content/bb/strip/BBStrip.mjs";

const KNOWN = SWITCHES.map(({ pref }) => pref);

export class BBStripPaneParent extends JSWindowActorParent {
  receiveMessage({ name, data }) {
    switch (name) {
      case "BBStripPane:GetState":
        return SWITCHES.map(({ pref, restart }) => ({
          pref,
          restart,
          value: Services.prefs.getBoolPref(pref, false),
        }));
      case "BBStripPane:SetPref":
        if (KNOWN.includes(data.pref)) {
          Services.prefs.setBoolPref(data.pref, !!data.value);
        }
        return null;
      case "BBStripPane:Restart":
        restartBrowser();
        return null;
    }
    return null;
  }
}

function restartBrowser() {
  const cancel = Cc["@mozilla.org/supports-PRBool;1"].createInstance(
    Ci.nsISupportsPRBool
  );
  Services.obs.notifyObservers(cancel, "quit-application-requested", "restart");
  if (cancel.data) {
    return;
  }
  Services.startup.quit(
    Ci.nsIAppStartup.eAttemptQuit | Ci.nsIAppStartup.eRestart
  );
}
