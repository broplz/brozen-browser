#!/usr/bin/env bash
# Human-run. Land a finished feature branch on main (ADR-0002 §3 steps 3-4): rebase onto main from
# the recorded fork point, build + smoke by hand, ff-merge, clean up. The pipeline never does this.
#
#   scripts/agents/finish_feature.sh feat/<eN>-<slug> [--no-build]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
NAME="${1:?usage: finish_feature.sh feat/<eN>-<slug>}"; shift || true
BUILD=1; [ "${1:-}" = "--no-build" ] && BUILD=0
FORK="bb/fork/${NAME#feat/}"
[ -z "$(git status --porcelain)" ] || { echo "working tree is dirty" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/$FORK" >/dev/null || { echo "no tag $FORK; create it on the commit the feature forked from: git tag $FORK <sha>" >&2; exit 1; }
echo "1/4 rebase $NAME onto main from $FORK"
git switch "$NAME"
git rebase --onto main "$FORK" "$NAME"
echo "    optional: squash to meaningful commits now (git rebase -i main), then press Enter"; read -r _
if [ "$BUILD" = 1 ]; then
  echo "2/4 build + smoke (full build if C++ changed)"
  scripts/agents/build.sh auto
  if [ -x scripts/bb/smoke.sh ]; then scripts/bb/smoke.sh; else echo "    scripts/bb/smoke.sh not there yet — run the smoke checklist by hand, then press Enter"; read -r _; fi
fi
echo "3/4 ff-merge into main"
git switch main
git merge --ff-only "$NAME"
echo "4/4 cleanup + push"
git branch -d "$NAME"
git tag -d "$FORK"
git push origin main || echo "push failed (slow link?) — push main later by hand"
echo "done: main is at $(git log -1 --oneline)"
