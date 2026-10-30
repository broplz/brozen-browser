---
id: 0029
title: layer_lint.py allows a non-bb.* pref only in prefs/bb/strip.yaml and only when no Zen yaml defines it
epic: e1-strip
prefix: e1
kind: test
role: developer
size: S
status: ready
base: feat/layer
branch: task/0029-strip-lint-exception
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/agents/layer_lint.py
  - scripts/agents/tests/test_layer_lint_prefs.py
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#решение-1--уровни-и-правило-выбора
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
ADR-0003 v2 Решение 1, "Размещение префов": the ADR-0002 rule "no foreign pref names in `prefs/bb/`" narrows for
e1-strip. After this task `scripts/agents/layer_lint.py` accepts a non-`bb.*` name in `prefs/bb/strip.yaml` when that
name appears in no `prefs/{zen,firefox,fastfox,privatefox}/**/*.yaml`, and fails it with
`Zen задаёт этот pref: не дублировать` when it does. Every other file under `prefs/bb/` keeps the old rule. This
unblocks 0025, which puts Firefox-only names into `strip.yaml` (ADR 2.1–2.4).

## Definition of Done
1. `scripts/agents/layer_lint.py` replaces the inline loop at l.127-130 with one helper
   `prefs_fails(path, text, zen_names) -> list[str]` (name exact) and one helper `zen_pref_names(branch) -> set[str]`
   (name exact); main() calls both. No other rule in the file changes behaviour.
2. `prefs_fails` returns, for each `- name:` entry in `text`:
   a. `bb.*` name → nothing (any file under `prefs/bb/`);
   b. non-`bb.*` name in a file other than `prefs/bb/strip.yaml` → the existing message
      `<path>: pref <name> outside the bb.* namespace (Zen defaults change in prefs/zen/)`, unchanged;
   c. non-`bb.*` name in `prefs/bb/strip.yaml` that is in `zen_names` →
      `<path>: pref <name>: Zen задаёт этот pref: не дублировать`;
   d. non-`bb.*` name in `prefs/bb/strip.yaml` that is not in `zen_names` → nothing.
3. `zen_pref_names(branch)` collects every `- name:` from all `*.yaml` under `prefs/zen`, `prefs/firefox`,
   `prefs/fastfox`, `prefs/privatefox`, recursively, including entries whose value is `"@cond"` (ADR R6). The four
   directory names live in one tuple at the top of the file next to `CLASS2`/`SCOPE_FREE`.
4. `python3 scripts/agents/tests/test_layer_lint_prefs.py` → exit 0, prints `test_layer_lint_prefs: OK`. It builds a
   temp git repo (tempfile, sets `config.ROOT` before calling the helpers — the pattern of
   `scripts/agents/tests/test_same_code.py`) with fixture yaml and asserts:
   a. `strip.yaml` with a Firefox-only name (`browser.discovery.enabled`) → no fail;
   b. `strip.yaml` with a name that a fixture `prefs/firefox/ai.yaml` defines → exactly one fail containing
      `Zen задаёт этот pref: не дублировать`;
   c. same, the name defined only as a `value: "@cond"` entry in a fixture `prefs/zen/x.yaml` → fail;
   d. same, the name defined in a nested fixture `prefs/privatefox/sub/y.yaml` → fail;
   e. a non-`bb.*` name in `prefs/bb/bb.yaml` → the old `outside the bb.* namespace` fail;
   f. `bb.strip.ai` in `strip.yaml` → no fail.
5. `python3 scripts/agents/layer_lint.py tasks/0024-strip-inventory.md` → exit code unchanged from before this task
   (regression on a merged task).
6. `python3 scripts/agents/layer_lint.py tasks/0029-strip-lint-exception.md` → 0 fail.
7. `scripts/agents/diff.sh tasks/0029-strip-lint-exception.md --names` lists only allowed_paths.

## Notes from teamlead
- Read Zen yaml through the existing `file_text(path, branch)`; list the files with
  `pl.git_out("ls-tree", "-r", "--name-only", branch, "--", <dirs>)` (or the same helper the file already uses) — no
  second file-reading path, no `os.walk` over the working tree (lint must see the branch, not the checkout).
- Name regex: reuse the one at l.128 (`^\s*-\s*name:\s*([^\s#]+)`); define it once as a module constant and use it for
  both helpers.
- `strip.yaml` path is one constant; do not generalise to "any yaml in prefs/bb/" — the ADR exception is this file
  only.
- The message text `Zen задаёт этот pref: не дублировать` is quoted from ADR-0003 v2 verbatim (the one non-English
  string allowed here: the ADR fixes it).
- build none: no engine needed.

## Handoff

## Result

## Review

## QA
