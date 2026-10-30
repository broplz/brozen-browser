# Backlog

Active feature branch: feat/layer
(The pipeline merges tasks into this branch; `main` changes only by the owner's hand —
scripts/agents/finish_feature.sh. Order under `## Next` is the owner's priority; the teamlead
writes task files for the first items that have none: `scripts/agents/run_queue.py --plan`.)

## Next
- 0001 layer: `src/bb/layer.yaml` registry (base, hooks, edits, zen_patches) + `src/bb/README.md` describing the layout — ADR-0002 §Решение 1, 2 · S · build none
- 0002 layer: `scripts/bb/lib.sh` — `step` wrapper (header, tee into $BB_LOG_DIR, duration, exit code), log dir default `../logs/` — ADR-0002 §Решение 4 "Логирование" · S · build none
- 0003 layer: `src/bb/` skeleton + the five hook lines (moz.build, jar.inc.mn, bb-assets.inc.xhtml, BBStartup.mjs via ZenPreloadedScripts.js, BBComponents.manifest) + `prefs/bb/bb.yaml` with `bb.layer.version` — ADR-0002 план проверки п.1 · M · build ui · DoD: about:config shows bb.* `[human]`, Browser Console shows the BBStartup line `[human]`, headless: `grep bb.layer.version engine/browser/app/profile/zen.js`
  - split by teamlead (12 files > M cap): 0003 = src/bb skeleton + prefs/bb/bb.yaml (build none), 0013 = the five hook lines + layer.yaml hooks (build ui, needs_approval, depends 0001, 0003)
- 0004 layer: `configs/bb/mozconfig` + `mozconfig.macos` (empty fragments with comments) + the hook line in `configs/common/mozconfig` — ADR-0002 §Границы · S · build full (qa) · role developer
- 0005 layer: `scripts/bb/patches.sh` check|export|status (temporary index, Zen-patch overlap check, same flags as surfer export) — ADR-0002 §Решение 2 последний абзац · M · build none · depends 0002
- 0006 layer: learning BB patch on `browser/base/content/browser.js` far from Zen's hunks, in `src/bb/patches/layer/learning-browser-js/` with README; check → export → import → status, import twice, surfer reset → import — ADR-0002 план проверки п.2 (R2, R3) · S · build ui · depends 0013, 0005
- 0007 layer: `scripts/bb/rebase.sh <tag>` steps 1-9 (preflight, fetch upstream, recon, rebase/<tag>, deps, engine reset or re-download, patches check, import, build) + `--continue` — ADR-0002 §Решение 4 · L · build none · depends 0002, 0005 · role developer
  - split by teamlead (steps 1-9 + git fixture test > one session): 0007 = steps 1-4 + --continue (M), 0014 = steps 5-9 in post_rebase (M, depends 0007)
- 0008 layer: `scripts/bb/smoke.sh` + `scripts/bb/smoke.d/e0.txt`… (checklist v1, y/n prompts, answers into the report) — ADR-0002 §Решение 4 "Smoke-чеклист v1" · S · build none · depends 0002
- 0009 layer: `scripts/bb/report.sh` + `docs/rebase/README.md` (summary table) — ADR-0002 §Решение 4 "Метрика" · S · build none · depends 0002
- 0010 layer: `scripts/bb/l10n.sh` (bare mirror cache + sparse checkout en-US, ru) — ADR-0002 §Решение 4 "Кэш" · S · build none · depends 0002
- 0011 layer: rebase.sh steps 10-11 (smoke hand-off, package, main := rebase/<tag>, tag bb/base/<tag>, force-with-lease push, report) — ADR-0002 §Решение 4 · M · build none · depends 0014, 0008, 0009 · needs_approval
- 0012 layer: dry-run `rebase.sh 1.23.4b` from a `main'` built on 1.23.3b with the same layer; timings into docs/rebase/1.23.4b.md — ADR-0002 план проверки п.4 (R5, R6, R8) · L · role rebaser · needs_approval · depends 0006, 0011
- 0015 env: `.gitignore` add `!configs/bb/mozconfig` (bare `mozconfig` rule ignores it); `chmod +x scripts/bb/patches.sh` (git mode 100755) — found by agents (0004, 0006) · S · build none
- 0016 env: post-init step `python3 scripts/update_en_US_packs.py` (else empty UI strings, no shortcuts) — add to `scripts/agents/build.sh`/driver init and the runbook; preflight check for Node 22 (`.nvmrc`; Node 25 breaks surfer import via async-icns rmdir) and gnu-tar on macOS — found 2026-10-29 · S · build none
- 0017 agents: `triage_log.py` false error on `Notification center failed: Install terminal-notifier`; `.claude/settings.json` allow `Bash(grep *)` and fix why `Bash(bash -n *)` is still denied (night log 2026-10-29) — · S · build none
- 0018 agents: merge gate — after a manual rebase `reviewed_sha`/`qa_sha` != head is a false positive; compare `git patch-id` of the task diff vs base instead of commit sha (`pipeline_lib.py`, `merge_task.py`) — · M · build none
- 0019 layer: `rebase.sh` — `do_build` reads `BB_JOBS` (hardcoded `--jobs 6`); define `--continue` after a failed `publish` (finalize commit already on rebase/<tag>: no second commit, re-run publish only) — · S · build none · depends 0011
- 0020 layer: Browser Console `Key element … missing "key"/"keycode"` warnings for Zen shortcuts (ShortcutUtils.sys.mjs) — find out whether upstream Zen 1.23.4b has them too (official build) or it is our l10n/init; report only — · S · build none · role developer
- 0021 brand: BB brand instead of `unofficial`/Nightly — surfer brand config under `configs/branding/` modelled on Zen's, placeholder name "BROzen BROwser", logo reuse allowed for now — · M · build full · needs_approval
  - not planned by teamlead (2026-10-29): dry-run mechanics not in the ADR; see docs/reports/decisions-needed.md
  - planned 2026-10-30 (3rd run): 0017 = triage_log.py half only (settings.json half is owner work, decisions-needed), 0018, 0019 (both needs_approval)
  - not planned by teamlead (2026-10-30): brand selection in build.sh, binary asset copy, identity ids — see docs/reports/decisions-needed.md
  - (the "not planned … 2026-10-29" note above refers to 0012) planned 2026-10-30 after owner answers: tasks/0012 is `draft` until the owner sets `ready`; 0015 role rebaser (hook: only rebaser may name rebase.sh/smoke.sh); 0016 scoped to build.sh, rebase.sh/driver en-US step left for "Found by agents"

## Found by agents
(moved to ## Next: 0015)
- 0016: add the en-US packs step (`python3 scripts/update_en_US_packs.py`) after the `import` step in `scripts/bb/rebase.sh` (ADR-0002 step 8)
- 0016: add the en-US packs step after import in the driver's environment init (`scripts/agents/run_task.py` / night.sh)

## For the owner
- commit ADR-0001 to docs/adr/0001-little-bb-floating-window.md (status Proposed → Accepted?)
- Apple Developer account status (E0 signing; approval can take up to two weeks)

