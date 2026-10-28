---
id: 0001
title: src/bb/layer.yaml registry (base, hooks, edits, zen_patches) + src/bb/README.md
epic: layer
prefix: layer
kind: docs
role: developer
size: S
status: done
base: feat/layer
branch: task/0001-layer-registry
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - src/bb/layer.yaml
  - src/bb/README.md
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-1--структура-слоя-bb
returns: 0
sessions: 0
reviewed_sha: 0854b345acf5c64c273ce4b68038fa57bbc0502e
qa_sha: 0854b345acf5c64c273ce4b68038fa57bbc0502e
blocked_reason: 
---
## Goal
Create the BB layer registry `src/bb/layer.yaml` — the single source of truth for the Zen base
the layer sits on and for every BB change outside `src/bb/patches/` — and `src/bb/README.md`
describing the layer layout, per ADR-0002 Решение 1 (tree), Решение 2 (layer.yaml paragraph) and
Решение 3 (`base` block). No hooks exist yet, so the three lists start empty; later tasks append
their own entries.

## Definition of Done
1. `grep -c -E "^(base|hooks|edits|zen_patches):" src/bb/layer.yaml` → `4`
2. `grep -E "^  (zen|firefox|commit):" src/bb/layer.yaml` → exactly three lines:
   `  zen: 1.23.4b`, `  firefox: 158.0.1`, `  commit: 541ee55`
3. `grep -c -E "^(hooks|edits|zen_patches): \[\]" src/bb/layer.yaml` → `3`
4. `src/bb/layer.yaml` has a comment block above each list showing the entry schema (see Notes).
5. `python3 scripts/agents/layer_lint.py 0001` → no FAIL lines.
6. `src/bb/README.md` contains the headings `## Layout`, `## Hook lines`, `## Foreign files`,
   `## layer.yaml`; `grep -c "src/bb/patches/<epic>/<name>/" src/bb/README.md` → ≥ 1.
7. `scripts/agents/diff.sh tasks/0001-layer-registry.md --names` lists only the two allowed files.

## Notes from teamlead
- `base` block, exactly (ADR-0002 Решение 3): `zen: 1.23.4b`, `firefox: 158.0.1`, `commit: 541ee55`.
  It is read by scripts (rebase.sh step 1) — keep it a plain two-space-indented mapping, no
  flow style, no quotes, no anchors.
- Entry schemas (as YAML comments, lists stay `[]`):
  - `hooks`: `file`, `line` (the exact hook line), `epic`, `why`
  - `edits`: `file`, `epic`, `why`
  - `zen_patches`: `file` (the `.patch` path), `epic`, `why`
  `epic` is `layer` or `eN-slug` (e.g. `e3-little-bb`). layer_lint.py matches by substring of
  the file path, so `file:` values are repo-relative paths, unquoted.
- Header comment in layer.yaml: one line stating the rule from ADR-0002 Решение 2 — a conflict in
  `src/bb/**` belongs to the epic by directory name, anywhere else by this file; a foreign file
  without an entry is a registry defect.
- README.md: English, short (≤ ~80 lines). Layout = the ADR-0002 Решение 1 tree (src/bb, prefs/bb,
  configs/bb, configs/branding/bb, scripts/bb); Hook lines = the ADR table (7 rows: src/zen/moz.build,
  zen-assets.jar.inc.mn, zen-assets.inc.xhtml, ZenPreloadedScripts.js, ZenComponents.manifest,
  configs/common/mozconfig, package.json) with the exact line text; Foreign files = the three
  classes and their mechanisms; layer.yaml = what goes in it. Do not invent anything the ADR
  does not say; cite the ADR file.
- Note in the README that every non-`.patch` file under `src/bb/` (this README too) is symlinked
  into `engine/bb/` by surfer — harmless, the build does not see it.
- No other files. Do not create src/bb/moz.build etc. — that is task 0003.

## Handoff

## Result
Round 1: added `src/bb/layer.yaml` (base block, three empty lists with schema comments, header
rule) and `src/bb/README.md` (Layout, Hook lines, Foreign files, layer.yaml). Verified:
`layer_lint.py 0001` → 0 fail; `grep -c` of the four top-level keys → 4. Not run: the other DoD
greps and diff.sh --names (no build needed; the two files are the only ones changed besides this task file).

## Review
APPROVE
1. Spec: layer.yaml base block, three empty lists and schema comments match the Notes and ADR-0002
   Решение 3 (line 197). The README Layout tree, the 7-row Hook-lines table and the Foreign-files classes
   match ADR-0002 lines 72-109 and 128-138. Nothing invented. The README is 74 lines.
2. Scope: `diff.sh --names` → only src/bb/README.md and src/bb/layer.yaml (DoD 7). No tests touched.
3. Layer: no Zen/Firefox files, prefs or engine/ touched. Nothing to mark.
4. Correctness: n/a (docs and YAML only). The base mapping is plain block style with no quotes, so scripts can read it.
5. Verification: I re-ran the DoD greps the developer left unrun. DoD 1 → 4, DoD 2 → the three exact lines,
   DoD 3 → 3, DoD 6 headings are present and the `src/bb/patches/<epic>/<name>/` grep → 1 (README.md:32).
   layer_lint → 0 fail, 0 warn. The Result honestly says which checks were not run.
6. Hygiene (non-blocking): src/bb/layer.yaml:1 cites "Решение 2" in Cyrillic. That is the ADR's own
   section name, so it is acceptable as a citation. If touched later, "ADR-0002 decision 2" would keep it ASCII.

## QA
PASS
1. Build: type none, skipped. `test.sh lint`: `npm run lint` skipped (no engine/); layer_lint 0 fail, 0 warn.
2. DoD 1: grep -c → 4. DoD 2: the three exact lines (zen 1.23.4b, firefox 158.0.1, commit 541ee55).
3. DoD 3: grep -c → 3. DoD 4: layer.yaml lines 9-29 have a schema comment above each list.
4. DoD 5: layer_lint → no FAIL lines.
5. DoD 6: README has `## Layout` (9), `## Hook lines` (34), `## Foreign files` (48), `## layer.yaml` (64). The `src/bb/patches/<epic>/<name>/` grep matches at line 31.
6. DoD 7: diff.sh --names lists only src/bb/README.md and src/bb/layer.yaml.
