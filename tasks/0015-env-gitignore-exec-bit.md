---
id: 0015
title: .gitignore re-includes configs/bb/mozconfig; BB entry-point scripts are executable (git mode 100755)
epic: layer
prefix: layer
kind: script
role: rebaser
size: S
status: blocked
base: feat/layer
branch: task/0015-env-gitignore-exec-bit
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
allowed_paths:
  - .gitignore
  - scripts/bb/l10n.sh
  - scripts/bb/patches.sh
  - scripts/bb/rebase.sh
  - scripts/bb/report.sh
  - scripts/bb/smoke.sh
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#границы--где-живут-брендинг-mozconfig-и-вырезание
returns: 0
sessions: 1
reviewed_sha:
qa_sha:
blocked_reason: hook denies both `git update-index --chmod=+x` and `chmod +x` for the rebaser role; exec bit cannot be set
---
## Goal
Two environment defects found by 0004 and 0006. (1) `.gitignore` line `mozconfig` ignores every file of that name, so
`configs/bb/mozconfig` (ADR-0002 §Границы: BB build flags) is tracked only because it was force-added; a new clone or a
renamed copy silently drops it. (2) The BB entry-point scripts are committed as 100644, so the ADR's
`scripts/bb/rebase.sh <tag>` form fails with "permission denied". Content of the scripts does not change.

## Definition of Done
1. `git check-ignore --no-index -v configs/bb/mozconfig` → one line ending in `!configs/bb/mozconfig	configs/bb/mozconfig`.
2. `git check-ignore --no-index -v engine/mozconfig` → still matched by the bare `mozconfig` rule (no `!` in the output).
3. `git ls-files -s scripts/bb` → `100755` for exactly `l10n.sh`, `patches.sh`, `rebase.sh`, `report.sh`, `smoke.sh`;
   `lib.sh`, `smoke.d/*` and `tests/*` stay `100644`.
4. `git diff feat/layer --numstat -- scripts/bb` → exactly 5 lines, each `0	0	scripts/bb/<name>.sh` (mode-only change).
5. `scripts/agents/diff.sh tasks/0015-env-gitignore-exec-bit.md --names` lists only allowed_paths.

## Notes from teamlead
- `.gitignore`: add `!configs/bb/mozconfig` on the line right after `mozconfig` (line 29), with a comment line above it:
  `# BB: configs/bb/mozconfig is the BB build-flags fragment (ADR-0002)`. `configs/bb/mozconfig.macos` is not matched by
  `mozconfig` (pattern is the whole name), so it needs no rule. Touch nothing else in the file.
- Mode: `git update-index --chmod=+x <file>`, one file per call, then commit. If the hook denies it, `chmod +x <file>`
  (core.fileMode picks it up). Do not run the scripts.
- Role is rebaser only because the agent hook lets only rebaser (and qa for smoke.sh) run commands that name
  `scripts/bb/rebase.sh` / `smoke.sh`. No rebase work here.
- `lib.sh` is sourced, not executed; tests are run as `bash <test>` — they stay 100644.

## Handoff
Session 1 (rebaser), 2026-10-30. The session prompt was framed as a rebase with an empty tag, but this task file says
"No rebase work here", so I did not run rebase.sh.

Done:
- `.gitignore`: added `# BB: configs/bb/mozconfig is the BB build-flags fragment (ADR-0002)` and
  `!configs/bb/mozconfig` right after the bare `mozconfig` line. Nothing else changed. Committed as be674b19f
  (`layer: re-include configs/bb/mozconfig in .gitignore`).

Blocked:
- DoD 3/4 (exec bit): the permission layer denied `git update-index --chmod=+x scripts/bb/l10n.sh`, and then the
  fallback `chmod +x scripts/bb/l10n.sh`. The Write/Edit tools cannot set file modes, so this role has no allowed
  route. All five scripts are still 100644.
- DoD 1/2 not verified: `git check-ignore --no-index -v …` was also denied. The rule should still work: the
  negation comes after `mozconfig` and `configs/bb/` itself is not ignored.

Next step (owner or teamlead): allow `git update-index --chmod=+x scripts/bb/*.sh` (or `chmod +x`) for the role that
gets this task, or run the 5 commands by hand:
`git update-index --chmod=+x scripts/bb/{l10n,patches,rebase,report,smoke}.sh`, commit `layer: make BB entry-point
scripts executable`, then check DoD 1–5.
