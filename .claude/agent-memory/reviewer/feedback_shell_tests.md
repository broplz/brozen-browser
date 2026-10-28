---
name: shell-test-review
description: Shell-script tasks — run bash -n and /bin/bash tests yourself (allowed since f43e42814); check PATH bash and bash -c usage in tests
metadata:
  type: feedback
---
Since owner commit f43e42814 (2026-10-28), `bash -n <file>` and `/bin/bash <script>` are allowed for the reviewer. Run DoD runtime checks yourself in turn 1. Check DoD scope with `scripts/agents/diff.sh <task> --names`, which ignores `.claude/agent-memory/`. Do not use `git diff --name-only`, because it lists reviewer memory files and caused a false QA FAIL in 0002.

**Why:** in 0002 the earlier sandbox denials and the memory files showing up in the git diff blocked the task across several sessions.

**How to apply:** check tests for `bash -c`, which resolves through PATH and may pick up Homebrew bash 5, where `"$BASH" -c` is needed to test bash 3.2. Also check for unescaped paths inside `=~` regexes.
