---
name: helper-copy
description: new rebase.sh helpers often re-implement an existing loop/awk (patch_pairs, epic_of) and recompute pairs per loop item
metadata:
  type: feedback
---
New helpers in scripts/bb/*.sh tend to copy an existing function's loop/parsing (e.g. bb_patch_hunks copied patch_pairs;
first_epic duplicated epic_of's awk) and to call registry_pairs/patch_pairs inside per-file loops.

**Why:** the owner's global rule is no duplicates and shared values in one structure; 0041 got returned for this.
**How to apply:** for every new helper, look for a sibling function with the same glob/grep/awk and check whether
expensive generators are hoisted out of loops. See [[test-helper-dupes]].
