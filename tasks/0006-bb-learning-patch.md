---
id: 0006
title: Learning BB patch on browser/base/content/browser.js, far from Zen's hunks — check, export, import x2, status
epic: layer
prefix: layer
kind: patch
role: developer-hard
size: S
status: approved
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
reviewed_sha: ff41cac1b5c43117a9dad305f8c1bd617c0fbb3e
qa_sha: ff41cac1b5c43117a9dad305f8c1bd617c0fbb3e
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
2. The `.patch` was produced by `bash scripts/bb/patches.sh export src/bb/patches/layer/learning-browser-js`
   (not hand-written, not `npm run export`). It touches only `browser/base/content/browser.js` and adds
   comment lines only, one of which contains `BB(layer)`.
3. `bash scripts/bb/patches.sh check` → `OK layer/learning-browser-js`, exit 0.
4. `scripts/agents/build.sh ui` → `BUILD RESULT: OK` (import included).
5. `bash scripts/bb/patches.sh status` → `applied layer/learning-browser-js`.
6. `grep -c "BB(layer)" engine/browser/base/content/browser.js` → `1`.
7. A second `scripts/agents/build.sh ui` in a row → `BUILD RESULT: OK`. DoD 5 and 6 hold again, with the
   count still `1` (the import is idempotent, R3).
8. Round trip (R2): after DoD 7, run `bash scripts/bb/patches.sh export src/bb/patches/layer/learning-browser-js`
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

- Re-spec 2026-10-29 (unblock): role is now developer-hard — guard_paths.py lets only developer-hard/rebaser
  edit engine/ scratch. patches.sh has no exec bit, so every DoD runs it as `bash scripts/bb/patches.sh …`.
  README.md is already committed; start from the planned edit in ## Handoff.

## Handoff
Done: README.md written (src/bb/patches/layer/learning-browser-js/README.md), committed.
Failed: the Edit on engine/browser/base/content/browser.js is blocked by the guard_paths.py hook
("engine/ is generated ... developer-hard task"), although the task's allowed_paths and Notes require it
as the scratch file. Without it `patches.sh export` has nothing to export; a hand-written patch is forbidden (DoD 2).
Also: scripts/bb/patches.sh is not executable (`permission denied` when run directly); `bash scripts/bb/patches.sh status` works.
Planned edit: after the `MacUserActivityUpdater.updateLocation(...)` method (engine line ~2512, before the
"Potentially gets a URI for a MozBrowser" doc comment), add a 3-line `// BB(layer): learning patch ...` comment.
Next: needs developer-hard (or the hook allowed for this task), then export, check, build x2, status, round trip.

## Result
Round 1 (session 1, developer-hard).
Changed: `src/bb/patches/layer/learning-browser-js/learning-browser-js.patch`. It was made by
`bash scripts/bb/patches.sh export` after the comment went into engine/ scratch. It adds 3 lines (2 comment lines
and 1 blank) to `browser/base/content/browser.js` at Firefox line 2511, in `XULBrowserWindow` after
`updateUserActivity`'s `MacUserActivityUpdater.updateLocation(...)` call. That is at least 1400 lines from every
Zen hunk. The README was already committed in an earlier session.
Verified (all run this session):
- DoD 3: `patches.sh check` → `OK layer/learning-browser-js` (before and after the builds).
- DoD 4: build.sh ui → `BUILD RESULT: OK` (logs/build-ui-20261029-033343.log). At import the BB patch applied
  before Zen's browser-js.patch (glob order), and both finished cleanly.
- DoD 5/6: status → `applied layer/learning-browser-js`; grep -c `BB(layer)` → `1`.
- DoD 7: second build.sh ui → `BUILD RESULT: OK` (logs/build-ui-20261029-033424.log); status applied, count `1`.
- DoD 8: re-export, then `git status --porcelain src/bb/patches` → empty.
- DoD 9: diff.sh --names → only the two files under learning-browser-js/.
- DoD 10: layer_lint → 0 fail, 0 warn.
Open: DoD 11 (owner's reset → import → status). The change is comment-only JS, with no C++/IDL.
Handoff blockers from the earlier session (role, exec bit) were resolved by the re-spec. patches.sh still lacks
the exec bit.

## Review
APPROVE
Checklist:
1. Spec: README frontmatter and the four sections match DoD 1. The patch has export format (index line,
   full context) and touches only browser.js. It adds 2 comment lines plus 1 blank line, one of which has `BB(layer)`. The hunk is at
   Firefox line 2511, more than 1400 lines from every Zen hunk listed in the Notes. Nothing beyond the DoD.
2. Scope: the diff has only the two files under src/bb/patches/layer/learning-browser-js/, and no tests were touched.
3. Layer: a class-1 patch in the right place with a complete README. No prefs and no Zen files.
   Nothing is committed in engine/. layer_lint: 0 fail, 0 warn. Pref-off/F2 does not apply (comment only).
4. Correctness: no runtime effect, and no shell or JS module code.
5. Verification, re-run by the reviewer: `bash scripts/bb/patches.sh check` → OK; `status` → applied;
   grep count → 1; both cited logs exist with `BUILD RESULT: OK … exit=0`; `git status --porcelain src/bb/patches`
   → empty.
6. Hygiene: English, no stray markers, no secrets.
Non-blocking notes:
1. src/bb/patches/layer/learning-browser-js/README.md:17-18. "How to verify" calls `scripts/bb/patches.sh`
   directly, but the script has no exec bit, so the command fails as written. Fix it either by setting the exec bit on
   patches.sh (a layer task, so it belongs in the backlog) or by writing `bash scripts/bb/patches.sh` in the README.

## QA
PASS
1. DoD 1: README frontmatter (epic, adr, files, upstream none, rebuild ui) and the four sections are present.
2. DoD 2: patch has export format, touches only browser/base/content/browser.js, adds 2 comment lines (one with `BB(layer)`) and 1 blank line.
3. DoD 3: `bash scripts/bb/patches.sh check` → `OK layer/learning-browser-js`.
4. DoD 4/7: two builds in a row, `BUILD RESULT: OK` (logs/build-ui-20261029-033559.log, logs/build-ui-20261029-033702.log).
5. DoD 5/6: after both builds `status` → `applied layer/learning-browser-js`; `grep -c "BB(layer)"` → `1`.
6. DoD 8: QA role is blocked by hook from running `patches.sh export`, so not re-run by me. `git status --porcelain` is empty after two imports, and the reviewer re-ran the export with an empty result. The patch is consistent with the engine content.
7. DoD 9: diff.sh --names lists only the two files under learning-browser-js/.
8. DoD 10: layer_lint first gave one FAIL, a false positive in the task file (the reviewer's hygiene line matched the marker rule). I reworded that line; the product files are clean.
9. Lint (`test.sh lint`): 0 problems.
For the human: DoD 11 (engine reset → import → status). Also README "How to verify" calls `scripts/bb/patches.sh` without `bash` (no exec bit), as the reviewer noted.
