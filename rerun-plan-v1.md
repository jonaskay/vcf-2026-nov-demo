# Rerun plan: giving Harness² a fair chance

Nov 15, 2026 · draft v1 · follows [the experiment report](Experiment%20report%20Meta-Harness%20and%20Harness²%20on%20Rails%20tasks.md) (run 1, Sat Nov 14)

## Goal

Run 1 showed that naive Harness² at k=1 cannot learn: every edit was confounded, the library stayed empty, and the composer judged against the wrong baseline. Run 2 reruns Harness² the way the paper intends (k>1, a selector, local references, evidence the improver actually reads) on tasks where Luna's behaviour varies, so the library has something to learn from.

Two constraints:

1. **Run 1 stays intact and is still the talk's first act.** Nothing in run 2 may overwrite run 1's files, and run 1's open items are closed before run 2 starts.
2. **Pre-register what counts as success**, and report run 2 whatever the result.

## Success criteria (fixed before the run)

Harness² "had a chance" if the mechanism works; it "succeeded" if outcomes also improve.

| Level | Criterion | Run 1 |
| --- | --- | --- |
| Mechanism | Reflector writes ≥ 2 library entries over the stream | 0 |
| Mechanism | ≥ 1 later task's editor reads and cites a library entry in its notes | n/a (empty) |
| Mechanism | ≥ 1 reflector verdict is `helped` or `hurt` (not `confounded`) | 0 |
| Outcome | Selected output passes at a rate ≥ local H0 on the stream overall | 0 vs 0 |
| Outcome | Strictly better than local H0 on ≥ 1 task, or better mean credit | no |

Scores are computed afterwards by a script Harness² never sees, exactly as in run 1.

## Phase 0: freeze run 1 (before any run-2 work)

The talk needs run 1's material exactly as reported. Do this first, in order.

