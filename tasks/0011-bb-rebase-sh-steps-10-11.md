---
id: 0011
title: scripts/bb/rebase.sh steps 10-11 (smoke, package + install, commit, main := rebase/<tag>, tag, push, report)
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: ready
base: feat/layer
branch: task/0011-bb-rebase-sh-steps-10-11
depends_on: [0014, 0008, 0009]
build: none
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_final_test.sh
  - scripts/bb/tests/rebase_fixture.sh
  - scripts/bb/tests/rebase_test.sh
  - scripts/bb/tests/rebase_post_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4--runbook-ребейза
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Finish `scripts/bb/rebase.sh` with ADR-0002 Решение 4 steps 10-11: after `lint`, run the smoke checklist, package and
install the DMG, commit `rebase: Zen Y (Firefox fy)` with the new `base` in `layer.yaml` and the report, move `main` to
`rebase/Y`, tag `bb/base/Y`, push with `--force-with-lease`, delete `rebase/Y`. On any failed step (1-11), write the
report with status `failed` and the blocker, leave `main` untouched. This is the only code allowed to move and push `main`
(ADR "Минусы": `main` is touched only by the script) — hence needs_approval.

## Definition of Done
1. `/bin/bash scripts/bb/tests/rebase_test.sh` → `PASS`; `/bin/bash scripts/bb/tests/rebase_post_test.sh` → `PASS` (still).
2. `/bin/bash scripts/bb/tests/rebase_final_test.sh` → last line `PASS`, exit 0. Fixture: 0007/0014 git fixture + stubs from
   `rebase_fixture.sh`, plus a bare `$T/origin.git` as `BB_PUSH_REMOTE` (main and `bb/base/<X>` pushed to it first), stub
   `BB_SMOKE` (prints `smoke: y e0 window` / `smoke: result 1/1`, exit 0; with `STUB_FAIL_SMOKE` prints `smoke: n …`, exit 1),
   stub `hdiutil` in the stub PATH (logs argv; `attach … -mountpoint <m>` creates `<m>/BB.app/x`), a `$BB_DIST_DIR` with one
   `*.dmg`, `BB_APPS_DIR=$T/Applications`. Asserts, with a message on failure:
   a. happy path → exit 0; step footers `exit=0` for `smoke`, `package`, `install`, `finalize`, `publish` in this order after `lint`;
      `$T/calls` has `npm run package`; `$T/Applications/BB.app/x` exists; `hdiutil detach` was called;
   b. `git log -1 --format=%s main` = `rebase: Zen <Y> (Firefox <fy>)`; that commit changes `src/bb/layer.yaml`
      (`zen: <Y>`, `firefox: <fy>`, `commit: <short sha of tag Y>`) and adds `docs/rebase/<Y>.md` with status ok and a
      `docs/rebase/README.md` row for `<Y>`;
   c. tag `bb/base/<Y>` points at tag `<Y>`'s commit; `$T/origin.git` has `main` = local `main` and tag `bb/base/<Y>`;
      branch `rebase/<Y>` no longer exists; current branch is `main`;
   d. `STUB_FAIL_SMOKE=1` → exit 1; `main` and `$T/origin.git` main unchanged; `rebase/<Y>` exists; `docs/rebase/<Y>.md`
      exists in the work tree with status `failed` and the blocker `smoke`; no `npm run package` call;
   e. stub `npm` failing on `run build` (existing `STUB_FAIL_BUILD`) → exit 1; report written with status failed, blocker `build`;
   f. origin's `main` moved by someone else before publish (the test pushes an extra commit to `$T/origin.git` main inside the
      stub `BB_SMOKE`) → push rejected → exit 1; the `publish` footer has `exit=1`; stderr has `stop: publish`;
      local `main` = its sha before the run; no local tag `bb/base/<Y>`; `rebase/<Y>` exists; `$T/origin.git` main = the extra commit.
3. The tests write only under their `mktemp -d` and remove it; no test reaches a real remote or `/Applications`.
4. `grep -c -E "reset-ff|push --force[^-]|push -f|branch -D main" scripts/bb/rebase.sh` → `0`.
5. `scripts/agents/diff.sh tasks/0011-bb-rebase-sh-steps-10-11.md --names` lists only allowed_paths.
6. `[human]` the owner reads the `publish` step in the diff (force-with-lease, refspec, tag) before approving.

