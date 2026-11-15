#!/usr/bin/env bash
# Run 2: local H0 reference rollouts, NREF per task, all in parallel (at most MAX_SANDBOXES at once).
# Same route, client and limits as every other run-2 rollout. Exported WITHOUT scores into
# $RUN_ROOT/baselines/h0/<task>/r<i>/; raw output (with scores) in demo/private/raw-runs/r2-h0-<task>-<i>/.
#
#   demo/harness2/refs.sh <task>...            # e.g. Phase 1: the three candidate varying tasks
#   NREF=3 demo/harness2/refs.sh ft-card-stalled-quiet-clock
#
# Resumable: a rollout that already has a record is skipped. Check Phase 1's gate with
# `demo/harness2/scores.sh --refs <task>...` (prints to the terminal only).
set -euo pipefail
h2=$(cd "$(dirname "$0")" && pwd -P)
. "$h2/../tools/run2_env.sh"
(( $# > 0 )) || { echo "usage: refs.sh <task>..." >&2; exit 1; }
NREF=${NREF:-3}
for t in "$@"; do [[ -f $evals/tasks/$t/instruction.md ]] || r2_refuse "unknown task $t"; done
pids=""
for t in "$@"; do
  mkdir -p "$R2_BASE/h0/$t"
  for i in $(seq 1 "$NREF"); do
    ( run_one "$demo/harnesses/h0" "r2-h0-$t-$i" "$R2_BASE/h0/$t/r$i" "$t" \
        && echo "refs.sh $(date '+%H:%M:%S') $t r$i: $(jq -c '{outcome, steps, duration_s}' "$R2_BASE/h0/$t/r$i/result.json")" \
        || echo "refs.sh $(date '+%H:%M:%S') $t r$i: NO RECORD (see $R2_BASE/h0/$t/r$i.eval.log)" ) | tee -a "$R2_LOGS/refs.log" &
    pids="$pids $!"
  done
done
for p in $pids; do wait "$p" || true; done
echo "refs.sh $(date '+%H:%M:%S') done: $*" | tee -a "$R2_LOGS/refs.log"
