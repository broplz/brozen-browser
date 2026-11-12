---
id: 0034
title: rebase.sh finalize sets brands.bb displayVersion to the target Zen tag in the same commit
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: done
base: feat/layer
branch: task/0034-bb-rebase-finalize-display-version
depends_on: [0033]
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/bb/rebase.sh
  - scripts/bb/tests/rebase_display_version_test.sh
  - scripts/bb/tests/rebase_fixture.sh
  - scripts/bb/tests/rebase_final_test.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-4
returns: 0
sessions: 0
reviewed_sha: 27696d09be6e11036f474eb610fd093e84a81eef
qa_sha: 27696d09be6e11036f474eb610fd093e84a81eef
blocked_reason: 
---
## Goal
Step 11 of the runbook (ADR-0002 Решение 4, `do_finalize` in scripts/bb/rebase.sh) writes the new base into
src/bb/layer.yaml and the report in one commit. The BB brand's `brands.bb.release.displayVersion` in the build
config (repo-root JSON, `$BUILD_CONFIG` in rebase.sh) is hardcoded `1.23.4b` and goes stale on every rebase.
After this task `do_finalize` sets it to the target tag `$Y` and the finalize commit contains that file too.
Owner's backlog item 0034, needed before the rebase to 1.24.1b. (ADR-0002 l.197 says displayVersion becomes BB's
own version in E0; until the E0 ADR exists, the owner's choice is "= Zen tag".)

## Definition of Done
1. `/bin/bash scripts/bb/tests/rebase_display_version_test.sh` → exit 0, last line `rebase_display_version_test: OK`.
   Fixture and stubs as in `rebase_final_test.sh` (finalize runs via `--continue` on `rebase/<tag>`,
   `BB_POST_STEPS=finalize`). Cases:
   a. finalize ok → in the finalize commit (`git show --name-only HEAD`) the build config, `src/bb/layer.yaml`
      and `docs/rebase/<tag>.md` are listed; the config's `bb` brand has `"displayVersion": "<tag>"`; the
      `release` brand's `displayVersion` is unchanged; every other line of the config is byte-identical
      (`git diff HEAD~1 HEAD -- <config>` shows exactly one `-` and one `+` line).
   b. the config on `rebase/<tag>` has no `bb` brand → exit 1, stderr names `displayVersion`, HEAD is not a
      finalize commit, `git status --porcelain` shows no change to the config or `src/bb/layer.yaml`.
2. Existing tests still pass: `/bin/bash scripts/bb/tests/rebase_final_test.sh`, `rebase_continue_test.sh`,
   `rebase_post_test.sh`, `rebase_test.sh` (all under `scripts/bb/tests/`) → exit 0.
   In `rebase_final_test.sh` the only allowed change is the expected string of check "b: files" (line 99): it
   gains the build config entry (`M <config> `) at the position `git diff-tree` prints it (path-sorted). No other
   line of that test changes (`git diff feat/layer -- scripts/bb/tests/rebase_final_test.sh` shows one `-` and one `+` line).
3. `scripts/agents/diff.sh tasks/0034-bb-rebase-finalize-display-version.md --names` lists only allowed_paths and the task file.

## Notes from teamlead
- Rewrite with awk, line-based, like `rewrite_base` (rebase.sh:266): inside the `"bb": {` object of `"brands"`,
  replace the value of the first `"displayVersion"` line; keep indentation, quotes and the trailing comma as they
  are. No `python3 -m json`/`jq` round trip (it would reformat the file). The awk exits non-zero when it did not
  replace a line → `say_fail "no brands.bb displayVersion in $BUILD_CONFIG"; return 1`.
- Order in `do_finalize`: config first, then layer.yaml, then report, then `git add` of all of them (add
  `"$BUILD_CONFIG"` to the existing `g add` line) and the one commit. A failure before the commit must leave both
  files untouched: write to a temp file and replace only on success.
- Both rewrites (layer.yaml, config) use one helper, e.g. `replace_with <file> <cmd…>` (run cmd into a mktemp file,
  then `cat tmp >file`, rm tmp; non-zero on failure) — the current temp-file dance at rebase.sh:286-289 moves into
  it; do not duplicate it.
- Never type the config file's name or the word `surfer` in a Bash command (hook); rebase.sh already holds it in
  `BUILD_CONFIG`. In the test, build the name the same way or write the JSON via `ff_cfg`.
- rebase_fixture.sh: extend `ff_cfg` so the JSON it prints also has
  `"brands": { "release": { "release": { "displayVersion": "9.9.9" } }, "bb": { "release": { "displayVersion": "0.0.0" } } }`
  (multi-line, one key per line, like the real file) — `tag_firefox` must still read `version.version`. That keeps
  rebase_final_test.sh and rebase_continue_test.sh green (except the one expected-list line in rebase_final_test.sh).
