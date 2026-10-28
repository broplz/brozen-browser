---
id: 0003
title: src/bb/ skeleton (moz.build, jar.inc.mn, bb-assets.inc.xhtml, BBStartup.mjs, BBComponents.manifest) + prefs/bb/bb.yaml
epic: layer
prefix: layer
kind: feature
role: developer
size: S
status: approved
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
returns: 1
sessions: 0
reviewed_sha: 783ec8ef4d8b324e209c248e8a1c79ab901545b9
qa_sha: 783ec8ef4d8b324e209c248e8a1c79ab901545b9
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
Round 2: fixed Review item 1 — `src/bb/bb-assets.inc.xhtml` now uses the `# ` preprocessor header
and placeholder comment, as in `zen-assets.inc.xhtml`. Not re-run: lint/layer_lint (comment-only
change in a non-linted file).

Round 1: added the six allowed files (jar.inc.mn with one BBStartup entry, BBStartup.mjs logging
`BBStartup: bb.layer.version=<n>`, header+comment-only moz.build / bb-assets.inc.xhtml /
BBComponents.manifest, prefs/bb/bb.yaml with bb.layer.version = 1). Verified: `test.sh lint` OK
(0 problems); `layer_lint.py 0003` 0 fail (1 size WARN: 6 files vs cap 5, no production lines).
Nothing reaches the build until task 0013. Open: none.

## Review
APPROVE

Checklist notes (round 2):
- Spec/DoD: round-1 item 1 is fixed. src/bb/bb-assets.inc.xhtml:1-5 now has the three `# ` MPL
  lines and a `# ` placeholder, as in zen-assets.inc.xhtml. DoD 1–4 and 7 still hold (6 files, 33 lines).
- Scope: only the six allowed_paths changed. No Zen files, layer.yaml or tests touched.
- Layer: layer_lint re-run gives 0 fail and 1 size WARN. The WARN comes from the teamlead's
  allowed_paths (6 files vs the S cap of 5). There are no class-2/3 edits and the pref is `bb.*`
  only. Nothing reaches the build yet (F2 holds).
- Correctness: unchanged since round 1. BBStartup.mjs only logs the one line, with no listeners
  and no async work.
- Verification: the Result says lint was not re-run for the comment-only change, and that is
  accurate. Every `#` line in a preprocessed include is stripped, so the risk is negligible.
- Hygiene: no TODOs or secrets, and everything is in English.

---
REQUEST_CHANGES
1. src/bb/bb-assets.inc.xhtml:1-5 — the MPL header and the placeholder comment use XML comments
   (`<!-- … -->`). The teamlead note says to copy the header from the neighbouring Zen file of the
   same type. That file, `src/browser/base/content/zen-assets.inc.xhtml:1-3`, uses preprocessor
   `# ` lines, and no file under src/zen or src/browser/base/content has an XML-style MPL header.
   This file is `#include`d into the preprocessed browser.xhtml (task 0013). Because of that,
   `<!-- -->` comments would ship in the built markup, while `# ` comments are stripped at
   preprocessing. Fix: use the same three `# ` header lines as zen-assets.inc.xhtml, and write
   the placeholder as `# <link rel="stylesheet"> elements for BB CSS go here (none yet).`

Checklist notes:
- Spec/DoD: DoD 1 holds (one entry, same `(` column as src/zen/folders/jar.inc.mn). DoD 2 holds
  (`console.info` with `getIntPref("bb.layer.version", 0)`). DoD 3 holds (only `bb.layer.version`,
  value 1, no sticky/condition). DoD 4 holds except item 1. DoD 6 re-run: 0 fail. DoD 7 holds: 6 files.
- Scope: only the six allowed_paths. No Zen files, layer.yaml or tests touched.
- Layer: no class-2/3 edits, so no BB(eN) markers needed. Pref is `bb.*` only. Nothing is in
  engine/. Nothing reaches the build yet, so stock Zen behaviour is unchanged (F2).
- Correctness: BBStartup.mjs runs in the window global (`global: "current"`), so `Services` is
  available. It adds no listeners and has no async work.
- Verification: the Result claims match my layer_lint re-run. The size WARN (6 files vs the S cap
  of 5) comes from the teamlead's allowed_paths, not from the developer.
- Hygiene: no TODOs or secrets, English only, one intended log line.

## QA
PASS

1. DoD 1: `src/bb/jar.inc.mn` has one entry, `content/browser/bb/BBStartup.mjs … (../../bb/BBStartup.mjs)`, in Zen's column style.
2. DoD 2: `src/bb/BBStartup.mjs:5-7` is a `console.info` of `BBStartup: bb.layer.version=${Services.prefs.getIntPref("bb.layer.version", 0)}`.
3. DoD 3: `prefs/bb/bb.yaml` has `- name: bb.layer.version` and `value: 1`. The only `name:` line in prefs/bb/ is `bb.*`, so the non-bb count is 0.
4. DoD 4: moz.build, bb-assets.inc.xhtml and BBComponents.manifest each hold the MPL header (`# ` lines) plus one comment.
5. DoD 5: `scripts/agents/test.sh lint` → OK, 0 problems. Log: logs/test-lint-20261029-011819.log.
6. DoD 6: layer_lint → 0 fail, 1 size WARN (6 files vs cap 5, from the task's allowed_paths).
7. DoD 7: `diff.sh --names` lists exactly the six allowed files (33 insertions).
Build type is none, so no build was run.

For the human: nothing marked `[human]`.
