#!/usr/bin/env bash
# Meta-Harness outer loop. Each iteration: propose 2 candidates, audit, evaluate on the
# search tasks (4 runs in parallel), rebuild scoreboard.md.
#
#   demo/meta_harness/loop.sh <first_iter> <last_iter>
#   EVAL=0 demo/meta_harness/loop.sh 1 1      # propose + audit only (dry run, no Luna runs)
#
# If both candidate harnesses of an iteration already exist (e.g. from a dry run), the
# proposal is reused and only evaluation runs. Env: PROPOSER_BUDGET (USD, default 8),
# PROPOSER_MAX_TURNS (default 200), EVAL (default 1), MODEL (passed to run_harness.sh).
set -euo pipefail

first=${1:?usage: loop.sh <first_iter> <last_iter>}; last=${2:?usage: loop.sh <first_iter> <last_iter>}
mh=$(cd "$(dirname "$0")" && pwd)
demo=$(cd "$mh/.." && pwd)
tasks=(ft-card-stalled-quiet-clock ft-entropy-sweep)
budget=${PROPOSER_BUDGET:-8}
max_turns=${PROPOSER_MAX_TURNS:-200}
mkdir -p "$mh/logs"
[[ -d $mh/candidates/h0 ]] || { echo "loop: run seed_h0.sh first" >&2; exit 1; }
"$mh/scoreboard.sh" > "$mh/scoreboard.md"

fingerprint() { # hash of every existing candidate file except the two new ones
  (cd "$mh" && find candidates -type f ! -path "candidates/$1/*" ! -path "candidates/$2/*" -print0 \
    | sort -z | xargs -0 shasum 2>/dev/null | shasum | cut -c1-16)
}

for i in $(seq "$first" "$last"); do
  a="i${i}a"; b="i${i}b"
  log="$mh/logs/iter$i.proposer.jsonl"
  echo "=== iteration $i ($a, $b) $(date '+%H:%M:%S')"

  if [[ -d $mh/candidates/$a/harness && -d $mh/candidates/$b/harness ]]; then
    echo "loop: reusing existing proposal for iteration $i"
  else
    before=$(fingerprint "$a" "$b")
    prompt="You are the proposer in iteration $i of a Meta-Harness search. Read SKILL.md in the current directory and follow it. Create exactly two new candidates: candidates/$a/ and candidates/$b/, each with a harness/ directory and a notes.md."
    ( cd "$mh" && claude --bare -p "$prompt" \
        --model claude-sonnet-5-5 \
        --tools "Read,Write,Edit,Glob,Grep" \
        --permission-mode dontAsk \
        --allowedTools "Read(./**)" "Glob" "Grep" "Write(./candidates/**)" "Edit(./candidates/**)" \
        --disallowedTools "Read(../private/**)" "Read(../../ai-evals/**)" "Read(../../sanity/**)" \
        --max-budget-usd "$budget" --max-turns "$max_turns" \
        --output-format stream-json --verbose > "$log" ) || echo "loop: proposer exited non-zero (see $log)"
    after=$(fingerprint "$a" "$b")
    [[ $before == "$after" ]] || echo "loop: WARNING proposer changed files outside $a/$b"
  fi

  # Stats and leak audit from the proposer log (tool inputs only)
  if [[ -f $log ]]; then
    {
      echo "iteration $i proposer"
      jq -c 'select(.type == "result") | {subtype, cost_usd: .total_cost_usd, turns: .num_turns}' "$log"
      echo "tool calls:"
      jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' "$log" | sort | uniq -c
      echo "distinct files read: $(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Read") | .input.file_path' "$log" | sort -u | wc -l | tr -d ' ')"
    } > "$mh/logs/iter$i.stats.txt"
    bad=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input | tostring
                 | select(test("private/|raw-runs|ai-evals|sanity/|checks\\.json|verifier\\.log|evidence\\.json"))' "$log" | wc -l | tr -d ' ')
    if [[ $bad != 0 ]]; then
      echo "loop: AUDIT FAILED iteration $i: $bad tool call(s) touched forbidden paths. Stopping." | tee -a "$mh/logs/iter$i.stats.txt"
      exit 3
    fi
    echo "audit: clean" >> "$mh/logs/iter$i.stats.txt"
    cat "$mh/logs/iter$i.stats.txt"
  fi

  for id in "$a" "$b"; do
    c="$mh/candidates/$id"
    [[ -d $c/harness ]] || { echo "loop: $id has no harness"; continue; }
    "$demo/tools/validate.sh" "$c/harness" > "$c/validation.txt" || true
    cat "$c/validation.txt"
  done

  if [[ ${EVAL:-1} == 1 ]]; then
    for id in "$a" "$b"; do
      c="$mh/candidates/$id"
      grep -q '^OK' "$c/validation.txt" 2>/dev/null || continue
      "$demo/tools/run_harness.sh" "$c/harness" "mh-$id" "$c/runs" "${tasks[@]}" > "$mh/logs/iter$i.$id.eval.log" 2>&1 &
    done
    wait || true
    cat "$mh"/logs/iter$i.*.eval.log 2>/dev/null | grep '^run_harness:' || true
  fi

  "$mh/scoreboard.sh" > "$mh/scoreboard.md"
  echo "=== iteration $i done $(date '+%H:%M:%S')"
done
cat "$mh/scoreboard.md"
