---
name: bb-build
description: How to build, lint and test BB without flooding your context — build types and durations, the wrapper scripts, logs and triage, the build lock. Injected into developer, developer-hard, qa and rebaser; /bb-build for humans.
disable-model-invocation: true
---
# Building and testing (one engine/, one build at a time)

| command | what | time on M1 Pro |
|---|---|---|
| `scripts/agents/build.sh` | `npm run import` + `surfer build --ui`, or full when the diff touches C/C++/ObjC/IDL/Rust/moz.build/mozconfig (patch targets count) | ui ≈ 3 min · full ≈ 40 min |
| `scripts/agents/build.sh ui` / `full` | force the type (full: developer-hard, qa, rebaser only) | |
| `scripts/agents/test.sh lint` | `npm run lint` (mach lint zen) + `layer_lint.py` on your task | ≈ 1-2 min |
| `scripts/agents/test.sh <dir>` | Zen mochitests for `src/zen/tests/<dir>` (e.g. `glance`) | minutes |
| `scripts/agents/diff.sh <task>` | your branch's diff vs base, capped | |
| `python3 scripts/agents/layer_lint.py <task>` | ADR-0002 rules on the diff; FAIL lines block the merge | seconds |
| `python3 scripts/agents/triage_log.py <log>` | errors + context from any log | |

Every wrapper logs to `logs/<kind>-<stamp>.log` and prints `BUILD RESULT: OK|FAIL …` /
`TEST RESULT: …` plus a triage. **That triage is what you read.** Never Read a `.log`, never
`cat` it; for more, `Grep` the log with a narrow pattern and head_limit, or `tail -n 40`.

Rules of thumb
- Run the build once per meaningful change, not after every edit; think first.
- `exit 3` from build.sh = full build required → not your role; write ## Handoff.
- `exit 4` = another build holds the lock → `sleep 120`, retry once, then Handoff.
- `npm run import` is part of build.sh and idempotent; new files under src/ need it (symlinks).
- An edit in `engine/` is lost on the next import unless it is exported to a BB patch.
- Firefox source is huge: locate first (`Grep` with `glob`/`type` + `head_limit`), then `Read`
  with offset/limit ≤ 400. Prefer the Zen copy under `src/` — same file, no symlink hop.
- No network from the shell; no package installs. Missing tool → one line under
  "Found by agents" in tasks/backlog.md and a Handoff.
- Strikes: 3 failed ui builds/tests or 2 failed full builds in a row → stop, Handoff.
