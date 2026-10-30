---
id: 0021
title: surfer brand `bb` ("BROzen BROwser", short "BB", vendor broplz) on Zen's placeholder assets
epic: e0
prefix: e0
kind: feature
role: developer-hard
size: S
status: ready
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
reviewed_sha:
qa_sha:
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

## Review

## QA
