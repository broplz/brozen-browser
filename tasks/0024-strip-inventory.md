---
id: 0024
title: Strip inventory report — every ADR-0003 "[не нашёл подтверждения]" answered from the source
epic: e1-strip
prefix: e1
kind: docs
role: developer
size: S
status: approved
base: feat/layer
branch: task/0024-strip-inventory
depends_on: []
build: none
tests: []
needs_approval: false
allow_zen_patch: false
zen_tag:
allowed_paths:
  - docs/reports/strip-inventory.md
spec: docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md#решение-3--проверка
returns: 1
sessions: 0
reviewed_sha: 8dd8a8d958044603b94957bb68cb07bc7b4a755c
qa_sha: 8dd8a8d958044603b94957bb68cb07bc7b4a755c
blocked_reason:
---
## Goal
ADR-0003 Решение 3 step 0: before any strip work, read the Zen/Firefox sources and answer every claim the ADR
tags **[не нашёл подтверждения]**, so that 0025–0028 can be specified with real pref names, files and
mechanisms (L2 / L3 / patch). Read-only: no build, no code change. The result is one report,
`docs/reports/strip-inventory.md`.

## Definition of Done
1. `docs/reports/strip-inventory.md` exists and has one section per question Q1–Q9 below, each with:
   **Answer** (one or two sentences), **Evidence** (`file:line` or the exact command and its trimmed output),
   **Consequence** (the ADR-0003 level L2 / L3 / L4 and the files a later task will touch).
2. Every pref name the report proposes for 0025/0026 is quoted with the `file:line` where it is defined
   (Zen `prefs/**/*.yaml` or `engine/browser/app/profile/firefox.js` / `engine/modules/libpref/init/StaticPrefList.yaml`).
   A name with no definition found is listed under "Not found" and is not proposed.
3. The report ends with a table "ADR-0003 claim → confirmed | refuted | still open", one row per
   `[не нашёл подтверждения]` in the ADR (lines 26, 27, 28, 70, 82, 94, 110 of the ADR at this commit),
   plus a section "Proposed task changes" for 0025–0028 (allowed_paths, level, needs_approval).
4. `scripts/agents/diff.sh tasks/0024-strip-inventory.md --names` lists only `docs/reports/strip-inventory.md`
   and this task file.

## Notes from teamlead
Questions (each one a report section):
- **Q1 Mods** (ADR 2.5, R2): is there a Zen pref that turns Mods off (any `zen.mods.*`)? How does `src/zen/mods/` get
  loaded — a line in `src/zen/common/ZenPreloadedScripts.js`, `src/zen/ZenComponents.manifest`, `src/zen/moz.build`,
  a `.sys.mjs` imported elsewhere? Is there a window instance (`gZenMods…`) that BBStartup could replace? Where is
  the Mods entry in about:preferences (file:line)? Estimate the hook size in lines.
- **Q2 Boosts** (ADR 2.6): the same questions for `src/zen/boosts/`.
- **Q3 Zen Sync** (ADR 2.3, R4): what `src/zen/sync/` does — Sync engines on top of FxA, its own UI, or something
  loaded unconditionally? Does it still run or draw anything when `identity.fxaccounts.enabled=false`?
- **Q4 AI** (ADR 2.2, R3): does any Zen `prefs/**/*.yaml` set `browser.ml.*`, `extensions.ml.*`,
  `browser.tabs.groups.smart.*`, `browser.search.visualSearch.*`? Full list of `browser.ml.*` names defined in
  Firefox 158 (`firefox.js`, `StaticPrefList.yaml`), and which of the 17 names in ADR 2.2 exist / are missing /
  are new. Is there a build flag for ML in `moz.configure` files (`grep -rn "ml" --include=moz.configure` limited)?
- **Q5 Telemetry** (ADR 2.1): which of the ADR 2.1 prefs Zen already sets (file:line, value) and which are only
  Firefox defaults. Same for `datareporting.*`.
- **Q6 EME** (ADR 2.4): which of `media.eme.enabled`, `media.gmp-widevinecdm.enabled`, `media.gmp-widevinecdm.visible`,
  `browser.eme.ui.enabled` are set by Zen prefs or by `--enable-eme` (where in firefox.js, under which `#if`).
