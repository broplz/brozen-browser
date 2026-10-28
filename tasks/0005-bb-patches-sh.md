---
id: 0005
title: scripts/bb/patches.sh check|export|status — BB patches against clean Firefox and Firefox + Zen
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: done
base: feat/layer
branch: task/0005-bb-patches-sh
depends_on: [0002]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - scripts/bb/patches.sh
  - scripts/bb/tests/patches_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-2--правила-изменений-чужого-кода
returns: 1
sessions: 0
reviewed_sha: b3e8d9fbd989a5f36ffd0d5650a520f6fe4b0d6e
qa_sha: b3e8d9fbd989a5f36ffd0d5650a520f6fe4b0d6e
blocked_reason: 
---
## Goal
Create `scripts/bb/patches.sh`, the BB patch tool from the last paragraph of ADR-0002 Решение 2. It is
built on git only and does not change the build tooling:
- `check` proves each BB patch applies both to clean Firefox and to Firefox plus Zen's patches of the same files.
- `export` regenerates a BB patch from `engine/` without leaking Zen's hunks into it.
- `status` reports which BB patches are applied in `engine/`.
Without this tool no BB patch to a Firefox file can be authored safely (0006, 0007 and E3 depend on it).

## Definition of Done
1. `bash -n scripts/bb/patches.sh` → exit 0, no output.
2. `/bin/bash scripts/bb/tests/patches_test.sh` → last line `PASS`, exit 0 (macOS bash 3.2).
3. The test builds a throwaway fixture under `mktemp -d`: an "engine" git repo whose root commit is the
   "Firefox" tree with a file `a/b/foo.sys.mjs`, plus a "src" tree with Zen's
   `src/a/b/foo-sys-mjs.patch` and BB patch dirs under `src/bb/patches/layer/<name>/`. It points the
   script at the fixture through `BB_ENGINE_DIR` / `BB_SRC_DIR`. It asserts each of these, with a message on failure:
   a. a BB patch far from Zen's hunk → `check` prints `OK layer/<name>` and exits 0;
   b. a BB patch whose hunk overlaps Zen's hunk → `FAIL layer/<name>: zen …`, exit 1;
   c. a BB patch that only applies on top of Zen (context taken from Zen's lines) → `FAIL layer/<name>: clean …`, exit 1;
   d. a Zen patch found by scanning `src/external-patches/**/*.patch` (`+++ b/<file>`) is also applied for the zen base;
   e. `export <dir>`, with the engine working tree = Firefox + Zen patch + BB edit, writes `<dir>/<name>.patch`
      that contains the BB hunk and none of Zen's hunk lines, with `diff --git a/… b/…` headers and full-index
      `index <40 hex>..<40 hex>` lines;
   f. the exported patch applies with `git apply --ignore-space-change --ignore-whitespace` on Firefox + Zen (round trip);
   g. `status` prints `applied layer/<name>` when the BB patch is in the engine working tree and
      `not-applied layer/<name>` when it is not;
   h. `check` and `status` leave the engine's `git status --porcelain` and its real index unchanged;
   i. no BB patch dirs → `check` prints `no BB patches` and exits 0;
   j. unknown command or `export` without a dir → usage on stderr, exit 2.
4. The test writes only under its `mktemp -d` and removes it. It never touches the real `engine/` or `src/`.
5. `grep -c -E "npm run|surfer" scripts/bb/patches.sh` → `0`.
6. `scripts/agents/diff.sh tasks/0005-bb-patches-sh.md --names` lists only the two allowed_paths.

## Notes from teamlead
- Source `scripts/bb/lib.sh` for `BB_ROOT` (do not re-derive it). Defaults are
  `BB_ENGINE_DIR=$BB_ROOT/engine` and `BB_SRC_DIR=$BB_ROOT/src`, and environment values win (that is how the test works).
  `step`/logging are not needed here: rebase.sh wraps patches.sh in `step`.
- BB patch layout (ADR Решение 2): `src/bb/patches/<eN-slug>/<kebab-name>/<kebab-name>.patch` with
  `README.md` next to it. Address and print a patch as `<eN-slug>/<kebab-name>`. `check`/`status` without
  args take every such dir; with args, only the dirs given.
- Target files of a BB patch: the `+++ b/<path>` lines of its `.patch` (for check/status). For export,
  use the README frontmatter `files:` list (ADR: "files из README"): parse the `  - <path>` lines after `files:` up to
  the next key.
- "Firefox" commit: the root commit of the engine repo, `git rev-list --max-parents=0 HEAD` run inside
  `$BB_ENGINE_DIR`. Run every git command with `git -C "$BB_ENGINE_DIR"` (the script may do that; only
  agents' own Bash calls are barred from it).
- Zen patches for a target file `<dir>/<name>` (ADR rule, exactly these two sources):
  1. `$BB_SRC_DIR/<dir>/<name with every "." replaced by "-">.patch`, if it exists. Real examples:
     `browser/base/content/browser.js` → `src/browser/base/content/browser-js.patch`, and
     `browser/components/sessionstore/SessionStore.sys.mjs` → `src/browser/components/sessionstore/SessionStore-sys-mjs.patch`;
  2. every `$BB_SRC_DIR/external-patches/**/*.patch` containing the line `+++ b/<dir>/<name>`.
  Never treat anything under `src/bb/` as a Zen patch.
- Temporary index: `GIT_INDEX_FILE=<mktemp file>` + `git read-tree <firefox>`. For the zen base, apply each
  Zen patch with `git apply --cached --ignore-space-change --ignore-whitespace`. Those are the import tool's own
  flags (ADR §Контекст п.2). Then run `git apply --cached --check` with the same flags for the BB patch. Do it twice:
  `clean` base (Firefox only) and `zen` base (Firefox + Zen patches of the patch's files; skip `zen` when
  there are none). Remove the temp index on exit (trap). Never write the real index or the work tree.
- check output, fixed (rebase.sh and report.sh will grep it): one line per patch, `OK <id>` or
  `FAIL <id>: <clean|zen> <first line of git's error>`. Exit 1 if any FAIL, else 0.
- export: zen-base temp index, then
  `git diff --src-prefix=a/ --dst-prefix=b/ --full-index -- <files>` (the import tool's export flags, ADR R2)
  → overwrite `<dir>/<kebab-name>.patch`. On an empty diff: error on stderr, exit 1, file untouched.
- status: per patch, `git apply --check -R --ignore-space-change --ignore-whitespace` of the BB patch in the
  engine work tree → `applied <id>`, otherwise `not-applied <id>`. Exit 0.
- macOS bash 3.2: no associative arrays, no `mapfile`, no `${var,,}`; BSD `sed`/`grep`/`mktemp`.
- Out of scope: the `package.json` `bb:patches` hook, `--reject` repair mode (rebase task 0007),
  writing any real BB patch (0006).

## Handoff

## Result
Round 2 (review items 1–5):
1. patches.sh now `set -euo pipefail`; rc protocol via `|| rc=$?`; `[ … ] && echo` replaced by `if`.
   The test keeps `set -u` only, with a comment (its asserts rely on non-zero statuses).
2. Fail fast with `no root commit in <dir>` (exit 1) when the engine has no commits; `read-tree`
   errors are captured into `ERR`.
3. Test passes `TMPDIR="$T"` to the script (both calls) and sets `GIT_CONFIG_GLOBAL=/dev/null`.
4. Loops use `while IFS= read -r` (paths with spaces work).
5. `export` runs `git add -N` on the README files in the temp index, so files created by a BB patch
   are included. Not covered by a test (existing tests untouched by rule).
Verified: `bash -n` clean; `/bin/bash scripts/bb/tests/patches_test.sh` → PASS; `npm run|surfer` grep → 0.

Round 1: added `scripts/bb/patches.sh` (check/export/status, git only, temp index) and
`scripts/bb/tests/patches_test.sh` (fixture under mktemp -d, covers DoD a–j).
Verified: `bash -n` clean; `/bin/bash scripts/bb/tests/patches_test.sh` → PASS; grep for `npm run|surfer` → 0.
`export <dir>` takes a patch dir path or an `<epic>/<name>` id. Not run: `diff.sh --names` (only the two files changed).

## Review
APPROVE

Checklist (round 2): (1) spec — check/export/status match the teamlead notes and ADR-0002 R2. Output
lines are `OK|FAIL <id>: <clean|zen> …`, `applied|not-applied <id>` and `no BB patches`, and the exit codes are
0/1/2 as specified. (2) scope — diff.sh shows only the two allowed_paths. (3) layer — no Zen/Firefox files,
no prefs, nothing in engine/; layer_lint: 0 fail, 0 warn. (4) correctness — all round-1 items are fixed:
`set -euo pipefail` with `|| rc=$?` captures (patches.sh:107,131), the empty-root-commit guard (patches.sh:24–25),
`ERR` set on a `read-tree` failure (patches.sh:83), `while IFS= read -r` loops, `git add -N` for new files in the temp
index only, and the temp index is removed by the EXIT trap. The test's `set -u`-only choice is explained in a
comment (patches_test.sh:3). (5) verification — I ran these myself: `bash -n` → no output; `/bin/bash
scripts/bb/tests/patches_test.sh` → `PASS`; the `npm run|surfer` grep → `0`. The ## Result claims hold. (6) hygiene —
English, no TODOs, no secrets.

Non-blocking (for a later task, no return needed):
1. scripts/bb/patches.sh:24–25 — the root-commit guard runs before argument parsing. So with no engine,
   `patches.sh bogus` exits 1 ("no root commit") instead of 2 (usage). If rebase.sh/report.sh will rely on exit 2,
   move the guard after the usage checks.
2. scripts/bb/patches.sh:134 — the `git add -N` path (a BB patch that creates a file) has no test. 0006 should add one
   when it writes the first real patch.

---
Round 1:
REQUEST_CHANGES

Checklist: (1) spec — check/export/status match the teamlead notes and ADR-0002 R2; output formats are
right. (2) scope — only the two allowed_paths are touched (diff.sh shows 2 files). (3) layer — no Zen/Firefox
files, no prefs; layer_lint: 0 fail, 0 warn. (4) correctness — see items 1–3. (5) verification — I re-ran
`/bin/bash scripts/bb/tests/patches_test.sh` → PASS; `bash -n` and the `npm run|surfer` grep check
out; the "Not run: diff.sh --names" note is honest. (6) hygiene — English, no TODOs, no secrets.

1. scripts/bb/patches.sh:4 — `set -u` only; the reviewer checklist requires `set -euo pipefail` for shell
   scripts. Switch to it and keep the rc protocol under `-e` by writing `rc=0; make_index "$base" $files || rc=$?`
   (line 101–102) and `make_index zen $files || rc=$?` + `case $rc` (line 127–128). Also guard the
   `[ -f … ] && echo` lines (39–40, 65–67) so a false test is not the function's last status
   (`if …; then …; fi`). Make the same change in scripts/bb/tests/patches_test.sh:3, or say in a comment why the
   test needs `set -u` only (its assert helpers depend on `$?`).
2. scripts/bb/patches.sh:24,79 — if `$BB_ENGINE_DIR` is not a git repo or has no commits, `FIREFOX` is empty.
   Then every patch prints `FAIL <id>: clean ` with an empty reason, because `read-tree` fails at line 79
   without setting `ERR`. Fail fast after line 24: `[ -n "$FIREFOX" ] || { echo "patches.sh: no root commit in $BB_ENGINE_DIR" >&2; exit 1; }`
   (status and export need it too), and set `ERR` when `read-tree` fails at line 79.
3. scripts/bb/tests/patches_test.sh:24 — DoD 4 says the test writes only under its `mktemp -d`. Right now
   patches.sh makes its own temp dir under the caller's `$TMPDIR` (patches.sh:14). Pass `TMPDIR="$T"` in `run()`
   and in the direct call at line 123. Also set `GIT_CONFIG_GLOBAL=/dev/null` next to line 15, so a
   developer's global `commit.gpgsign`/hooks cannot break the fixture commits.

Non-blocking (fix if cheap, otherwise answer in ## Result):
4. scripts/bb/patches.sh:84,93,140 — word-splitting over `$(patch_dirs)` / `$patches` breaks if
   `BB_ROOT` or `BB_SRC_DIR` contains a space. Use `while IFS= read -r` loops.
5. scripts/bb/patches.sh:131 — a BB patch that creates a new file (not in the Firefox tree) is left out of
   `export`, because `git diff` against the index skips untracked paths. Either `git add -N` those files
   into the temp index, or note this limit in ## Result for 0006.

## QA
PASS

1. Build: type none, skipped. `test.sh lint` → OK (0 problems); layer_lint 0 fail, 0 warn.
2. DoD 1: `bash -n scripts/bb/patches.sh` → exit 0, no output.
3. DoD 2: `/bin/bash scripts/bb/tests/patches_test.sh` → `PASS` (covers a–j).
4. DoD 3/4: the test uses a `mktemp -d` fixture with `BB_ENGINE_DIR`/`BB_SRC_DIR` and passes `TMPDIR` to the script. I did not trace the cleanup by hand.
5. DoD 5: `grep -c -E "npm run|surfer" scripts/bb/patches.sh` → `0`.
6. DoD 6: `diff.sh --names` lists only `scripts/bb/patches.sh` and `scripts/bb/tests/patches_test.sh`.

For the human: none. Non-blocking notes from the review still apply (usage exit 2 vs the root-commit guard order; no test for new-file patches).
