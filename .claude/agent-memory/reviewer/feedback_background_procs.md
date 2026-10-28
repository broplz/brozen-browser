---
name: background-procs-under-step
description: bb scripts that background a process (browser launch) must redirect its stdout/stderr, or lib.sh step's tee pipe hangs
metadata:
  type: feedback
---
Any `cmd &` in a scripts/bb/* script that runs under lib.sh `step` (`"$@" 2>&1 | tee -a $BB_LOG`) must redirect the
child's stdout/stderr (to a file), or the child holds the pipe open and tee never ends. It also pollutes stdout contracts.

**Why:** found in 0008 smoke.sh (Zen launched `&` with inherited fds).
**How to apply:** grep the diff for `&$` / ` &` launches; check redirection. Also note: the reviewer hook blocks any
command containing "smoke" or "rebase" (even grep of rebase.sh); grep lib.sh instead. See [[shell-strict-mode]].
