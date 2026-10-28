---
id: 0004
title: configs/bb/mozconfig + mozconfig.macos (empty fragments) and their hook line in configs/common/mozconfig
epic: layer
prefix: layer
kind: feature
role: developer-hard
size: S
status: ready
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
reviewed_sha:
qa_sha:
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

## Review

## QA
