---
name: preprocessed-headers
description: Preprocessed include files (.inc.xhtml, .manifest, jar.inc.mn) must use `# ` comments, not XML/JS comments
metadata:
  type: feedback
---
In files that get `#include`d by the Mozilla preprocessor (`*.inc.xhtml`, `*.manifest` in
EXTRA_PP_COMPONENTS, `jar.inc.mn`), comments and the MPL header must be `# ` lines. Zen's
neighbouring files all do it this way.

**Why:** `<!-- -->` comments would ship in the built browser.xhtml, while `# ` lines are stripped
at preprocessing. A developer did this in 0003 round 1 (bb-assets.inc.xhtml).

Recurred in 0013 (marker above the #include in zen-assets.inc.xhtml); the teamlead note had
prescribed `<!-- -->`, so also check teamlead notes for this in hook tasks.

**How to apply:** check BB(eN) marker lines in preprocessed files too, and the header style of each new include file against its Zen neighbour, e.g. `head -3`.
