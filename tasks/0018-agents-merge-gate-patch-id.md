---
id: 0018
title: merge gate accepts a verdict whose code diff equals the head's diff by `git patch-id` (survives a clean rebase)
epic: layer
prefix: layer
kind: script
role: developer
size: M
status: done
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
reviewed_sha: 03f9dcadf5c04eef99a54cdd15987802b71bc202
qa_sha: 03f9dcadf5c04eef99a54cdd15987802b71bc202
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

## Result
Round 1:
- pipeline_lib.py: shared `CODE_PATHSPEC` (used by `code_head`), `code_patch_id(base, rev)`, `same_code(base, sha, branch)` (missing object → False, prefix fast path, then patch-id compare; empty diff → False).
- merge_task.py: gate loop calls `pl.same_code`; error text unchanged; docstring mentions the patch-id fallback.
- run_task.py: only writes `reviewed_sha`/`qa_sha`, never compares them to the head → left untouched.
- tests/test_same_code.py covers cases a–f and `import merge_task` → `test_same_code: OK` (run).
- Not run: diff.sh --names before commit was empty; re-check after commit is the reviewer's job. No build needed.

## Review
APPROVE

Checklist notes:
1. Spec: DoD 1 holds. `same_code(base, sha, branch)` is at pipeline_lib.py:111. It checks for a missing object first, then the prefix fast path, then compares patch-ids, and an empty diff returns False. merge_task.py:38 calls it, and the error text is unchanged. DoD 5: the docstring at merge_task.py:8-9 mentions the patch-id fallback. The excludes are one shared `CODE_PATHSPEC` tuple (pipeline_lib.py:91), and `code_head` uses it too. The teamlead notes allow subprocess with cwd=config.ROOT for the patch-id pipe.
2. Scope: DoD 4 holds. `diff.sh --names` lists only merge_task.py, pipeline_lib.py and tests/test_same_code.py. run_task.py is untouched. That is correct: run_task.py:87/95 only decide whether to *set* the fields. They do not gate on them.
3. Layer: not applicable (pipeline scripts). layer_lint gives 0 fail, 0 warn.
4. Correctness: errors are handled without raising. `merge-base` failure and unknown objects return False or "", with check=False. I traced the rebase logic by hand. In case c, both diffs are taken against their own merge-bases, so they are the same diff. Case e differs, as it should.
5. Verification: I ran `python3 scripts/agents/tests/test_same_code.py` and got `test_same_code: OK`. Cases a–f and the `import merge_task` + `gates` check (DoD 3) are all present.
6. Hygiene: no secrets and no TODOs. Two non-blocking nits:
   1. scripts/agents/tests/test_same_code.py:39: the `mkdtemp` repo is never removed. A `tempfile.TemporaryDirectory()` would clean it up.
   2. Conflict-rebase limit: after any conflicted rebase the gate always needs a fresh review/qa, even when the resolution is identical. In that case the diff against the new base still differs. This matches the Goal ("clean rebase") and DoD 2e, so it is noted here only.

## QA
PASS

1. Lint: `scripts/agents/test.sh lint` → OK, 0 problems; layer_lint 0 fail, 0 warn. Build type none, so no build.
2. DoD 1: `pl.same_code` is used at merge_task.py:38. The error text is unchanged.
3. DoD 2 and 3: `python3 scripts/agents/tests/test_same_code.py` → `test_same_code: OK` (cases a–f, plus the merge_task import and `gates` check).
4. DoD 4: `diff.sh` needs a path argument (`tasks/0018-...md`), not the bare id, so `diff.sh 0018 --names` crashed. The crash is in the script, not the task. The branch diff lists only merge_task.py, pipeline_lib.py and tests/test_same_code.py, all within allowed_paths.
5. DoD 5: the docstring at merge_task.py:8-9 mentions the patch-id fallback.
