#!/usr/bin/env bash
# Seeds meta_harness/candidates/h0 with H0 and its existing runs, so iteration 1 needs no H0 runs.
#
#   demo/meta_harness/seed_h0.sh [extra_trial_dir ...]
#
# Published runs (stock miniswen-installed, same model via OpenRouter) become runs/<task>__p<n>.
# H0 renders byte-identical to stock, so they are H0 runs. Extra trial dirs (e.g. the local
# sanity run of H0) become runs/<task>__local<n>.
set -euo pipefail

mh=$(cd "$(dirname "$0")" && pwd)
demo=$(cd "$mh/.." && pwd)
evals=$(cd "$demo/../ai-evals" && pwd)
published=${PUBLISHED:-$evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max}
tasks=(ft-card-stalled-quiet-clock ft-entropy-sweep)

c="$mh/candidates/h0"
rm -rf "$c"; mkdir -p "$c/runs"
cp -R "$demo/harnesses/h0" "$c/harness"
"$demo/tools/validate.sh" "$c/harness" > "$c/validation.txt"

for t in "${tasks[@]}"; do
  n=0
  for d in "$published/${t}__"*/; do
    [[ -f $d/result.json ]] || continue
    n=$((n + 1))
    "$demo/tools/export_run.sh" "$d" "$c/runs/${t}__p$n"
  done
  echo "seed_h0: $t: $n published trial(s)"
done

k=0
for d in "$@"; do
  k=$((k + 1))
  t=$(jq -r .task "$d/result.json")
  "$demo/tools/export_run.sh" "$d" "$c/runs/${t}__local$k"
  echo "seed_h0: $t: local trial $d"
done

cat > "$c/notes.md" <<'EOF'
# h0 (base harness)

Parent: none. Stock miniswen prompt split into the four always-on files; no memory, no skills.

Runs named `__p<n>` were recorded in October 2026 with the stock agent and the same model.
H0 renders the identical prompt, so they count as H0 runs. Runs named `__local<n>` used this
exact setup.
EOF
echo "seed_h0: done -> $c"
