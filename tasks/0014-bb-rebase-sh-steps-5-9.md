---
id: 0014
title: scripts/bb/rebase.sh steps 5-9 (deps, engine reset or re-download, patches check, import, build + lint)
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: approved
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
returns: 1
sessions: 0
reviewed_sha: 2a66896d2259bd41f558dc99ab5bb19662a355f7
qa_sha: 2a66896d2259bd41f558dc99ab5bb19662a355f7
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
Round 2 (review items 1-3)
- 1: `use_node` result is recorded in `NVM_RC`; `do_deps` fails first on it, so a failed `nvm use` goes through
  `step`/`run_step` (footer `<== step: deps exit=1`, `stop: deps`). New test case (h) with a `STUB_FAIL_NVM` stub.
- 2: `rm -rf "$BB_ENGINE_DIR"` failure now returns 1 with a reason.
- 3: build label is now `npm run build`.
- Verified: `rebase_post_test.sh` → PASS (incl. h); `rebase_test.sh` → PASS.

Round 1
- `rebase.sh`: `post_rebase` now runs `use_node` (nvm in the main shell, because a step runs in a pipe subshell and
  nvm's PATH change would be lost) and the steps `deps`, `engine`, `patches`, `import`, `build`, `lint` via `run_step`
  (failure → `stop: <step>` on stderr, exit 1). Engine: re-download + bootstrap on a major change + keep 2 newest
  tarballs; unchanged Firefox → reset/checkout/`clean -fdxq -e 'obj-*'`.
- Tests: new `rebase_fixture.sh` (stubs, shared), `rebase_post_test.sh` (cases a-g), `rebase_test.sh` only gained the
  stub setup (no assertion touched).
- Verified: `rebase_post_test.sh` → PASS; `rebase_test.sh` → PASS. `bash -n` and the DoD-5 grep were blocked by the
  agent hook (the command mentions "rebase"); the scripts ran under bash, and I wrote no reset-ff/push/clean -fdx words.
- Open: DoD 3a says 150.0 → 151.0 with no bootstrap, 3b says 150.0 → 151.0 is a major change. I used 150.0 → 150.0.1
  for (a) and 150.0 → 151.0 for (b).

## Review
APPROVE
Round 2: all three items are fixed.
1. Item 1: `post_rebase` now runs `use_node >>"$BB_LOG" 2>&1 || NVM_RC=$?`, and `do_deps` fails first on `NVM_RC`.
   A failed `nvm use` therefore goes through `step`/`run_step`, which writes the `<== step: deps exit=1` footer and
   prints `stop: deps`. Test case (h) covers it: stub `nvm` fails → exit 1, no `npm ci`, the footer, and the stop line.
2. Item 2: `rm -rf "$BB_ENGINE_DIR"` failure now returns 1 with a reason.
3. Item 3: the build label is `npm run build`.

Checklist:
- Spec: matches DoD 3a-g and the notes.
- Scope: diff = the 4 allowed_paths. In `rebase_test.sh` the only change is the stub setup.
- Layer: layer_lint 0 fail / 0 warn; no Zen files or engine/ touched.
- Correctness: `NVM_RC` is a plain shell variable, and the pipe subshell of `step` inherits it.
- Hygiene: no TODOs, everything in English.
- Verification: I re-ran the DoD 5 grep across scripts/bb → 0 everywhere. A direct grep on rebase.sh is blocked
  for the reviewer by the hook.
- Not run by me (sandbox/hook): `bash -n` and the two test scripts. qa must run them.

---
REQUEST_CHANGES
1. scripts/bb/rebase.sh:221 — `nvm use` runs outside `step deps`, so when it fails the log gets no
   `<== step: deps exit=1` footer (report.sh 0009 reads step footers by name) and the stop message is a one-off
   `stop: deps (nvm use failed)` that skips `run_step`. The notes say every step runs under `step`. Keep `use_node` in
   the main shell (the PATH reason is correct), but record its result instead of exiting, e.g.
   `use_node >>"$BB_LOG" 2>&1 || NVM_RC=$?`, and have `do_deps` (rebase.sh:176) start with
   `[ "${NVM_RC:-0}" = 0 ] || { say_fail "nvm use failed"; return 1; }`. A failure then goes through `step`/`run_step`
   like every other step: it writes the footer and prints `stop: deps`. Add a test case: the stub `nvm` fails
   (for example via a `STUB_FAIL_NVM` env) → exit 1, no `npm ci`, the log has `<== step: deps exit=1`, stderr has `stop: deps`.
2. scripts/bb/rebase.sh:199 — errexit is off inside step functions (rebase.sh:36), so a failed `rm -rf "$BB_ENGINE_DIR"`
   (permissions, or a busy file in the objdir) is ignored and `npm run download` runs on top of the old tree. Use
   `rm -rf "$BB_ENGINE_DIR" || { say_fail "cannot remove $BB_ENGINE_DIR"; return 1; }`.
3. scripts/bb/rebase.sh:214 — nit: the `npm_or_fail` label is `build`, while the other steps use the command
   (`npm run import`, `npm run lint`). Use `npm run build` so the stderr reason looks the same for every step.

Checked and fine: DoD 5 grep → 0 (run over scripts/bb); diff --names = allowed_paths; layer_lint 0 fail / 0 warn;
rebase_test.sh only gained the stub setup, with no assertion changed; the reset command matches the ADR exactly;
the tarball default is `.surfer/engine`; patch-check failure → `rebase: stop: BB patch check failed …` and
`stop: patches`; using 150.0 → 150.0.1 for (a) and 150.0 → 151.0 for (b) is a sound way to resolve the DoD
contradiction. Not run by me (sandbox): `bash -n` and the two tests — qa must run them, because the developer
could not run `bash -n` either.

## QA
PASS
1. DoD 2: `/bin/bash scripts/bb/tests/rebase_test.sh` → `PASS`.
2. DoD 3, 4: `/bin/bash scripts/bb/tests/rebase_post_test.sh` → `PASS` (cases a-h).
3. DoD 6: diff.sh --names lists only the 4 allowed_paths.
4. `scripts/agents/test.sh lint`: 0 problems; layer_lint 0 fail / 0 warn.
5. DoD 1 (`bash -n`) and DoD 5 (grep count) were blocked for role qa by the Bash hook (the command names "rebase").
   Substitute checks: both test scripts source and run rebase.sh to completion, so it parses. I read rebase.sh lines 160-260
   and found no `reset-ff`, `push` or `clean -fdx` without `q` (only `clean -fdxq -e 'obj-*'`). The reviewer's grep over scripts/bb gave 0.

For the human: run `bash -n scripts/bb/rebase.sh` and the DoD 5 grep once by hand if you want the literal confirmation.
