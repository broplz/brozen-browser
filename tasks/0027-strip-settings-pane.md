---
id: 0027
title: about:preferences category BROzen with five switches (EME, AI, Sync, Mods, Boosts) bound to bb.strip.*
epic: e1-strip
prefix: e1
kind: feature
role: developer
size: M
status: blocked
base: feat/layer
branch: task/0027-strip-settings-pane
depends_on: [0024, 0026]
build: ui
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/strip/**
  - src/bb/jar.inc.mn
  - src/bb/layer.yaml
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#27-панель-переключателей--категория-brozen-в-aboutpreferences
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason: "waits for 0024; needs re-spec from the inventory report: how Zen adds about:preferences categories (Q7, ADR-0003 R1)"
---
## Goal
ADR-0003 S6 and 2.7 (variant A): all strip switches in one place. After this task about:preferences has a category
"BROzen" with five switches — EME, AI, Sync, Mods, Boosts — each bound to its `bb.strip.*` pref, with a one-line
explanation, a "restart required" note on EME and Sync, and a "Restart" button. The pane only reads and writes
`bb.strip.*`; translation into internal prefs is BBStrip.mjs (0026).

## Definition of Done
1. The pane's markup binds exactly the five prefs `bb.strip.eme`, `bb.strip.ai`, `bb.strip.sync`, `bb.strip.mods`,
   `bb.strip.boosts` and no other pref (`grep -rn "preference=" <pane files>` → those five).
2. EME and Sync rows carry the restart note; the pane has one "Restart" button.
3. Every edit of a Zen file (hook into Zen's preferences entry point, per report 0024 Q7) has a `BB(e1-strip)` marker
   and an entry in `src/bb/layer.yaml` (`hooks` or `edits`); each ≤ 10 lines.
4. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`; `scripts/agents/test.sh lint` → OK.
5. `python3 scripts/agents/layer_lint.py tasks/0027-strip-settings-pane.md` → 0 fail.
6. `scripts/agents/diff.sh tasks/0027-strip-settings-pane.md --names` lists only allowed_paths.
7. [human] about:preferences shows the "BROzen" category with five switches; toggling AI changes `bb.strip.ai` in
   about:config without restart; toggling EME shows the restart note.

## Notes from teamlead
Needs clarification from report 0024 before it can be `ready`; the teamlead re-specs allowed_paths and DoD 1–3:
- **Mechanism (Q7, R1)**: if Zen adds its categories from flat files (class 2) → a one-line hook there, plus the BB
  pane files under `src/bb/strip/`. If the only entry point is a Zen `.patch` on `preferences.xhtml`/`preferences.js`
  (class 3) → the owner chooses between a hunk in Zen's patch (ADR-0002 Решение 2 п.4: `allow_zen_patch: true`,
  `layer.yaml: zen_patches`, role developer-hard) and variant B, a separate `about:brozen` page (ADR 2.7 table).
  Either way it goes to docs/reports/decisions-needed.md before this task is `ready`.
- **Strings (Q7)**: Fluent file location by the report; English plus the locales in `locales/supported-languages`
  that BB ships (en-US, ru per ADR-0002 Кэш), no hard-coded UI strings.
- Icon: reuse an existing Firefox/Zen category icon for now; a BB icon is E0 branding work.
- No `lockPref`, no policies (S3). The pane never names `media.*`, `browser.ml.*`, `identity.*` or `zen.*` prefs.

## Handoff

## Result

## Review

## QA
