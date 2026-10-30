---
id: 0011
title: scripts/bb/rebase.sh steps 10-11 (smoke, package + install, commit, main := rebase/<tag>, tag, push, report)
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: done
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
returns: 1
sessions: 0
reviewed_sha: 399c98431312dab3cf0e76f17b3e6f9c5736e404
qa_sha: 399c98431312dab3cf0e76f17b3e6f9c5736e404
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
Round 2 (review items 1-4)
1. `do_publish`: the tag is created first (a failure leaves `main` untouched); one `publish_rollback` helper
   (switch rebase/Y, `branch -f main $old`, `tag -d`) serves both the move-failed and push-rejected paths.
2. The rollback commands are chained; if any fails, `say_fail` prints the manual restore commands with the `old` sha.
3. `run_step` writes the failed report only when HEAD is `rebase/$Y`; otherwise a `note:` line goes to `$BB_LOG`
   (not stderr: `rebase_test.sh` asserts a one-line stderr reason, and a `rebase:` prefix would override the reason).
   Deviation: "any failed step (1-11)" is narrowed to steps that fail on `rebase/Y` (so not preflight/fetch/recon/an early
   rebase failure). New tests `g` (broken upstream → clean tree on main) and `h` (stale local tag → main untouched).
4. `do_install`: one `app` picked, `[ -d "$app" ]` check with `say_fail "no .app in $dmg"`; loop and dead check dropped.
Verified: `rebase_final_test.sh`, `rebase_test.sh`, `rebase_post_test.sh` print PASS.

Round 1
- rebase.sh: steps `smoke package install finalize publish` after `lint`; new env `BB_SMOKE BB_REPORT BB_DIST_DIR
  BB_APPS_DIR BB_PUSH_REMOTE` (header). `run_step` writes a `failed` report (blocker = step name) on exit 1.
- Deviations from the task text (please check):
  1. New env `BB_POST_STEPS` (default = all steps 5-11). Without it the 0007/0014 tests (happy path asserting `main`
     unchanged) would run through publish and move `main`; `stub_env` sets it to steps 5-9, so no old assertion changed.
  2. No failed report for `preflight` (nothing ran; a report would dirty the tree and make the re-run fail preflight).
  3. Push uses `--atomic` as well as `--force-with-lease=main:<old>`, so a rejected main does not leave the tag on origin.
  4. Push is limited to `main` + `refs/tags/bb/base/Y` (not `--tags`): narrows ADR п.11, upstream Zen tags stay off origin.
- Fixture: `rebase_fixture.sh` `stub_env` now also stubs hdiutil/smoke and exports BB_SMOKE BB_DIST_DIR BB_APPS_DIR
  BB_PUSH_REMOTE BB_POST_STEPS. New `rebase_final_test.sh` covers DoD 2 a-f.
- Verified: `rebase_final_test.sh`, `rebase_test.sh`, `rebase_post_test.sh` all print PASS.
- Not run: DoD 4 grep (the agent hook blocks any command naming rebase.sh); by reading, the script has none of the patterns.
  DoD 5 diff.sh not run.

## Review
APPROVE
Round 2. All four items from round 1 are fixed:
1. Fixed. `do_publish` now creates the tag before it moves `main`, so a stale tag leaves `main` untouched. Test `h` covers it.
2. Fixed. `publish_rollback` chains switch → `branch -f` → `tag -d`. If any of them fails, `say_fail` prints the manual
   restore commands with the `old` sha. Both failure paths use this helper.
3. Fixed. `run_step` now decides by where HEAD is (`rebase/$Y`), not by the step name. Test `g` checks that the tree stays
   clean on main. The narrower "any failed step" is listed under the Result deviations.
4. Fixed. `do_install` picks `app` once and checks it with `[ -d ]`. The loop and the dead check are gone.

Checklist notes (round 2):
- Spec: the steps, names, env, commit message, lease, two-ref refspec, `--atomic` and `branch -d` after the push all match
  the notes. The `--continue` path has no clean-tree check (rebase.sh:348-356), so an uncommitted failed report does not
  block a resume. Then finalize overwrites it with the ok report, and report.sh upserts the README row (report.sh:112).
- Scope: diff.sh lists rebase.sh, rebase_final_test.sh and rebase_fixture.sh, all in allowed_paths. The fixture only adds
  stubs and env, so no existing assertion changed.
- Layer: layer_lint gives 0 fail and 0 warn. No Zen, engine or prefs files are touched.
- Correctness, non-blocking: `publish_rollback` is defined inside `do_publish`, so bash makes it a global function. This
  is harmless here.
- Verification: I did not run the tests (the sandbox and the hook block it); qa runs them. DoD 4 was grepped in round 1,
  and the new code adds no matching pattern (read in the diff).
