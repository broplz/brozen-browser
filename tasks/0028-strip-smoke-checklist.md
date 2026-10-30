---
id: 0028
title: scripts/bb/smoke.d/e1.txt — ADR-0003 smoke items for the strip epic
epic: e1-strip
prefix: e1
kind: docs
role: developer
size: S
status: blocked
base: feat/layer
branch: task/0028-strip-smoke-checklist
depends_on: [0024, 0025, 0026, 0027]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/bb/smoke.d/e1.txt
  - scripts/bb/smoke.d/e0.txt
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#решение-3--проверка
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason: "waits for 0024 (and the pane/module tasks 0026, 0027 whose behaviour the items check)"
---
## Goal
ADR-0003 Решение 3, last paragraph: the human smoke checklist gets the strip items, read by `scripts/bb/smoke.sh`
from `scripts/bb/smoke.d/e1.txt` (one item per line, `#` comments, ADR-0002 Решение 4 п.10).

## Definition of Done
1. `scripts/bb/smoke.d/e1.txt` has a `#` header line citing ADR-0003 and one line per item, in this order:
   BROzen category in settings with five switches; no Sync pane; no "Ask AI" in menus or Labs; Mods absent from
   settings, Boosts present; Netflix does not play; EME switch on → restart → Netflix plays; EME switch back off;
   Browser Console has no `ml`/`fxaccounts`/`mods`/`BBStrip` errors in the first 30 s.
2. `scripts/bb/smoke.d/e0.txt` no longer has the line "Stripped features are absent per ADR-0003 …" (now covered
   by e1.txt — no duplicate item); its other lines unchanged.
3. `grep -c -v -e "^#" -e "^$" scripts/bb/smoke.d/e1.txt` → the number of items in DoD 1 (smoke.sh reads every
   non-empty, non-`#` line as one item).
4. `scripts/agents/diff.sh tasks/0028-strip-smoke-checklist.md --names` lists only allowed_paths.

## Notes from teamlead
- Wording of items that depend on the final mechanism (where Mods/Boosts entries appear, the pane's name and the
  Sync pane id) — by report 0024 and the merged 0026/0027; keep each item one checkable sentence.
- English, no shell code in the file; smoke.sh treats every non-empty, non-`#` line as an item.

## Handoff

## Result

## Review

## QA
