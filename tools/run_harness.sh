#!/usr/bin/env bash
# Validates a harness, runs it once per task (all tasks in parallel, one lemans process each),
# then exports each trial into <out_dir>/<task>__<index>/ via export_run.sh.
#
#   demo/tools/run_harness.sh [--no-score] <harness_dir> <label> <out_dir> <task>...
#
# Raw lemans output (with checks.json, verifier.log, ...) goes to demo/private/raw-runs/<label>/
# and never into <out_dir>. Env: MODEL (default openai/gpt-6-luna#max).
#
# A trial that ends in agent_error, or leaves no result at all, is rerun once. Such failures
# are infrastructure noise, not a property of the harness: one local run out of ten was cut
# off when the provider's content filter rejected an ordinary prompt (invalid_prompt).
# The failed attempt is kept in demo/private/raw-runs/<label>.failed/.
set -euo pipefail

noscore=()
[[ ${1:-} == --no-score ]] && { noscore=(--no-score); shift; }
harness=${1:?usage: run_harness.sh [--no-score] <harness_dir> <label> <out_dir> <task>...}
label=${2:?label}; out=${3:?out_dir}; shift 3
(( $# > 0 )) || { echo "run_harness: no tasks given" >&2; exit 1; }

demo=$(cd "$(dirname "$0")/.." && pwd)
evals=$(cd "$demo/../ai-evals" && pwd)
model=${MODEL:-openai/gpt-6-luna#max}
harness=$(cd "$harness" && pwd)
mkdir -p "$out"; out=$(cd "$out" && pwd)
raw="$demo/private/raw-runs/$label"

"$demo/tools/validate.sh" "$harness" || { echo "run_harness: $label rejected by validate.sh" >&2; exit 2; }

run_task() { # <task>
  ( cd "$evals" && HARNESS_DIR="$harness" lemans -r "$demo/agents/harnessed_miniswen.rb" run \
      --backend docker --agent harnessed-miniswen --model "$model" \
      --task "$1" --runs-dir "$raw/$1" > "$raw/$1.log" 2>&1 )
}

rm -rf "$raw" "$raw.failed"; mkdir -p "$raw"
echo "run_harness: $label starting $# task(s) at $(date '+%H:%M:%S')"
for task in "$@"; do run_task "$task" & done
wait || true

retry=()
for task in "$@"; do
  r=$(ls "$raw/$task"/*/*/result.json 2>/dev/null | head -1 || true)
  outcome=missing
  [[ -n $r ]] && outcome=$(jq -r '.outcome.name // "unknown"' "$r")
  if [[ $outcome == agent_error || $outcome == missing ]]; then
    code=$( [[ -n $r ]] && jq -r '.outcome.detail // ""' "$r" | grep -o 'invalid_prompt\|rate_limit[a-z_]*\|timeout' | head -1 || true)
    echo "run_harness: $label $task: $outcome${code:+ ($code)}, retrying once at $(date '+%H:%M:%S')"
    mkdir -p "$raw.failed"
    mv "$raw/$task" "$raw.failed/$task" 2>/dev/null || true
    mv "$raw/$task.log" "$raw.failed/$task.log" 2>/dev/null || true
    retry+=("$task")
  fi
done
if (( ${#retry[@]} > 0 )); then
  for task in "${retry[@]}"; do run_task "$task" & done
  wait || true
fi

for r in "$raw"/*/*/*/result.json; do
  [[ -f $r ]] || continue
  trial=$(dirname "$r")
  name="$(jq -r .task "$r")__$(jq -r '.index // 1' "$r")"
  "$demo/tools/export_run.sh" "$trial" "$out/$name" ${noscore[@]+"${noscore[@]}"}
done

# Loader status per task; a missing line means stock prompts may have been used
for task in "$@"; do
  line=$(grep -h "harnessed-miniswen \[" "$raw/$task.log" 2>/dev/null | tail -1 || true)
  echo "run_harness: $label $task: ${line:-NO LOADER STATUS (check $raw/$task.log)}"
done
echo "run_harness: $label done at $(date '+%H:%M:%S')"