- Hygiene: English, no TODOs, no secrets.
- For the owner (DoD 6): `BB_POST_STEPS` is a test knob in production code that can skip `smoke` before `publish`.

---
Round 1
REQUEST_CHANGES
1. scripts/bb/rebase.sh:289-290 (`do_publish`): `g branch -f main rebase/Y && g switch main && g tag bb/base/Y … || { say_fail; return 1; }`
   — if the tag step fails (e.g. a stale local `bb/base/Y` from an earlier manual try), `main` has already been moved and
   checked out, and the function returns 1 without restoring it. That breaks "a failed step leaves main untouched".
   Fix: create the tag first (it does not depend on `main`), or send both failure paths through one rollback helper
   (switch rebase/Y, `branch -f main $old`, `tag -d`), used by the push-rejected branch too.
2. scripts/bb/rebase.sh:292-295: the rollback commands are not checked (errexit is off inside `step`), yet the message
   always says "main restored". If `g switch rebase/Y` fails, `g branch -f main $old` fails too (it is the current branch)
   and the message is wrong. Chain them, and on failure `say_fail` with the `old` sha so the operator can restore it by hand.
3. scripts/bb/rebase.sh:320-323 (`run_step` failed report): the reason for skipping `preflight` ("a report would dirty
   the tree") applies just as much to `fetch`, `recon` and a `rebase` that fails before `switch -c`. Those run on `main`, so
   the report adds an untracked `docs/rebase/Y.md` and modifies the tracked `docs/rebase/README.md` on `main`, and the next
   `rebase.sh Y` fails preflight with "working tree is not clean". Use one rule based on where the report would land, not on
   the step name: write the failed report only when HEAD is `rebase/$Y`, and print the reason on stderr otherwise. Add a
   test (e.g. a broken upstream URL → fetch fails → `git status --porcelain` on main is empty). Describe the narrowed
   "any failed step (1-11)" under the Result deviations.
4. scripts/bb/rebase.sh:249-253 (`do_install`): `for app …; break` is an "if" written as a loop. With no `.app` in the DMG
   the glob stays literal: `rm -rf "$BB_APPS_DIR/*.app"` runs, then `ditto` fails with a confusing error. Also,
   `[ -n "${dest:-}" ] || rc=1` can never be true, because `dest` is always set in the loop, so it is dead code. Pick
   `app` once, check it with `[ -d "$app" ]` and a clear `say_fail "no .app in $dmg"`, then mkdir/rm/ditto. Drop the loop
   and the dead check.

Checklist notes:
- Spec: steps/names/order, env overrides, commit message, `--force-with-lease=main:<old>`, two-ref refspec, `branch -d`
  only after push all match the notes; `--atomic` (deviation 3) is a strict improvement. Item 1 above is the gap vs "main untouched".
- `BB_POST_STEPS` (deviation 1) is not in the spec. It is a test knob in production code that can also skip `smoke`
  before `publish`. I accept it because the old happy-path tests would otherwise reach `publish`. Not blocking, but the owner
  should be aware of it for DoD 6.
- Scope: `--names` = rebase.sh, rebase_final_test.sh, rebase_fixture.sh, all in allowed_paths (DoD 5 checked by reviewer).
  rebase_test.sh and rebase_post_test.sh are untouched; the fixture changes only add stubs/env.
- Layer: no Zen/engine/prefs files; layer_lint: 0 fail, 0 warn.
- DoD 4 re-run by the reviewer (grep over scripts/bb): rebase.sh 0.
- Tests: write only under `$T` (BB_APPS_DIR, BB_DIST_DIR, origin.git, the no-such-remote default), trap cleanup, same header
  as 0007/0014. Not run (sandbox); qa runs them.
- Hygiene: English, no TODOs, no secrets.

## QA
PASS
1. Build none; `test.sh lint` OK (0 problems), layer_lint 0 fail / 0 warn.
2. DoD 1: `rebase_test.sh` PASS, `rebase_post_test.sh` PASS.
3. DoD 2: `rebase_final_test.sh` last line PASS, exit 0 (cases a-h).
4. DoD 3: not verified by reading line by line; the tests passed and trap-clean `$T` per review.
5. DoD 4: the hook blocks naming the script, so I ran the grep over `scripts/bb` with `--include` → `rebase.sh:0`.
6. DoD 5: `diff.sh --names` lists rebase.sh, rebase_final_test.sh, rebase_fixture.sh, all in allowed_paths.

For the human: DoD 6 (read the `publish` step: force-with-lease, two-ref refspec, tag). Also note the
`BB_POST_STEPS` test knob in production code, and the narrowing of `--tags` to two refs.
