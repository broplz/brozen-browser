---
epic: layer
adr: docs/adr/0002-bb-layer-and-rebase-runbook.md
files:
  - browser/base/content/browser.js
upstream: none
rebuild: ui
---
# Why
Learning patch for ADR-0002 verification plan item 2: proves that a BB patch on a file Zen also
patches applies at import (R2) and that a repeated import is idempotent (R3).

# What it changes
Adds a comment block to `browser/base/content/browser.js`, far from Zen's hunks. No runtime effect.

# How to verify
`scripts/bb/patches.sh check` prints `OK layer/learning-browser-js`; after an import
`scripts/bb/patches.sh status` prints `applied layer/learning-browser-js` and
`grep -c "BB(layer)" engine/browser/base/content/browser.js` prints `1`.

# What usually breaks on rebase
The context lines around the comment may move or change upstream; re-author the comment at a
nearby stable spot and re-export.
