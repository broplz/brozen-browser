---
name: switch-polarity
description: bb.strip.* switches are "Remove X" (on = stripped); checklists/docs written from the ADR's "X on" wording come out inverted
metadata:
  type: feedback
---
The `bb.strip.*` UI switches are labelled "Remove X" (on = feature stripped, per 0027). ADR-0003 2.9 says "EME switch on → Netflix plays", which means the opposite of the built UI.

**Why:** 0028 copied the ADR wording into the smoke checklist, so every correct build would fail the item.

**How to apply:** for any doc, test or checklist that mentions a strip switch state, grep src/bb/strip/l10n/en-US/brozen-pane.ftl for the real label and check that the polarity matches.