- **Q7 Settings pane** (ADR 2.7, R1): how Zen adds its own about:preferences categories — flat files under `src/zen/`
  or `src/browser/components/preferences/`, or `.patch` files on `preferences.xhtml` / `preferences.js`? Name every
  file a BB category "BROzen" would have to hook, its class (2 flat / 3 patch per ADR-0002), and whether an
  `#include`-style one-line hook is possible. Where do Zen's settings strings live (Fluent files)?
- **Q8 Prefs placement** (ADR-0002 Решение 1/2 vs ADR-0003 Решение 1): for every non-`bb.*` pref the ADR wants
  changed, does Zen already define it in `prefs/zen/*.yaml` / `prefs/firefox/` / `prefs/fastfox/` /
  `prefs/privatefox/` (then the ADR-0002 rule is "edit Zen's line") or nowhere in `prefs/` (then it is a
  Firefox default only)? Report counts per group. Context: `scripts/agents/layer_lint.py:127-130` fails any
  non-`bb.*` pref in `prefs/bb/`, so the ADR's `prefs/bb/strip.yaml` with Firefox names cannot pass lint as is.
- **Q9 Build check inputs** (ADR Решение 3 strip-check): in the existing objdir, where `MOZ_TELEMETRY_REPORTING`,
  `MOZ_DATA_REPORTING`, `MOZ_SERVICES_HEALTHREPORT`, `MOZ_CRASHREPORTER` show up (`config.statusd/substs/`,
  `config.status`, `mozinfo.json`) — the exact path strip-check.sh must read; and confirm the generated
  `engine/browser/app/profile/zen.js` / `zen-static-prefs.inc` format strip-check will parse.

Starting commands (from ADR-0003 Решение 3; one command per Bash call, no chaining):
```
grep -rn "browser.ml\|fxaccounts\|telemetry\|datareporting\|eme\|widevine\|mods\|boosts" prefs/zen prefs/firefox prefs/fastfox prefs/privatefox
grep -n "mods\|boosts\|sync" src/zen/common/ZenPreloadedScripts.js src/zen/ZenComponents.manifest src/zen/moz.build
ls src/zen/mods src/zen/boosts src/zen/sync
grep -rn "zen-settings\|category-zen\|preferences.xhtml" src/zen src/browser | head -30
grep -rn "browser.ml" engine/browser/app/profile/firefox.js | head
```
- engine/ only via Grep/grep with a narrow path and head; Read with offset/limit. No build, no `test.sh`.
- Do not invent pref names: a name enters the report only with its `file:line`.
- The report is English. Keep it under ~250 lines; evidence trimmed to the relevant lines.
- Anything outside these questions goes to tasks/backlog.md "Found by agents" (one line), not into the report.

## Handoff
Session 1 ran out of turns; report written but with OPEN items (listed at the end of the report). Status kept in_progress.

## Result
Round 3 (review fixes 1-4): rewrote the report intro; Q2 marker is now "Still open (runtime check, 0027)"; deleted the "Open items" section; Q4 text and table now agree (2 not found, `extensions.ml.enabled` included, `browser.ml.enable` listed as Zen-only); Q8 AI row adds up to 17 (7 Zen + 8 Firefox-only + 2 not found); "Not found" section no longer lists `browser.ml.enable`. Text edits only; no code changed.

Round 2: closed the open items from round 1 (ff.js `#if` conditions, zen.js format, config.statusd, Sync engine registration, `extensions.ml.enabled`); claim table rows 27/82 updated; added "Not found" and "Still open" sections. Verified by grep/read only; no code changed. Open: Boost UI behaviour at `zen.boosts.enabled=false` needs a runtime check (0027); Sync-off behaviour is by reading only.

Round 1 (partial): `docs/reports/strip-inventory.md` covers Q1–Q9 and the claim table; no code changed. Not yet verified: ff.js `#if` conditions (l.240, 2547), zen.js format, Zen Sync engine registration, 4 pref names not found. Verification: grep/read only.

