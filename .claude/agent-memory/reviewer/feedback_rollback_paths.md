---
name: rollback-paths
description: In bb scripts that mutate refs (main, tags), check every failure branch restores state — not just the "expected" one
metadata:
  type: feedback
---
Check each `a && b && c || fail` chain that moves refs: a failure in the middle step (c) usually leaves a and b in place, with no rollback. Rollback commands are unchecked too, because errexit is off inside `step`. Also check exclusion rules ("skip X because Y"): see whether Y holds for other cases (e.g. a report that dirties main on fetch/recon failure, not only on preflight failure).
**Why:** 0011 do_publish moved main, then the tag step failed and the function returned without restoring main. The failed-report rule covered only preflight.
**How to apply:** for any publish/rollback code, list each step that can fail and note the state it leaves. Related: [[step-wrapping]].
