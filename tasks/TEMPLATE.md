---
id: 0000
title: One line — what exists after this task
epic: layer              # layer | e0 … e11
prefix: layer            # commit prefix: layer | e<N>
kind: feature            # feature | script | docs | patch | test | rebase | bug
role: developer          # developer | developer-hard | rebaser
size: S                  # S ≤150 production lines / 5 files · M ≤300 / 10 · L ≤500 / 15
status: draft            # draft | ready | in_progress | review | qa | approved | done | returned | blocked | split
base: feat/layer         # branch tasks merge into — always a feat/* branch, never main
branch: task/0000-slug
depends_on: []           # task ids that must be done first
build: ui                # none | ui | full — what qa must run before PASS
tests: []                # Zen mochitest dirs for test.sh (e.g. glance); usually []
needs_approval: false    # true → the merge waits for "0000 approved" in tasks/approvals.txt
allow_zen_patch: false   # true only when a BB hunk must live inside one of Zen's patches (ADR-0002 §2 p.4)
zen_tag:                 # role rebaser only, required there: the Zen tag to bring the layer to, quoted (e.g. "1.23.4b")
allowed_paths:           # exact files or narrow globs; the hooks enforce this
  - src/bb/example/example.mjs
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#решение-1
returns: 0               # driver-maintained
sessions: 0              # driver-maintained
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
One paragraph: what exists after this task and why, citing the ADR section it implements.

## Definition of Done
1. `<command>` → expected output or state
2. `<file>` contains `<thing>`
3. `scripts/agents/build.sh ui` → BUILD RESULT: OK
(Every item is checkable by qa with a command or a file read. What only a human can see is
tagged `[human]` and makes the task needs_approval: true.)

## Notes from teamlead
Exact rules, numbers, file names and forbidden mechanisms the developer must not re-derive.

## Handoff
(developer, when a session ends before review: done / failed / tried / next idea)

## Result
(developer at review: what changed, how verified, open questions — newest round first)

## Review
(reviewer: APPROVE | REQUEST_CHANGES on the first line, then numbered items with file:line)

## QA
(qa: PASS | FAIL on the first line, then numbered items with repro + log path; "For the human:" list for [human] items)
