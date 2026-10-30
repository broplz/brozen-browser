// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// ADR-0003 2.7, variant A: injects the BROzen category into about:preferences.
// DOMContentLoaded reaches this actor (chrome event handler, capture) before
// the page's own init_all, so the category is registered before gotoPref runs.

import { injectPane } from "chrome://browser/content/bb/strip/brozen-pane.mjs";

export class BBStripPaneChild extends JSWindowActorChild {
  handleEvent(event) {
    if (event.type !== "DOMContentLoaded") {
      return;
    }
    injectPane(this.contentWindow, {
      getState: () => this.sendQuery("BBStripPane:GetState"),
      setPref: (pref, value) =>
        this.sendAsyncMessage("BBStripPane:SetPref", { pref, value }),
      restart: () => this.sendAsyncMessage("BBStripPane:Restart"),
    });
  }
}
