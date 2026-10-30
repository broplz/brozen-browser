---
id: 0012
title: Dry-run of rebase.sh 1.23.4b from a throwaway main' on 1.23.3b; first docs/rebase/1.23.4b.md with timings
epic: layer
prefix: layer
kind: rebase
role: rebaser
size: L
status: draft
base: feat/layer
branch: task/0012-bb-rebase-dry-run
depends_on: [0006, 0011]
build: none
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - docs/rebase/1.23.4b.md
  - docs/rebase/README.md
  - docs/notes/rebase-dry-run.md
  - tasks/backlog.md
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#риски-и-план-проверки-фаза-0-до-7-ноября
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0002 plan п.4 (closes R5, R6, R8): run the full runbook path with a Firefox tarball change without waiting for
Firefox 159. Build a throwaway `main'` = the current BB layer (feat/layer) on Zen 1.23.3b (Firefox 158.0) in a git
worktree, run `scripts/bb/rebase.sh 1.23.4b` there up to and including `finalize`, never `publish`, and bring back the
report `docs/rebase/1.23.4b.md`, its README row and a notes file with timings and every defect found. The real repo
state (`main`, `bb/base/1.23.4b`, `/Applications`, origin) stays untouched.

## Definition of Done
1. `docs/rebase/1.23.4b.md` exists on the task branch: the report.sh output from the worktree run, status `ok` or `failed`
   with the blocker step; header line added by hand: `dry-run from main' on 1.23.3b (ADR-0002 plan п.4), not published`.
2. `docs/rebase/README.md` has one row for `1.23.4b` (from report.sh), marked `dry-run` in its notes column/cell.
3. `docs/notes/rebase-dry-run.md` has the sections `# Timings` (wall-clock per step from the step footers in the log,
   plus total machine time and the human minutes spent on conflicts/smoke), `# Risks` (one line each for R5, R6, R8:
   confirmed / not confirmed / not exercised, with the evidence), `# Defects` (each defect also added as one line under
   "Found by agents" in tasks/backlog.md), `# How it was run` (the exact commands, env and worktree path).
4. `git worktree list` → only the main working tree (the throwaway worktree is removed at the end).
5. `git branch --list "dryrun/*" "rebase/1.23.4b"` → empty; `git tag -l "bb/base/1.23.3b"` → empty;
   `git tag -l "bb/base/*"` → exactly `bb/base/1.23.4b`, and `git rev-parse bb/base/1.23.4b^{commit}` is still `541ee55…`.
6. `git rev-parse main` is the same before and after the run (write both shas into ## Result).
7. `ls /tmp/bb-apps` shows the installed `.app` (or ## Result says which step failed before `install`); `/Applications`
   was never written (no step runs without `BB_APPS_DIR=/tmp/bb-apps`).
8. `scripts/agents/diff.sh tasks/0012-bb-rebase-dry-run.md --names` lists only allowed_paths.
9. `[human]` the owner runs the smoke checklist on the dry-run build (see Notes: smoke is not run by the agent) and
   reads `# Timings` against R8's 4-hour threshold.

## Notes from teamlead
Owner answers (docs/reports/decisions-needed.md, 2026-10-30), binding:
1. `main'` lives in a throwaway worktree `../bb-rebase-test`, not as a long-lived branch of this repo.
2. Stop before publish: `BB_POST_STEPS` without `publish`. Tag `bb/base/1.23.4b` is never touched.
3. `BB_APPS_DIR=/tmp/bb-apps`. Never write `/Applications`.
4. You (rebaser) build `main'`. The owner approves this task file before the run (hence status draft until then).

Git mechanics the answers imply (worktrees share refs with this repo, so these refs are temporary and deleted in DoD 5):
- `git worktree add -b dryrun/main ../bb-rebase-test 1.23.3b`. rebase.sh needs a branch (preflight: current branch ==
  `BB_MAIN_BRANCH`; step 4: `git switch -c rebase/Y <main>`), so a detached HEAD does not work.
- Layer onto 1.23.3b inside the worktree: `git rebase --onto 1.23.3b bb/base/1.23.4b dryrun/main` after resetting
  `dryrun/main` to `feat/layer`'s sha (`git -C ../bb-rebase-test reset --hard <feat/layer sha>` is a worktree-only reset,
  never in this repo). Conflicts here are data: record them under `# Defects`, resolve, continue.
- Then in the worktree edit `src/bb/layer.yaml` `base:` to `zen: 1.23.3b`, `firefox: 158.0`, `commit: <short sha of 1.23.3b>`
  and commit; `git tag bb/base/1.23.3b 1.23.3b` (step 4 rebases `--onto Y bb/base/X`).
- No separate Firefox 158.0 build of `main'`: Firefox changes 158.0 → 158.0.1, so step 6 does `rm -rf engine` +
  download anyway; a prior build would be thrown away. Say so in `# How it was run`.
- Run from the worktree: `BB_REPO_DIR=<abs worktree> BB_MAIN_BRANCH=dryrun/main BB_APPS_DIR=/tmp/bb-apps
  BB_PUSH_REMOTE=/nonexistent BB_LOG_DIR=<repo>/logs BB_POST_STEPS="deps engine patches import build lint package install finalize"
  bash <worktree>/scripts/bb/rebase.sh 1.23.4b`. `BB_PUSH_REMOTE` points nowhere so even a mistaken `publish` cannot push.
  It runs ≈ 1.5 h: start it with run_in_background and read progress only via `python3 scripts/agents/triage_log.py <log>`.
- `smoke` is excluded: it is interactive y/n on a terminal and an agent has none. The owner runs it afterwards (DoD 9):
  `bash scripts/bb/smoke.sh 1.23.4b` against the `/tmp/bb-apps` build. Note in the report header that smoke is pending.
- On conflict (exit 3) or failure (exit 1): resolve in the worktree when it is a BB-layer conflict you can see the fix for,
  `rebase.sh --continue 1.23.4b` with the same env; otherwise stop, keep the failed report, fill DoD 1-3 with what you have.
- Cleanup, in order, after copying the report/README row out of the worktree with Read + Write:
  `git worktree remove --force ../bb-rebase-test`, `git branch -D dryrun/main rebase/1.23.4b`, `git tag -d bb/base/1.23.3b`.
  Never `git push`, never touch `main` or `bb/base/1.23.4b`, never `npm run reset-ff`.
- If a hook blocks work outside the repo (`../bb-rebase-test`) or `git worktree`: that is a Handoff + blocked, not a workaround.
