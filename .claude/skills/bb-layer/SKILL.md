---
name: bb-layer
description: ADR-0002 in agent form — where BB code lives, the three classes of foreign files and the allowed mechanism for each, patch READMEs, layer.yaml, forbidden commands. Injected into developer, reviewer, teamlead and rebaser roles; /bb-layer for humans.
disable-model-invocation: true
---
# The BB layer (from ADR-0002 — the ADR wins on any disagreement)

Zen = Firefox tarball in `engine/` + `src/` and `prefs/` applied by surfer at `npm run import`:
non-`.patch` files under `src/` are **symlinked** into `engine/` by path; every `src/**/*.patch`
is `git apply`-ed in undefined order. `engine/` is reset by surfer — nothing lives there.

## Where BB things go
| what | where | how it reaches the build |
|---|---|---|
| JS/CSS/manifests of a feature | `src/bb/<feature>/` | `src/bb/moz.build`, `jar.inc.mn`, `bb-assets.inc.xhtml`, `BBStartup.mjs` (loads modules by pref) |
| patches to Firefox files | `src/bb/patches/<eN-slug>/<kebab-name>/<kebab-name>.patch` + `README.md` | surfer's `**/*.patch` glob |
| prefs | `prefs/bb/*.yaml`, names only `bb.*` | ffprefs reads prefs/ recursively |
| build flags | `configs/bb/mozconfig`, `mozconfig.macos` | one hook line in `configs/common/mozconfig` |
| branding | `configs/branding/bb/` + brand `bb` in `surfer.json` | surfer |
| product scripts | `scripts/bb/` (lib.sh, patches.sh, rebase.sh, smoke.sh, report.sh, l10n.sh) | `npm run bb:*` |
| registry of everything outside src/bb/patches | `src/bb/layer.yaml` (`base`, `hooks`, `edits`, `zen_patches`) | read by scripts |

Hook lines (one each, in Zen's flat files, never in patches): `src/zen/moz.build`
`DIRS += ["../bb"]` · `src/browser/base/content/zen-assets.jar.inc.mn` `#include ../../../bb/jar.inc.mn` ·
`zen-assets.inc.xhtml` `#include ../../../bb/bb-assets.inc.xhtml` · `src/zen/common/ZenPreloadedScripts.js`
`"chrome://browser/content/bb/BBStartup.mjs"` last · `src/zen/ZenComponents.manifest`
`#include ../bb/BBComponents.manifest` · `configs/common/mozconfig` `. "$topsrcdir/../configs/bb/mozconfig"`.

## Three classes of foreign files — pick the cheapest allowed mechanism
1. **Firefox files** (real files in `engine/` from the tarball): a BB patch in `src/bb/patches/`.
   Never edit `engine/` as a deliverable (it is scratch for authoring the patch, then
   `scripts/bb/patches.sh export <dir>`). Never `npm run export` for a file that has a BB patch.
2. **Zen flat files** (`src/zen/**`, `src/browser/base/content/zen-*.inc.*`, `prefs/zen/*.yaml`,
   `configs/*/mozconfig`, `package.json`, `surfer.json`): plain edit in the branch. A `.patch`
   for them can never apply (symlinks). Hook ≤ ~10 lines with a marker `// BB(eN): why`
   (CSS `/* BB(eN) */`, yaml `# BB(eN)`) + an entry in `layer.yaml: edits`. Bigger change →
   replace the module behind a pref: `BBStartup.mjs` loads last, so
   `window.gZenX = new BBX()` where `BBX extends gZenX.constructor`; pref off = stock Zen (F2).
3. **Zen patches** (`src/**/*.patch`, `src/external-patches/`): edit only when a BB hunk
   unavoidably overlaps a Zen hunk, in a task with `allow_zen_patch: true`, via `npm run export`,
   marker inside the hunk, entry in `layer.yaml: zen_patches`. Human approval required.

C++/ObjC/IDL: only where nothing else works (ADR-0001 is the known case), always its own patch
with README, always human-approved — role developer-hard, full build.

## Patch README (frontmatter is machine-read by patches.sh and report.sh)
```
---
epic: e3-little-bb
adr: docs/adr/0001-little-bb-floating-window.md
files:
  - widget/cocoa/nsCocoaWindow.mm
upstream: none          # none | zen-pr | firefox-bug
rebuild: full           # full | ui
---
# Why · # What it changes · # How to verify · # What usually breaks on rebase
```
A BB patch must apply both to clean Firefox and to Firefox + Zen's patch of the same file
(`scripts/bb/patches.sh check`). One patch = one logical change; may touch several files.

## Forbidden for agents (hooks enforce)
`npm run export` on BB-patched files · `npm run reset-ff` / `surfer reset` · direct `mach`,
`surfer`, `npm run build/import` (use scripts/agents/build.sh) · `.patch` under `src/zen/` ·
Zen pref names in `prefs/bb/` · editing `.github/`, `.claude/`, `CLAUDE.md` · pushing, merging,
switching branches · reading `engine/` wholesale.

Commit prefixes: `eN:` feature work, `layer:` hooks/registry/scripts, `rebase:` only from rebase.sh.
