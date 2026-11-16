# Experiment report: Harness² run 2 on Rails tasks

Nov 16, 2026 · @Joonas · **placeholder: sections marked _TBD_ are filled in after step 5 of the [cookbook](COOKBOOK.md)**

## Summary

_TBD after the stream and `scores.sh`._ One paragraph: what ran, the success-table outcome (mechanism and outcome levels), and the headline numbers.

This report covers run 2 only. Run 1 is in [`run1/Experiment report Meta-Harness and Harness² on Rails tasks.md`](../run1/Experiment%20report%20Meta-Harness%20and%20Harness²%20on%20Rails%20tasks.md) and stays sealed. Run 2 follows the pre-registered plan in [`rerun-plan-v1.md`](../rerun-plan-v1.md). Every slide based on this report says that it shows run 2.

Headline findings for the talk:

1. _TBD_
2. _TBD_
3. _TBD_

## Framing and setup

Run 2 reruns Harness² the way the paper intends: k=3, a selector, local references, and evidence the improver has to read. It runs on a stream that starts with tasks where Luna's behaviour varies. A small Meta-Harness side runs run 1's winner i4b unchanged on the same stream.

**Setup differences from run 1.** There are two changes in the improver setup, so any difference from run 1 can come from either one. Say both on the slides.

| Part | Run 1 | Run 2 |
| --- | --- | --- |
| Rollouts per candidate | k=1 | **k=3** (refs, probes and composed runs: `NREF`/`K`/`KFINAL` = 3/3/3) |
| Improver | Claude Sonnet 5.5 | **Claude Opus 5.5** |
| References | 3 published runs + 1 local | 3 fresh local H0 runs per task |
| Editor scope | Several components per proposal | One component per proposal (`single-component` check) |
| Evidence | Raw workspace | Script-built `evidence.md` per task, plus engagement checks with one retry |
| Selector | None | Answer-free selector over the anonymous, shuffled pool |
| Session budgets | $3–4 | Editor $3, composer $6, selector $4, reflector $4; `MAX_TURNS` 60 |
| Stream | card, entropy, mysql (all 0/3 for Luna) | 3 varying tasks first, then run 1's three |
| Cost cap | none | `COST_CAP` $150 |

Unchanged from run 1: the executor (`openai/gpt-6-luna#max` via OpenAI direct), lemans 1.6.0 on the same Mac, the text-only harness format, H0, and the leakage controls (allowlist export, `validate.sh`, path audit, score guard, `leak_check.sh`).

**Stream** (`harness2/stream-tasks.txt`):

| # | Task | Why it's in the stream |
| --- | --- | --- |
| 1 | ft-local-time-human-clock | varying (passed the step-1 task gate) |
| 2 | ft-notification-bundle-window-overlap | varying |
| 3 | ft-card-reactions | varying; replaced ft-saas-billing (see setup findings) |
| 4 | ft-card-stalled-quiet-clock | run 1 task 1 |
| 5 | ft-entropy-sweep | run 1 task 2 |
| 6 | ft-mysql-fulltext-search-foundation | run 1 task 3 |

## Setup findings

**Task gate (step 1).** _TBD: the local H0 results per candidate task and the gate line._

**ft-saas-billing was dropped because it can't run on arm64**, not because of its score. Its Dockerfile pins a single-platform amd64 base image. Under emulation on the arm64 Mac, the agent's jail never starts (`unshare: pidfd_open failed: Function not implemented`), so all 6 attempts ended `agent_error` in under 2 s. Don't count it as a task-gate failure. Its raw records stay in `private/raw-runs/r2-h0-ft-saas-billing-*`. Details are in [STEP1-FOLLOWUPS.md](STEP1-FOLLOWUPS.md).

**Improver sessions never had Glob or Grep, in run 1 or run 2.** `task.sh` passes `--tools "Read,Glob,Grep"` (plus `Edit,Write` for editors), but the `init` record of every session (Claude Code 2.1.325) lists only `["Read"]`, or `["Edit","Read"]` for editors and the composer. Run 1's logs show the same lists. So run 1's setup table ("tools Read/Write/Edit/Glob/Grep only") overstates what the sessions had. No session could list a folder or search; they could only open paths they were given. Editors created new files with Edit.

