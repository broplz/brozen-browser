---
name: rerun-dod-greps
description: Developers often skip some DoD greps (e.g. 0001 left DoD 2/3/6/7 unrun); reviewer re-runs the cheap ones
metadata:
  type: feedback
---
Re-run every cheap DoD command (grep, diff.sh --names, layer_lint) yourself instead of trusting ## Result.

**Why:** in task 0001 the Result said "Not run: the other DoD greps". It was honest, but it left gaps that QA would otherwise find.

**How to apply:** for docs/registry tasks, run the DoD greps in parallel with diff.sh and layer_lint in the first turn, then check the cited ADR lines with grep and offset/limit reads.
