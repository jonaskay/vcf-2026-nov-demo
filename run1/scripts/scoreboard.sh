#!/usr/bin/env bash
# Prints a markdown scoreboard of every candidate, best first.
# Order: mean reward, then mean credit (partial score), then cost per pass, then steps.
# Means are per task first, then across tasks, so h0's extra trials don't dominate.
#
#   demo/meta_harness/scoreboard.sh > demo/meta_harness/scoreboard.md
set -euo pipefail
mh=$(cd "$(dirname "$0")" && pwd)

rows=$(
  for c in "$mh"/candidates/*/; do
    id=$(basename "$c")
    status=ok
    grep -q '^REJECT' "$c/validation.txt" 2>/dev/null && status=rejected
    set -- "$c"runs/*/result.json
    if [[ -f $1 ]]; then
      jq -s --arg id "$id" --arg status "$status" '
        def mean: if length == 0 then 0 else add / length end;
        group_by(.task) | map({
          task: (.[0].task | sub("^ft-"; "")),
          n: length,
          r: (map(.reward // 0) | mean),
          c: (map(.credit // 0) | mean),
          cost: (map(.cost_usd // 0) | mean),
          steps: (map(.steps // 0) | mean),
          out: (map(.outcome) | group_by(.) | map("\(.[0])×\(length)") | join(" "))
        }) as $t
        | { id: $id, status: $status,
            reward: ($t | map(.r) | mean), credit: ($t | map(.c) | mean),
            cost: ($t | map(.cost) | add), steps: ($t | map(.steps) | mean),
            detail: ($t | map("\(.task): r=\(.r * 100 | round / 100) c=\(.c * 100 | round / 100) n=\(.n) \(.out)") | join("<br>")) }
      ' "$@"
    else
      jq -n --arg id "$id" --arg status "$status" \
        '{id: $id, status: (if $status == "ok" then "no runs" else $status end), reward: null, credit: null, cost: null, steps: null, detail: ""}'
    fi
  done
)

echo "# Scoreboard"
echo
echo "Updated $(date '+%Y-%m-%d %H:%M'). Sorted by mean reward, then mean credit, then cost per pass over the search set, then steps."
echo
echo "| rank | candidate | status | mean reward | mean credit | cost/pass | mean steps | per task |"
echo "|---|---|---|---|---|---|---|---|"
echo "$rows" | jq -rs '
  def r2: if . == null then "–" else (. * 100 | round / 100 | tostring) end;
  sort_by([ -(.reward // -1), -(.credit // -1), (.cost // 1e9), (.steps // 1e9) ])
  | to_entries[]
  | "| \(.key + 1) | \(.value.id) | \(.value.status) | \(.value.reward | r2) | \(.value.credit | r2) | \(if .value.cost == null then "–" else "$" + (.value.cost | r2) end) | \(.value.steps | if . == null then "–" else round | tostring end) | \(.value.detail) |"'
