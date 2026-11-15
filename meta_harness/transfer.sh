#!/usr/bin/env bash
# Run 2, Meta-Harness side (rerun plan v1): run 1's winner i4b, deployed unchanged, K times on each
# run-2 task, plus REPEAT extra runs on ft-entropy-sweep to firm up run 1's entropy result.
# The harness is read from the sealed run-1 archive. Exported without scores into
# $RUN_ROOT/meta_harness/i4b/<task>/r<i>/; scores come from demo/harness2/scores.sh.
#
#   demo/meta_harness/transfer.sh [task...]    # default: the six run-2 stream tasks
#   K=3 REPEAT=3 demo/meta_harness/transfer.sh
set -euo pipefail
mh=$(cd "$(dirname "$0")" && pwd -P)
. "$mh/../tools/run2_env.sh"
harness="$demo/run1/meta_harness/candidates/i4b/harness"
[[ -d $harness ]] || r2_refuse "no sealed i4b harness at $harness (Phase 0 not done?)"
K=${K:-3}; REPEAT=${REPEAT:-3}
[[ $# -gt 0 ]] || set -- $(cat "$demo/harness2/stream-tasks.txt")
out="$RUN_ROOT/meta_harness/i4b"; mkdir -p "$out"
pids=""
for t in "$@"; do
  n=$K; [[ $t == ft-entropy-sweep ]] && n=$((K + REPEAT))
  mkdir -p "$out/$t"
  for i in $(seq 1 "$n"); do
    ( run_one "$harness" "r2-mh-i4b-$t-$i" "$out/$t/r$i" "$t" \
        && echo "transfer.sh $(date '+%H:%M:%S') $t r$i: $(jq -c '{outcome, steps, duration_s}' "$out/$t/r$i/result.json")" \
        || echo "transfer.sh $(date '+%H:%M:%S') $t r$i: NO RECORD" ) | tee -a "$R2_LOGS/transfer.log" &
    pids="$pids $!"
  done
done
for p in $pids; do wait "$p" || true; done
echo "transfer.sh $(date '+%H:%M:%S') done" | tee -a "$R2_LOGS/transfer.log"
