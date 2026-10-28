---
id: 0005
title: scripts/bb/patches.sh check|export|status — BB patches against clean Firefox and Firefox + Zen
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: ready
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
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
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

## Review

## QA