**The dry run found a selector bug, which was fixed before the stream** (Nov 16, 08:36–08:52). The first selector session couldn't see any candidate: the prompt only says `context/candidates/<id>.patch`, and without Glob it can't list the folder. It spent 18 turns guessing names (`a.patch`, `1.patch`, `cand1.patch`, …) and declined to choose. The automatic retry worked only because the miss message happened to name the files. Fix: `task.sh` now appends the list of candidate files to the selector's prompt. After the fix, the selector opened the task and all 3 patches in 5 turns, chose without a retry, and had no engagement misses.

**Dry run on task 1, otherwise as intended.** Every audit came back clean and `leak_check` said `CLEAN`. Each editor changed one component: INV changed `tool_guidance.md`, and DOM added the `skills/time-display` skill with its trigger line in `system.md`. The composer read `evidence.md` and all 3 base trajectories. Sessions ran 21–31 turns, against 12–13 for run 1's composer. Total cost was $3.73, plus about $0.78 for the rerun after the fix.

## Harness²

**How it ran.** _TBD: anything that differed from the cookbook (restarts, gates, engagement retries)._

**Per-arm results** (from `scores.sh` section 1):

| Task | H0 refs (3) | Run 1 local H0 | INV probes (3) | DOM probes (3) | Composed (3) | Selected output | i4b transfer (3) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ft-local-time-human-clock | _TBD_ | – | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| ft-notification-bundle-window-overlap | _TBD_ | – | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| ft-card-reactions | _TBD_ | – | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| ft-card-stalled-quiet-clock | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| ft-entropy-sweep | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ (+3) |
| ft-mysql-fulltext-search-foundation | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ |

**Pass rate per arm over the stream** (`scores.sh` section 2): _TBD_

**What the editors and composer did, per task.** _TBD: one row per task (INV change, DOM change, what the composer kept, whether the composed runs were skipped)._

| Task | INV edit | DOM edit | Composer kept | Composed runs |
| --- | --- | --- | --- | --- |
| _TBD_ | | | | |

## Pre-registered success table

Fixed before the run in `rerun-plan-v1.md`. Filled in whatever the outcome.

| Level | Criterion | Run 1 | Run 2 |
| --- | --- | --- | --- |
| Mechanism | Reflector writes ≥ 2 library entries over the stream | 0 | _TBD_ |
| Mechanism | ≥ 1 later task's editor reads and cites a library entry in its notes | n/a (empty) | _TBD_ |
| Mechanism | ≥ 1 reflector verdict is `helped` or `hurt` (not `confounded`) | 0 | _TBD_ |
| Outcome | Selected output passes at a rate ≥ local H0 on the stream overall | 0 vs 0 | _TBD_ |
| Outcome | Strictly better than local H0 on ≥ 1 task, or better mean credit | no | _TBD_ |

## The selector

_TBD from `scores.sh` section 3: what it picked per task, whether a passing output was in the pool, and how often it picked H0. Compare its picks against the per-arm pass rates._

| Task | Pool size | Picked (arm, run) | Passing output in pool? | Pick passed? |
| --- | --- | --- | --- | --- |
| _TBD_ | | | | |

**Caveat: the selector's pick wasn't stable in the dry run.** On task 1's three H0 patches, the two dry-run selections picked different runs. The first, which got the candidate list only through the retry message, chose base r3 and rejected r2 for renaming `bridge_share_card_description` to `bridge_share_card_details`. The second, after the fix, chose r2, flagged the same rename as its one deviation, and rejected r1 and r3 on other grounds. The ids are reshuffled for each selection, and both runs used the same model and the same three patches. One dry run with only H0 candidates can't measure stability. Still, it suggests that picks between near-identical candidates are noisy, so read the selector's picks in the stream as single draws, not as a ranking. _TBD: whether the stream shows the same pattern, for example close calls decided on small deviations._

