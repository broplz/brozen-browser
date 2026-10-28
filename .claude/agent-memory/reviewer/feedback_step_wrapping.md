---
name: step-wrapping
description: bb scripts — work done outside `step` (main-shell helpers) loses the log footer report.sh needs; errexit is off inside step fns
metadata:
  type: feedback
---
In scripts/bb/*.sh, check that every sub-action of a named step goes through `step`/`run_step` and so gets a
`<== step: <name> exit=N` footer. Main-shell work (e.g. `nvm use`, which has to change PATH) should record an rc
that the do_<step> function checks; it should not `exit` on its own.
Inside do_* functions errexit is off (they run in a && / || list), so a bare `rm -rf`/`mkdir` with no `|| return 1`
is a silent failure.
**Why:** 0014 round 1 had both defects (nvm outside the deps step, unchecked rm -rf of the engine dir).
**How to apply:** for every command inside a do_* function, ask "is its failure checked?"; for anything in
post_rebase that runs before the loop, ask "does it write a footer?". See [[shell-strict-mode]].
