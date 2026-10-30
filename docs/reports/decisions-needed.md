# Decisions needed from the owner

Append-only for agents (one `- ` line each: task id, question, the options the ADR allows).
The owner answers inline, in the ADR or in the task file, and deletes the line.

- [resolved f43e42814, 0002 re-spec'd] 0002: code is approved and needs no changes. The branch diff includes `.claude/agent-memory/reviewer/{MEMORY.md,feedback_shell_tests.md}`, which a reviewer session committed. Agents cannot remove them: `git rm` is denied and `.claude/` is forbidden. DoD 1 (`bash -n`) and DoD 2 (`/bin/bash …lib_test.sh`) are denied by the sandbox for every role. Options: (a) the owner drops the 2 files from the branch (or makes the driver exclude/stash `.claude/agent-memory/` changes on task branches), allows those two Bash commands and sets 0002 back to `qa`; (b) the owner amends the DoD 6 rule to ignore `.claude/agent-memory/`. Pipeline fix to prevent repeats: agent-memory writes must not land on task branches.
- 0010: ADR-0002 "Кэш" says the l10n sparse checkout covers `locales/supported-languages` "(v1: en-US, ru)", but the repo file lists 39 Zen languages. l10n.sh (task 0010) reads the file, so no code depends on the answer. Options: (a) trim `locales/supported-languages` to `ru` (class-2 edit, its own task; it also changes Zen's release packaging); (b) keep all 39 and fix the ADR wording.
- 0012 (not planned, kept in backlog): the ADR plan п.4 dry-run is silent on how to run it without touching the real repo state. Open points: (1) where `main'` on 1.23.3b lives: a throwaway clone/worktree, or a branch in this repo with `BB_MAIN_BRANCH` set; (2) `bb/base/1.23.4b` already exists (п.3), so step 11's tag/push would collide: run against a local bare `BB_PUSH_REMOTE` (0011 adds it), or stop before `publish`; (3) whether the install step may replace the `/Applications` daily driver (0011 adds a `BB_APPS_DIR` override); (4) who builds `main'`: the rebaser agent (git branch work the driver normally owns) or the owner by hand. Once these are answered, 0012 becomes a role-rebaser task with needs_approval.


### 0012 — owner answers (2026-10-30)
1. `main'` lives in a throwaway worktree: `git worktree add ../bb-rebase-test <base-on-1.23.3b>`; never a branch in this repo.
2. Stop before publish: run with `BB_POST_STEPS` without `publish`; tag `bb/base/1.23.4b` is not touched.
3. Install must not touch /Applications: `BB_APPS_DIR=/tmp/bb-apps`.
4. The rebaser agent builds `main'` (worktree + the layer on 1.23.3b); task needs_approval, owner approves the task file before the run.
