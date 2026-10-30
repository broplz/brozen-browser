---
id: 0020
title: Report on where the Browser Console "missing key/keycode" warnings for Zen shortcuts come from
epic: layer
prefix: layer
kind: docs
role: developer
size: S
status: ready
base: feat/layer
branch: task/0020-zen-shortcut-key-warnings
depends_on: []
build: none
tests: []
needs_approval: true
allow_zen_patch: false
allowed_paths:
  - docs/reports/0020-zen-shortcut-key-warnings.md
spec: tasks/backlog.md
returns: 0
sessions: 0
reviewed_sha:
qa_sha:
blocked_reason:
---
## Goal
Our builds log Browser Console warnings `Key element … is missing "key" and "keycode" attributes
necessary to define a shortcut` (from `ShortcutUtils.sys.mjs`) for Zen shortcuts. Find out, by
reading code only, whether stock Zen 1.23.4b produces them too or whether they come from our
build/l10n/init. Deliverable: one report file. No code change, no fix. Backlog item 0020
("report only"); there is no ADR section for it.

## Definition of Done
1. `scripts/agents/diff.sh 0020 --names` → only `docs/reports/0020-zen-shortcut-key-warnings.md`
   and `tasks/0020-zen-shortcut-key-warnings.md`.
2. `grep -c "^## " docs/reports/0020-zen-shortcut-key-warnings.md` → 5, and the headings are, in order:
   `## Source`, `## Trigger`, `## Upstream`, `## Verdict`, `## Proposed fix`.
3. `## Source` cites the `file:line` in `engine/toolkit/modules/ShortcutUtils.sys.mjs` that emits
   the warning and names the calling function(s) that reach it.
4. `## Trigger` cites, with `file:line`, the code that creates or keeps `<key>` elements without
   either attribute, and says which shortcut ids are affected (or how to list them).
5. `## Upstream` contains the output of `git diff --stat bb/base/1.23.4b -- src/zen/kbs` (expected
   empty: then our kbs code equals Zen 1.23.4b) and states whether the trigger depends on Fluent
   strings (en-US packs / l10n), with the evidence.
6. `grep -c "^Verdict: \(upstream\|ours\|unknown\)$" docs/reports/0020-zen-shortcut-key-warnings.md` → 1.
7. `## Proposed fix` is prose only (one paragraph + which layer mechanism from ADR-0002 would carry
   it: class-2 hook / module replacement / upstream Zen PR / nothing); no code in the diff.
8. [human] The owner opens the official Zen 1.23.4b build, opens the Browser Console, and checks
   whether the same warnings appear. This confirms or overturns the Verdict.

## Notes from teamlead
- Warning text: `engine/toolkit/modules/ShortcutUtils.sys.mjs:68`. Read `engine/` only with Grep
  (path + head_limit) and then Read with offset/limit. Never read the tree wholesale.
- Zen side: `src/zen/kbs/ZenKeyboardShortcuts.mjs`. `replaceWithChild()` (~l.455-490) removes both
  `key` and `keycode` when a shortcut has neither. Empty shortcuts are those where `isEmpty()`
  (~l.583) is true. Default shortcuts are parsed from Firefox's `<key>` elements (~l.401-416).
  Check this first.
- Two hypotheses to confirm or rule out:
  (a) upstream: Zen emits `<key>` for empty or disabled shortcuts, and any ShortcutUtils caller
      (menus, tooltips, `prettifyShortcut`/`findShortcut`) warns on them;
  (b) ours: Firefox keys get `key` through Fluent (`data-l10n-id` with a `.key` attribute). Without
      en-US packs (build.sh now runs `scripts/update_en_US_packs.py` after import, task 0016), or
      in a profile created before that, the parsed defaults come out empty.
  Say which hypothesis the code supports. If neither can be decided from code alone, the verdict
  is `unknown` and DoD 8 decides.
- Base tag: `bb/base/1.23.4b` (layer.yaml `base.zen: 1.23.4b`, commit 541ee55).
- Do not run the browser and do not build: build none. Do not edit `src/zen/**`. If the fix is
  obvious, it goes into `## Proposed fix` plus one line in tasks/backlog.md under "Found by agents".
