---
id: 0028
title: scripts/bb/smoke.d/e1.txt — ADR-0003 2.9 smoke items for the strip epic
epic: e1-strip
prefix: e1
kind: docs
role: developer
size: S
status: approved
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
returns: 1
sessions: 0
reviewed_sha: 1ea77b452a9a85f7045150e08b36d12656a95385
qa_sha: 1ea77b452a9a85f7045150e08b36d12656a95385
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
Round 2: fixed Review item 1 — e1.txt lines 7-8 now use the real label "Remove DRM (EME)" with correct polarity
(off → Netflix plays, on → does not play). `grep -c` still 8. Nothing else changed.

Round 1: added scripts/bb/smoke.d/e1.txt (header + 8 items in ADR 2.9 order); removed the duplicate "Stripped features…"
line from e0.txt. 0027 built variant A, so item 1 names about:preferences. Verified: `grep -c` → 8. No build needed.

## Review
APPROVE
Round 2: item 1 from round 1 is fixed. e1.txt:7-8 now use the real label "Remove DRM (EME)" with the correct polarity:
off → plays, on → does not play, in ADR 2.9 order. Nothing else changed.
Checklist: (1) spec: header + 8 items in ADR order, item 1 matches variant A. (2) scope: only the two allowed_paths;
e0.txt has exactly one line removed. (3) layer: docs only, no Zen/engine files. layer_lint had 1 fail, caused only by
the wording of my own round-1 review (a marker word); that wording is rewritten below, and the code has 0 fail.
(4) correctness: `wc -lc` gives 9 lines / 568 bytes, so the file ends with a newline and `while read` keeps item 8.
(5) verification: I re-ran `grep -c` and got 8, as the Result says. (6) hygiene: English, one checkable sentence per item.

---
REQUEST_CHANGES
1. scripts/bb/smoke.d/e1.txt:7-8: the polarity is the wrong way round compared with the UI that 0027 actually built. The
   switch is labelled "Remove DRM (EME)" (src/bb/strip/l10n/en-US/brozen-pane.ftl:14) and it is bound to `bb.strip.eme`
   (on = stripped, see 0027 ## Result). "With the EME switch on, after Restart Netflix plays" therefore tells the tester
   to turn DRM *removal* on and then expect Netflix to play. Every correct build would fail this item. The teamlead
   note says to use the names as they are after 0027, so use the real label and state the expected result. Example:
   line 7 "Turn off 'Remove DRM (EME)', Restart: Netflix plays"; line 8 "Turn on 'Remove DRM (EME)', Restart: Netflix
   does not play". Keep the ADR 2.9 order (enable, then disable).

Checklist notes: (1) spec: header, 8 items and the ADR order are all correct; item 1 matches variant A (0027 Result);
only the EME wording is wrong (item 1 above). (2) scope: only allowed_paths are touched; e0.txt has exactly one line
removed. (3) layer: docs only, layer_lint shows 0 fail / 0 warn, no Zen/engine files. (4) correctness: the file ends
with a newline, so `while read` keeps the last item; no shell code. (5) verification: I re-ran `grep -c` and got 8,
as the Result says. (6) hygiene: English, no untracked markers, no dead lines.

## QA
PASS
1. DoD 1: e1.txt has the `#` header citing ADR-0003 2.9 and 8 items in ADR order; EME items use "Remove DRM (EME)" with correct polarity.
2. DoD 2: git diff of e0.txt shows exactly one removed line (the "Stripped features…" one).
3. DoD 3: `grep -c -v -e "^#" -e "^$" scripts/bb/smoke.d/e1.txt` → 8.
4. DoD 4: diff names list only e0.txt and e1.txt (plus the task file).
5. Lint: OK, 0 problems; layer_lint 0 fail, 0 warn (logs/test-lint-20261031-025513.log). Build: none.
