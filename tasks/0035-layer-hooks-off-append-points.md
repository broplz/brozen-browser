---
id: 0035
title: BB hook lines moved off the end of lists upstream appends to; positions recorded in layer.yaml
epic: layer
prefix: layer
kind: feature
role: developer
size: M
status: ready
base: feat/layer
branch: task/0035-layer-hooks-off-append-points
depends_on: []
build: ui
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - src/browser/base/content/zen-assets.jar.inc.mn
  - src/browser/base/content/zen-assets.inc.xhtml
  - src/zen/ZenComponents.manifest
  - src/zen/moz.build
  - src/bb/layer.yaml
  - src/bb/README.md
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0002 (hook table, l.99-108) makes each hook one line in a Zen flat file so a rebase is a plain 3-way merge.
Four of the six hooks sit at the end of a list that upstream appends to, so every upstream append conflicts with
them (seen by the owner in the 0012 setup: ZenComponents.manifest vs Zen's new `media` include; decisions-needed,
"0012 — owner answers round 2"). After this task those four hooks sit where upstream does not append, the two
order-bound hooks stay, and src/bb/layer.yaml records every hook's position and why. Needed before the rebase to
1.24.1b.

## Definition of Done
1. `grep -n "BB(layer)\|bb/jar.inc.mn" src/browser/base/content/zen-assets.jar.inc.mn` → exactly
   `5:# BB(layer): BB layer jar manifest` and `6:#include ../../../bb/jar.inc.mn`; line 7 is empty;
   `tail -n 1` of the file → `#include ../../../zen/library/jar.inc.mn`.
2. `grep -n "BB(layer)\|BBComponents" src/zen/ZenComponents.manifest` → exactly `5:# BB(layer): BB layer components`
   and `6:#include ../bb/BBComponents.manifest`; line 7 empty; `tail -n 1` → `#include media/MediaComponents.manifest`.
3. `grep -n "BB(layer)\|\.\./bb" src/zen/moz.build` → exactly `5:# BB(layer): plug the BB layer into the build` and
   `6:DIRS += ["../bb"]`; line 7 empty; `tail -n 1` → `]`.
4. `grep -n "linkset>\|BB(layer)\|bb-assets" src/browser/base/content/zen-assets.inc.xhtml` → `8:<linkset>`,
   `31:</linkset>`, `32:# BB(layer): BB layer assets`, `33:#include ../../../bb/bb-assets.inc.xhtml`;
   `tail -n 1` → the `ZenPreloadedScripts.js` `<script>` line.
5. `grep -c "^    position:" src/bb/layer.yaml` → `6`; the schema comment above `hooks:` documents `position:`;
   every `line:` value is unchanged (`git diff` of layer.yaml has no `line:` lines).
6. src/bb/README.md, next to the hook table: one rule — a new hook goes where upstream does not append (top of
   the file after the license header, or after a closing tag), except when load order requires the end; the
   reason goes into `position:`/`why:` in layer.yaml.
7. `python3 scripts/agents/layer_lint.py tasks/0035-layer-hooks-off-append-points.md` → `0 fail`.
8. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`.
9. `scripts/agents/diff.sh tasks/0035-layer-hooks-off-append-points.md --names` lists only allowed_paths and the
   task file (in particular not `src/zen/common/ZenPreloadedScripts.js` or `configs/common/mozconfig`).

## Notes from teamlead
- Move = delete the 2-line block (marker + hook) at the end, insert it at the new place. Text of both lines
  unchanged. Keep the marker comment syntax of each file (`#` preprocessor comments in .mn/.manifest/.inc.xhtml,
  `#` in moz.build).
- Positions (decided; do not re-derive):
  | file | new place | why |
  | --- | --- | --- |
  | zen-assets.jar.inc.mn | lines 5-6, right after the license header, blank line after | jar includes are order-free |
  | ZenComponents.manifest | lines 5-6, right after the license header, blank line after | BBComponents.manifest is empty; a future BB override of a Zen contract must not rely on order — note it in `why:` |
  | src/zen/moz.build | lines 5-6, before `EXTRA_PP_COMPONENTS` | DIRS order is free for src/bb (jar + manifest only) |
  | zen-assets.inc.xhtml | right after `</linkset>` (l.31) | BB CSS must load after Zen's CSS (cascade); upstream adds `<link>`s inside the linkset, so one unchanged line separates the hunks |
  | ZenPreloadedScripts.js | unchanged | ADR-0002 l.106: BBStartup.mjs must be last in `scripts` |
  | configs/common/mozconfig | unchanged | BB flags must override Zen's: sourced last; a conflict on upstream appends is expected |
- layer.yaml: add `position:` to each of the six hook entries (after `line:`), values `top`, `top`, `top`,
  `after-linkset`, `last-in-scripts`, `end`; extend `why:` of the last two with the reason they stay. Add
  `#   position: <where the line sits and why it must>` to the entry schema comment. Do not change `line:`/`epic:`;
  rebase.sh `registry_pairs` reads only `file`/`epic`.
- No Zen `.patch`, no change to src/browser/base/moz-build.patch. Plain edits of class-2 flat files only.
- needs_approval: hook changes in Zen files (owner's item).

## Handoff

## Result

## Review

## QA
