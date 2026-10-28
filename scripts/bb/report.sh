#!/usr/bin/env bash
# report.sh <Y> <log> <ok|failed> [<blocker>] — per-rebase report + summary row (ADR-0002 Решение 4).
# Reads only the log; never runs git. Exit 0 ok · 1 missing log · 2 usage.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() { echo "usage: report.sh <Y> <log> <ok|failed> [<blocker>]" >&2; exit 2; }

[ $# -ge 3 ] && [ $# -le 4 ] || usage
Y=$1 LOG=$2 STATUS=$3 BLOCKER=${4:-}
case "$STATUS" in ok|failed) ;; *) usage ;; esac
[ -f "$LOG" ] || { echo "report.sh: no such log: $LOG" >&2; exit 1; }

DOCS=${BB_REBASE_DOCS:-$BB_ROOT/docs/rebase}
mkdir -p "$DOCS"
OUT="$DOCS/$Y.md"
README="$DOCS/README.md"

# step-line parsing shared by both awk passes, so they cannot drift apart
STEPLIB='
function is_hdr() { return $0 ~ /^==> [0-9]+-[0-9]+-[0-9]+ [0-9:]+ step: / }
function is_ftr() { return $0 ~ /^<== step: / }
function val(f, prefix) { sub("^" prefix, "", f); return f }
'

# wall time: first header .. last header + its footer duration
span=$(awk "$STEPLIB"'
  is_hdr() { if (first == "") first = $2 " " $3; last = $2 " " $3; name = $5; dur = 0 }
  is_ftr() && $3 == name { d = val($5, "duration="); sub(/s$/, "", d); dur = d }
  END { print first "|" last "|" dur }
' "$LOG")
IFS='|' read -r t_first t_last t_dur <<<"$span"
hours=0
if [ -n "$t_first" ]; then
  e_first=$(date -j -f '%Y-%m-%d %H:%M:%S' "$t_first" +%s)
  e_last=$(date -j -f '%Y-%m-%d %H:%M:%S' "$t_last" +%s)
  hours=$(awk -v a="$e_first" -v b="$e_last" -v d="$t_dur" 'BEGIN { printf "%.1f", (b + d - a) / 3600 }')
fi

ROWFILE=$(mktemp)
tmp=$(mktemp)
trap 'rm -f "$ROWFILE" "$tmp"' EXIT

awk -v y="$Y" -v status="$STATUS" -v blocker="$BLOCKER" -v date="${t_first%% *}" -v hours="$hours" \
    -v out="$OUT" -v rowfile="$ROWFILE" "$STEPLIB"'
function kind_of(file) { return (file ~ /^src\/.*\.patch$/ && file !~ /^src\/bb\//) ? "zen-patch" : "git" }
function add(kind, epic, file) {
  nc++; ckind[nc] = kind; cepic[nc] = epic; cfile[nc] = file
  if (!(epic in seen)) { seen[epic] = 1; epics[++ne] = epic }
  cnt[epic, kind]++; tot[epic]++
}
is_hdr() { next }
is_ftr() { ns++; sname[ns] = $3; sexit[ns] = val($4, "exit="); sdur[ns] = val($5, "duration="); next }
/^recon: zen / { zen = $3 " -> " $5; next }
/^recon: firefox / { ff = $3 " -> " $5; fy = $5; next }
/^recon: upstream-commits / { upc = $3; next }
/^recon: toolchain-changed / { tc = (tc == "" ? "" : tc ", ") $3; next }
/^recon: expected-conflict / { ex[++nx] = $3 " (" $4 ")"; next }
/^conflict: git / { add(kind_of($3), $4, $3); next }
/^FAIL [^ ]+\/[^ ]+: / {
  id = $2; sub(/:$/, "", id); epic = id; sub(/\/.*/, "", epic); add("bb-patch", epic, id); next
}
/^smoke: / { sm[++nsm] = substr($0, 8); next }
END {
  for (i = 2; i <= ne; i++) {  # insertion sort of epics
    v = epics[i]; j = i - 1
    while (j >= 1 && epics[j] > v) { epics[j + 1] = epics[j]; j-- }
    epics[j + 1] = v
  }
  print "# Rebase " y > out
  print "" > out
  print "- status: " status > out
  if (status == "failed") print "- blocker: " blocker > out
  print "- date: " date > out
  print "- zen: " (zen == "" ? "-" : zen) > out
  print "- firefox: " (ff == "" ? "-" : ff) > out
  print "- upstream commits: " (upc == "" ? "-" : upc) > out
  print "- toolchain changed: " (tc == "" ? "none" : tc) > out
  print "- hours: " hours > out
  print "" > out
  print "## Steps\n" > out
  print "| step | exit | duration |\n|---|---|---|" > out
  for (i = 1; i <= ns; i++) print "| " sname[i] " | " sexit[i] " | " sdur[i] " |" > out
  print "\n## Conflicts\n" > out
  if (nc == 0) print "none" > out
  else {
    print "| kind | epic | file |\n|---|---|---|" > out
    for (i = 1; i <= nc; i++) print "| " ckind[i] " | " cepic[i] " | " cfile[i] " |" > out
  }
  print "\n## Conflicts by epic\n" > out
  if (nc == 0) print "none" > out
  else {
    print "| epic | git | bb-patch | zen-patch | total |\n|---|---|---|---|---|" > out
    for (i = 1; i <= ne; i++) {
      e = epics[i]
      print "| " e " | " cnt[e, "git"] + 0 " | " cnt[e, "bb-patch"] + 0 " | " cnt[e, "zen-patch"] + 0 " | " tot[e] " |" > out
    }
  }
  print "\n## Expected conflicts\n" > out
  if (nx == 0) print "none" > out
  for (i = 1; i <= nx; i++) print "- " ex[i] > out
  print "\n## Smoke\n" > out
  if (nsm == 0) print "not run" > out
  for (i = 1; i <= nsm; i++) print sm[i] > out

  byepic = ""
  for (i = 1; i <= ne; i++) byepic = byepic (i > 1 ? ", " : "") epics[i] ":" tot[epics[i]]
  print "| " y " | " date " | " (fy == "" ? "-" : fy) " | " nc + 0 " | " (byepic == "" ? "-" : byepic) " | " hours " | " status " |" > rowfile
}' "$LOG"

# upsert the README row keyed by "| <Y> |", else append after the last table line
[ -f "$README" ] || { echo "report.sh: missing $README" >&2; exit 1; }
ROW=$(cat "$ROWFILE") KEY="| $Y |" awk '
  BEGIN { row = ENVIRON["ROW"]; key = ENVIRON["KEY"] }
  { line[++n] = $0; if ($0 ~ /^\|/) last = n }
  END {
    for (i = 1; i <= n; i++) {
      if (index(line[i], key) == 1) { if (!done) print row; done = 1; continue }
      print line[i]
      if (i == last && !done) { print row; done = 1 }
    }
    if (!done) print row
  }' "$README" >"$tmp"
cat "$tmp" >"$README"
