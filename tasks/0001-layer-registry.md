---
id: 0001
title: src/bb/layer.yaml registry (base, hooks, edits, zen_patches) + src/bb/README.md
epic: layer
prefix: layer
kind: docs
role: developer
size: S
status: ready
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
reviewed_sha:
qa_sha:
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

## Review

## QA
