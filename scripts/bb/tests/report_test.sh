#!/usr/bin/env bash
# Tests for scripts/bb/report.sh. Run: /bin/bash scripts/bb/tests/report_test.sh
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
report="$here/../report.sh"
real_readme="$here/../../../docs/rebase/README.md"
failed=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/rebase"
cp "$real_readme" "$T/rebase/README.md"
export BB_REBASE_DOCS="$T/rebase"

has() { # has <message> <file> <fixed line/substring>
  grep -qF -- "$3" "$2" || { echo "FAIL: $1 (missing: $3)"; failed=1; }
}

cat >"$T/b.log" <<'EOF'
==> 2026-11-08 10:00:00 step: recon
recon: zen 1.0.0b -> 1.0.1b
recon: firefox 150.0 -> 151.0
recon: upstream-commits 12
recon: toolchain-changed configs/common/mozconfig
recon: expected-conflict src/zen/moz.build layer
<== step: recon exit=0 duration=5s
==> 2026-11-08 10:10:00 step: rebase
conflict: git src/zen/moz.build layer
conflict: git src/browser/base/content/browser-js.patch e3-little-bb
<== step: rebase exit=1 duration=300s
==> 2026-11-08 11:20:00 step: patches
FAIL e3-little-bb/session-skip: zen error: patch failed
<== step: patches exit=1 duration=600s
smoke: y e3-little-bb tabs
smoke: n layer startup
smoke: result 1/2
EOF

"$BASH" "$report" 1.0.1b "$T/b.log" ok || { echo "FAIL: run ok exit"; failed=1; }
md="$T/rebase/1.0.1b.md"
has "hours" "$md" "- hours: 1.5"
has "date" "$md" "- date: 2026-11-08"
has "status" "$md" "- status: ok"
has "zen" "$md" "- zen: 1.0.0b -> 1.0.1b"
has "firefox" "$md" "- firefox: 150.0 -> 151.0"
has "kind git" "$md" "| git | layer | src/zen/moz.build |"
has "kind zen-patch" "$md" "| zen-patch | e3-little-bb | src/browser/base/content/browser-js.patch |"
has "kind bb-patch" "$md" "| bb-patch | e3-little-bb | e3-little-bb/session-skip |"
has "by epic layer" "$md" "| layer | 1 | 0 | 0 | 1 |"
has "by epic e3" "$md" "| e3-little-bb | 0 | 1 | 1 | 2 |"
has "step recon" "$md" "| recon | 0 | 5s |"
has "step rebase" "$md" "| rebase | 1 | 300s |"
has "step patches" "$md" "| patches | 1 | 600s |"
has "smoke line" "$md" "y e3-little-bb tabs"
has "smoke result" "$md" "result 1/2"
has "expected" "$md" "- src/zen/moz.build (layer)"
order=$(grep -n '^| recon \|^| rebase \|^| patches ' "$md" | cut -d'|' -f2 | tr -d ' \n')
[ "$order" = "reconrebasepatches" ] || { echo "FAIL: steps order ($order)"; failed=1; }
has "README row" "$T/rebase/README.md" "| 1.0.1b | 2026-11-08 | 151.0 | 3 | e3-little-bb:2, layer:1 | 1.5 | ok |"

"$BASH" "$report" 1.0.1b "$T/b.log" failed "build broke" || { echo "FAIL: run failed exit"; failed=1; }
has "failed status" "$md" "- status: failed"
has "blocker" "$md" "- blocker: build broke"
n=$(grep -c '^| 1.0.1b |' "$T/rebase/README.md")
[ "$n" = 1 ] || { echo "FAIL: README rows for 1.0.1b = $n"; failed=1; }
grep -q '^| 1.0.1b .*| failed |$' "$T/rebase/README.md" || { echo "FAIL: row not replaced with failed"; failed=1; }

# (f) no conflicts
cat >"$T/c.log" <<'EOF'
==> 2026-11-09 09:00:00 step: recon
recon: zen 1.0.1b -> 1.0.2b
recon: firefox 151.0 -> 152.0
<== step: recon exit=0 duration=60s
EOF
"$BASH" "$report" 1.0.2b "$T/c.log" ok || { echo "FAIL: clean run exit"; failed=1; }
has "clean row" "$T/rebase/README.md" "| 1.0.2b | 2026-11-09 | 152.0 | 0 | - | "
for sec in "## Conflicts" "## Conflicts by epic"; do
  body=$(awk -v s="$sec" '$0 == s { on = 1; next } /^## / { on = 0 } on && NF' "$T/rebase/1.0.2b.md")
  [ "$body" = none ] || { echo "FAIL: '$sec' is not none ($body)"; failed=1; }
done

# (g) errors
"$BASH" "$report" 1.0.3b "$T/missing.log" ok 2>/dev/null; rc=$?
[ "$rc" = 1 ] || { echo "FAIL: missing log exit $rc"; failed=1; }
"$BASH" "$report" 1.0.3b 2>"$T/err"; rc=$?
{ [ "$rc" = 2 ] && grep -q usage "$T/err"; } || { echo "FAIL: arg count exit $rc"; failed=1; }
"$BASH" "$report" 1.0.3b "$T/c.log" maybe 2>"$T/err"; rc=$?
{ [ "$rc" = 2 ] && grep -q usage "$T/err"; } || { echo "FAIL: bad status exit $rc"; failed=1; }

if [ "$failed" = 0 ]; then echo PASS; else echo FAILED; exit 1; fi