## The library

_TBD: number of entries, and one entry with the evidence behind it (the reflector's edit table rows, with the trajectory steps it quoted)._

**Overfitting check** (`run2/logs/library-task-terms.txt`): _TBD_

## Run 1 vs run 2 on card, entropy and mysql

| Task | Run 1 local H0 | Run 1 Harness² composed (k=1) | Run 2 H0 refs (3) | Run 2 selected output |
| --- | --- | --- | --- | --- |
| ft-card-stalled-quiet-clock | 0, timeout (149 steps, 90 min) | 0, timeout | _TBD_ | _TBD_ |
| ft-entropy-sweep | 0 (125 steps, 41 min) | 0 | _TBD_ | _TBD_ |
| ft-mysql-fulltext-search-foundation | 0 (66 steps, 23 min) | 0 | _TBD_ | _TBD_ |

## Meta-Harness side: i4b transfer

Run 1's winner i4b, unchanged, from the sealed copy in `run1/`: 3 runs on each stream task, plus 3 extra on entropy (21 runs).

_TBD: per-task results; whether its entropy pass rate from run 1 holds up over 6 runs; whether anything transferred to the other tasks._

## Costs

| Item | Cost |
| --- | --- |
| Luna rollouts (refs, probes, composed, transfer) | _TBD_ |
| Improver sessions (Opus 5.5) | _TBD_ |
| Dry run on task 1 (incl. the rerun after the selector fix) | about $4.51 |
| **Total** | _TBD_ |

## Lessons and caveats

_TBD._ Caveats to keep on the slides:

- Run 2 changes k and the improver model at the same time. _TBD: whether the optional Sonnet ablation was run, and what it showed for the selector and reflector._
- k=3 is still small: a single flip changes a task's pass rate by 33 points.
- The selector's pick between near-identical candidates was not stable in the dry run (see "The selector").
- Sessions had only Read (and Edit), not Glob/Grep, in both runs.
- Tasks 4–6 are the same tasks as run 1, so they aren't held out for anyone.
- ft-saas-billing was dropped for an arm64 incompatibility, not for its score.

## Timeline (Mon Nov 16, EET)

| Time | Event |
| --- | --- |
| _TBD_ | Stream finished |
| _TBD_ | Stream started |
| _TBD_ | Refs for tasks 4–6 and the i4b transfer done |
| 08:52 | Dry run rerun after the selector fix: selector chose without a retry |
| 08:41 | Dry run on task 1 done; selector needed the retry to see the candidates |
| 08:36 | Dry run on task 1 started |
| 08:35 | Local H0 candidate tasks committed (`54ab3fa`) |
| _TBD_ | Step 1: local H0 on candidate tasks, ft-saas-billing dropped, task gate |

## Artifact index

Paths are relative to `demo/`. Nothing from `private/` goes on a slide.

| Material | Where it is |
| --- | --- |
| Scores and the success table | `slides/raw/run2/scores.md` |
| Library | `run2/library/`, index copied to `slides/raw/run2/library-index.md` |
| Per-task stage log | `run2/work/<task>/logs/task.log` |
| Editor and composer notes | `run2/work/<task>/{inv,dom,compose}/notes.md` |
| Reflector edit tables | `run2/work/<task>/reflect/edits.md` |
| Session stats and engagement | `run2/work/<task>/logs/*.stats.txt`, `*.engagement.txt`, `engagement.txt` |
| Stream log (spend per task) | `run2/logs/stream.log` |
| Refs and transfer logs | `run2/logs/refs.log`, `run2/logs/transfer.log` |
| Dry run on task 1 | `run2/work/ft-local-time-human-clock/{compose_dry,select_dry}/` and its `logs/` (only the rerun after the fix remains) |
| saas-billing drop | [STEP1-FOLLOWUPS.md](STEP1-FOLLOWUPS.md); raw records in `private/raw-runs/r2-h0-ft-saas-billing-*` |
