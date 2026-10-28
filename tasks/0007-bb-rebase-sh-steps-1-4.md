---
id: 0007
title: scripts/bb/rebase.sh <tag> steps 1-4 (preflight, fetch, recon, rebase/<tag>) + --continue
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: ready
base: feat/layer
branch: task/0007-bb-rebase-sh-steps-1-4
depends_on: [0002, 0005]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4--runbook-ребейза
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Create `scripts/bb/rebase.sh`, the rebase runbook of ADR-0002 Решение 4, steps 1-4: preflight, fetch of
upstream tags, recon X → Y into the log, and the `rebase/<Y>` branch rebased with `git rebase --onto Y bb/base/X`.
It stops on the first git conflict with a list of files and their epics, and resumes with `--continue <Y>`.
Steps 5-9 (deps, engine, patches check, import, build) are task 0014; steps 10-11 are 0011.
Backlog item 0007 was split by the teamlead: steps 1-9 in one script plus a git-fixture test exceeded one session.

## Definition of Done
1. `bash -n scripts/bb/rebase.sh` → exit 0, no output.
2. `/bin/bash scripts/bb/tests/rebase_test.sh` → last line `PASS`, exit 0 (macOS bash 3.2).
3. The test builds a fixture under `mktemp -d`: a bare "upstream" repo with tags `1.0.0b` and `1.0.1b`
   (the build-config JSON `version.version` 150.0 → 151.0, `.nvmrc` 22 → 24, a change in `src/zen/moz.build`), and a
   clone with remote `upstream`, branch `main` = `1.0.0b` + one BB commit (a `src/bb/layer.yaml` with
   `base: zen: 1.0.0b`, a hook entry for `src/zen/moz.build` epic `layer`, and a BB patch
   `src/bb/patches/layer/x/x.patch` with `+++ b/browser/base/content/browser.js`), tag `bb/base/1.0.0b`.
   It runs the script with `BB_REPO_DIR`, `BB_LOG_DIR`, `BB_MIN_FREE_GB=0`, `BB_GTAR=<stub>` and asserts, with a message on failure:
   a. happy path `rebase.sh 1.0.1b` → exit 0; branch `rebase/1.0.1b` = `1.0.1b` + the BB commit; the single log
      `$BB_LOG_DIR/rebase-1.0.1b-*.log` contains `recon: zen 1.0.0b -> 1.0.1b`, `recon: firefox 150.0 -> 151.0`,
      `recon: upstream-commits 1`, `recon: toolchain-changed .nvmrc`, `recon: expected-conflict src/zen/moz.build layer`,
      and `<== step: <name> exit=0` for each of preflight, fetch, recon, rebase;
   b. upstream and BB change the same line of `src/zen/moz.build` → exit 3, stdout and log contain
      `conflict: git src/zen/moz.build layer`; after the test resolves it and runs `git rebase --continue`
      (`GIT_EDITOR=true`), `rebase.sh --continue 1.0.1b` → exit 0 and appends to the same log (still one `rebase-1.0.1b-*.log`);
   c. `--continue 1.0.1b` while the rebase is still in progress → exit 1;
   d. preflight failures, each → exit 1 with a one-line reason on stderr and no `rebase/*` branch: dirty tree, current
      branch not `main`, `BB_MIN_FREE_GB=999999`, `BB_GTAR=no-such-gtar-xyz`, target tag equal to base;
   e. a tag that does not exist after fetch → exit 1, no `rebase/*` branch;
   f. no args or an unknown option → usage on stderr, exit 2;
   g. in every case `main` points at the same commit as before (steps 1-4 never move `main`).
4. The test writes only under its `mktemp -d` and removes it; it never touches the real repo's refs, config or `logs/`.
5. `grep -c -E "npm run|reset-ff|push" scripts/bb/rebase.sh` → `0`.
6. `scripts/agents/diff.sh tasks/0007-bb-rebase-sh-steps-1-4.md --names` lists only the two allowed_paths.

## Notes from teamlead
- Source `scripts/bb/lib.sh`; use `bb_log_open "rebase-<Y>"` (→ `$BB_LOG_DIR/rebase-<Y>-<YYYYmmdd-HHMMSS>.log`) and wrap
  each of steps 1-4 in `step <name> …` with names exactly `preflight`, `fetch`, `recon`, `rebase`.
  `--continue <Y>`: reuse the newest existing `$BB_LOG_DIR/rebase-<Y>-*.log` (export `BB_LOG`), open a new one only if none.
  ADR: one log per rebase; report.sh (0009) takes step timings from it.
