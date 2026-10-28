---
id: 0003
title: src/bb/ skeleton (moz.build, jar.inc.mn, bb-assets.inc.xhtml, BBStartup.mjs, BBComponents.manifest) + prefs/bb/bb.yaml
epic: layer
prefix: layer
kind: feature
role: developer
size: S
status: ready
base: feat/layer
branch: task/0003-bb-skeleton
depends_on: [0001]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - src/bb/moz.build
  - src/bb/jar.inc.mn
  - src/bb/bb-assets.inc.xhtml
  - src/bb/BBStartup.mjs
  - src/bb/BBComponents.manifest
  - prefs/bb/bb.yaml
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#риски-и-план-проверки-фаза-0-до-7-ноября
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Create the BB layer's build entry files in `src/bb/` and the first BB pref, per ADR-0002
Решение 1 and план проверки п.1. This task adds only BB-owned files; nothing reaches the build
yet — the five hook lines in Zen's files are task 0013 (backlog item 0003 split: 12 files exceed
the M cap). After 0013, `BBStartup.mjs` is the last script Zen preloads and logs one line.

## Definition of Done
1. `src/bb/jar.inc.mn` contains exactly one entry line, matching
   `content/browser/bb/BBStartup.mjs` … `(../../bb/BBStartup.mjs)` (Zen's column style, see
   `src/zen/folders/jar.inc.mn`).
2. `grep -n "BBStartup" src/bb/BBStartup.mjs` shows a `console.info` call whose output is
   `BBStartup: bb.layer.version=<n>` with `<n>` read via `Services.prefs.getIntPref("bb.layer.version", 0)`.
3. `prefs/bb/bb.yaml` contains `- name: bb.layer.version` and `value: 1`;
   `grep -rh "name:" prefs/bb/ | grep -v -c "name: bb\."` → `0`.
4. `src/bb/moz.build`, `src/bb/bb-assets.inc.xhtml`, `src/bb/BBComponents.manifest` exist and
   contain only the MPL header plus one comment saying what goes there (no entries yet).
5. `scripts/agents/test.sh lint` → no new errors in src/bb/ or prefs/bb/.
6. `python3 scripts/agents/layer_lint.py 0003` → no FAIL lines.
7. `scripts/agents/diff.sh tasks/0003-bb-skeleton.md --names` lists only the six allowed files.

## Notes from teamlead
- File roles (ADR-0002 Решение 1):
  - `moz.build` — will hold `DIRS` of BB modules; none exist yet → header + comment only.
    jar entries do NOT go here: `jar.inc.mn` is `#include`d from Zen's `zen-assets.jar.inc.mn`.
  - `jar.inc.mn` — chrome paths `chrome://browser/content/bb/...`. Source paths are relative to
    `engine/browser/base/jar.mn`, hence `(../../bb/...)`, same as Zen's `(../../zen/...)`.
  - `bb-assets.inc.xhtml` — future `<link rel="stylesheet">` for BB CSS; empty for now.
  - `BBComponents.manifest` — future actors/components; empty for now. It is preprocessed
    (included into `ZenComponents.manifest`, an `EXTRA_PP_COMPONENTS`) — copy the comment/header
    style of `src/zen/ZenComponents.manifest` exactly, nothing else.
  - `BBStartup.mjs` — loaded by `ChromeUtils.importESModule(url, { global: "current" })` from
    `src/zen/common/ZenPreloadedScripts.js` (window global, after every `gZen*`). Today it only
    logs the one line. Later it loads feature modules by `bb.<feature>.enabled` prefs — do not
    write that loader now (no modules exist).
- Pref value: `bb.layer.version` = integer `1` (teamlead choice; ADR names the pref, not the value).
  YAML format: mirror `prefs/zen/watermark.yaml` (MPL header, `- name:` / `value:`), no `sticky`,
  no `condition`. Only `bb.*` names in `prefs/bb/` — a Zen pref name there is forbidden
  (ffprefs ordering is undefined for duplicates).
- License headers: MPL 2.0, copied from the neighbouring Zen file of the same type.
- Do not touch any Zen file or layer.yaml in this task.

## Handoff

## Result

## Review

## QA
