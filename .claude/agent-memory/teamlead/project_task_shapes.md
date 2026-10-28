---
name: project-task-shapes
description: Log of planned task shapes (size, files, build) and their outcome — first try / returned / split — to calibrate future planning
metadata:
  type: project
---

Planned 2026-10-28 on feat/layer (outcomes unknown yet — update when tasks finish):
- 0001 layer.yaml + README (docs, S, 2 files, build none)
- 0002 scripts/bb/lib.sh + bash-3.2 test script (script, S, build none)
- 0003 src/bb skeleton, 6 new files, build none
- 0013 five Zen hook lines + layer.yaml, build ui, needs_approval

Pre-split rule applied: backlog 0003 touched 12 files (> M cap 10) → split into BB-owned files
(no build) and Zen hook edits (build ui). Backlog line annotated, 0006 dep moved to 0013.

**Why:** calibrate S/M/L estimates and DoD style against real returns.
**How to apply:** after each run, record per id: done first try / returned (why) / split.
Watch 0013: `build.sh ui` may not regenerate backend for new DIRS/jar.mn → may need re-spec to full.
