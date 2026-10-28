# Backlog

Active feature branch: feat/layer
(The pipeline merges tasks into this branch; `main` changes only by the owner's hand —
scripts/agents/finish_feature.sh. Order under `## Next` is the owner's priority; the teamlead
writes task files for the first items that have none: `scripts/agents/run_queue.py --plan`.)

## Next
- 0001 layer: `src/bb/layer.yaml` registry (base, hooks, edits, zen_patches) + `src/bb/README.md` describing the layout — ADR-0002 §Решение 1, 2 · S · build none
- 0002 layer: `scripts/bb/lib.sh` — `step` wrapper (header, tee into $BB_LOG_DIR, duration, exit code), log dir default `../logs/` — ADR-0002 §Решение 4 "Логирование" · S · build none
- 0003 layer: `src/bb/` skeleton + the five hook lines (moz.build, jar.inc.mn, bb-assets.inc.xhtml, BBStartup.mjs via ZenPreloadedScripts.js, BBComponents.manifest) + `prefs/bb/bb.yaml` with `bb.layer.version` — ADR-0002 план проверки п.1 · M · build ui · DoD: about:config shows bb.* `[human]`, Browser Console shows the BBStartup line `[human]`, headless: `grep bb.layer.version engine/browser/app/profile/zen.js`
- 0004 layer: `configs/bb/mozconfig` + `mozconfig.macos` (empty fragments with comments) + the hook line in `configs/common/mozconfig` — ADR-0002 §Границы · S · build full (qa) · role developer
- 0005 layer: `scripts/bb/patches.sh` check|export|status (temporary index, Zen-patch overlap check, same flags as surfer export) — ADR-0002 §Решение 2 последний абзац · M · build none · depends 0002
- 0006 layer: learning BB patch on `browser/base/content/browser.js` far from Zen's hunks, in `src/bb/patches/layer/learning-browser-js/` with README; check → export → import → status, import twice, surfer reset → import — ADR-0002 план проверки п.2 (R2, R3) · S · build ui · depends 0003, 0005
- 0007 layer: `scripts/bb/rebase.sh <tag>` steps 1-9 (preflight, fetch upstream, recon, rebase/<tag>, deps, engine reset or re-download, patches check, import, build) + `--continue` — ADR-0002 §Решение 4 · L · build none · depends 0002, 0005 · role developer
- 0008 layer: `scripts/bb/smoke.sh` + `scripts/bb/smoke.d/e0.txt`… (checklist v1, y/n prompts, answers into the report) — ADR-0002 §Решение 4 "Smoke-чеклист v1" · S · build none · depends 0002
- 0009 layer: `scripts/bb/report.sh` + `docs/rebase/README.md` (summary table) — ADR-0002 §Решение 4 "Метрика" · S · build none · depends 0002
- 0010 layer: `scripts/bb/l10n.sh` (bare mirror cache + sparse checkout en-US, ru) — ADR-0002 §Решение 4 "Кэш" · S · build none · depends 0002
- 0011 layer: rebase.sh steps 10-11 (smoke hand-off, package, main := rebase/<tag>, tag bb/base/<tag>, force-with-lease push, report) — ADR-0002 §Решение 4 · M · build none · depends 0007, 0008, 0009 · needs_approval
- 0012 layer: dry-run `rebase.sh 1.23.4b` from a `main'` built on 1.23.3b with the same layer; timings into docs/rebase/1.23.4b.md — ADR-0002 план проверки п.4 (R5, R6, R8) · L · role rebaser · needs_approval · depends 0006, 0011

## Found by agents
(one line each: what, where, why it matters — the teamlead promotes these into tasks)

## For the owner
- commit ADR-0001 to docs/adr/0001-little-bb-floating-window.md (status Proposed → Accepted?)
- Apple Developer account status (E0 signing; approval can take up to two weeks)