## Notes from teamlead
- New steps, names exact (report.sh 0009 reads footers by name): `smoke`, `package`, `install`, `finalize`, `publish`,
  run through the existing `run_step … post` after `lint` in `post_rebase`. Reuse `g`, `say_fail`, `npm_or_fail`,
  `base_zen`, `tag_firefox`; no duplicated helpers.
- New env overrides, documented in the header like the others: `BB_SMOKE` (default `$BB_ROOT/scripts/bb/smoke.sh`),
  `BB_REPORT` (default `$BB_ROOT/scripts/bb/report.sh`), `BB_DIST_DIR` (default `$BB_REPO_DIR/dist`),
  `BB_APPS_DIR` (default `/Applications`), `BB_PUSH_REMOTE` (default `origin`).
- smoke: `bash "$BB_SMOKE" "$Y"` — interactive (y/n on the terminal); its `smoke: …` lines must reach `$BB_LOG` (step tees).
- package: `npm run package`. install: newest `*.dmg` in `$BB_DIST_DIR`; `hdiutil attach -nobrowse -mountpoint <mktemp -d> <dmg>`,
  `ditto <mnt>/<name>.app "$BB_APPS_DIR/<name>.app"` (remove the old .app first), `hdiutil detach <mnt>` also on failure.
- finalize, on `rebase/Y`: rewrite the three `base:` keys of `src/bb/layer.yaml` in place (awk into a temp file, keep the rest
  byte-identical); run `BB_REBASE_DOCS="$BB_REPO_DIR/docs/rebase" bash "$BB_REPORT" "$Y" "$BB_LOG" ok` BEFORE the
  commit so the report is in it; `git add` layer.yaml + docs/rebase/<Y>.md + docs/rebase/README.md;
  commit message exactly `rebase: Zen <Y> (Firefox <fy>)`. The finalize/publish footers land after the report — accepted.
- publish: record `old=$(g rev-parse "$BB_MAIN_BRANCH")` (the main the rebase started from = what origin is expected to
  hold), then `g branch -f "$BB_MAIN_BRANCH" "rebase/$Y"`, `g switch "$BB_MAIN_BRANCH"`, `g tag "bb/base/$Y" "refs/tags/$Y^{commit}"`,
  `g push --force-with-lease="$BB_MAIN_BRANCH:$old" "$BB_PUSH_REMOTE" "$BB_MAIN_BRANCH" "refs/tags/bb/base/$Y"` — push only those two refs, not `--tags` (upstream Zen tags must not go to origin;
  this narrows ADR п.11's `--tags`, say so in ## Result). Only after a successful push: `g branch -d "rebase/$Y"`.
  If the push fails, local `main` is already moved: `g switch "rebase/$Y"`, `g branch -f "$BB_MAIN_BRANCH" "$old"`, delete the local `bb/base/$Y` tag, exit 1. Never `-f`/`--force` without lease, never delete `main`.
- Failure report: in `run_step`, on exit 1 (not 3 = conflict) call
  `BB_REBASE_DOCS="$BB_REPO_DIR/docs/rebase" bash "$BB_REPORT" "$Y" "$BB_LOG" failed "<step name>" || true` before exiting.
  The failed report stays uncommitted on `rebase/Y`.
- 0007/0014 tests now reach steps 10-11. Their only allowed change: export the new stub env (`BB_SMOKE`, `BB_DIST_DIR`,
  `BB_APPS_DIR`, `BB_PUSH_REMOTE`, hdiutil stub) via `rebase_fixture.sh`; no assertion removed or weakened.
- Agent Bash hook: only role rebaser may run commands containing `scripts/bb/rebase.sh`, so `bash -n` on it is not in the
  DoD; the tests source/run it. `npm run …` is blocked for you; the stubs make it safe. bash 3.2, `set -euo pipefail`,
  `GIT_CONFIG_GLOBAL=/dev/null` in tests, as in 0007.

## Handoff

## Result

## Review

## QA
