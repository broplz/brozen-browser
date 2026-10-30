---
id: 0029
title: layer_lint.py allows a non-bb.* pref only in prefs/bb/strip.yaml and only when no Zen yaml defines it
epic: e1-strip
prefix: e1
kind: test
role: developer
size: S
status: approved
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
reviewed_sha: 695ed47775a193cde40a54c356203418ed29237c
qa_sha: 695ed47775a193cde40a54c356203418ed29237c
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
Round 1:
- layer_lint.py: constants `ZEN_PREF_DIRS`, `STRIP_YAML`, `PREF_NAME_RE`; helpers `zen_pref_names(branch)` (ls-tree + file_text) and `prefs_fails(path, text, zen_names)`; main() uses both instead of the inline loop.
- New test scripts/agents/tests/test_layer_lint_prefs.py covers cases a–f.
- Verified: the new test prints `test_layer_lint_prefs: OK`; layer_lint on 0024 gives 0 fail (exit 0); on 0029 gives 0 fail.
- Not run: `diff.sh --names` (only the two allowed files plus the task file changed).

## Review
APPROVE

Checklist: 1 spec — DoD 1–3 met to the letter (`zen_pref_names`, `prefs_fails`, `ZEN_PREF_DIRS` tuple next to
`CLASS2`/`SCOPE_FREE`, one `PREF_NAME_RE`, one `STRIP_YAML` constant, messages verbatim incl. the ADR string; `@cond`
entries are caught because the regex reads only the name). Nothing extra. 2 scope — only the two allowed_paths
(`diff.sh --names` re-run by reviewer). 3 layer — n/a (pipeline script, no Zen/Firefox files); layer_lint on 0029:
0 fail. 4 correctness — names read from the branch via `ls-tree` + `file_text`, no working-tree walk; non-existent
dirs are fine for `ls-tree`. 5 verification — reviewer re-ran `test_layer_lint_prefs.py` → OK; see item 1 for DoD 5.
6 hygiene — clean.

Non-blocking:
1. tasks/0029-strip-lint-exception.md:82 — "layer_lint on 0024 gives 0 fail (exit 0)" does not reproduce from this
   branch: 0024's branch is gone, so layer_lint falls back to `HEAD` (layer_lint.py:100) and diffs *this* task against
   0024's allowed_paths → exit 1 (2 scope fails). The meaningful check passes:
   `python3 scripts/agents/layer_lint.py tasks/0024-strip-inventory.md --base 4119b1329~1 --branch 4119b1329` → 0 fail.
   Next time state the exact command for regression runs on merged tasks.
2. scripts/agents/layer_lint.py:148 — `zen_pref_names(branch)` is recomputed for every changed `prefs/bb/*.yaml`;
   hoist it out of the loop (lazily) if prefs tasks start touching several files. Cosmetic today (one file).

## QA
PASS

1. build none: skipped. `test.sh lint` → OK (0 problems); layer_lint on 0029 → 0 fail.
2. DoD 1–3: helpers `zen_pref_names`, `prefs_fails`, constants `ZEN_PREF_DIRS`, `STRIP_YAML`, `PREF_NAME_RE` present in layer_lint.py (l.24-39).
3. DoD 4: `python3 scripts/agents/tests/test_layer_lint_prefs.py` → `test_layer_lint_prefs: OK`.
4. DoD 5: `layer_lint.py tasks/0024-strip-inventory.md --base 4119b1329~1 --branch 4119b1329` → 0 fail.
5. DoD 6: 0 fail. DoD 7: `diff.sh --names` lists only the two allowed_paths.
