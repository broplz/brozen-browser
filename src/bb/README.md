# BB layer

The BROzen layer on top of Zen. Source of truth: `docs/adr/0002-bb-layer-and-rebase-runbook.md`
(the ADR wins on any disagreement).

Every non-`.patch` file under `src/bb/` (this README too) is symlinked into `engine/bb/` by
surfer at import — harmless, the build does not see it.

## Layout

```
src/bb/                        # symlinked into engine/bb/, built via moz.build
  moz.build                    # DIRS per BB module
  BBComponents.manifest        # components and actors; #include'd from ZenComponents.manifest
  jar.inc.mn                   # chrome://browser/content/bb/...; #include'd from zen-assets.jar.inc.mn
  bb-assets.inc.xhtml          # <link> to BB CSS; #include'd from zen-assets.inc.xhtml
  BBStartup.mjs                # one line in ZenPreloadedScripts.js; loads modules by pref
  common/                      # BBPrefs, log, utilities, isLittleWindow()
  little-bb/                   # E3: BBLittle.mjs, actors/, bb-little.css
  split-view/                  # E6: BBSplitView — replaces ZenViewSplitter behind a pref
  <epic>/                      # command-bar, pip, containers, arc-import — one dir per epic
  patches/                     # patches to Firefox files in engine/, per epic
    e3-little-bb/cocoa-floating-window/{cocoa-floating-window.patch,README.md}
  layer.yaml                   # registry: hooks, direct Zen edits, Zen patches -> epic
prefs/bb/                      # *.yaml, read by ffprefs without hooks; namespace bb.*
configs/bb/                    # mozconfig + mozconfig.macos; one hook line in configs/common/mozconfig
configs/branding/bb/           # E0: brand via surfer's mechanism + surfer.json
scripts/bb/                    # rebase.sh, patches.sh, smoke.sh, report.sh, lib.sh
```

A patch lives at `src/bb/patches/<epic>/<name>/<name>.patch` with a `README.md` next to it
(kebab-case names; one patch = one logical change).

## Hook lines

One line each, in Zen's flat files (never in `.patch`):

| Zen file | Line |
| --- | --- |
| `src/zen/moz.build` | `DIRS += ["../bb"]` |
| `src/browser/base/content/zen-assets.jar.inc.mn` | `#include ../../../bb/jar.inc.mn` |
| `src/browser/base/content/zen-assets.inc.xhtml` | `#include ../../../bb/bb-assets.inc.xhtml` |
| `src/zen/common/ZenPreloadedScripts.js` | `"chrome://browser/content/bb/BBStartup.mjs"` last in `scripts` |
| `src/zen/ZenComponents.manifest` | `#include ../bb/BBComponents.manifest` |
| `configs/common/mozconfig` | `. "$topsrcdir/../configs/bb/mozconfig"` |
| `package.json` | `"bb:rebase"`, `"bb:patches"`, `"bb:smoke"` |

## Foreign files

The class of a foreign file decides the mechanism; take the cheapest one for rebases.

1. **Firefox files** (real files in `engine/`): a BB patch in `src/bb/patches/`. If Zen patches
   the same file, the hunks must not overlap (`scripts/bb/patches.sh check`); otherwise the hunk
   goes into Zen's patch via `npm run export <file>` with a `BB(eN)` marker and a
   `zen_patches` entry. Never edit `engine/` directly.
2. **Zen flat files** (`src/zen/**`, `zen-*.inc.*`, `prefs/zen/*.yaml`, `configs/*/mozconfig`,
   `package.json`): a direct edit (hook <= ~10 lines, marker `// BB(eN): why`, CSS
   `/* BB(eN) */`, yaml `# BB(eN)`) or a module replacement behind a `bb.<feature>.enabled`
   pref. Never a `.patch` — these are symlinks in `engine/`.
3. **Zen patches** (`src/**/*.patch`, `src/external-patches/`): only for unavoidable hunk overlap.

C++/ObjC/IDL only where nothing else works, always its own patch with a README and human approval.

## layer.yaml

`src/bb/layer.yaml` is the registry of everything outside `src/bb/patches/`:

- `base` — the Zen tag, Firefox version and Zen commit the layer sits on.
- `hooks` — the hook lines above (`file`, `line`, `epic`, `why`).
- `edits` — direct edits of Zen flat files (`file`, `epic`, `why`).
- `zen_patches` — edited Zen `.patch` files (`file`, `epic`, `why`).

A conflict in `src/bb/**` belongs to the epic by directory name, anywhere else by this file.
A foreign file without an entry is a registry defect.
