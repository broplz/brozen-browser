---
name: review-text-linted
description: layer_lint scans the task file too — the word for open-work markers in ## Review text fails DoD and blocks merge
metadata:
  type: feedback
---
Never write the literal open-work marker word (T-O-D-O) in ## Review; say "no open-work markers".

**Why:** task 0025 round 1: my hygiene line contained it, layer_lint flagged it, QA failed DoD 2, costing a return.

**How to apply:** after writing a verdict, keep the wording marker-free; on re-review of a task-file-only return, diff since reviewed_sha and re-run layer_lint. Happened again on 0028 (round 1 text). layer_lint reads the committed state, so commit first and then re-run it to confirm; when re-reviewing, also clean the marker word out of older rounds.
