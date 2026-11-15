#!/usr/bin/env bash
# Scores of the Harness² runs, FOR THE SLIDES ONLY. Prints to stdout; never redirect the
# output anywhere under demo/harness2/ (improver sessions read that tree, and Harness²
# must never see a score). Reads the raw lemans results in demo/private/raw-runs/.
#
#   demo/harness2/scores.sh [task ...]
set -euo pipefail
h2=$(cd "$(dirname "$0")" && pwd)
demo=$(cd "$h2/.." && pwd)
evals=$(cd "$demo/../ai-evals" && pwd)
published=${PUBLISHED:-$evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max}
[[ $# -gt 0 ]] || set -- ft-card-stalled-quiet-clock ft-entropy-sweep ft-mysql-fulltext-search-foundation
label() { # a function, not case inside $(...): bash 3.2 can't parse the latter
  case $1 in
    inv) echo "INV probe" ;;
    dom) echo "DOM probe" ;;
    final) echo "composed (result)" ;;
  esac
}
row() { jq -r --arg who "$2" '"| \(.task) | \($who) | \(.reward) | \(.credit // "–") | \(.outcome.name) | \(.usage.steps) | $\(.usage.cost_usd * 100 | round / 100) | \(.duration / 60 | round) min |"' "$1"; }
echo "| task | harness | reward | credit | outcome | steps | cost | duration |"
echo "|---|---|---|---|---|---|---|---|"
for t in "$@"; do
  for r in "$published/${t}__"*/result.json; do [[ -f $r ]] && row "$r" "H0 (published)"; done
  for s in inv dom final; do
    for r in "$demo/private/raw-runs/h2-$t-$s"/*/*/*/result.json; do
      [[ -f $r ]] && row "$r" "$(label "$s")"
    done
  done
done
