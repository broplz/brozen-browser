# Decisions needed from the owner

Append-only for agents (one `- ` line each: task id, question, the options the ADR allows).
The owner answers inline, in the ADR or in the task file, and deletes the line.

- 0002: code is approved and needs no changes. The branch diff includes `.claude/agent-memory/reviewer/{MEMORY.md,feedback_shell_tests.md}`, which a reviewer session committed. Agents cannot remove them: `git rm` is denied and `.claude/` is forbidden. DoD 1 (`bash -n`) and DoD 2 (`/bin/bash …lib_test.sh`) are denied by the sandbox for every role. Options: (a) the owner drops the 2 files from the branch (or makes the driver exclude/stash `.claude/agent-memory/` changes on task branches), allows those two Bash commands and sets 0002 back to `qa`; (b) the owner amends the DoD 6 rule to ignore `.claude/agent-memory/`. Pipeline fix to prevent repeats: agent-memory writes must not land on task branches.