1. **Close run 1's open items** (from the report's checklist) while the files are fresh:
   - Harness² task 3: composer decision and reflector outcome (`demo/harness2/work/ft-mysql-fulltext-search-foundation/compose/notes.md`, `logs/task.log`).
   - Meta-Harness iteration 3 and 4 proposer stats (`demo/meta_harness/logs/iter{3,4}.stats.txt`).
   - i3a's steps and time on its passing entropy run.
   - Exact end times of Harness² task 3, the i3a repeat and the i3a held-out run.
   - Exact total cost (all `result.json` + the failed trial's `agent.result.json` + every `*.stats.txt`).
   - Grep i4b's harness for task terms: `grep -rniE "entropy|postpone|stall|quiet|burst" demo/meta_harness/candidates/i4b/harness`.
   - Copy Harness² task 3 material to `demo/slides/raw/harness2-task3/`.
   - Update the report with the results and tick the checklist.
2. **Archive run 1** into `demo/run1/` (copy, not move, so existing paths in the report still resolve):
   - `meta_harness/` (candidates, logs, scoreboards), `harness2/` (work, library, logs, prompts, scripts), `baselines/`, `slides/raw/`, the report, `weekend-plan-v3.md`, `agent-tasks/`.
   - `demo/private/` stays where it is and is never copied into `run1/` or onto a slide.
3. **Seal it.** Write `demo/run1/MANIFEST.sha256` (`shasum -a 256` of every file), then `chmod -R a-w demo/run1`. Before the talk, `shasum -c` confirms nothing changed.
4. **Tag the scripts.** Copy `demo/harness2/{task.sh,stream.sh,scores.sh}` and `demo/meta_harness/{loop.sh,scoreboard.sh}` to `demo/run1/scripts/` so the run-1 code is preserved alongside its results.
5. **New output root.** Every run-2 script takes `RUN_ROOT=demo/run2` (default refuses to start if it would write under `demo/run1/` or into the run-1 paths). Run 2 gets its own `library/`, `work/`, `logs/` and `baselines/`.

Gate: manifest written, report's open items ticked, `RUN_ROOT` guard tested by trying to point it at `demo/run1` and seeing it refuse.

## Why Harness² failed in run 1, and what changes

| Run-1 failure | Cause | Run-2 change |
| --- | --- | --- |
| Every reflector verdict `confounded`, library empty | k=1: one rollout per candidate; editors changed several components at once | k=3 rollouts per candidate; each editor makes **one component edit** per proposal (single skill or single file), so a difference has one candidate cause |
| Composer compared against published runs (2–3× faster) | References were mostly published runs on a different API route; prompt said "3 base rollouts" while `r4` was local | References are **3 fresh local H0 runs** per task, same route and client as every other run; prompt counts generated from the directory |
| Composer and reflector ran 5–13 turns in 11–28 s | Large unread workspaces; Sonnet with low effort; nothing forced engagement | A script-built `evidence.md` per task (below); improver upgraded to Opus 5.5; post-session check that required files were opened, one retry otherwise |
| Reflector "did not open the trajectories" | Same | Reflector must quote at least one trajectory step per verdict row; validator rejects rows without a step reference |
| No way to choose between outputs | No selector at k=1 | Port the paper's answer-free selector (`ANSWER_FREE_SELECT`, `POOL_MIXED_SELECT` in `harness2/harness2/core/prompts.py`) to pick the deployed output from the pool |
| No behavioural variance to learn from | All three tasks were 0/3 for Luna; every run failed the same way | Stream includes tasks where Luna passes sometimes (published 1/3–2/3) |
| Shared-mistake "facts" from failing base runs | DOM editor turned patches of 0-scoring runs into facts | DOM editor may record a fact only if seen in the repo itself (file + line), not only in a patch |

What stays from run 1 (so the comparison is clean): executor Luna `#max` via OpenAI direct, lemans 1.6.0, miniswen + `harnessed-miniswen`, text-only harness format, H0, all leak controls (allowlist export, `validate.sh`, path audits, score guard, `leak_check.sh`), 90 min / 400 steps limits.

## Harness² run-2 loop (per task)

```
refs:     H0 × 3                      (local, prebuilt for all tasks up front)
propose:  INV editor, DOM editor      (one component edit each; library read via editors only)
probe:    INV × 3, DOM × 3
compose:  composer reads evidence.md + candidates → successor
execute:  composed × 3
select:   selector picks one output from the anonymous pool
          (3 H0 + 6 probes + 3 composed = 12 outputs, ids shuffled)
reflect:  edit table with helped / hurt / no observed effect / confounded → lesson or NO_ENTRY
```

The task's result is the **selected output**. We also score every rollout afterwards, so the talk can show the pass rate of each arm (H0, INV, DOM, composed) and whether the selector picked well.

**`evidence.md`** (new, `demo/harness2/evidence.sh`, no scores): one table row per rollout in the workspace with arm, steps, minutes, outcome (`completed`/`timeout`), files touched, test commands run and their last exit code, whether the agent ran the full suite, and the step of the first edit. Plus per arm: median steps/time and which harness files the agent `cat`-ed. This replaces "read 12 trajectory directories" with a page the composer cannot miss, while trajectories stay available for detail.

**Engagement checks** (in `task.sh`, from the session's tool-call log, which we already audit for leaks): composer must open `evidence.md` and ≥ 2 trajectories from different arms; reflector must open ≥ 1 trajectory per arm it rates. On a miss: one retry with the miss stated, then proceed and log it (we report the miss rather than hide it).

**Budgets.** Editors $3, composer $6, selector $4, reflector $4 per session, `--max-turns` 60. Run 1 never came close to its caps, so these are ceilings, not targets.

**Improver.** Opus 5.5 for all Harness² sessions. This is a second change on top of k, so the talk must say run 2 differs from run 1 in both. Optional ablation if budget allows: rerun one task's compose/select/reflect with Sonnet 5.5 on the same rollouts (no new Luna runs) to separate the two.

## Task stream

Six tasks, chosen from the published Oct 2026 Luna results (3 runs each, OpenRouter route):

| Order | Task | Published Luna | Why it's here |
| --- | --- | --- | --- |
| 1 | ft-local-time-human-clock | 2/3, credit 0.50 | Varies: contrasts between rollouts carry signal; seeds the library |
| 2 | ft-notification-bundle-window-overlap | 1/3, credit 0.23 | Varies; time-window logic, related to the card task |
| 3 | ft-saas-billing | 1/3, credit 0.33 | Varies; different domain, tests whether lessons stay general |
| 4 | ft-card-stalled-quiet-clock | 0/3 | Run-1 task; now arrives with a library |
| 5 | ft-entropy-sweep | 0/3 | Run-1 task; Meta-Harness solved it with scores; can Harness² without? |
| 6 | ft-mysql-fulltext-search-foundation | 0/3 | Run-1 task and Meta-Harness held-out task |

The varying tasks go first so the library has a chance to fill before the run-1 tasks, which gives the talk a direct "same task, run 1 vs run 2" comparison on tasks 4–6.

**Gate before committing to this list (Phase 1):** published pass rates came from a different route, and run 1 showed local runs are 2–3× slower. Run local H0 × 3 on tasks 1–3 first. If a task is 0/3 locally, swap it for the next partial-pass candidate or a 3/3-published task that is ≤ 2/3 locally (candidates: ft-card-reactions, ft-board-publish-unpublish-public-boundary, ft-activity-feed-api). A stream of only 0/3 tasks would repeat run 1's problem.

## Meta-Harness in run 2 (cheap, for the side-by-side)

Not a full rerun; two small additions so the talk can compare both methods on the same tasks.

1. **Transfer test of the run-1 winner:** i4b × 3 on each of the six run-2 tasks, deployed unchanged (18 runs). On tasks 1–3 this is genuinely held-out; on tasks 4–5 it was searched on.
2. **Repeat i4b on entropy × 3** to firm up "3 of 4" from run 1 (3 runs).

A full Meta-Harness rerun with 3 runs per candidate and a proper held-out set stays in the report's "fuller version" table; it is out of scope here.

## Run counts, cost and time

| Item | Luna runs | Notes |
| --- | --- | --- |
| Local H0 refs, 6 tasks × 3 | 18 | Reuse run 1's local H0 (card, entropy, mysql) as a 4th data point only; not as a ref |
| Harness² probes, 6 × 2 × 3 | 36 | |
| Harness² composed, 6 × 3 | 18 | |
| Meta-Harness i4b transfer + repeat | 21 | |
| **Total** | **93** | |

- **Luna cost:** run 1 averaged $0.35–0.95 per local run → about **$35–85**.
- **Improver cost:** Opus 5.5, ~5 sessions per task with higher budgets; expect **$20–60** for the stream. Hard cap: stop and review at $150 total for run 2.
- **Wall clock:** up to 8 sandboxes at once (run 1's tested limit). Refs and Meta-Harness transfer runs go up front in parallel (~2–3 h). The stream is sequential because of the library: per task ≈ probes (≤ 90 min) + composed (≤ 90 min) + sessions (~15 min) → **6–18 h** for six tasks. Plan it overnight, starting Friday evening, with the meetup material built Saturday/Sunday.

## Schedule

| Phase | What | Gate to continue |
| --- | --- | --- |
| 0 | Close run-1 open items; archive and seal `demo/run1/`; `RUN_ROOT` guard | Manifest written; guard refuses run-1 paths |
| 1 | Local H0 × 3 on candidate tasks 1–3 | ≥ 2 of the 3 vary locally (some pass or credit > 0); else swap tasks |
| 2 | Implement changes: k=3 in `task.sh`, single-component editor rule in prompts, `evidence.sh`, selector session, engagement checks, reflector step-reference validator | Dry run on task 1 with **existing H0 refs only** (no probes): editors, composer and selector run, read the required files, leak checks pass |
| 3 | Prebuild refs for tasks 4–6 + Meta-Harness transfer runs, in parallel | All refs `completed` or `timeout`, none `agent_error` after the one rerun |
| 4 | Harness² stream, tasks 1–6 | Check after task 1: did the reflector rate any edit non-`confounded`? If not, stop and look before spending on 2–6 |
| 5 | Score everything (`scores.sh` + per-arm pass rates); write run-2 report in the same format as run 1 | Success table filled, whatever the outcome |

## How run 2 fits into the talk

Run 1 stays the main story: it is the honest naive result and its lessons table predicted most of run 2's design. Run 2 becomes the answer to "what did you change, and did it help?".

| Talk part | Change |
| --- | --- |
| 4. Harness² | Keep run 1's card-task walk-through and the empty library as the punchline of the naive version |
| new 4b. Harness² done properly (4 min) | k=3 loop diagram; one library entry and the evidence behind it; selector pick vs. per-arm pass rates; tasks 4–6 run 1 vs run 2 |
| 5. Side by side | Add the i4b transfer row on run-2 tasks next to Harness²'s selected outputs |
| 6. Lessons | Mark which lessons-table rows were tested in run 2 and what happened |

Take minutes from part 3 (Meta-Harness, 8 → 6) and part 2 (setup, 4 → 3) to keep 30 minutes. All run-1 numbers on slides come from `demo/run1/`; all run-2 numbers from `demo/run2/`; every slide says which run it shows.

## Risks

- **Run 2 still scores 0 everywhere.** Then the success table shows whether the mechanism worked (library entries, non-confounded verdicts) even without outcomes; that is still a talk result. Phase 1's gate reduces the chance.
- **Two changes at once (k and improver).** Stated on the slide; the optional Sonnet ablation separates them on one task.
- **Library overfitting to tasks.** Same risk Meta-Harness showed: run the run-1 task-term grep on every library entry, and `leak_check.sh` as before.
- **Selector picks by length or elaborateness.** Anonymous shuffled pool with H0 outputs included, as in the paper; report how often it picked H0.
- **Overnight failures.** `run_harness.sh` already reruns `agent_error` once; `stream.sh` must resume from the last finished task rather than restart.
- **Content filter again.** Same retry; count and report occurrences.

## Implementation status (Nov 15)

- **Phase 0: done.** Run 1's open items are closed in the report (with an addendum: iteration 4 was evaluated twice, so the i3a lineage passed entropy 4 of 6, not 3 of 4, and i4b 1 of 2). Exact run-1 total: $11.64. `demo/run1/` is copied, `MANIFEST.sha256` written (986 files), made read-only; run-1 scripts are in `demo/run1/scripts/`. The `RUN_ROOT` guard refuses `run1`, the run-1 trees and their ancestors. Also new: `run_harness.sh` refuses run-1 labels, and run-1 raw dirs in `demo/private/raw-runs/` are read-only.
- **Phase 2: implemented and plumbing-tested** with a stub improver and runner (no cost). See [run2/README.md](run2/README.md) for commands, layout and the decisions this plan left open.
- **Not started (each needs Luna runs or Opus sessions):** Phase 1 (`harness2/refs.sh` on tasks 1–3, then `scores.sh --refs`), the Phase 2 dry-run gate on task 1, Phases 3–5.
