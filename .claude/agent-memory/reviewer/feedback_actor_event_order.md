---
name: actor-event-order
description: JSWindowActor DOMContentLoaded without capture:true fires after the page's own document listeners
metadata:
  type: feedback
---
JSWindowActor `events: { X: {} }` is a bubble listener on the chrome event handler, so it fires AFTER page listeners
on document/window (e.g. preferences.js `init_all`). Code that must run first needs `{ capture: true }`.

**Why:** 0027 claimed "capture" in comments/notes but registered without it; deep-link `#brozen` would break.
**How to apply:** for any actor that injects before page init, grep the registration for `capture: true` and the
page's addEventListener in engine/ to confirm ordering.
