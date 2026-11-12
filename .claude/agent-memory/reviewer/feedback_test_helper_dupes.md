---
name: test-helper-dupes
description: developers add new runner helpers / fixture literals in bb shell tests instead of generalising the existing one
metadata:
  type: feedback
---
New test cases in scripts/bb/tests/*.sh tend to copy an existing runner helper (e.g. finalize_rb → steps_rb) and
repeat fixture literals (the "no bb brand" config printf) verbatim.

**Why:** the owner's global rule is "no duplicates; flag them on review with file:line" (0039 was returned for this).
**How to apply:** when a test diff adds a helper, compare it with the helpers above it; grep the new printf/fixture
literals for earlier copies in the same file.
