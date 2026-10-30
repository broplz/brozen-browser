---
id: 0023
title: build.sh selects the surfer brand from BB_BRAND (default bb) before import
epic: layer
prefix: layer
kind: script
role: developer
size: S
status: done
base: feat/layer
branch: task/0023-agents-build-brand
depends_on: []
build: none
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - scripts/agents/build.sh
  - scripts/agents/tests/build_brand_test.sh
  - docs/notes/README.md
  - tasks/backlog.md
spec: docs/reports/decisions-needed.md
returns: 0
sessions: 0
reviewed_sha: eed0c22d9da8b9f214ed770c74aae059ccc1eda5
qa_sha: eed0c22d9da8b9f214ed770c74aae059ccc1eda5
blocked_reason: 
---
## Goal
Owner answer to 0021, round 2 (docs/reports/decisions-needed.md, "0021 — owner answers, round 2", item 1): `scripts/agents/build.sh`
reads `BB_BRAND` (default `bb`) and selects that surfer brand before every import, so agent builds and qa runs build the BB brand
(ADR-0002 §Границы: brand `bb` in surfer.json, assets in `configs/branding/bb/`). Agents may not run surfer's brand command
themselves; build.sh is the only place that does it. Task 0021 (the brand itself) depends on this.

## Definition of Done
1. `bash -n scripts/agents/build.sh` → no output.
2. `bash scripts/agents/tests/build_brand_test.sh` → last line `PASS`, exit 0. The test uses `T=$(mktemp -d)` (trap removes it),
   a stub dir first in `PATH`, `BB_LOG_DIR=$T/logs`, `BB_GTAR` pointing to a stub, stub `node` printing `v<.nvmrc>.11.0`,
   stub `python3` and `caffeinate` (caffeinate drops its flag and execs the rest), stub `npm` appending its argv to `$T/calls`.
   It runs `build.sh ui` and asserts with a message on failure:
   a. `BB_BRAND` unset → line 1 of `$T/calls` is `run surfer -- set brand bb`, line 2 is `run import`; exit 0;
   b. `BB_BRAND=release` → line 1 is `run surfer -- set brand release`;
   c. stub npm exits 1 when its 2nd argument is `surfer` → build.sh exits non-zero, `$T/calls` has no `run import` line,
      output contains `BUILD RESULT: FAIL`;
   d. `build.sh ui --no-import` → `$T/calls` has no `set brand` line.
3. `bash scripts/agents/tests/build_preflight_test.sh` → `PASS` (unchanged test still passes).
4. `scripts/agents/build.sh` header comment documents `BB_BRAND` (default `bb`).
5. `docs/notes/README.md` `## Build environment` has one line: build.sh selects the brand `${BB_BRAND:-bb}` (step `brand`) before import.
6. `scripts/agents/diff.sh tasks/0023-agents-build-brand.md --names` lists only allowed_paths.

## Notes from teamlead
- Exactly: `BRAND="${BB_BRAND:-bb}"` next to `JOBS=…`; inside the existing `IMPORT=1` branch, first
  `step "brand" npm run surfer -- set brand "$BRAND" || RC=$?`, then `import` only if `RC=0` (same guard style as the
  `en-US-packs` line). Order: brand → import → en-US-packs → build.
- Brand is set only with import: surfer copies `configs/branding/<brand>/` at import and writes `brandingDir` into the mozconfig
  at build; a brand switch without import would build a half-switched tree. `--no-import` leaves the brand as it is.
- Do not add a check that the brand exists in surfer.json: `set brand` fails on its own and the step reports it.
- Known window: brand `bb` is added to surfer.json by 0021. Until 0021 merges, a default `build.sh` fails at the `brand` step.
  That is why build is `none` here (no real build in DoD) and 0021 is queued right after. Say so in ## Result.
- The Bash hook blocks any command containing the word `surfer`; the word may appear inside the test file and build.sh, but never
  type it in a Bash command (use Read on `$T/calls` output via the test's own assertions).
- Stubs: PATH order matters: `caffeinate` is in /usr/bin and must be stubbed, or it runs the real npm via its own PATH lookup.
- macOS bash 3.2: no arrays. Reuse the stub style of `scripts/agents/tests/build_preflight_test.sh`; do not edit that file.
- Out of scope, one line under "Found by agents" in tasks/backlog.md: `scripts/bb/rebase.sh` `package`/`import` steps should
  select the same brand. Do not edit rebase.sh.
- needs_approval: pipeline change the owner asked to approve (decisions-needed, 0021 round 2).

## Handoff

## Result
Round 1:
- build.sh: `BRAND="${BB_BRAND:-bb}"`; in the import branch, step `brand` (`npm run surfer -- set brand "$BRAND"`) runs first, import only if RC=0, then en-US-packs, build. `--no-import` leaves the brand untouched. Header comment documents `BB_BRAND`.
- New `scripts/agents/tests/build_brand_test.sh` (cases a–d); docs/notes/README.md line added; rebase.sh follow-up in backlog "Found by agents".
- Verified: `bash -n build.sh` clean; build_brand_test.sh PASS; build_preflight_test.sh PASS. No real build (build: none). diff.sh --names not run separately; only allowed paths were edited.
- Known window: brand `bb` is added to surfer.json by 0021; until it merges, a default build.sh fails at the `brand` step.

## Review
APPROVE
1. Spec: build.sh:20 `BRAND="${BB_BRAND:-bb}"` next to JOBS; build.sh:106-108 order brand → import (RC-guarded) → en-US-packs → build, exactly as the Notes ask. No surfer.json check was added, which is correct. The header comment (build.sh:13) and the docs/notes line (DoD 4, 5) are present.
2. Scope: the diff covers build.sh, the new test, docs/notes/README.md, tasks/backlog.md:43 (the rebase.sh follow-up) and the task file. All are in allowed_paths. build_preflight_test.sh is untouched.
3. Layer: no Zen/Firefox files and no prefs are touched. layer_lint: 0 fail, 0 warn.
4. Correctness: `--no-import` skips the whole IMPORT branch, brand included. A failed brand step sets RC, which blocks import and the build. The test is bash-3.2 safe (no arrays), uses mktemp plus trap cleanup, and stubs caffeinate. `VAR=x run_build` exports to the function under bash, which is fine.
5. Verification: I re-ran `bash scripts/agents/tests/build_brand_test.sh` → PASS and `build_preflight_test.sh` → PASS. `git diff --stat` shows only allowed paths. ## Result names the known window (bb brand is missing until 0021 lands).
6. Hygiene: nothing blocking. Nit only: build_brand_test.sh is committed as 100644, so it runs only via `bash …`, which matches the DoD.

## QA
PASS
1. `bash -n scripts/agents/build.sh` → no output.
2. `bash scripts/agents/tests/build_brand_test.sh` → `PASS`.
3. `bash scripts/agents/tests/build_preflight_test.sh` → `PASS`.
4. build.sh:13 header documents `BB_BRAND` (default bb); build.sh:20 `BRAND="${BB_BRAND:-bb}"`.
5. docs/notes/README.md:12 has the brand line.
6. `diff.sh --names` lists build.sh, the new test, docs/notes/README.md (all allowed); backlog line 43 holds the rebase.sh follow-up.
7. `test.sh lint` → OK, 0 problems; layer_lint 0 fail, 0 warn (log: logs/test-lint-20261030-180838.log). Build type none, so no build was run.

For the human: the default build.sh fails at the `brand` step until 0021 adds brand `bb` to surfer.json.
