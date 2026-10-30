---
id: 0026
title: src/bb/strip/BBStrip.mjs — bb.strip.* switches translated into Firefox/Zen prefs, applied at startup; Mods/Boosts hooks
epic: e1-strip
prefix: e1
kind: feature
role: developer
size: M
status: blocked
base: feat/layer
branch: task/0026-strip-bbstrip-module
depends_on: [0024, 0025]
build: ui
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/bb/strip/BBStrip.mjs
  - src/bb/BBStartup.mjs
  - src/bb/jar.inc.mn
  - src/bb/layer.yaml
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#27-панель-переключателей--категория-brozen-в-aboutpreferences
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason: "waits for 0024; needs re-spec from the inventory report: Mods/Boosts/Zen Sync mechanism and the Zen files to hook (Q1-Q3, Q8)"
---
## Goal
ADR-0003 Решение 1 (last paragraph) and 2.7 "Логика": one module owns the contract between the user switches
`bb.strip.*` and the internal Firefox/Zen prefs, so the settings pane (0027) never names internal prefs. After this
task `BBStrip.mjs` reads the five switches, writes the translated prefs, listens for changes, and on every startup
brings the internal prefs back in line with `bb.strip.*` (an update that flips `browser.ml.enable` back does not
survive the next BB start). Mods and Boosts are switched by the mechanism report 0024 found (pref → L2; otherwise
L3 hook ≤ 10 lines or instance replacement from BBStartup, ADR 2.5, R2).

## Definition of Done
1. `src/bb/strip/BBStrip.mjs` holds the translation as one table (switch → list of `[pref, value when stripped]`)
   and one loop applies it; no per-switch branches (CLAUDE.md global rules). Table contents — by report 0024.
2. `src/bb/BBStartup.mjs` loads BBStrip once per process (not once per window) — mechanism by report 0024.
3. With `bb.strip.boosts=false` and every other switch at its default, Zen behaves as stock for Boosts (F2);
   setting any `bb.strip.<x>=false` restores the stock Zen/Firefox value of each translated pref.
4. Every edit of a Zen flat file has a `// BB(e1-strip)` marker and an entry under `edits` in `src/bb/layer.yaml`;
   each hook ≤ 10 lines.
5. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`; `scripts/agents/test.sh lint` → OK.
6. `python3 scripts/agents/layer_lint.py tasks/0026-strip-bbstrip-module.md` → 0 fail.
7. `scripts/agents/diff.sh tasks/0026-strip-bbstrip-module.md --names` lists only allowed_paths.
8. [human] Fresh profile: about:config shows the translated prefs at their stripped values; flip `bb.strip.ai` to
   false → `browser.ml.*` back to Firefox defaults without restart; Browser Console has no `BBStrip` errors in 30 s.

## Notes from teamlead
Needs clarification from report 0024 before it can be `ready`; the teamlead re-specs DoD 1–4 and allowed_paths:
- **Mods / Boosts (Q1, Q2)**: pref exists → L2 entry in the table; no pref and scripts are listed as an array in
  `src/zen/common/ZenPreloadedScripts.js` → L3 hook there (add that file to allowed_paths); otherwise instance
  replacement from BBStartup (ADR-0002 Решение 2 п.2). Removing `src/zen/mods/` (L4) is out.
- **Zen Sync (Q3, R4)**: dead when FxA is off → nothing to do; loads UI on its own → L3 hook behind `bb.strip.sync`.
- **Internal pref names**: only those confirmed in the report, per component. Do not write a Zen pref name that the
  ADR or the report does not give.
- **Where the stripped values live (Q8, owner decision recorded in 0025)**: if the owner picks (a), BBStrip sets
  Firefox defaults through `Services.prefs.getDefaultBranch("")` so the user can still change them, and nothing is
  locked (S3).
- Restart-only prefs (EME, `identity.fxaccounts.enabled` — ADR 2.3, 2.4, R6): BBStrip sets all four EME prefs together;
  telling the user about the restart is 0027's job.
- No `strip.css` here unless the report shows a UI leftover a pref cannot hide; if it does, add `src/bb/strip/strip.css`
  and `src/bb/bb-assets.inc.xhtml` to allowed_paths in the re-spec.

## Handoff

## Result

## Review

## QA