## Review
APPROVE
Round 2 re-review. All four items are fixed:
1. Intro (:3-5) now describes the report plainly. No session or OPEN text is left.
2. The Q2 marker reads "Still open (runtime check, 0027)". The "Open items" section is gone, and "Still open" (:138-139) matches Q2 and claim 70.
3. Q4 consequence (:61-63) proposes 13 ff.js names + `extensions.ml.enabled` (all.js:1784) + `browser.ml.enable` (Zen). That is 15, plus 2 not found = 17, which agrees with the Q4 table.
4. The Q8 AI row adds up to 17 once: 6 + 1 Zen, 7 + 1 Firefox-only, 2 not found. The "Not found" section states that Zen defines `browser.ml.enable` and lists it only as a clarification.

Checklist:
- Spec: Q1–Q9 each have Answer, Evidence and Consequence. The claim table has 7 rows (ADR lines 26, 27, 28, 70, 82, 94, 110), plus "Proposed task changes", and the "Not found" list matches DoD 2.
- Telemetry count: ADR line 64 lists 13 items, Zen sets 11 and 2 are not set, so the count is consistent.
- Scope: `diff.sh --names` lists only the report (DoD 4).
- Layer: docs only, and layer_lint reports 0 fail.
- Correctness and verification: ## Result round 3 matches the diff.
- Hygiene: English, no TODOs, no secrets.

---
REQUEST_CHANGES
Spot-checked evidence matches the source: ZenPreloadedScripts.js:21/32, the line numbers in ai.yaml, boosts.yaml, mods.yaml, media.yaml and privacy.yaml, ff.js:240/242/2481/2547-2548/3082, and the ADR claim lines 26/27/28/70/82/94/110. Scope is OK (the diff touches only the report), and layer_lint is clean. The report contradicts itself in four places. 0025–0028 get specified from this report, so these must be fixed:
1. docs/reports/strip-inventory.md:3-4: the intro still says "Session 1 ran out of turns … items marked **OPEN** need a follow-up read". This is out of date after round 2. Rewrite it as a plain description of the report.
2. docs/reports/strip-inventory.md:29: the inline "**OPEN:**" marker in Q2 is left over. Write it as "Still open (runtime check, 0027)" so it matches the "Still open" section. At :134-135, the "Open items for a follow-up read" section is now only a log of what session 2 resolved, which is dead text. Delete it (that history belongs in the task file's ## Result).
3. docs/reports/strip-inventory.md:61-62: "the four 'not found' names" is wrong. After `extensions.ml.enabled` was found, the Q4 table lists three. "0025 should use the 13 existing names + `browser.ml.enable`" leaves out `extensions.ml.enabled` (all.js:1784), which the Q4 table itself lists as existing. Fix both to agree with the table.
4. docs/reports/strip-inventory.md:101: the Q8 AI row counts `browser.ml.enable` twice: once in "Zen-only = 7" and again in "3 not found", because Q4 puts it in the not-found row. The row also drops `extensions.ml.enabled`. Make the 17 add up once, e.g. Zen 6 + Zen-only `browser.ml.enable` 1 | Firefox-only 7 (ff.js) + 1 (all.js:1784) | not found 2 (`hideFromLabs`, `hideLabsShortcuts`). Then make the Q4 table and the "Not found" section (:138) match: either keep "Firefox-side `browser.ml.enable`" listed and say clearly that Zen defines it, or drop it there.

## QA
PASS
1. Lint: `test.sh lint` OK (0 problems); layer_lint 0 fail, 0 warn. Build none (skipped); log logs/test-lint-20261030-235007.log.
2. DoD 1: Q1–Q9 each have Answer / Evidence / Consequence in the report.
3. DoD 2: spot-checked ZenPreloadedScripts.js:21, ai.yaml:18, firefox.js:2481 — all match. Unlocated names are under "Not found" and not proposed.
4. DoD 3: claim table has 7 rows (ADR lines 26, 27, 28, 70, 82, 94, 110) and a "Proposed task changes" section for 0025–0028.
5. DoD 4: `diff.sh --names` lists only docs/reports/strip-inventory.md (the task file is edited at the QA step); working tree clean.

For the human: none.
