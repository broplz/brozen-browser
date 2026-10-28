---
id: 0004
title: configs/bb/mozconfig + mozconfig.macos (empty fragments) and their hook line in configs/common/mozconfig
epic: layer
prefix: layer
kind: feature
role: developer-hard
size: S
status: done
base: feat/layer
branch: task/0004-bb-mozconfig-hook
depends_on: [0001]
build: full
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - configs/bb/mozconfig
  - configs/bb/mozconfig.macos
  - configs/common/mozconfig
  - src/bb/layer.yaml
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#границы--где-живут-брендинг-mozconfig-и-вырезание
returns: 0
sessions: 0
reviewed_sha: d893683d24fc6bc1d82692706219234775470180
qa_sha: d893683d24fc6bc1d82692706219234775470180
blocked_reason: 
---
## Goal
Give BB its own build-flag fragments, as ADR-0002 §Границы and the hook table in Решение 1 require:
`configs/bb/mozconfig` and `configs/bb/mozconfig.macos`. They hold comments only for now, because
the flags themselves come from ADR-0003 and E0. Add the one hook line to Zen's
`configs/common/mozconfig` that sources the fragments, and register that hook in
`src/bb/layer.yaml: hooks`. After this task, flag work in E0 and ADR-0003 is only an edit in `configs/bb/`.

## Definition of Done
1. `configs/bb/mozconfig` and `configs/bb/mozconfig.macos` exist and contain only `#` comment lines,
   blank lines, and (in `mozconfig` only) the line that sources `mozconfig.macos`.
   `grep -v -E "^#|^$" configs/bb/mozconfig.macos | wc -l` → `0`.
2. `grep -n 'configs/bb/mozconfig"' configs/common/mozconfig` → exactly one line,
   `. "$topsrcdir/../configs/bb/mozconfig"`, which is the last non-blank line of the file. A
   `# BB(layer): ...` marker line sits directly above it.
3. `scripts/agents/diff.sh tasks/0004-bb-mozconfig-hook.md` shows exactly 2 added and 0 removed lines in
   `configs/common/mozconfig`.
4. `grep -c "file: configs/common/mozconfig" src/bb/layer.yaml` → `1`. The entry has `epic: layer` and
   `line:` equal to the exact hook line. Nothing else in layer.yaml changed.
5. `scripts/agents/diff.sh tasks/0004-bb-mozconfig-hook.md --names` lists only the four allowed_paths.
6. `python3 scripts/agents/layer_lint.py 0004` → no FAIL lines.
7. `scripts/agents/build.sh full` → `BUILD RESULT: OK`. A wrong path makes `.` fail in mozconfig
   evaluation, so a green build proves both fragments were sourced.
8. `grep -n "configs/bb/mozconfig" engine/mozconfig` → the hook line is present in the generated mozconfig.

## Notes from teamlead
- Hook line, exact text from the ADR-0002 table: `. "$topsrcdir/../configs/bb/mozconfig"`. Use
  `$topsrcdir` WITHOUT braces. The build tooling substitutes `${…}` templates in configs/common/mozconfig
  (`${binName}`, `${brandingDir}`, `${changeset}`), so do not give it another `${…}`.
- Put the hook at the END of configs/common/mozconfig. The ADR rule is "Zen flags are not duplicated, only added or
  overridden", so BB must come after Zen's common flags.
- Fact for the configs/bb/mozconfig comment: the build concatenates common, then `configs/macos/mozconfig`, so
  Zen's macOS flags still come after BB's.
- The ADR names only ONE hook line. So `mozconfig.macos` is reached from `configs/bb/mozconfig`
  through `. "$topsrcdir/../configs/bb/mozconfig.macos"`, unconditionally, because BB is macOS-only.
  Do not add a second hook to Zen's `configs/macos/mozconfig`.
- Fragment contents: an MPL-free short header that says what goes here (release flags such as PGO/LTO/SDK
  and strip flags `--disable-*`, `MOZ_*=`), who decides it (E0, ADR-0003), and the rule "add or override,
  never copy Zen's flags". Add no actual options. An empty fragment is the deliverable.
- configs/common/mozconfig is a Zen flat file (class 2): make a plain edit. A `.patch` is forbidden and so is
  `npm run export`.
- layer.yaml: append one entry to `hooks:` with the existing schema (`file`, `line`, `epic: layer`, `why`).
  Do not touch `base`, `edits`, `zen_patches` or the other hooks.
