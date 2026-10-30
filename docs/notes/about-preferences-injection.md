# Injecting a category into about:preferences (variant A, task 0027)

Mechanism: `BBStripPane` JSWindowActor (registered in `src/bb/strip/BBStrip.mjs`, `matches`
about:preferences*/about:settings*) with a child on `DOMContentLoaded`.

Mount points the injection depends on (re-check on every Firefox/Zen rebase; smoke e1 catches drift):
- `preferences.js` `register_module(name, obj)` is a function declaration, so it is a window property:
  `win.register_module("paneBrozen", { init() {} })`. `gCategoryInits` is a `var`, but we never touch it.
- The actor registers `events: { DOMContentLoaded: { capture: true } }` (without `capture` it is a bubble listener
  and runs after the document's own). The listener sits on the chrome event handler (capture), so it runs before the
  page's own `init_all` listener: the nav button and module exist before `gotoPref()` reads `#brozen`.
- Nav: `moz-page-nav-button[view="paneBrozen"]` inside `#categories`, inserted before `#category-sync`.
  `gotoPref` finds it by `view`; the hash is `#brozen` (`internalPrefCategoryNameToFriendlyName`).
- Pane: a child of `#mainPrefPane` with `data-category="paneBrozen"`; `search()` toggles `hidden` by that
  attribute.
- Zen's Marketplace nav button is `#category-zen-marketplace`; hidden by CSS under `:root[bb-strip-mods]`.
- Prefs are read/written only in the parent actor (content/privilegedabout processes may not set prefs).
- Strings: an `L10nFileSource` ("bb-strip") over `chrome://browser/content/bb/strip/l10n/{locale}/`,
  attached with `document.l10n.addResourceIds(["brozen-pane.ftl"])`.

Fallback B (about:brozen) is needed only if `register_module` stops being global or `#category-sync`
disappears.
