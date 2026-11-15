#!/usr/bin/env bash
# The Harness² stream: tasks one after another, because each reads the library the earlier
# ones left. The library starts empty (delete library/ and work/ to restart from scratch).
#
#   nohup demo/harness2/stream.sh > demo/harness2/logs/stream.log 2>&1 &
#   demo/harness2/stream.sh ft-entropy-sweep          # a subset, in the given order
#
# `touch demo/harness2/STOP` ends the stream after the task in progress (e.g. to skip
# task 3 when it can't finish by Sunday morning). Stops on the first failing task;
# rerunning resumes it from its last finished stage.
set -euo pipefail
h2=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$h2/logs"
[[ $# -gt 0 ]] || set -- ft-card-stalled-quiet-clock ft-entropy-sweep ft-mysql-fulltext-search-foundation
rm -f "$h2/STOP"
for t in "$@"; do
  echo "=== stream: $t starting $(date '+%a %H:%M:%S')"
  rc=0; "$h2/task.sh" "$t" || rc=$?
  if [[ $rc != 0 ]]; then echo "=== stream: $t failed (exit $rc); stopping"; exit "$rc"; fi
  echo "=== stream: $t done $(date '+%a %H:%M:%S')"
  if [[ -f $h2/STOP ]]; then echo "=== stream: STOP file found; ending after $t"; rm -f "$h2/STOP"; exit 0; fi
done
echo "=== stream: all tasks done $(date '+%a %H:%M:%S')"
