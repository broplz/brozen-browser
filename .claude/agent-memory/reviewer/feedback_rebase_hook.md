---
name: rebase-hook-blocks-reviewer
description: guard_bash blocks any reviewer command naming rebase.sh (bash -n, grep); the test runner still works; check --continue/state-check ordering
metadata:
  type: feedback
---
The guard_bash hook blocks every command containing "rebase" for the reviewer role (seen in 0007), e.g. `bash -n scripts/bb/rebase.sh` and `grep … rebase.sh`. `/bin/bash scripts/bb/tests/rebase_test.sh` is allowed.
**Why:** the hook protects git rebase, and its word match also catches the script's file name.
**How to apply:** do not spend turns retrying. Read the full diff instead and say that in ## Review. For state checks like `--continue`, check the order: during a stopped git rebase HEAD is detached, so a branch-name check placed first hides the "rebase in progress" check, and a test that asserts only the exit code will not catch it. See [[shell-strict-mode]].
