---
name: patches-sh-exec-bit
description: scripts/bb/patches.sh has no exec bit (as of 2026-10-29); docs/READMEs calling it directly fail
metadata:
  type: project
---
`scripts/bb/patches.sh` lacked the exec bit as of 2026-10-29 (task 0006). Run it as `bash scripts/bb/patches.sh …`.

**Why:** patch READMEs' "How to verify" sections called it directly, so the command fails as written.

**How to apply:** check with `ls -l` first. If the bit is still missing, flag patch READMEs that call it without `bash` as a non-blocking note.
