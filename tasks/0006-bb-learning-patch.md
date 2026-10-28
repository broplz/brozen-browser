---
id: 0006
title: Learning BB patch on browser/base/content/browser.js, far from Zen's hunks — check, export, import x2, status
epic: layer
prefix: layer
kind: patch
role: developer
size: S
status: ready
base: feat/layer
branch: task/0006-bb-learning-patch
depends_on: [0013, 0005]
build: ui
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - src/bb/patches/layer/learning-browser-js/learning-browser-js.patch
  - src/bb/patches/layer/learning-browser-js/README.md
  - engine/browser/base/content/browser.js
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#риски-и-план-проверки-фаза-0-до-7-ноября
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Run ADR-0002 план проверки п.2: author the first BB patch, a learning one, on `browser/base/content/browser.js`
(a Firefox file Zen also patches), far from Zen's hunks. Take it through the full path:
`patches.sh check` → `patches.sh export` → import → `patches.sh status`, then a second import in a row.
This closes R2 (the exported patch applies at import) and R3 (glob order does not break a repeated import).
The reset → import leg is the owner's, because agents may not reset the engine.

## Definition of Done
1. `src/bb/patches/layer/learning-browser-js/README.md` has frontmatter with `epic: layer`,
   `adr: docs/adr/0002-bb-layer-and-rebase-runbook.md`, `files:` = `- browser/base/content/browser.js`,
   `upstream: none` and `rebuild: ui`, followed by the four sections `# Why`, `# What it changes`,
   `# How to verify` and `# What usually breaks on rebase`.
2. The `.patch` was produced by `scripts/bb/patches.sh export src/bb/patches/layer/learning-browser-js`
   (not hand-written, not `npm run export`). It touches only `browser/base/content/browser.js` and adds
   comment lines only, one of which contains `BB(layer)`.
3. `scripts/bb/patches.sh check` → `OK layer/learning-browser-js`, exit 0.
4. `scripts/agents/build.sh ui` → `BUILD RESULT: OK` (import included).
5. `scripts/bb/patches.sh status` → `applied layer/learning-browser-js`.
6. `grep -c "BB(layer)" engine/browser/base/content/browser.js` → `1`.
7. A second `scripts/agents/build.sh ui` in a row → `BUILD RESULT: OK`. DoD 5 and 6 hold again, with the
   count still `1` (the import is idempotent, R3).
8. Round trip (R2): after DoD 7, run `scripts/bb/patches.sh export src/bb/patches/layer/learning-browser-js`
   again. `git status --porcelain src/bb/patches` then prints nothing, so export reproduced the committed patch byte for byte.
9. `scripts/agents/diff.sh tasks/0006-bb-learning-patch.md --names` lists only the two files under
   `src/bb/patches/layer/learning-browser-js/`.
10. `python3 scripts/agents/layer_lint.py 0006` → no FAIL lines.
11. [human] The owner runs the engine reset → `npm run import` → `scripts/bb/patches.sh status` → `applied
    layer/learning-browser-js`, with no import errors (ADR п.2 last leg).

## Notes from teamlead
- Zen's hunks in `src/browser/base/content/browser-js.patch` start (in Firefox line numbers) at 34, 852,
  3985, 4025, 4050, 4763, 4791 and 4976. Place the BB hunk at least 200 lines away from every one of them,
  for example between Firefox lines 1500 and 3500. Firefox line N = engine line N minus the lines Zen added above it.
  Just check with `patches.sh check`.
- Content: a comment block only (2–4 lines), with no runtime effect, e.g.
  `// BB(layer): learning patch, ADR-0002 план проверки п.2 — see src/bb/patches/layer/learning-browser-js/README.md`.
  It may stay in the product, so it must be harmless and self-explaining.
- Authoring flow: `engine/browser/base/content/browser.js` is scratch. Edit it with the Edit tool (Read it with
  offset/limit only; it is about 5000 lines), then run `patches.sh export`. engine/ is never a deliverable, and
  it is git-ignored in this repo. Write README.md first: export reads `files:` from it.
- Forbidden here: `npm run export` (it would merge the BB hunk into Zen's browser-js.patch), editing
  `browser-js.patch`, `npm run import`/the import tool directly (build.sh does the import), and resetting the engine
  (the owner's DoD 11).
- If `check` reports `FAIL … zen`, the hunk is too close to Zen's. Move it. Do not touch Zen's patch.
- Strikes: 3 failed ui builds → write the Handoff and set status blocked. If `status` says not-applied after a green
  import, that is R2 materialising: Handoff with the import part of the build log triage, set status blocked. Do not work around it.

## Handoff

## Result

## Review

## QA
