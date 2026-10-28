# Rebase cost metric

Each row is one Zen rebase onto a new upstream tag, written by `scripts/bb/report.sh` from the rebase log; details live in `<tag>.md`.
`conflicts` counts three kinds: a git conflict during the rebase, a BB patch that did not apply, and a Zen patch hunk that had to be edited.
`by epic` splits that count per epic (`epic:n`), `hours` is wall time including human conflict work.
January checkpoint: if the hours and conflicts of the rebases so far are too high, we decide on the hard fork (ADR-0002).

| tag | date | firefox | conflicts | by epic | hours | status |
|---|---|---|---|---|---|---|
