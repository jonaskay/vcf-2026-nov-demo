#!/usr/bin/env bash
# Copies the improver-visible part of one lemans trial. Nothing else leaves the trial dir.
#
#   demo/tools/export_run.sh <trial_dir> <dest_dir> [--no-score]
#
# Writes exactly four files:
#   agent.patch      the agent's diff (empty file if the trial has none)
#   trajectory.json  compacted: per step the message, commands, outputs, exit codes, timestamp.
#                    agent.extra.agent_config is dropped: it always shows the STOCK template,
#                    even for an evolved harness, which would mislead an improver.
#   steps.tsv        one line per step: step, timestamp, exit codes, first 160 chars of command
#   result.json      task, outcome, steps, cost_usd, duration_s, plus reward and credit
#                    unless --no-score (Harness² editors never see ground truth)
set -euo pipefail

src=${1:?usage: export_run.sh <trial_dir> <dest_dir> [--no-score]}
dest=${2:?usage: export_run.sh <trial_dir> <dest_dir> [--no-score]}
score=1; [[ ${3:-} == --no-score ]] && score=0

[[ -f $src/result.json ]] || { echo "export_run: no result.json in $src" >&2; exit 1; }
rm -rf "$dest"; mkdir -p "$dest"

if [[ -f $src/agent.patch ]]; then cp "$src/agent.patch" "$dest/agent.patch"; else : > "$dest/agent.patch"; fi

if [[ -f $src/trajectory.json ]]; then
  jq '{
    steps: [ .steps[]? | {
      step: .step_id,
      source,
      t: .timestamp,
      message,
      commands: ([ .tool_calls[]?.arguments.command ] | if length == 0 then null else . end),
      results:  ([ .observation.results[]? | { exit: .extra.exit_code, output: .content } ]
                 | if length == 0 then null else . end)
    } | with_entries(select(.value != null)) ],
    final: (.final_metrics // {} | {
      steps: .total_steps, cost_usd: .total_cost_usd,
      prompt_tokens: .total_prompt_tokens, completion_tokens: .total_completion_tokens
    }),
    status: (.extra.status // null)
  }' "$src/trajectory.json" > "$dest/trajectory.json"

  jq -r '.steps[]? | [
    (.step_id | tostring),
    (.timestamp // ""),
    ([ .observation.results[]?.extra.exit_code | tostring ] | join(",")),
    ([ .tool_calls[]?.arguments.command ] | join(" ; ") | gsub("[\\t\\n\\r]+"; " ") | .[0:160])
  ] | @tsv' "$src/trajectory.json" > "$dest/steps.tsv"
else
  echo '{"steps": [], "note": "no trajectory recorded for this trial"}' > "$dest/trajectory.json"
  : > "$dest/steps.tsv"
fi

jq --argjson score "$score" '
  { task, outcome: .outcome.name, steps: .usage.steps, cost_usd: .usage.cost_usd, duration_s: .duration }
  + (if $score == 1 then { reward, credit } else {} end)
' "$src/result.json" > "$dest/result.json"
