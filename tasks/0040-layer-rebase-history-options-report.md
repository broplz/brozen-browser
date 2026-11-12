---
id: 0040
title: Report — how rebase.sh should carry the layer history (squash / merge / rerere as is), for the owner to decide
epic: layer
prefix: layer
kind: docs
role: developer
size: S
status: ready
base: feat/layer
branch: task/0040-layer-rebase-history-options-report
depends_on: []
build: none
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - docs/reports/0040-rebase-history-options.md
  - docs/reports/decisions-needed.md
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-3
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
`rebase.sh` step 4 (`git rebase --onto Y bb/base/X`, ADR-0002 Решение 4 p.4) replays the whole layer history:
154 commits on feat/layer. In the 1.24.1b rebase, `src/browser/base/content/zen-assets.jar.inc.mn` conflicted twice,
on the replayed commits of 0013 and 0035, although the final state does not conflict
(docs/rebase/1.24.1b.md, `## Notes`). After this task a report compares the options with their consequences for
ADR-0002, so the owner can decide. Report only: no script, ADR or task change.

## Definition of Done
1. `docs/reports/0040-rebase-history-options.md` has exactly these `## ` headings, in this order: `## Facts`,
   `## Options`, `## Consequences for ADR-0002`, `## Recommendation`, `## Open questions`.
2. `## Facts` gives numbers with the command that produced each one:
   - the commit count `bb/base/<X>..feat/layer` for the current base tag X (`base: zen:` in `src/bb/layer.yaml`);
   - how many of those commits touch at least one hook/edit file from `layer.yaml` (`hooks`, `edits`), with
     `git log --oneline -- <file>` counts per file;
   - the 1.24.1b conflict count from docs/rebase/1.24.1b.md: 1 file, resolved twice.
3. `## Options` has one `### ` subsection each for: A squash the layer into one commit before the rebase; B squash into
   one commit per epic/topic (ADR-0002 Решение 3 p.3 already asks for "patch + README in one commit, hook + layer.yaml
   entry in one commit"); C `git merge` of tag Y instead of a rebase; D keep as is, with rerere. Each subsection has
   the lines `Conflicts per rebase:`, `Effect on the N5 metric:`, `History/blame kept:`, `rebase.sh change:`,
   `Pipeline change:` (feat/* branches, `bb/base/<tag>`, task branches, finish_feature.sh).
4. `## Consequences for ADR-0002` names, for every option, each ADR line that would have to change, as
   `docs/adr/0002-bb-layer-and-rebase-runbook.md:<line>`. At least l.173, l.224, l.231 and l.284 are discussed.
5. `## Recommendation` starts with one line `Recommendation: A|B|C|D` followed by ≤ 5 lines of reasons.
6. `docs/reports/decisions-needed.md` gains exactly one line pointing to the report (`git diff feat/layer --
   docs/reports/decisions-needed.md` shows only `+` lines, one of them).
7. `scripts/agents/diff.sh tasks/0040-layer-rebase-history-options-report.md --names` lists only allowed_paths and the task file.
8. [human] The owner reads the report and picks an option. The pick becomes an ADR change plus new backlog items;
   it is not part of this task.

## Notes from teamlead
- Read-only git only: `git log`, `git rev-list --count`, `git show`, `git diff`, `git tag -l`. Hooks block
  `git rebase`, `git merge`, `git worktree`, `git -C` and `git reset` for every role. Do not try a squash or merge
  for real. If a number needs one, write `not measured: <why>`.
- `main` is untouched since the rebase. `publish` went into feat/layer (docs/rebase/1.24.1b.md:65), so count from
  `bb/base/<X>` as it exists now. Run `git tag -l 'bb/base/*'` first. If that tag is missing, say so in `## Facts`
  and count from the Zen tag instead.
- Keep the 0035 lesson in mind: hooks were moved off the append points, so a hook that was moved later in history
  conflicts once per historic position. Option D's row must say whether rerere helps when the conflicting context
  differs between the replayed commits.
- Option C breaks ADR l.173 ("main = Zen tag + a linear series of BB commits") and the `bb/base/<tag>` + `rebase
  --onto` mechanics. Name what `recon`, `report.sh` (N5 metric) and `finish_feature.sh` would have to do differently.
- Do not open, edit or quote rebase.sh or finish_feature.sh in Bash: names under scripts/bb/rebase.sh are hook-blocked
  for non-rebasers. Read them with the Read tool if needed.
- English, ≤ ~200 lines.

## Handoff

## Result

## Review

## QA
