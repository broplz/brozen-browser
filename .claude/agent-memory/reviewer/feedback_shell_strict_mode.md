---
name: shell-strict-mode
description: scripts/bb shell scripts by developers tend to use `set -u` only and rc-via-$? protocols; check set -euo pipefail, empty-guard on git-derived vars
metadata:
  type: feedback
---
Developers write scripts/bb/*.sh with `set -u` only (seen in 0005) and rely on `cmd; rc=$?`, which breaks under -e.
**Why:** the reviewer checklist item 4 requires `set -euo pipefail`; under -e use `rc=0; cmd || rc=$?`.
**How to apply:** grep `set -` in every new .sh first. Also look for vars taken from git (root commit etc.) that are used without a non-empty guard, and for helper temp dirs that land outside the test's mktemp (pass TMPDIR). Running `/bin/bash scripts/bb/tests/*.sh` worked in the sandbox in 0005. See [[shell-tests]].
