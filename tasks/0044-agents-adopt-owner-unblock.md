---
id: 0044
title: The driver adopts the owner's unblock from the base copy only when the base copy changed after the block
epic: layer
prefix: layer
kind: bug
role: developer
size: S
status: ready
base: feat/layer
branch: task/0044-agents-adopt-owner-unblock
depends_on: []
build: none
tests: []
needs_approval: true
allow_zen_patch: false
zen_tag:
allowed_paths:
  - scripts/agents/pipeline_lib.py
  - scripts/agents/run_task.py
  - scripts/agents/tests/check_run_task.py
spec: tasks/backlog.md
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Supersedes 0037 (rejected 2026-11-13, see tasks/0037 `## Outcome`). While a task is in flight, `pl.live_task()`
(pipeline_lib.py:201) reads the task branch's copy. The owner answers an escalation by editing the copy on the base
branch, so the driver never sees it. 0037 adopted any runnable base status, but the untouched base copy always says
`ready`, so every block was lifted. After this task the driver adopts the base copy's `status` and
`blocked_reason` only when the base copy was committed **after** the branch copy's last commit, i.e. the owner
changed it after the block. Sections and counters on the branch stay as they are.

## Definition of Done
1. `python3 -m py_compile scripts/agents/pipeline_lib.py scripts/agents/tests/check_run_task.py` → exit 0, no output.
2. `python3 scripts/agents/tests/check_run_task.py` → last line `all OK`, exit 0. Existing cases pass unedited. New
   section `# --- owner unblock on base`, against a throwaway git repo (`git init` in `TMP`; `config.ROOT`,
   `config.TASK_DIR`, `config.BACKLOG` pointed at it for this section only, restored after). Base `feat/x`, task branch
   `task/0999-probe`; commit times fixed with `GIT_COMMITTER_DATE` so "after" is deterministic.
   Function level, `pl.adopt_owner_unblock(path)`:
   a. branch `blocked` (committed at T2), base edited to `ready` at T3 > T2 → True; branch copy now has
      `status: ready`, the base's `blocked_reason`, and the branch's `## Handoff`, `returns`, `sessions`,
      `reviewed_sha`, `qa_sha` unchanged; last commit message `tasks: 0999 owner unblock adopted (driver)`;
   b. branch `blocked` at T2, base `ready` last committed at T1 < T2 (untouched planning copy) → False, no commit;
   c. base edited at T3 but still `blocked` → False;
   d. branch `in_progress`, base edited to `ready` at T3 → False (only a blocked branch copy is overridden);
   e. base edited to `done`/`split`/`draft` at T3 → False (finals stay with `live_task`'s base rule);
   f. no task branch → False.
   Loop level, `run_task.run_task(path, once=True)` with `run_agent` stubbed to record the roles it is called with:
   g. for each `blocked_reason` in `too_big`, `returns`, `merge_gate`: branch `blocked` at T2, base untouched `ready`
      at T1 → after the call the branch copy still says `blocked` with the same reason, `returns`/`sessions` and
      `## Handoff` unchanged, and no developer session was started;
   h. branch `blocked` at T2, base `ready` at T3 → a developer session is started (stub called with the developer
      role), `returns`/`sessions` on the branch are the pre-block values (not the base's).
3. `python3 scripts/agents/tests/test_same_code.py` → exit 0.
4. Read `scripts/agents/run_task.py`: the loop calls `pl.adopt_owner_unblock(path)` once per iteration, before
   `pl.live_task(path)`. No other change in run_task.py.
5. `scripts/agents/diff.sh tasks/0044-agents-adopt-owner-unblock.md --names` lists only allowed_paths and the task file.

## Notes from teamlead
- One function `adopt_owner_unblock(path) -> bool` right after `live_task`, plus one helper `ref_copy(path, ref)`
  (working-tree copy when `current_branch() == ref`, else `git show ref:rel(path)` + `TaskFile.from_text`, None when
  absent) that `live_task` also uses. No duplicated show/parse code.
- "After the block" = `git log -1 --format=%ct <base> -- <rel>` > `git log -1 --format=%ct <branch> -- <rel>`. Equal
  times do not count. The blocking write (`set_blocked`, merge gate) commits the branch copy, so its last commit is at
  or after the block. Compare commit times, never statuses alone.
- Adopt only when the branch says `blocked` and the base status is in module-level
  `ADOPTABLE = ("ready", "in_progress", "returned", "review", "qa", "approved")`.
- Adoption copies only `status` and `blocked_reason` from the base copy into the branch copy with `TaskFile.set`
  (switch to the branch first if needed), then `git add` + commit with the message above, then `log(...)`. Do not use
  `sync_task_file`: it overwrites the whole file (0037's bug). Other owner edits on the base (e.g. Notes) are not
  carried; the owner re-runs the teamlead for those. Say so in the docstring.
- A teamlead re-spec in `run_unblock` lands on the base after the block too; adopting it is harmless because
  `run_unblock` syncs it anyway. Do not touch `run_unblock`, `set_blocked` or `merge_task.py`.
- Guard clauses / early returns, no negated compound conditions (owner's rule).
- Hook: any Bash command naming `run_task`, `run_queue`, `run_agent` or `merge_task` is denied for every role, even
  `py_compile`/`grep`. Check run_task.py through `check_run_task.py` (it imports it) and the Read tool.
- The git fixture: `subprocess.run(["git", "-C", repo, …])` with `-c user.name=t -c user.email=t@t` and
  `env={**os.environ, "GIT_COMMITTER_DATE": "<epoch> +0000"}`. The earlier sections stub `pl.live_task`,
  `run_task.ensure_branch`, `pl.autocommit`; restore the real ones for this section and re-stub nothing else than
  `run_agent`. If the loop reaches `run_unblock` in case g, stub the teamlead call through `run_agent` too and
  assert it was the only role called.
- needs_approval: this changes the driver that runs every task.

## Handoff

## Result

## Review

## QA
