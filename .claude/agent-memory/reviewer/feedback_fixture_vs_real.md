---
name: fixture-vs-real
description: Compare test fixtures against the real input files (trailing newline, CRLF); `while read` drops a last line without a newline
metadata:
  type: feedback
---
Check that the test fixtures match the real repo input files byte for byte in shape: trailing newline and CRLF.

**Why:** In 0010, `locales/language-maps` is `nb:nb-NO` with no newline (`wc -lc` → 0 8). The script's `while read` loop dropped that line, and the test still passed because its fixture had a newline.

**How to apply:** Any shell `while read` over a repo file: run `wc -lc <file>` on the real file and ask for the `|| [ -n "$var" ]` guard.
