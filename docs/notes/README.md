# API notes for agents

Short, verified facts about Gecko, Zen and surfer that the next agent would otherwise re-derive
from engine/ (where a wrong grep costs a whole session). One file per area, e.g.
`cocoa-windows.md`, `sessionstore.md`, `surfer-import.md`. Every note names the file:line it was
read from and the Firefox version. Agents may extend these in any task (docs/notes/** is always
writable); the reviewer checks that a note is a fact, not a guess.

## Build environment
- Node 22 per `.nvmrc` (`nvm use`); Node 25 breaks `surfer import` (async-icns rmdir).
- gnu-tar is required (`brew install gnu-tar`; override the binary with `BB_GTAR`).
- After `npm run import` the engine has no Zen en-US strings; `scripts/agents/build.sh` copies them
  (`scripts/update_en_US_packs.py`) as its `en-US-packs` step. `build.sh` checks Node and gnu-tar first (exit 2).
