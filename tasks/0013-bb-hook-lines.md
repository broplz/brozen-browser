---
id: 0013
title: The five hook lines that plug src/bb/ into Zen's build + their layer.yaml entries
epic: layer
prefix: layer
kind: feature
role: developer
size: S
status: ready
base: feat/layer
branch: task/0013-bb-hook-lines
depends_on: [0001, 0003]
build: ui
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - src/zen/moz.build
  - src/browser/base/content/zen-assets.jar.inc.mn
  - src/browser/base/content/zen-assets.inc.xhtml
  - src/zen/common/ZenPreloadedScripts.js
  - src/zen/ZenComponents.manifest
  - src/bb/layer.yaml
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-1--структура-слоя-bb
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Add the five one-line hooks from ADR-0002 Решение 1 (hook table) to Zen's flat files so the
`src/bb/` skeleton from task 0003 reaches the build, and register each hook in
`src/bb/layer.yaml: hooks`. This completes ADR-0002 план проверки п.1: after import + ui build,
`bb.*` prefs are in about:config and the Browser Console shows the BBStartup line.
(Second half of backlog item 0003.)

## Definition of Done
1. Each of the five Zen files gains exactly the hook line plus at most one `BB(layer)` marker
   line, nothing removed or reformatted; `scripts/agents/diff.sh 0013` shows ≤ 2 added and 0
   removed lines per Zen file, plus the layer.yaml entries.
2. `grep -c "file: src/" src/bb/layer.yaml` → `5`, one `hooks` entry per file, `epic: layer`,
   `line:` = the exact hook line.
3. `python3 scripts/agents/layer_lint.py 0013` → no FAIL lines.
4. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`.
5. `grep -n "bb.layer.version" engine/browser/app/profile/zen.js` → one `pref("bb.layer.version", 1…` line.
6. `scripts/agents/test.sh lint` → no new errors.
7. [human] `about:config`, search `bb.` → `bb.layer.version = 1`.
8. [human] Browser Console after startup shows `BBStartup: bb.layer.version=1`, with no new
   errors mentioning `bb/`.

## Notes from teamlead
- Hook lines, exact text (ADR-0002 Решение 1 table), each in its own file, marker on the same line
  or the line directly above (layer_lint needs `BB(` on an added line):
  | file | line | placement |
  |---|---|---|
  | `src/zen/moz.build` | `DIRS += ["../bb"]` | new statement after Zen's `DIRS += [...]` block; marker `# BB(layer): ...` |
  | `src/browser/base/content/zen-assets.jar.inc.mn` | `#include ../../../bb/jar.inc.mn` | last line; marker as a `# BB(layer)` comment line above (jar.mn `#` + space = comment) |
  | `src/browser/base/content/zen-assets.inc.xhtml` | `#include ../../../bb/bb-assets.inc.xhtml` | last line; marker `<!-- BB(layer): ... -->` above |
  | `src/zen/common/ZenPreloadedScripts.js` | `"chrome://browser/content/bb/BBStartup.mjs",` | LAST element of the `scripts` array (after `ZenShareManager.mjs`); `// BB(layer): must stay last` on the same line |
  | `src/zen/ZenComponents.manifest` | `#include ../bb/BBComponents.manifest` | after the last `#include`; marker `# BB(layer)` above |
  "≤ ~10 lines" rule: the marker line counts — keep it to the hook + one marker per file.
- The `configs/common/mozconfig` and `package.json` hooks are NOT part of this task (0004, later).
- These are Zen flat files (class 2): plain edits. A `.patch` for them is forbidden, `npm run export`
  is forbidden, nothing under `engine/` is a deliverable.
- `layer.yaml`: append to `hooks:` (replace `[]` with block entries), schema from task 0001's
  comments: `file`, `line`, `epic: layer`, `why`. Do not touch `base`, `edits`, `zen_patches`.
- Build risk: a new `DIRS` entry and new jar.mn lines may need the build backend regenerated, which
  `build.sh ui` might not do. If the ui build is OK but `chrome://browser/content/bb/BBStartup.mjs`
  fails to load (console error) or `engine/bb` is not picked up, do not switch to `full` yourself:
  write it in ## Handoff (what you saw, log path) and set blocked — the teamlead re-specs to `build: full`.
  Same if mozbuild rejects `"../bb"` in DIRS.
- Strikes: 3 failed ui builds → Handoff, blocked.

## Handoff

## Result

## Review

## QA
