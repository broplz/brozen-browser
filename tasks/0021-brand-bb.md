---
id: 0021
title: surfer brand `bb` ("BROzen BROwser", short "BB", vendor broplz) on Zen's placeholder assets
epic: e0
prefix: e0
kind: feature
role: developer-hard
size: S
status: done
base: feat/layer
branch: task/0021-brand-bb
depends_on: [0023]
build: full
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - surfer.json
  - src/bb/layer.yaml
  - configs/branding/bb/README.md
spec: docs/adr/0002-bb-layer-and-rebase-runbook.md#границы--где-живут-брендинг-mozconfig-и-вырезание
returns: 0
sessions: 0
reviewed_sha: 03e08636d6274357d4be1ca95eaa851e81dba1db
qa_sha: 03e08636d6274357d4be1ca95eaa851e81dba1db
blocked_reason: 
---
## Goal
ADR-0002 §Границы: branding lives in `configs/branding/bb/` + brand `bb` in `surfer.json` (class 2 plain edit). The owner copied
Zen's release assets to `configs/branding/bb/` and fixed the content (decisions-needed.md, "0021 — owner answers" rounds 1 and 2):
name "BROzen BROwser", short name "BB", vendor "broplz", Zen logos as placeholders with attribution; appId / binaryName /
bundle id / profile dir stay Zen's. After this task a default `scripts/agents/build.sh` (brand `bb`, task 0023) builds an app
that calls itself BROzen BROwser instead of `unofficial`/Nightly.

## Definition of Done
1. `surfer.json` (Read it) has `"vendor": "broplz"` and `brands.bb` = `backgroundColor` `#282A33`, `brandShorterName` `BB`,
   `brandShortName` `BB`, `brandFullName` `BROzen BROwser`, `release.displayVersion` `1.23.4b`, and a key
   `"_bb": "BB(e0): BB brand, ADR-0002 Границы"`. `name`, `appId`, `binaryName`, `updateHostname`, `release`, `twilight` unchanged.
2. surfer.json stays valid JSON: proven by DoD 5 (the `brand` and `import` steps parse it). No Bash command may name the file.
3. `src/bb/layer.yaml` `edits:` has an entry `file: surfer.json`, `epic: e0`, `why:` naming the bb brand and vendor.
4. `configs/branding/bb/README.md` exists: says the assets are copies of Zen's `configs/branding/release/` (MPL-2.0, Zen OSS Team),
   used as placeholders until E0 replaces them; names the brand fields in surfer.json.
5. `scripts/agents/build.sh full` → `BUILD RESULT: OK`; the log has `===== brand` with footer `brand: exit 0`.
6. `grep -rl "BROzen BROwser" engine/browser/branding/bb` → at least one file (the generated brand strings).
7. `python3 scripts/agents/layer_lint.py tasks/0021-brand-bb.md` → 0 fail.
8. `scripts/agents/diff.sh tasks/0021-brand-bb.md --names` lists only allowed_paths.
9. [human] The built app shows "BROzen BROwser" in the menu bar / About dialog; the Dock icon is Zen's logo.
10. [human] The app opens the existing dev profile (profile dir unchanged, tabs/settings still there).

## Notes from teamlead
- surfer.json is a Zen flat file (class 2): plain edit. JSON has no comments, but layer_lint requires a `BB(` marker on an added
  line — hence the `"_bb"` key inside `brands.bb` (surfer reads only the fields it knows). Do not add comments to the JSON.
- Do not touch `appId`, `binaryName`, `name`, `updateHostname` (owner round 2 item 3: ids stay Zen's; separate profile dir is
  deferred to an E0 ADR). Vendor does not enter the macOS profile path, so changing it is in scope (owner round 1).
- No `github`/`archives` under `brands.bb.release`: BB has no update server (updates are disabled by 0022).
- Do not edit `configs/common/mozconfig` (`--with-app-basename=Zen`, `MOZ_APP_BASENAME=Zen` are ids and stay).
- Do not add, copy or edit binary assets in `configs/branding/bb/`; only the README is new.
- Brand selection is build.sh's job (0023, `step "brand"`). The Bash hook blocks any command containing the word `surfer` — never
  type it; read surfer.json with the Read tool. Do not run surfer's brand command yourself.