- Out of scope: the `package.json` `bb:*` scripts hook, branding, any real flags.
- Build: the diff touches mozconfig, so `build.sh auto` also picks full. Only developer-hard and qa may run it.
  Strikes: 2 failed full builds → write the Handoff and set status blocked.

## Handoff

## Result
Round 1.
- `configs/bb/mozconfig`: comment header (what goes here, who decides it (E0/ADR-0003), the add/override rule, the
  order common → BB → Zen macOS) plus one line `. "$topsrcdir/../configs/bb/mozconfig.macos"` (unconditional, macOS-only).
- `configs/bb/mozconfig.macos`: comments only.
- `configs/common/mozconfig`: +2 lines at the end, the `# BB(layer): ...` marker and `. "$topsrcdir/../configs/bb/mozconfig"`.
- `src/bb/layer.yaml`: one new `hooks:` entry (file, exact line, epic: layer, why). Nothing else changed.

Verified (run this session):
1. `grep -c -v -E "^#|^$" configs/bb/mozconfig.macos` → 0.
2. The hook line is at configs/common/mozconfig:106, the last line, with the marker directly above it.
3. diff.sh `--names`: configs/common/mozconfig 2 added, 0 removed. The diff has exactly the four allowed_paths.
6. `layer_lint.py 0004` → 0 fail, 0 warn.
7. `scripts/agents/build.sh full` → `BUILD RESULT: OK type=full duration=1732s` (logs/build-full-20261029-022820.log).
8. `grep -n "configs/bb/mozconfig" engine/mozconfig` → line 108, the hook line.

Open points for the reviewer:
- `.gitignore:29` has a bare `mozconfig` that ignores `configs/bb/mozconfig`. I added the file with `git add -f`
  (commit d893683d2). It is tracked now, but `git add` without `-f` refuses new files of that name. Logged in
  tasks/backlog.md "Found by agents" (that is the 1 line outside allowed_paths, from the protocol's Found-by-agents rule).
- build.sh printed the whole log to stdout instead of only the triage. That was not changed here.

## Review
APPROVE
Checklist:
1. Spec: matches ADR-0002 §Решение 1 hook table (line 108) and §Границы (line 268). The hook text is exact,
   with no braces, and is the last line of configs/common/mozconfig (106). Both fragments contain comments
   only, plus the unconditional `.` of mozconfig.macos. They add no options.
2. Scope: code diff touches exactly the four allowed_paths. The other changes are the task file and the
   one-line tasks/backlog.md "Found by agents" entry that the protocol allows. No tests were touched.
3. Layer: class-2 plain edit with a `# BB(layer):` marker directly above. There is one layer.yaml `hooks:` entry
   using the existing schema, and nothing else in layer.yaml changed. No patch, no engine/ edits, no prefs.
   layer_lint: 0 fail, 0 warn.
4. Correctness: the hook sits after Zen's common flags, so BB can only add or override them. Zen's macOS
   config still comes after BB's, as the fragment comment says. Both fragments are tracked (`git ls-files
   configs/bb`), even though `.gitignore:29` ignores files named `mozconfig`.
5. Verification: re-checked. engine/mozconfig:108 has the hook line, the cited log
   logs/build-full-20261029-022820.log exists, and the diff counts match.
6. Hygiene: English text, no TODOs, no secrets.
Non-blocking: the `.gitignore` `mozconfig` pattern will refuse future new files with that name unless
`git add -f` is used. It is already in the backlog.

## QA
PASS
1. DoD 1: `grep -c -v -E "^#|^$" configs/bb/mozconfig.macos` → 0. `configs/bb/mozconfig` has only the `.` line for mozconfig.macos besides comments.
2. DoD 2: the hook line is the last line of configs/common/mozconfig (106), with the `# BB(layer):` marker directly above it. It is the only match.
3. DoD 3: diff.sh shows `configs/common/mozconfig | 2 ++`, so 2 added and 0 removed.
4. DoD 4: layer.yaml has one `file: configs/common/mozconfig` entry with `epic: layer` and the exact `line:`. It is a 4-line addition only.
5. DoD 5: `--names` lists exactly the four allowed_paths (22 insertions, 0 deletions).
6. DoD 6: `layer_lint.py 0004` → 0 fail, 0 warn.
7. DoD 7: `build.sh full` → `BUILD RESULT: OK duration=1633s` (logs/build-full-20261029-025811.log).
8. DoD 8: `engine/mozconfig:108` contains the hook line.
9. `test.sh lint` → OK, 0 problems (logs/test-lint-20261029-032528.log).
