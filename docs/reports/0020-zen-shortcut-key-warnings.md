# 0020 - Browser Console "missing key and keycode" warnings for Zen shortcuts

Code reading only; nothing was run or built.

## Source

`engine/toolkit/modules/ShortcutUtils.sys.mjs:65-69`, inside `prettifyShortcut(aElemKey)` (l.58). It calls `console.warn("Key element", el, 'is missing "key" and "keycode" attributes ...')` when `getKeyString(keycode, key)` returns empty (l.64), then returns `""`.

Callers that reach it with `<key>` elements:
- `engine/browser/base/content/browser.js:3574` - `gDynamicTooltipCache.getText()`, tooltips of toolbar buttons (`nodeToShortcutMap`, e.g. `key_stop`, `key_newNavigatorTab`, `key_fullZoomReset`).
- `engine/browser/components/customizableui/content/panelUI.js:1416` - `_ensureShortcutsShown()`, appmenu buttons with a `key` attribute.

## Trigger

`src/zen/kbs/ZenKeyboardShortcuts.mjs:455-490`, `replaceWithChild()`: when the shortcut has neither `#keycode` nor `#key` (l.479-490), it calls `removeAttribute("key")` and `removeAttribute("keycode")` (l.488-489). The element is still appended to the keyset by `_applyShortcuts()` (l.1500-1505 via `toXHTMLElement`, l.450-453), and for devtools keys by `_applyDevtoolsShortcuts()` (l.1533). The element keeps its id, so `document.getElementById(shortcutId)` in the callers above finds a `<key>` with no `key`/`keycode`, and `prettifyShortcut` warns.

How a shortcut ends up with neither:
1. `clearKeybind()` (l.673-677) sets `#key` and `#keycode` to `""` - the user cleared or disabled the shortcut (also l.1577 `targetShortcut.clearKeybind()`).
2. Default parsing, `parseFromXHTML()` (l.412-431), reads `key.getAttribute("key")`/`"keycode"` from Firefox's `mainKeyset` at l.728-749. Many Firefox keys in `engine/browser/base/content/browser-sets.inc.xhtml` have no `key` attribute at all and carry only `data-l10n-id` (e.g. `key_newNavigatorTab`, l.143; `focusURLBar`, l.145; `key_stop_mac`, l.301). Their `key` is filled in by Fluent (`.key` attribute of the message), not by the XHTML. For those, `getAttribute("key")` is `null` unless Fluent has already translated the element. The constructor (l.356) keeps `null`, `replaceWithChild` hits the else branch (l.487), and the `key` attribute is removed.

`isInvalid()` (l.582) compares to `""`, so a `null` key is not flagged invalid either.

Affected ids: every default shortcut whose `<key>` in `browser-sets.inc.xhtml` / the devtools keyset has `data-l10n-id` and no `key`/`keycode`, plus every user-cleared shortcut. To list them: in the Browser Console, `[...document.querySelectorAll("key[zen-keybind]")].filter(k => !k.hasAttribute("key") && !k.hasAttribute("keycode")).map(k => k.id)`. The tooltip/appmenu ids in `nodeToShortcutMap` are the ones that actually warn.

## Upstream

`git diff --stat bb/base/1.23.4b -- src/zen/kbs`:

```
(empty)
```

Our kbs code is identical to Zen 1.23.4b.

Fluent dependency: yes, in the sense above. `ZenKeyboardShortcuts.mjs` has no code that waits for Fluent translation before parsing (the only l10n references are the id plumbing at l.338-426 and the `zen-shortcuts-corrupted` label at l.1405), and `l10nId` is explicitly not re-applied to the element (l.497-499, commented out). So whether `key` is present at parse time depends on Fluent having translated `mainKeyset` first. A missing en-US string (task 0016, `update_en_US_packs.py`, or a profile whose shortcut list was saved while the strings were absent) would produce the same empty result. From code alone I cannot tell whether stock Zen wins that race (the Fluent timing is a runtime property) or whether a missing en-US pack is the cause in our build.

## Verdict

Verdict: unknown

The code path is stock Zen code (empty diff), so the mechanism exists upstream. Whether the official 1.23.4b build actually logs it depends on Fluent timing/availability, which only a run can show. DoD 8 (owner checks the official build's Browser Console) decides.

## Proposed fix

No fix yet. If the official build is clean, the cause is on our side (missing/late Fluent strings), and the fix is to make sure the en-US packs are present and that the keyset is parsed after translation; that would be a module replacement in `src/bb` (a `BBStartup.mjs`-loaded subclass of `gZenKeyboardShortcutsManager` per ADR-0002 class 2), not an edit of `src/zen/kbs`. If the official build warns too, the right route is an upstream Zen PR (skip writing an empty `<key>` or keep the Firefox-provided attributes in `replaceWithChild`), and BB does nothing. Cleared shortcuts that warn are an upstream behavior either way.