- full build: the brand changes `brandingDir` in the generated mozconfig. Role developer-hard (full builds).
- texts in `src/bb/branding/` (ADR) are not needed: surfer generates brand.ftl/brand.properties from surfer.json
  (`buildOptions.generateBranding: true`).

## Handoff

## Result
Round 1 (session 1).
- `surfer.json`: `vendor` changed to `broplz`. Added `brands.bb`, which has the `_bb` marker key, `#282A33`, `BB`/`BB`,
  `BROzen BROwser` and `release.displayVersion 1.23.4b`, with no github/archives. `name`, `appId`, `binaryName`,
  `updateHostname`, `release` and `twilight` are unchanged.
- `src/bb/layer.yaml`: `edits:` now has an entry for surfer.json (epic e0).
- `configs/branding/bb/README.md`: new. It covers the placeholder assets copied from Zen's release branding (MPL-2.0,
  Zen OSS Team) and lists the brand fields.

Verified:
- DoD 5: `scripts/agents/build.sh full` gave `BUILD RESULT: OK type=full duration=2243s`. The log is
  logs/build-full-20261030-181423.log, which has `===== brand` and `===== brand: exit 0 after 0s`. surfer.json parsed fine (DoD 2).
- DoD 6: grep matched branding.nsi, README.md, and brand.dtd/.properties/.ftl under `locales/en-US`.
- DoD 7: layer_lint reported 0 fail, 0 warn.
- DoD 8: `--names` listed only the 3 allowed paths.
- DoD 9 and 10 are [human] checks and were not run.

Open points:
- surfer also copies `README.md` into `engine/browser/branding/bb/`. That does no harm, because the brand moz.build lists
  its files explicitly.
- The hook blocks `git add <paths>` because the command names the file, so I staged with `git add -A`.
- No C++ changes: the reviewer only needs to check the JSON and README.

## Review
APPROVE
1. Spec: surfer.json:3 sets vendor `broplz`. surfer.json:49-57 adds `brands.bb` with exactly the DoD 1 fields plus the `_bb` marker,
   and has no github/archives. name/appId/binaryName/updateHostname/release/twilight are untouched. layer.yaml:46-49 has the
   edits entry. The README covers the source of the copied assets, MPL-2.0, Zen OSS Team attribution and the brand fields. Nothing extra.
2. Scope: the diff touches only the 3 allowed_paths. The binary assets were already tracked (owner copy) and are not in this diff.
3. Layer: surfer.json is class 2 with the `BB(e0)` marker and a layer.yaml entry. layer_lint gave 0 fail, 0 warn (15 lines).
   No engine/ edits and no prefs. Pref-off/F2 does not apply to branding.
4. Correctness: no code. A JSON parse failure would have failed the brand step, and the log shows `brand: exit 0`.
5. Verification: logs/build-full-20261030-181423.log has `BUILD RESULT: OK` and `brand: exit 0`.
   `grep -rl "BROzen BROwser" engine/browser/branding/bb` returns the 5 files claimed.
6. Hygiene: no secrets and no TODOs. Text is English, apart from the ADR section title, which is quoted as-is.

## QA
PASS
1. DoD 1: surfer.json read. vendor `broplz`; brands.bb has all required fields and the `_bb` key. name/appId/binaryName/updateHostname/release/twilight unchanged.
2. DoD 2: the brand and import steps parsed the file (build log below).
3. DoD 3: src/bb/layer.yaml:47-49 has the surfer.json entry, epic e0, why names the bb brand and vendor.
4. DoD 4: configs/branding/bb/README.md has the Zen release copy, MPL-2.0, Zen OSS Team, placeholders and brand fields.
5. DoD 5: `scripts/agents/build.sh full` gave `BUILD RESULT: OK type=full duration=1961s`; log logs/build-full-20261030-185250.log has `===== brand: exit 0 after 0s`.
6. DoD 6: grep found 5 files in engine/browser/branding/bb.
7. DoD 7: layer_lint reported 0 fail, 0 warn.
8. DoD 8: diff.sh --names listed only the 3 allowed paths.
9. Lint: `test.sh lint` OK, 0 problems (logs/test-lint-20261030-192535.log).

For the human: DoD 9 (menu bar / About show "BROzen BROwser", Dock icon is Zen's logo) and DoD 10 (existing dev profile still opens).
