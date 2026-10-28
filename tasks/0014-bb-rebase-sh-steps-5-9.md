---
id: 0014
title: scripts/bb/rebase.sh steps 5-9 (deps, engine reset or re-download, patches check, import, build + lint)
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: ready
base: feat/layer
branch: task/0014-bb-rebase-sh-steps-5-9
depends_on: [0007]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_post_test.sh
  - scripts/bb/tests/rebase_test.sh
  - scripts/bb/tests/rebase_fixture.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4--runbook-ребейза
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Fill `post_rebase` in `scripts/bb/rebase.sh` (left by 0007) with ADR-0002 Решение 4 steps 5-9: Node deps, the
engine (re-download when Firefox changed, own reset that keeps `obj-*` otherwise), `patches.sh check`, import, build
under caffeinate, lint. Each step runs under `step`, the first failure stops the script with exit 1. Second half of
the split backlog item 0007.

## Definition of Done
1. `bash -n scripts/bb/rebase.sh` → exit 0, no output.
2. `/bin/bash scripts/bb/tests/rebase_test.sh` (0007's test) → `PASS` still.
3. `/bin/bash scripts/bb/tests/rebase_post_test.sh` → last line `PASS`, exit 0. It uses the 0007-style git fixture under
   `mktemp -d`, a stub dir first in `PATH` (`npm`, `caffeinate` append their argv to `$T/calls`), `NVM_DIR` with a stub
   `nvm.sh` defining `nvm()` that logs its argv, `BB_PATCHES=<stub script>`, `BB_ENGINE_DIR=$T/engine` (a git repo with an
   `obj-x/keep` file and an untracked `junk` file), `BB_TARBALL_DIR=$T/tarballs`. It asserts, with a message on failure:
   a. Firefox changed (150.0 → 151.0) and `.nvmrc` changed: `$T/calls` holds in this order `nvm use`, `npm ci`,
      `npm run download`, `npm run import`, `caffeinate -dims npm run build -- --jobs 6`, `npm run lint`; no `npm run bootstrap`;
      `$T/engine` was removed before download; exit 0;
   b. Firefox major changed (150.0 → 151.0 counts as major: first component differs) → `npm run bootstrap` right after download.
      Use a 150.0 → 150.0.1 fixture for "same major, changed version" → download without bootstrap;
   c. Firefox unchanged: no download; `$T/engine/obj-x/keep` still exists, `junk` is gone, tracked edits are reverted;
      `.nvmrc` unchanged → no `nvm use`;
   d. with 4 tarballs `firefox-<v>.source.tar.xz` of different mtimes in `$BB_TARBALL_DIR`, after a download only the 2 newest remain;
   e. stub `BB_PATCHES` printing `FAIL layer/x: zen …` and exiting 1 → rebase.sh exits 1, no `npm run import` in calls,
      the log has `<== step: patches exit=1`;
   f. stub `npm` failing on `run build` → exit 1, no `npm run lint`;
   g. the log has `<== step: <name> exit=0` for deps, engine, patches, import, build, lint in the happy path.
4. The test writes only under its `mktemp -d` and removes it.
5. `grep -c -E "reset-ff|push|clean -fdx[^q]" scripts/bb/rebase.sh` → `0`.
6. `scripts/agents/diff.sh tasks/0014-bb-rebase-sh-steps-5-9.md --names` lists only allowed_paths.

## Notes from teamlead
- Step names exactly: `deps`, `engine`, `patches`, `import`, `build`, `lint` (report.sh 0009 reads footers by name).
- Inputs: X = `base: zen:` from layer.yaml (still X during the rebase; step 11 updates it), Y = the tag argument. Firefox
  versions via 0007's helper (`git show <tag>:<build-config JSON>`). Reuse 0007's helpers; do not duplicate them.
- Step 5 deps (ADR п.5): if `.nvmrc` differs X → Y: `. "$NVM_DIR/nvm.sh"` then `nvm use`. Always `npm ci`.
- Step 6 engine (ADR п.6). Firefox changed: `rm -rf "$BB_ENGINE_DIR"` → `npm run download` → `npm run bootstrap` only when
  the major (first dot component) changed → keep the 2 newest `firefox-*.source.tar.xz` in `$BB_TARBALL_DIR`
  (default `$BB_REPO_DIR/.<tool>/engine`, the tool = the build-config JSON's base name), delete older ones.
  Firefox same: `git -C "$BB_ENGINE_DIR" reset -q`, `git -C … checkout -q -- .`, `git -C … clean -fdxq -e 'obj-*'`
  (exact ADR command; never `npm run reset-ff` — it wipes the objdir).
- Step 7: `step patches bash "$BB_PATCHES" check` with `BB_PATCHES` default `$BB_ROOT/scripts/bb/patches.sh` and
  `BB_ENGINE_DIR` exported. On failure print `stop: BB patch check failed — fix with git apply --reject in engine/, patches.sh export, check again`.
- Step 8: `npm run import`. Step 9: `caffeinate -dims npm run build -- --jobs 6`, then `npm run lint`.
- npm runs with cwd `$BB_REPO_DIR` (`cd` inside the script is fine). The test drives steps 5-9 through
  `rebase.sh --continue <Y>` on a prepared `rebase/<Y>` branch.
- 0007's happy path now reaches `post_rebase`, so `rebase_test.sh` would call the real npm. Its only allowed change: run
  the script with the same stub `PATH`/`NVM_DIR`/`BB_PATCHES`/`BB_ENGINE_DIR`/`BB_TARBALL_DIR` setup (share it via a sourced
  `scripts/bb/tests/rebase_fixture.sh` if both tests need it). No assertion of 0007 may be removed or weakened.
- Exit 1 at the first failed step, with `stop: <step>` on stderr. Never touch `main`, never push (0011).
- Agent Bash hook: commands containing the build tool's name, or `npm run …`, are blocked for you. Run only
  `bash -n` and `/bin/bash scripts/bb/tests/*.sh`; the stubs make the script's npm calls safe.
- Same bash 3.2 / `set -euo pipefail` / `GIT_CONFIG_GLOBAL=/dev/null` rules as 0007.

## Handoff

## Result

## Review

## QA
