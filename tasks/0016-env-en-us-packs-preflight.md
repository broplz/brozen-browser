---
id: 0016
title: build.sh preflight (Node major = .nvmrc, gnu-tar present) and an en-US packs step after import
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: done
base: feat/layer
branch: task/0016-env-en-us-packs-preflight
depends_on: []
build: ui
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/agents/build.sh
  - scripts/agents/tests/build_preflight_test.sh
  - docs/notes/README.md
  - tasks/backlog.md
spec: tasks/backlog.md
returns: 0
sessions: 0
reviewed_sha: 7a97b28aa7607cffdd4a77fe4dac108f2655a92b
qa_sha: 7a97b28aa7607cffdd4a77fe4dac108f2655a92b
blocked_reason: 
---
## Goal
Found 2026-10-29: after `npm run import` the engine has no Zen en-US strings until `python3 scripts/update_en_US_packs.py`
runs (empty UI labels, no shortcuts), and Node 25 breaks `surfer import` (async-icns rmdir) while `.nvmrc` pins 22. After
this task `scripts/agents/build.sh` refuses to start with the wrong Node major or without gnu-tar, and copies the en-US
packs right after every import, so every agent build and qa run gets a usable UI.

## Definition of Done
1. `bash -n scripts/agents/build.sh` → no output.
2. `bash scripts/agents/tests/build_preflight_test.sh` → last line `PASS`, exit 0. The test uses a `mktemp -d` dir `$T`,
   a stub PATH dir first in `PATH` and `BB_LOG_DIR=$T/logs`, and asserts with a message on failure:
   a. stub `node` prints `v25.1.0` → `build.sh ui` exits 2, stdout/stderr contains `Node 22` (the `.nvmrc` value) and
      `nvm use`; the stub `npm` (logs argv to `$T/calls`) was never called; no `$T/logs/.build.lock` left behind;
   b. stub `node` prints `v22.11.0`, `gtar` absent from the stub PATH and `BB_GTAR=$T/no-such-gtar` → exits 2,
      output contains `gnu-tar` and `brew install gnu-tar`; npm never called;
   c. the test removes `$T` on exit (trap).
3. `scripts/agents/build.sh ui` → `BUILD RESULT: OK`; the log has `===== en-US-packs` with footer `en-US-packs: exit 0`
   between the `import` and `build-ui` steps.
4. `scripts/agents/build.sh ui --no-import` log has no `en-US-packs` step.
5. `docs/notes/README.md` has a short `## Build environment` entry: Node 22 per `.nvmrc` (Node 25 breaks surfer import),
   gnu-tar required, en-US packs are copied by build.sh after import (`scripts/update_en_US_packs.py`).
6. `scripts/agents/diff.sh tasks/0016-env-en-us-packs-preflight.md --names` lists only allowed_paths.

## Notes from teamlead
- Preflight goes before the lock (`LOCK=…`), after argument parsing: a wrong environment must not take the build lock.
  Exit code 2 (build.sh already uses 3 = full build denied, 4 = lock busy; document 2 in the header comment).
- Node: compare the major of `node --version` (`v22.11.0` → `22`) with the first line of `$ROOT/.nvmrc` (currently `22`).
  Message: `Node <found> but .nvmrc wants <want>: run nvm use (Node 25 breaks surfer import)`. Missing `node` = same exit 2.
