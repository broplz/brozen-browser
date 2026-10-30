---
name: project-task-shapes
description: Log of planned task shapes (size, files, build) and their outcome — first try / returned / split — to calibrate future planning
metadata:
  type: project
---

Planned 2026-10-28 on feat/layer (record outcomes when tasks finish):
- 0001 layer.yaml + README (docs, S, 2 files, build none)
- 0002 scripts/bb/lib.sh + bash-3.2 test script (script, S, build none). The code was approved on the
  first try (review APPROVE). QA returned it for pipeline reasons, not code: the reviewer committed
  .claude/agent-memory files onto the task branch, which broke DoD 6 (diff-only), and the sandbox
  denied `bash -n` and `/bin/bash test` for all roles. Escalated 2026-10-28. The owner fixed both the
  same day (f43e42814: the commands are allowed, DoD scope goes through diff.sh). Re-spec'd to ready with
  returns 0 and no code change.
- 0003 src/bb skeleton, 6 new files, build none
- 0013 five Zen hook lines + layer.yaml, build ui, needs_approval

Outcomes: 0013 done after 1 return (the reviewer caught that my note asked for an XML comment marker in a
preprocessed .inc.xhtml; use `# ` preprocessor comments there). ui build was enough for new DIRS.

Planned 2026-10-29 on feat/layer:
- 0004 configs/bb mozconfig fragments + common hook, S, 4 files, build full, developer-hard
- 0005 scripts/bb/patches.sh + fixture test (BB_ENGINE_DIR/BB_SRC_DIR overrides), M, build none
- 0006 learning patch on browser.js via patches.sh export, S, build ui x2, needs_approval
  (engine reset leg is [human]; engine/browser.js is in allowed_paths as scratch, watch whether hooks allow it)

Planned 2026-10-29 (2nd run) on feat/layer:
- 0007 rebase.sh steps 1-4 + --continue, M, git fixture (bare upstream + clone), build none
- 0014 rebase.sh steps 5-9 (post_rebase), M, PATH stubs for npm/caffeinate, may edit 0007's test to add stubs
- 0008 smoke.sh + smoke.d/e0.txt, S; 0009 report.sh + docs/rebase/README.md, S
- Backlog 0007 (L, steps 1-9) pre-split: L script with git-fixture test judged > one session.
- Log-line contract (recon:/conflict:/FAIL/smoke:) is written into 0007/0008/0009/0014 notes; keep it identical
  in 0011/0012. Watch whether 0009 parses it first try.

Pre-split rule applied: backlog 0003 touched 12 files, over the M cap of 10. It was split into BB-owned
files (no build) and Zen hook edits (build ui). The backlog line was annotated and 0006's dependency moved to 0013.

Lessons:
- A DoD item of the form "git diff --name-only lists only X" fails when any agent's memory lands on the task branch.
  Fixed: always use `scripts/agents/diff.sh <task> --names`, which ignores agent memory.
- Before writing a DoD command, check that it is allowed in dontAsk mode. `bash -n` and `/bin/bash <script>`
  are allowed since f43e42814.
- In an unblock run, check `git log` for owner commits after the escalation. The blocker may already be
  fixed, and then a re-spec is the right call.
- An unblock run may start on feat/layer, not on the task branch. Compare with `git diff feat/layer...task/<id>`.

- 0006 blocked first session: role developer could not edit engine/ scratch (guard_paths.py: only
  developer-hard/rebaser). Re-spec'd to developer-hard. Rule: any task whose authoring flow touches engine/
  (BB patch on a Firefox file) is developer-hard, even if the content is a comment.
- New scripts may land without the exec bit; write DoDs as `bash scripts/...` unless mode is verified.

Outcome: 0014 done after 1 return (nvm outside step → no footer; rm -rf unchecked). 0007/0008/0009 done.

Planned 2026-10-29 (3rd run) on feat/layer:
- 0010 l10n.sh + fixture test (local "upstream" with allowAnySHA1InWant), S, build none
- 0011 rebase.sh steps 10-11 (smoke/package/install/finalize/publish + failure report), M, 5 files, needs_approval
  (moves+pushes main). Narrowed ADR `--tags` to the two refs. Watch: M with 5 steps + 6 test cases may return.
- 0012 dry-run NOT planned: escalated (main' location, bb/base tag collision, /Applications, who does git work).
- Hook: commands naming scripts/bb/rebase.sh run only for role rebaser; smoke.sh only rebaser/qa (teamlead too
  can't grep them — use Read). So no `bash -n rebase.sh` in a developer DoD; tests that source it are fine.

Planning run 2026-10-29 (4th): nothing to plan. Every ## Next item has a task file except 0012, still
escalated (decisions-needed line unanswered). Found-by-agents items (.gitignore negation, patches.sh exec
bit) were not promoted: they are not on ## Next and are left for the owner to order.
Outcome: 0010 done.

Planning run 2026-10-30: nothing to plan again; 0012 is still escalated and unanswered. Outcomes: 0011 (M, 5 steps)
and 0006 (developer-hard re-spec) both merged after owner approval.

Planning run 2026-10-30 (2nd) after owner answered 0012:
- 0012 dry-run, L, rebaser, status draft (owner: approve task file before run), worktree + temp refs dryrun/main,
  rebase/1.23.4b, bb/base/1.23.3b deleted at end; smoke excluded (no tty) → [human]. Watch: hooks on ../ worktree.
- 0015 .gitignore negation + exec bit on 5 entry scripts, S, role rebaser only because of the rebase.sh/smoke.sh name hook.
- 0016 build.sh preflight (node major vs .nvmrc, gtar) + en-US-packs step after import, S, build ui, stub-PATH test.
  Watch: whether developer may edit scripts/agents/build.sh; teamlead cannot even grep it (hook: "building").

**Why:** calibrate S/M/L estimates and DoD style against real returns.
**How to apply:** after each run, record per id: done first try / returned (why) / split.
Watch 0013: `build.sh ui` may not regenerate the backend for new DIRS/jar.mn, so it may need a re-spec to full.
