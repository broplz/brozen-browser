---
name: multisession-docs-staleness
description: Docs/report tasks finished over 2+ sessions keep stale "OPEN"/"session 1" text and counts that no longer add up
metadata:
  type: feedback
---
In multi-session docs tasks (e.g. 0024 strip inventory), round 2 updates the facts but leaves round-1 framing behind: intro text saying "session 1 ran out of turns", inline **OPEN** markers, "four not found" after one was found, and count tables that double-count.

**Why:** the developer adds the new findings but does not reread the whole report.
**How to apply:** grep the report for OPEN|session|four|count words, and check that each count table adds up to the ADR total once, before approving.
