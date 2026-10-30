---
id: 0018
title: merge gate accepts a verdict whose code diff equals the head's diff by `git patch-id` (survives a clean rebase)
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: ready
base: feat/layer
branch: task/0018-agents-merge-gate-patch-id
depends_on: []
build: none
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - scripts/agents/pipeline_lib.py
  - scripts/agents/merge_task.py
  - scripts/agents/run_task.py
  - scripts/agents/tests/test_same_code.py
spec: tasks/backlog.md
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
After the owner rebases a task branch by hand (merge_conflict), `reviewed_sha`/`qa_sha` point at
pre-rebase commits and merge_task.py's gate (`merge_task.py:32-38`, sha prefix compare against
`pl.code_head(branch)`) blocks a task whose code did not change. After this task the gate passes when
the verdict sha is the code head (as now) OR the code diff of the verdict sha against its base
has the same `git patch-id --stable` as the code diff of the branch head against its base. Any real
code change after the verdict still fails the gate. Backlog 0018.

## Definition of Done
1. `scripts/agents/pipeline_lib.py` has one new function `same_code(base, sha, branch) -> bool`
   (name exact); merge_task.py's sha loop calls it instead of the inline prefix compare; the error
   text for a mismatch stays `<key> <sha10> != code head <head10> (code changed after the verdict)`.
2. `python3 scripts/agents/tests/test_same_code.py` → exit 0, prints `test_same_code: OK`. It builds a
   temp git repo (tempfile, sets `config.ROOT` to it before calling pl) and asserts:
   a. sha == code head → True
   b. a task branch with one code commit + one `tasks/` commit after it, verdict = the code commit → True
   c. same branch rebased (`git rebase`) onto a base that gained an unrelated commit; verdict = the
      old pre-rebase sha → True
   d. a code commit added after the verdict → False
   e. rebase that resolves a conflict differently (diff content differs) → False
   f. verdict sha that does not exist in the repo → False (no exception)
3. The test also does `import merge_task` (sys.path → scripts/agents) and asserts
   `merge_task.gates` exists, so a syntax error in merge_task.py fails DoD 2.
4. `scripts/agents/diff.sh 0018 --names` lists only files from allowed_paths plus the task file.
5. merge_task.py module docstring line about the gate mentions the patch-id fallback.

## Notes from teamlead
- Diff for patch-id: `git diff <merge-base(base, X)> <X> -- . ':(exclude)tasks' ':(exclude)logs'
  ':(exclude).claude/agent-memory'` — the same three excludes `code_head` uses (pipeline_lib.py:93);
  reuse one shared tuple, do not copy the list. X = the verdict sha, resp. `code_head(branch)`.
  Pipe each diff into `git patch-id --stable` via `pl.run(..., input)` or subprocess with the same cwd
  (`config.ROOT`); compare the first field. Empty diff on both sides → not a match (return False).
- Fast path first: the existing prefix compare (`code.startswith(sha) or sha.startswith(code[:7])`).
- Missing object (`git cat-file -e <sha>^{commit}` fails) → False, never raise.
- run_task.py is in allowed_paths only in case it compares `reviewed_sha`/`qa_sha` to the head itself
  (e.g. deciding whether qa must re-run); if it does, switch it to `same_code` too; if not, leave it
  untouched. Do not change who sets these fields.
- Agents may not run commands naming run_task/run_queue/run_agent/merge_task (hook). Test through
  `pipeline_lib` and an in-test `import merge_task`; never put `merge_task`/`run_task` in a Bash
  command line (even py_compile or grep on the path is denied). Read/Edit tools work on them.
- `test_*.py` under scripts/agents/tests is a new file — allowed for this kind.