- Overrides (env wins): `BB_REPO_DIR` (default `$BB_ROOT`; run every git command as `git -C "$BB_REPO_DIR"`),
  `BB_MAIN_BRANCH` (default `main`; the 0012 dry-run uses another branch), `BB_UPSTREAM_REMOTE` (default `upstream`),
  `BB_MIN_FREE_GB` (default `60`), `BB_GTAR` (default `gtar`).
- Exit codes: 0 ok · 1 failure (preflight, fetch, unknown tag, bad --continue state) · 2 usage · 3 stopped on a git conflict.
- Step 1 preflight (ADR п.1): `git status --porcelain` empty; current branch = `$BB_MAIN_BRANCH`; free space on the repo
  filesystem ≥ `$BB_MIN_FREE_GB` GB (BSD `df -g`); `command -v "$BB_GTAR"`; X = `base: zen:` from `src/bb/layer.yaml`; Y ≠ X;
  `git config rerere.enabled true` (repo-local; ADR п.4 "rerere включён").
- Step 2: `git fetch "$BB_UPSTREAM_REMOTE" --tags --prune --progress`; then Y must resolve as a tag (`refs/tags/Y`), else exit 1.
- Step 3 recon, log lines in this exact format (report.sh 0009 greps them — do not change):
  `recon: zen <X> -> <Y>` · `recon: firefox <fx> -> <fy>` (the `"version"` value inside the `"version": {` block of the
  build-config JSON at the repo root, read with `git show <tag>:<file>`) · `recon: upstream-commits <git rev-list --count X..Y>` ·
  `recon: toolchain-changed <file>` for each of `.nvmrc rust-toolchain.toml package-lock.json requirements.txt` that differs
  X → Y · `recon: expected-conflict <file> <epic>` for each file in `git diff --name-only X Y` that is either a `file:` entry of
  `layer.yaml` (hooks, edits, zen_patches; epic from that entry) or the Zen patch of a BB patch target. Zen patch of target
  `<dir>/<name>` = `src/<dir>/<name with every "." replaced by "-">.patch` (same rule as patches.sh); the target comes from
  `+++ b/<path>` lines of `src/bb/patches/<epic>/<name>/<name>.patch`; epic = `<epic>` dir.
- Step 4: `rebase/Y` already exists → exit 1. Else `git switch -c rebase/Y "$BB_MAIN_BRANCH"` then
  `git rebase --onto Y bb/base/X`. On conflict: one line per `git diff --name-only --diff-filter=U` file,
  `conflict: git <file> <epic>`, then a hint (resolve → `git rebase --continue` → `rebase.sh --continue Y`), exit 3.
- Epic of a file: `src/bb/patches/<epic>/…` → `<epic>`; `src/bb/<dir>/…` → `<dir>`; other `src/bb/<file>` → `layer`;
  else the `epic:` of the layer.yaml entry whose `file:` equals the path; else `unregistered` (ADR Решение 2: registry defect).
  Parse layer.yaml with awk (`- file:` then the following `epic:`); no yq/python.
- `--continue Y`: current branch must be `rebase/Y` and no rebase in progress (`git rev-parse --git-path rebase-merge`
  / `rebase-apply` do not exist), else exit 1.
- After step 4 or `--continue`, call one function `post_rebase` that prints `post-rebase: steps 5-9 are task 0014` and returns 0;
  0014 fills it. Never touch `main`, never push, never delete branches (step 11 is 0011).
- Agent Bash hook: any command containing the word for Zen's build tool (the JSON's base name) is blocked. Read the file with the
  Read tool; in the script refer to it by its file name, that is fine.
- macOS bash 3.2: no associative arrays, no `mapfile`; BSD `df`/`sed`/`date`. `set -euo pipefail`, rc captures as `|| rc=$?`
  (reviewer checklist; see patches.sh). Test: `GIT_CONFIG_GLOBAL=/dev/null`, `TMPDIR="$T"`, git identity via env.

## Handoff

## Result

## Review

## QA
