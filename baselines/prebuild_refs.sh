#!/usr/bin/env bash
# Prebuilds Harness² references for tasks 2 and 3: 3 published H0 runs + 1 local H0 run.
P=ai-evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max
for t in ft-entropy-sweep ft-mysql-fulltext-search-foundation; do
  R=demo/harness2/work/$t/refs
  if [ -e demo/harness2/work/$t ]; then echo "$t already started, skipping"; continue; fi
  L=$(ls -d demo/private/raw-runs/h0-local/$t/*/*/ 2>/dev/null | head -1)
  if [ -z "$L" ]; then echo "$t: no local H0 run, skipping"; continue; fi
  mkdir -p $R && cp ai-evals/tasks/$t/instruction.md $R/task.md
  n=0
  for d in $(ls -d $P/${t}__*/ | head -3); do n=$((n+1)); demo/tools/export_run.sh "$d" $R/r$n --no-score; done
  demo/tools/export_run.sh "$L" $R/r$((n+1)) --no-score
  date '+%H:%M:%S' > $R/DONE
  echo "$t: $(ls $R | tr '\n' ' ')"
done
