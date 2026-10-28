---
id: 0013
title: The five hook lines that plug src/bb/ into Zen's build + their layer.yaml entries
epic: layer
prefix: layer
kind: feature
role: developer
size: S
status: done
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
returns: 1
sessions: 0
reviewed_sha: 602cdf102d246f0c99cf8b77a2366f3dfd337e20
qa_sha: 602cdf102d246f0c99cf8b77a2366f3dfd337e20
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
Round 2
- Review item 1 fixed: marker in zen-assets.inc.xhtml is now a preprocessor `# BB(layer): BB layer assets` line instead of an XML comment. Nothing else changed. No build rerun (comment-only change in a preprocessed line, stripped at build).

Round 1
- Added the five hook lines (each with one `BB(layer)` marker line; on the same line for ZenPreloadedScripts.js) to the Zen flat files. 0 lines removed. Registered all five in `src/bb/layer.yaml: hooks` (epic layer).
- Verified: `layer_lint.py 0013` 0 fail (1 size warn: 6 files vs cap 5, layer.yaml counted); `build.sh ui` BUILD RESULT: OK (42s); `grep bb.layer.version engine/browser/app/profile/zen.js` → `pref("bb.layer.version", 1);`; `test.sh lint` OK, 0 problems.
- Not verified (human DoD 7, 8): about:config value and Browser Console BBStartup line; I did not launch the browser. If chrome://browser/content/bb/BBStartup.mjs fails to load, the build backend may need a full build.

## Review
APPROVE
Round 2 checklist notes:
- Item 1 is fixed. src/browser/base/content/zen-assets.inc.xhtml:42 is now `# BB(layer): BB layer assets`,
  a preprocessor comment that gets stripped. Since reviewed_sha the only code change is that one line
  (`git diff --stat 3b7d16d..HEAD`).
- Spec/scope/layer: same as round 1. There are 5 exact hook lines, each Zen file has ≤ 2 added and 0
  removed lines, only allowed_paths are touched, and every hunk carries a BB(layer) marker plus a
  layer.yaml `hooks` entry. There is no .patch, nothing in engine/, and no prefs.
- layer_lint re-run: 0 fail, 1 size WARN. The task's own file list (6 paths) makes that warning unavoidable.
- Verification: the developer did not re-run the build for the comment-only change. That is acceptable
  because `# ` lines are stripped by the preprocessor. qa runs the build. DoD 7 and 8 stay [human].

---
REQUEST_CHANGES
1. src/browser/base/content/zen-assets.inc.xhtml:42 — the marker `<!-- BB(layer): BB layer assets -->`
   is an XML comment. This file goes through the Mozilla preprocessor, so the comment would end up
   in the built browser.xhtml. Every other comment in this file (lines 1-3, 7, 33-40) is a `# ` line,
   and the preprocessor strips those. Replace it with `# BB(layer): BB layer assets` (layer_lint only
   needs `BB(` on an added line). The teamlead note asked for `<!-- -->` here, but that note is wrong:
   0003 round 1 was returned for this same defect in bb-assets.inc.xhtml.

Checklist notes:
- Spec/DoD: all five hook lines match ADR-0002 Решение 1 exactly. Each Zen file gets ≤ 2 added and 0
  removed lines. BBStartup.mjs is the last element of `scripts`. configs/common/mozconfig was not
  touched (that belongs to 0004). I re-ran the checks: `grep -c "file: src/" src/bb/layer.yaml` → 5,
  and `grep bb.layer.version engine/browser/app/profile/zen.js` → `pref("bb.layer.version", 1);`.
- Scope: only allowed_paths were touched. No tests changed.
- Layer: these are class 2 plain edits. Every added hunk has a BB(layer) marker and a layer.yaml
  `hooks` entry. There is no .patch file, nothing in engine/ and no new prefs. With bb.* prefs off,
  BBStartup controls the stock behaviour, so this task does not affect F2. In layer.yaml the
  ZenPreloadedScripts entry's `line:` includes the same-line marker. That is acceptable because it
  is the exact text of the file line.
- layer_lint: 0 fail. It gives 1 size WARN (6 files with layer.yaml counted), which the
  teamlead's own file list makes unavoidable.
- Result: the claims I could check are real. The human items (DoD 7, 8) are honestly marked as
  not verified.

## QA
PASS
1. DoD 1: `scripts/agents/diff.sh 0013` (the script wants a task file path, so I ran it with the id and then read the printed diff). Each Zen file has exactly 2 added and 0 removed lines, apart from ZenPreloadedScripts.js with 1 added. The only removal is `hooks: []` in layer.yaml, which the task allows.
2. DoD 2: `grep -c "file: src/" src/bb/layer.yaml` → 5. Every entry has `epic: layer` and the exact hook line.
3. DoD 3: `layer_lint.py 0013` → 0 fail, 1 size warn (6 files against the cap of 5). The warn comes from the task's own file list.
4. DoD 4: `build.sh ui` → `BUILD RESULT: OK` (45s). Log: logs/build-ui-20261029-012251.log.
5. DoD 5: `grep -n "bb.layer.version" engine/browser/app/profile/zen.js` → `11:pref("bb.layer.version", 1);`.
6. DoD 6: `test.sh lint` → `TEST RESULT: OK`, 0 problems. Log: logs/test-lint-20261029-012339.log.

For the human: DoD 7 (about:config `bb.layer.version = 1`) and DoD 8 (Browser Console `BBStartup: bb.layer.version=1`, no new `bb/` errors). I did not launch the browser. If `chrome://browser/content/bb/BBStartup.mjs` fails to load, the teamlead re-specs this task to a full build.
