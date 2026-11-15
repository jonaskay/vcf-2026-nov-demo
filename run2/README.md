# Run 2: runbook

Implements [rerun-plan-v1.md](../rerun-plan-v1.md). Everything run 2 writes lives under this
directory (`RUN_ROOT`, default `demo/run2`); run 1 is sealed in `demo/run1/`.

## Layout

| Path | What |
| --- | --- |
| `baselines/h0/<task>/r<i>/` | local H0 references (no scores), from `harness2/refs.sh` |
| `work/<task>/` | one Harness² task: `refs/`, `inv/`, `dom/`, `probe_{inv,dom}/r<i>/`, `compose/`, `final/`, `select/`, `reflect/`, `logs/`, `DONE` |
| `work/<task>/select.map.tsv` | anonymous id → arm, run, raw label (outside every session dir) |
| `work/<task>/logs/engagement.txt` | every engagement miss and retry (reported, not hidden) |
| `library/` | run 2's library (starts empty) |
| `meta_harness/i4b/<task>/r<i>/` | i4b transfer runs (no scores) |
| `logs/` | `stream.log`, `refs.log`, `transfer.log`, `library-task-terms.txt` |

Raw lemans output (with scores) goes to `demo/private/raw-runs/r2-*/`. Only `harness2/scores.sh`
reads it, and only to stdout.

## Commands, by phase

```sh
cd vcf-nov-2026-talk/demo

# Phase 0 check (any time, and before the talk): run 1 unchanged
(cd run1 && shasum -a 256 -c MANIFEST.sha256 --quiet && echo "run 1 intact")

# Phase 1: local H0 x 3 on candidate tasks 1-3 (9 Luna runs, ~1.5 h), then the gate
harness2/refs.sh ft-local-time-human-clock ft-notification-bundle-window-overlap ft-saas-billing
harness2/scores.sh --refs ft-local-time-human-clock ft-notification-bundle-window-overlap ft-saas-billing
#   if a task is 0/3 locally: try ft-card-reactions, ft-board-publish-unpublish-public-boundary,
#   ft-activity-feed-api the same way, and edit harness2/stream-tasks.txt

# Phase 2 gate: dry run on task 1 with the existing refs only (no Luna runs; Opus sessions)
DRY=1 harness2/task.sh ft-local-time-human-clock
#   check work/<task>/logs/: *.stats.txt (turns, files read, audit), *.engagement.txt, engagement.txt

# Phase 3: refs for tasks 4-6 + Meta-Harness transfer (30 Luna runs: 9 refs + 21 transfer; max 8 at once)
harness2/refs.sh ft-card-stalled-quiet-clock ft-entropy-sweep ft-mysql-fulltext-search-foundation &
meta_harness/transfer.sh &
wait

# Phase 4: the stream, overnight (stops after task 1 if every verdict is confounded; rerun to go on)
nohup harness2/stream.sh > run2/logs/stream.log 2>&1 &

# Phase 5: scores, per-arm pass rates, selector, success table (terminal only)
harness2/scores.sh
```

`touch run2/STOP` ends the stream after the current task. `COST_CAP` (default 150) is checked
before each task against run 2's Luna + improver spend. A second stream or task on the same
directory is refused by a lock.

## What changed from run 1 (code)

| Plan item | Where |
| --- | --- |
| `RUN_ROOT` guard (refuses run 1, the shared trees, and their ancestors) | `tools/run2_env.sh` |
| Run-1 raw labels can never be reused (run_harness `rm -rf`s its label dir); run-1 raw dirs read-only | `tools/run_harness.sh`, `private/raw-runs/.run1-labels` |
| k=3 probes, 3 local H0 refs, 3 composed rollouts | `harness2/task.sh` (`K`, `NREF`, `KFINAL`) |
| One component per editor proposal (validator + retry + fallback) | `harness2/r2.py single-component`, editor prompts |
| DOM facts only from the repo (file + line), not from patches | editor prompts (applied to INV too: it has the same facts section) |
| `evidence.md` per session | `harness2/r2.py evidence` |
| Engagement checks with one retry, misses logged | `harness2/r2.py engagement`, `task.sh` `engaged`/`edit_stage` |
| Reflector step references (validator + retry) | `harness2/r2.py edits-check`, reflector prompt |
| Answer-free selector over the anonymous shuffled pool | `harness2/prompts/selector.md`, `task.sh` stage 6 |
| Improver Opus 5.5; budgets 3/6/4/4; `--max-turns 60` | `task.sh` defaults |
| Per-arm scores and the success table | `harness2/scores.sh` |
| Stream: resume, task-1 gate, cost cap, lock | `harness2/stream.sh` |
| i4b transfer (3 per task) + 3 extra entropy repeats | `meta_harness/transfer.sh` |

Run 1's scripts are preserved in `demo/run1/scripts/` (and in git at `e033663`).

## Decisions the plan left open

- **Selector has no `source/`.** The paper's selector checks claims against the source material; here
  the Fizzy repository exists only inside the sandbox image, so the selector judges each patch against
  the request and the code its own context lines show. Stated in its prompt.
- **Composer gets no library** ("library read via editors only"); the reflector keeps it so it doesn't
  repeat a lesson, as in the paper.
- **Composed = base or = a candidate:** not rerun; that set is its evidence, and the pool is deduplicated.
  Saves up to 3 Luna runs per task, and the run count drops below 93.
- **Engagement counts both sessions** when there is a retry. The selector must open every candidate
  (an extra check, same retry rule).
- **Editors also get `evidence.md`** (base rollouts only); it carries no scores.
- **Library overfitting check** is report-only: run 1's task-term grep over each new entry's harness and
  lesson, into `logs/library-task-terms.txt`.

## Tested so far

Plumbing only, with a stub `claude` and a stub runner replaying run-1 exports, in a scratch `RUN_ROOT`
(no Luna runs, no improver cost): dry run; full task (probes, compose, execute reuse, select, reflect,
library entry); a multi-component proposal rejected then fixed on retry; a composer that skipped
`evidence.md` and trajectories retried; a reflector row without a step reference retried; stream gate,
resume, cost cap and lock. `RUN_ROOT` pointed at `run1`, `run1/meta_harness`, `harness2`, `baselines`,
`demo` and its parent: all refused. `run_harness.sh` refuses a run-1 label.
