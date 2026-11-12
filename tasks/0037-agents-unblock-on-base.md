---
id: 0037
title: The driver picks up a task the owner unblocked on the base branch while its task branch still says blocked
epic: layer
prefix: layer
kind: bug
role: developer
size: S
status: done
base: feat/layer
branch: task/0037-agents-unblock-on-base
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
Backlog item (0025, 2026-10-31): while a task is in flight, `pl.live_task()` treats the task branch's copy of
`tasks/<file>` as the truth. The driver's own writes already land there: `set_blocked` and `merge_task` write on
the task branch, and `run_unblock` syncs a teamlead re-spec base→branch (run_task.py:144-149). The owner, though,
answers an escalation by editing the file on the base branch (`feat/layer`), e.g. `status: ready` or `status: qa`.
The branch copy still says `blocked`, so the driver never sees the answer. After this task the driver adopts such an
answer: the branch copy is `blocked`, the base copy is a non-blocked runnable status → the base copy is synced onto
the task branch before the loop reads the status.

## Definition of Done
1. `python3 -m py_compile scripts/agents/pipeline_lib.py scripts/agents/tests/check_run_task.py` → no output, exit 0.
2. `python3 scripts/agents/tests/check_run_task.py` → last line `all OK`, exit 0. Every existing case still passes
   unedited. New cases go in a `# --- adopt_base_unblock` section and run against a real throwaway git repo
   (`git init` inside `TMP`, with `config.ROOT`, `config.TASK_DIR` and `config.BACKLOG` pointed at it for that section only).
   The repo has a base branch `feat/x` and a task branch `task/0999-probe`. Cases (status on base / on branch → expected):
   a. `ready` / `blocked` → returns True; the current branch is `task/0999-probe`; its task file says `ready`, and its
      last commit message is `tasks: 0999 unblocked on base (driver)`;
   b. `qa` / `blocked` → True, the branch copy says `qa`;
   c. `blocked` / `blocked` → False, no new commit on either branch;
   d. `ready` / `in_progress` → False (only a blocked branch copy is overridden), no new commit;
   e. `done` / `blocked` → False (final statuses stay with `live_task`'s base rule), no new commit;
   f. `draft` / `blocked` → False;
   g. no task branch → False, no commit.
3. `python3 scripts/agents/tests/test_same_code.py` → exit 0 (pipeline_lib's other checks are not broken).
4. Read `scripts/agents/run_task.py`: `run_task()` calls `pl.adopt_base_unblock(path)` once per loop iteration, before
   `pl.live_task(path)`. No other change in run_task.py.
5. `scripts/agents/diff.sh tasks/0037-agents-unblock-on-base.md --names` lists only allowed_paths (plus this task file).

## Notes from teamlead
- One new function in `pipeline_lib.py`, `adopt_base_unblock(path) -> bool`, placed right after `live_task`. Logic:
  1. `wt = TaskFile(path)`; `base, branch = task_base(wt), task_branch(wt)`. Return False unless
     `branch_exists(branch)` and `branch_exists(base)`.
  2. Read both copies with `git show <ref>:<rel(path)>` + `TaskFile.from_text`, the way `live_task` does. When
     `current_branch() == ref`, use the working-tree copy instead. Factor that read into one small helper
     `ref_copy(path, ref)` and make `live_task` use it too. No duplicated show/parse code.
  3. Adopt only when branch status == `blocked` and the base status is in `ADOPTABLE = ("ready", "in_progress",
     "returned", "review", "qa", "approved")`. That excludes draft, blocked, done and split.
  4. Then `switch(branch)` if not on it, `sync_task_file(path, base, f"tasks: {id} unblocked on base (driver)")`,
     `log(...)`, return True.
- Do not touch `run_unblock`, `set_blocked` or `merge_task.py`. They already write the branch copy.
- Guard clauses / early returns, no negated compound conditions (owner's rule). `ADOPTABLE` is a module-level tuple.
- Counters (`returns`, `sessions`, `blocked_reason`) come over with the base copy as the owner left them. Do not reset
  them here.
- Hook: any Bash command that names `run_task`, `run_queue`, `run_agent` or `merge_task` is denied for every role. That
  includes `python3 -m py_compile scripts/agents/run_task.py` and `grep … run_task.py`. Check run_task.py through
  `check_run_task.py` (it imports it) and the Read tool. The test file's path `tests/check_run_task.py` is allowed.
- The git fixture in the test: plain `subprocess.run(["git", "-C", repo, …])` from Python is fine. The Bash hook does
  not see it. Commit with `-c user.name=t -c user.email=t@t`. `pl.git` runs in `config.ROOT`, so point `config.ROOT`
  at the fixture repo for the section and restore it afterwards. The earlier sections stub `pl.live_task`,
  `run_task.ensure_branch` and `pl.autocommit`. Leave them stubbed, or restore them; the new section only calls
  `pl.adopt_base_unblock` directly.
- needs_approval: this changes the driver that runs every task.

## Outcome
Rejected by owner 2026-11-13, superseded by 0044.

Reason: `adopt_base_unblock` cannot tell the owner's answer from an untouched copy on the base. While a task is in
flight the base copy always says `ready`, so any block on the branch (`too_big`, `returns`, `merge_gate`,
`merge_conflict`) would be lifted on the next iteration, the `sessions`/`returns` counters would be reset, the Handoff
on the branch would be erased, and `run_unblock` would not call the teamlead.
