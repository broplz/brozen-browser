---
name: merged-task-lint
description: layer_lint on a merged task falls back to HEAD (branch deleted) — "regression" DoD claims need --base/--branch
metadata:
  type: feedback
---
`layer_lint.py <merged task>` with its branch deleted diffs HEAD, i.e. the *current* task's changes against the
merged task's allowed_paths → spurious scope fails (or a meaningless 0 fail if run before commit).

**Why:** 0029 claimed "0024 → 0 fail"; from the branch it gave exit 1. Real check:
`--base <squash>~1 --branch <squash>` (find squash via `git log --oneline feat/<x> --grep <id>`).

**How to apply:** for any DoD "layer_lint on merged task N unchanged", re-run with explicit --base/--branch.
