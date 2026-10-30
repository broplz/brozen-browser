---
id: 0030
title: BROzen pane switches mean "feature enabled" (on = AI / Sync / DRM / Boosts / Mods work); bb.strip.* prefs and defaults unchanged
epic: e1-strip
prefix: e1
kind: feature
role: developer
size: S
status: ready
base: feat/layer
branch: task/0030-strip-pane-enable-semantics
depends_on: [0028]
build: ui
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/strip/brozen-pane.mjs
  - src/bb/strip/l10n/**
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#27-панель-brozen--инъекция-из-своего-кода
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0003 2.7 (pane from 0027): the owner wants each switch to read as "this feature is enabled", not "this feature is
removed". After this task a switch that is on means the feature works (AI features, Firefox Account and Sync, DRM,
Zen Boosts, Zen Mods); off means stripped. Only the display is inverted: the `bb.strip.*` prefs keep their meaning
(`true` = stripped) and their defaults in `prefs/bb/strip.yaml`, so BBStrip.mjs, the translation table of 2.7 and
strip-check stay as they are. With default prefs the pane shows only Zen Boosts on.

## Definition of Done
1. `scripts/agents/diff.sh tasks/0030-strip-pane-enable-semantics.md --names` lists only
   `src/bb/strip/brozen-pane.mjs` and files under `src/bb/strip/l10n/`.
2. `src/bb/strip/brozen-pane.mjs`: a switch shows `pressed = !value` of its `bb.strip.*` pref and writes
   `!pressed` on toggle; the Mods marketplace attribute (`bb-strip-mods`) still follows the pref value (set while
   `bb.strip.mods=true`, i.e. while the Mods switch is off).
3. `src/bb/strip/l10n/en-US/brozen-pane.ftl` labels: "AI features", "Firefox Account and Sync", "DRM (Widevine)",
   "Zen Boosts", "Zen Mods"; each `.description` says what turning the switch on gives. `l10n/ru/brozen-pane.ftl`
   carries the same meaning. No label or description says "Remove".
4. `bb-restart-note` ("Takes effect after a restart.") is still shown under Sync and DRM (from the list's `restart`
   flag, unchanged).
5. The only prefs the pane reads or writes are the five `bb.strip.*` (as 0027 DoD 3):
   `grep -rnE "media\.|browser\.ml|identity\.|zen\.|extensions\." src/bb/strip/brozen-pane.*` → no output.
6. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`; `scripts/agents/test.sh lint` → OK.
7. [human] Fresh profile: the BROzen pane shows only "Zen Boosts" on; the other four are off.
8. [human] DRM switch on → Restart → about:config `media.gmp-widevinecdm.enabled=true`; DRM switch off → Restart →
   `media.gmp-widevinecdm.enabled=false`.

## Notes from teamlead
- Do not touch `BBStrip.mjs`, `BBStripPane{Child,Parent}.sys.mjs`, `prefs/bb/strip.yaml` or the pref names: the
  inversion lives in the pane only. The parent actor still receives and writes `bb.strip.*` values (`true` =
  stripped).
- Keep the Fluent ids (`bb-strip-ai` … `bb-strip-boosts`) — they are derived from the pref names by `l10nId()`.
- Mods: the toggle handler currently sets `bb-strip-mods` from `toggle.pressed`; after the inversion it must be set
  from the pref value written (`!toggle.pressed`), same as `fillPane` does from state.
- needs_approval is false by the owner's decision although DoD 7-8 are [human]; qa lists them under "For the human".

## Handoff

## Result

## Review

## QA
