---
name: project-task-shapes
description: Log of planned task shapes (size, files, build) and their outcome — first try / returned / split — to calibrate future planning
metadata:
  type: project
---

Planned 2026-10-28 on feat/layer (record outcomes when tasks finish):
- 0001 layer.yaml + README (docs, S, 2 files, build none)
- 0002 scripts/bb/lib.sh + bash-3.2 test script (script, S, build none). The code was approved on the
  first try (review APPROVE). QA returned it for pipeline reasons, not code: the reviewer committed
  .claude/agent-memory files onto the task branch, which broke DoD 6 (diff-only), and the sandbox
  denied `bash -n` and `/bin/bash test` for all roles. Escalated 2026-10-28.
- 0003 src/bb skeleton, 6 new files, build none
- 0013 five Zen hook lines + layer.yaml, build ui, needs_approval

Pre-split rule applied: backlog 0003 touched 12 files, over the M cap of 10. It was split into BB-owned
files (no build) and Zen hook edits (build ui). The backlog line was annotated and 0006's dependency moved to 0013.

Lessons:
- A DoD item of the form "git diff --name-only lists only X" fails when any agent's memory lands on the task branch.
  Until the owner fixes this, expect that failure again. Do not split the task over it; escalate.
- Before writing a DoD command, check that it is allowed in dontAsk mode. `bash -n` and `/bin/bash <script>`
  were denied. Consider a test.sh wrapper or an allowlist request.

**Why:** calibrate S/M/L estimates and DoD style against real returns.
**How to apply:** after each run, record per id: done first try / returned (why) / split.
Watch 0013: `build.sh ui` may not regenerate the backend for new DIRS/jar.mn, so it may need a re-spec to full.
