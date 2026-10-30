---
id: 0028
title: scripts/bb/smoke.d/e1.txt — ADR-0003 2.9 smoke items for the strip epic
epic: e1-strip
prefix: e1
kind: docs
role: developer
size: S
status: ready
base: feat/layer
branch: task/0028-strip-smoke-checklist
depends_on: [0027]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/bb/smoke.d/e1.txt
  - scripts/bb/smoke.d/e0.txt
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#29-проверка
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0003 v2 2.9, last paragraph: the human smoke checklist gets the strip items, read by `scripts/bb/smoke.sh` from
`scripts/bb/smoke.d/e1.txt` (one item per line, `#` comments, ADR-0002 Решение 4 п.10). These items are how every
rebase proves the L3 mechanisms of e1-strip (gZenMods stub, the about:preferences injection) still work — ADR
"Последствия": they break silently.

## Definition of Done
1. `scripts/bb/smoke.d/e1.txt` has a `#` header line citing ADR-0003 2.9 and one line per item, in this order (ADR 2.9):
   1. about:preferences has the "BROzen" category with five switches (EME, AI, Sync, Mods, Boosts);
   2. no Sync pane in about:preferences;
   3. no "Ask AI" entry in menus;
   4. no Zen Marketplace category; Boosts present;
   5. Netflix does not play (DRM) on a fresh profile;
   6. EME switch on → Restart → Netflix plays;
   7. EME switch off → Restart → Netflix does not play;
   8. Browser Console has no `ml`/`fxaccounts`/`gZenMods`/`BBStrip` errors in the first 30 s.
2. `scripts/bb/smoke.d/e0.txt` no longer has the line "Stripped features are absent per ADR-0003 …" (now covered by
   e1.txt — no duplicate item); its other lines unchanged (`git diff` of e0.txt shows one removed line).
3. `grep -c -v -e "^#" -e "^$" scripts/bb/smoke.d/e1.txt` → `8`.
4. `scripts/agents/diff.sh tasks/0028-strip-smoke-checklist.md --names` lists only allowed_paths.

## Notes from teamlead
- Wording: names as they are after 0026/0027 merged (category label, fallback B `about:brozen` if 0027 ## Result says
  B was built — then item 1 names that page). Keep each item one checkable sentence, English, no shell code.
- Item 5/6 are ADR R3 (`media.eme.enabled=true` stays Zen's): if item 5 fails on a real run, that is a finding for
  the ADR (add `media.eme.enabled` to the 0026 table), not a reason to change this list.
- `strip-check.sh` already runs as smoke.sh's first step (0025); no item for it here.

## Handoff

## Result

## Review

## QA
