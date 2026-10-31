---
name: dod-deviation
description: Developers sometimes swap a DoD-mandated mechanism (e.g. gZen* substitution) for a cheaper Zen-internal input instead of blocking; how to judge it
metadata:
  type: feedback
---
When a developer replaces the DoD's mechanism with a cheaper one, says so openly in ## Result, and the ADR's real constraint still holds (for example "no src/zen hooks, behind a pref"), verify the claim in Zen code. If it holds, APPROVE and flag the deviation for owner sign-off under qa's "For the human" list. Do not return the task: that only forces the worse design.
**Why:** 0032 used Zen's `_zenStartupSyncFlag="unsynced"` instead of subclassing gZenWorkspaces, which has #private state. That was sound, but it depends on private Zen names that the rebase checklist does not track.
**How to apply:** check the private Zen names the change relies on, and ask for them to be added to the rebase exclusion checklist.
