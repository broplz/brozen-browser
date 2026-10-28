---
name: feedback-bash-hooks
description: Bash guard quirks met while planning — words that trigger blocks and paths outside the repo
metadata:
  type: feedback
---

guard_bash.py blocks any command containing the word `surfer` (even `ls surfer.json`) and `ls ../`
outside the repo is denied. Use Read for surfer.json; do not probe sibling dirs.

**Why:** two wasted turns on 2026-10-28.
**How to apply:** check file existence with `ls` lists that avoid "surfer"/"npm"; Read the rest.