- gnu-tar: `command -v "${BB_GTAR:-gtar}"`; message names `brew install gnu-tar`. Same variable name as `scripts/bb/rebase.sh`.
- One table + one loop is not needed for two checks; one `preflight()` function with two guarded early returns is enough.
- en-US step: `step "en-US-packs" python3 scripts/update_en_US_packs.py || RC=$?` inside the existing `IMPORT=1` branch,
  right after `import`, only if import succeeded. The script writes `engine/browser/locales/<code>/` using paths relative
  to the cwd; build.sh already `cd`s to `$ROOT`. Do not edit `scripts/update_en_US_packs.py` or `copy_language_pack.py` (Zen's).
- `BB_JOBS` already exists in build.sh; leave the build commands as they are.
- Out of scope, add one line each under "Found by agents" in tasks/backlog.md: the same en-US step in `scripts/bb/rebase.sh`
  `import` step (ADR-0002 step 8) and in the driver's environment init (`scripts/agents/run_task.py` / night.sh). Do not
  edit those files.
- If the hook denies editing `scripts/agents/build.sh` for role developer: Handoff + blocked, do not work around it.
- macOS bash 3.2, no arrays (header of build.sh says so).

## Result
Round 1:
- build.sh: `preflight()` (Node major vs `.nvmrc`, `BB_GTAR`/gtar) runs after arg parsing, before the lock, exit 2; header documents 2. `en-US-packs` step runs right after a successful `import` (inside the `IMPORT=1` branch).
- New `scripts/agents/tests/build_preflight_test.sh` (stub node/npm, trap cleanup); docs/notes/README.md `## Build environment`; two "Found by agents" lines in tasks/backlog.md (rebase.sh, driver init).
- Verified: `bash -n` clean; preflight test prints PASS; `build.sh ui` → BUILD RESULT: OK with `en-US-packs: exit 0` between import and build-ui.
- Not run separately: DoD 4 (`--no-import`) — by construction the step sits inside the `IMPORT=1` branch. DoD 6 diff.sh not run.

## QA
PASS

1. DoD 1: `bash -n scripts/agents/build.sh` → no output.
2. DoD 2: `bash scripts/agents/tests/build_preflight_test.sh` → `PASS`.
3. DoD 3: `build.sh ui` → BUILD RESULT: OK; log logs/build-ui-20261030-170221.log has `en-US-packs` (line 371) with `en-US-packs: exit 0` (387) between import (369) and build-ui (389).
4. DoD 4: `build.sh ui --no-import` → OK; log logs/build-ui-20261030-170305.log has only the build-ui step, no en-US-packs.
5. DoD 5: docs/notes/README.md has `## Build environment` with all required points.
6. DoD 6: diff.sh --names lists only allowed paths (build.sh, test, README).
7. `test.sh lint` → OK, layer_lint 0 fail / 0 warn.
Reviewer's non-blocking nits (message wording, stderr) are not DoD items.

## Review
APPROVE

Checklist (round 1):
1. Spec: preflight after arg parsing, before `LOCK=` (build.sh:32-44), exit 2 documented in the header (build.sh:11-13); en-US step only after a successful import, inside `IMPORT=1` (build.sh:106). Docs entry and two backlog lines present. Nothing extra.
2. Scope: changed files = build.sh, tests/build_preflight_test.sh, docs/notes/README.md, tasks/backlog.md, task file — all allowed. No existing test touched.
3. Layer: no Zen/Firefox files, no prefs, nothing in engine/; layer_lint 0 fail, 0 warn.
4. Correctness: bash 3.2 safe (no arrays); a missing node gives an empty `found` → "Node missing", exit 2; the lock is never taken on a refusal; test trap removes `$T`. Zen's scripts not edited.
5. Verification: `bash scripts/agents/tests/build_preflight_test.sh` → PASS (re-run by reviewer). DoD 3/4 (real ui build, `--no-import` log) are left to qa; the Result says honestly that DoD 4/6 were not run. diff --stat confirms DoD 6.
6. Hygiene: no secrets, TODOs or dead code.

Non-blocking nits (fix only if the task comes back for another reason):
1. scripts/agents/build.sh:37 — the `; expected Node $want` suffix repeats `.nvmrc wants $want` just so the DoD grep finds `Node 22`. Write `.nvmrc wants Node $want: run nvm use …` and drop the suffix.
2. scripts/agents/build.sh:37,41 — the preflight messages go to stdout, but the unknown-argument error at :27 goes to stderr. Send exit-2 messages to `>&2` for consistency.