- Re-spec 2026-11-12 (session 1 blocked): rebase_final_test.sh:99 asserts the finalize commit's exact file list, so it
  must list the config too. It is now in allowed_paths for that single line only. Make the edit with the Edit tool
  (the config's name in a Bash command is hook-blocked; in a file it is fine).
- No change to `finalize_subject`/`finalized` (0019): the commit subject stays the same.
- Hook: no agent role but rebaser may run a command naming `scripts/bb/rebase.sh`; tests reach it via `$here/../rebase.sh`.

## Handoff
Done: rebase.sh `rewrite_display_version` + `replace_with` helper, `do_finalize` rewrites the config first and adds it
to the commit; `ff_cfg` extended with `brands`; new `rebase_display_version_test.sh` → OK. rebase_continue_test,
rebase_post_test, rebase_test pass.
Blocked (spec contradiction): `rebase_final_test.sh` check "b: files" (line 99) asserts the finalize commit's exact file
list `A docs/rebase/1.0.1b.md M docs/rebase/README.md M src/bb/layer.yaml`. DoD 1a requires the config in that commit,
so the list now also has `M surfer.json` and the check fails. Not avoidable in rebase.sh; fixing needs editing that
existing test (forbidden for me, and outside allowed_paths). Next: teamlead adds `M <config>` (list is sorted:
`M docs/rebase/README.md`, `A docs/rebase/1.0.1b.md`, `M src/bb/layer.yaml`, `M surfer.json`) to line 99 of
rebase_final_test.sh, or allows the edit; then this task is ready for review.

## Result
Round 1: `rebase.sh` gets `replace_with` (temp-file replace helper, shared by layer.yaml and config rewrites) and
`rewrite_display_version` (awk, line-based, `brands.bb` first displayVersion = `$Y`); `do_finalize` rewrites the
config first and adds it to the finalize commit. `ff_cfg` in the fixture gains `brands`. New
`rebase_display_version_test.sh`. `rebase_final_test.sh:99` only gained `M surfer.json ` in the expected list.
Verified by running: rebase_display_version_test, rebase_final_test, rebase_continue_test, rebase_post_test,
rebase_test — all pass. Note: diff.sh `--names` printed a stat, listing only allowed files (the final_test edit is
uncommitted until this commit).

## Review
APPROVE
Checklist: (1) spec — `rewrite_display_version` (awk, line-based, first displayVersion after `"bb": {` inside
`"brands"`, exit !done) and `replace_with` match the notes; order config → layer.yaml → report → one `g add` + commit;
subject unchanged. Test covers DoD 1a (files, bb value, release kept, exactly one -/+ line) and 1b (exit 1, stderr,
HEAD unchanged, porcelain clean). (2) scope — 4 allowed files; rebase_final_test.sh changes only line 99 (one -/+),
new entry in path-sorted position. (3) layer — scripts only, layer_lint 0 fail/0 warn. (4) correctness — temp file
removed on every path; on a layer.yaml failure the config is restored with `g checkout`. (5) Result claims match the
diff; I did not run the tests (hook blocks rebase commands for reviewer) — qa runs them. (6) no TODOs/secrets.
Non-blocking, for the owner / a later task:
1. scripts/bb/rebase.sh:315 — when the report or the commit fails, config and layer.yaml stay rewritten (same as
   before for layer.yaml). The rewrites are idempotent, so `--continue` heals it, but the note "a failure before the
   commit must leave both files untouched" holds only for the two rewrite steps.
2. scripts/bb/tests/rebase_display_version_test.sh:27-67 — a third copy of the fixture() from rebase_final_test.sh /
   rebase_continue_test.sh (the DoD asked for "as in"); moving it into rebase_fixture.sh is backlog material.
3. scripts/bb/tests/rebase_fixture.sh:7 — the header comment for `ff_cfg` does not mention the new `brands` block.

## QA
PASS
1. Lint: `test.sh lint` OK (0 problems); layer_lint 0 fail / 0 warn (log: logs/test-lint-20261112-160026.log).
2. DoD 1: `rebase_display_version_test.sh` → exit 0, last line `rebase_display_version_test: OK`.
3. DoD 2: rebase_final_test, rebase_continue_test, rebase_post_test, rebase_test all pass; `git diff feat/layer -- rebase_final_test.sh` shows exactly one `-`/one `+` line (line 99, adds `M surfer.json `).
4. DoD 3: diff.sh --names lists only rebase.sh, the 3 allowed tests (task file excluded/allowed).
