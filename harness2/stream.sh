#!/usr/bin/env bash
# The Harness² RUN-2 stream (rerun plan v1, Phase 4): tasks one after another, because each reads
# the library the earlier ones left. Run 1's version is in demo/run1/scripts/stream.sh.
#
#   nohup demo/harness2/stream.sh > demo/run2/logs/stream.log 2>&1 &
#   demo/harness2/stream.sh ft-entropy-sweep          # a subset, in the given order
#
# Default order: harness2/stream-tasks.txt. Writes only under $RUN_ROOT (default demo/run2).
#
# - Resumes: a task with work/<task>/DONE is skipped; an unfinished task resumes from its last
#   finished stage. Stops on the first failing task (rerun to resume).
# - Gate after the first task (plan, Phase 4): if the reflector rated no edit helped, hurt or
#   no observed effect (all confounded, or no rows), the stream stops so you can look before
#   spending on the rest; rerunning goes on (CONTINUE_AFTER_GATE=1 skips the gate entirely).
# - Cost cap: before each task, stops if run 2's Luna + improver cost has reached COST_CAP
#   (default $150).
# - `touch $RUN_ROOT/STOP` ends the stream after the task in progress.
# - A lock refuses a second stream on the same RUN_ROOT.
set -euo pipefail
h2=$(cd "$(dirname "$0")" && pwd -P)
. "$h2/../tools/run2_env.sh"
take_lock "$R2_LOGS/stream"
cap=${COST_CAP:-150}
[[ $# -gt 0 ]] || set -- $(cat "$h2/stream-tasks.txt")
rm -f "$RUN_ROOT/STOP"
say() { echo "=== stream: $* $(date '+%a %H:%M:%S')"; }

nonconfounded() { # <task>: number of reflector verdicts other than confounded
  local e="$R2_WORK/$1/reflect/edits.md"
  [[ -f $e ]] || { echo 0; return; }
  { grep -iE '^verdict:' "$e" || true; } | { grep -viE 'confounded' || true; } | wc -l | tr -d ' '
}

first=1
for t in "$@"; do
  if [[ -f $R2_WORK/$t/DONE ]]; then say "$t already done, skipping"; first=0; continue; fi
  luna=$(r2_luna_cost); imp=$(r2_improver_cost)
  total=$(printf "%.2f" "$(echo "$luna + $imp" | bc)")
  say "$t starting (run-2 cost so far \$$total: Luna \$$luna, improver \$$imp; cap \$$cap)"
  if (( $(echo "$total >= $cap" | bc) )); then say "COST CAP reached; stopping before $t"; exit 4; fi
  rc=0; "$h2/task.sh" "$t" || rc=$?
  if [[ $rc != 0 ]]; then say "$t failed (exit $rc); stopping"; exit "$rc"; fi
  say "$t done"
  if [[ $first == 1 && ${CONTINUE_AFTER_GATE:-0} != 1 ]]; then
    n=$(nonconfounded "$t")
    if [[ $n == 0 ]]; then
      say "GATE: the reflector rated no edit of $t as helped, hurt or no observed effect. Look at $R2_WORK/$t/reflect/ before spending on the rest; rerun the stream to go on (the finished task is skipped)"
      exit 5
    fi
    say "gate passed: $n non-confounded verdict(s) on $t"
  fi
  first=0
  if [[ -f $RUN_ROOT/STOP ]]; then say "STOP file found; ending after $t"; rm -f "$RUN_ROOT/STOP"; exit 0; fi
done
say "all tasks done"
