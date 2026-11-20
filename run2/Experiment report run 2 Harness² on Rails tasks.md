# Experiment report: Harness² run 2 on Rails tasks

Nov 18, 2026 · @Joonas

## Summary

Run 2 reran Harness² the way the paper intends: k=3 rollouts per candidate, Claude Opus 5.5 as the improver, fresh local references, evidence the sessions had to read, and an answer-free selector. It ran on a six-task stream that starts with three tasks where Luna's behaviour varies. A small Meta-Harness side ran run 1's winner i4b, unchanged, on the same stream. All five pre-registered success criteria were met. This time the mechanism clearly worked: 14 reflector verdicts (12 `helped`, 2 `hurt`), a library entry on every task, and 4 cases where a later task's editor cited and reused an earlier entry. The outcome gain is small and partly confounded. The selected outputs passed 2 of 6 tasks (0.33), against 0.28 for local H0. Both of those passes came on tasks where 11 of 12 outputs in the pool passed. On the two tasks where a passing output was rare (1 of 9, 3 of 12), the selector rejected it on scope grounds. Total cost was about $57 against a $150 cap.

This report covers run 2 only. Run 1 is in [`run1/Experiment report Meta-Harness and Harness² on Rails tasks.md`](../run1/Experiment%20report%20Meta-Harness%20and%20Harness²%20on%20Rails%20tasks.md) and stays sealed. Run 2 follows the pre-registered plan in [`rerun-plan-v1.md`](../rerun-plan-v1.md). Every slide based on this report says that it shows run 2.

Headline findings for the talk:

1. **With k=3 and sessions that have to read, the library grows.** Run 1 wrote 0 entries and got 0 non-confounded verdicts. Run 2 wrote 6 entries and got 14 verdicts with a direction, each one citing run and step. Later editors reused earlier entries 4 times. For example, the `db-migration` skill written on task 3 was adapted on task 4, where it produced the only pass on that task in either run.
2. **Edited harnesses ran at least as well as H0 on every task.** INV probes passed 8/18 against 5/18 for H0 refs, and were strictly better on 3 tasks. The composed harness ran on 3 tasks and passed 7/9 there, against 5/9 for H0 on the same tasks. Caveats: k=3, and the H0 refs ran 1–2.5 days earlier, at slower API speeds on 4 of 6 tasks.
3. **The selector is the weak link.** It never picked an H0 output, and it picked a passing output whenever nearly everything in the pool passed. Twice, though, a pass was in the pool and it chose something else: on card it rejected the only passing output (1 of 9) and on entropy all three passing outputs (3 of 12), each for "out-of-scope" changes. So Harness²'s actual deliverable, the selected output, scored 0 on all three run-1 tasks.
4. **Reflector verdicts measure process, not correctness.** On entropy, the reflector rated the DOM skill `helped` because every run with it kept the named scope consistent. All 3 DOM runs failed the hidden tests, and 2 of the 3 passing outputs on that task took exactly the approach the skill steers away from.
5. **Run 1's Meta-Harness winner does not hold up.** i4b passed entropy 0 of 6 times (run 1: 1 of 2, lineage 4 of 6). It passed only the two tasks where H0 already passed 2 of 3: 6/21 overall, the same as H0.
6. **Infrastructure failures look like evidence unless you check for them.** Twice on Nov 17, running out of API credits (once Anthropic, once OpenAI) produced empty sessions and `agent_error` rollouts. The pipeline treated these as real results and marked tasks done. Guards were added and the affected tasks were rerun (see "How it ran").

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

**Task gate (step 1), Nov 15.** Local H0, 3 runs each: ft-local-time-human-clock **2/3**, ft-notification-bundle-window-overlap **0/3**, ft-card-reactions **2/3**. That makes 2 of 3 tasks with a pass, so the gate passed. Notification stayed in the stream as a varying task anyway: its runs took 42–76 min with very different pacing, even though none passed. A few rollouts ended `agent_error` in about 10 s and were rerun automatically (local-time r3, notification r2 and r3).

**ft-saas-billing was dropped because it can't run on arm64**, not because of its score. Its Dockerfile pins a single-platform amd64 base image. Under emulation on the arm64 Mac, the agent's jail never starts (`unshare: pidfd_open failed: Function not implemented`), so all 6 attempts ended `agent_error` in under 2 s. Don't count it as a task-gate failure. Its raw records stay in `private/raw-runs/r2-h0-ft-saas-billing-*`. Details are in [STEP1-FOLLOWUPS.md](STEP1-FOLLOWUPS.md).

**Improver sessions never had Glob or Grep, in run 1 or run 2.** `task.sh` passes `--tools "Read,Glob,Grep"` (plus `Edit,Write` for editors), but the `init` record of every session (Claude Code 2.1.325) lists only `["Read"]`, or `["Edit","Read"]` for editors and the composer. Run 1's logs show the same lists. So run 1's setup table ("tools Read/Write/Edit/Glob/Grep only") overstates what the sessions had. No session could list a folder or search; they could only open paths they were given. Editors created new files with Edit.

**The dry run found a selector bug, which was fixed before the stream** (Nov 16, 08:36–08:52). The first selector session couldn't see any candidate: the prompt only says `context/candidates/<id>.patch`, and without Glob it can't list the folder. It spent 18 turns guessing names (`a.patch`, `1.patch`, `cand1.patch`, …) and declined to choose. The automatic retry worked only because the miss message happened to name the files. Fix: `task.sh` now appends the list of candidate files to the selector's prompt. After the fix, the selector opened the task and all 3 patches in 5 turns, chose without a retry, and had no engagement misses.

**Dry run on task 1, otherwise as intended.** Every audit came back clean and `leak_check` said `CLEAN`. Each editor changed one component: INV changed `tool_guidance.md`, and DOM added the `skills/time-display` skill with its trigger line in `system.md`. The composer read `evidence.md` and all 3 base trajectories. Sessions ran 21–31 turns, against 12–13 for run 1's composer. Total cost was $3.73, plus about $0.78 for the rerun after the fix.

**Refs for tasks 4–6 and the i4b transfer (step 3), Nov 16 09:00–11:45.** Two rollouts ended `environment_error` in under 30 s: card-stalled H0 r3, plus mysql r2 and entropy r4 on the transfer side. The cause was Docker running out of network subnets when 8 sandboxes started at once. After a network prune, those records were removed and rerun.

## Harness²

**How it ran.** The stream started on Mon Nov 16 at 22:30 and finished on Wed Nov 18 at 10:40. It was not one clean overnight run.

- **Tasks 1–3 ran through overnight**, finishing Tue 02:48. The only problem was task 3's reflector, which hit an Anthropic credit error ("claude exited non-zero", $0, 1 turn). Its retry failed the same way. At that point `task.sh` read the empty reply as a missing edit table, logged it, and marked the task done with no library entry. After credits were added, the reflection was rerun twice (17:21, still failing; 17:30, succeeded) and wrote the card-reactions entry.
- **Task 4, first attempt (Tue 17:32–19:05), and tasks 5–6, first attempt (19:05–19:50), ran on fake results.** The OpenAI credits had run out, and every Luna rollout in those stages (probes and composed runs) ended `agent_error` after about 525 s. Nothing stopped the pipeline. The composer kept the base, the selector picked an H0 output, every reflector verdict was `confounded`, and no entry was written. Each task was marked done.
- **Fixes (now in `task.sh`):** `check_session_api` stops a stage when a session ends on an API error. `check_rollouts` stops a stage on an OpenAI credit/quota error, or when none of its rollouts completed, and clears the failed records so a rerun redoes only them. Neither stage is marked done in that case. `scores.sh` now counts composed rollouts only when the composed harness is the final source, so `final-*` records left over from a discarded attempt under the same label can't count.
- **Task 4, second attempt (Tue 20:27–22:01):** reran the probes, reusing the two editor proposals from the first attempt. Those proposals are valid, because the editors ran normally on the real H0 refs. The rest of the task ran from that point and wrote the card-stalled entry.
- **Tasks 5–6, second attempt (Tue 22:01 – Wed 01:25), discarded.** These also reused editor proposals from their first attempts. Those editor sessions had run at 19:05, before task 4's library entry existed, so they never saw it, and the stream order (each task sees every earlier task's entry) didn't hold. Both attempts were moved to `private/discarded-r2/`, along with their library entries. **Tasks 5–6, final attempt (Wed 09:03–10:40):** reran from the editors on, with the full library.
- `run2/logs/stream.log` only holds the last restart (Wed 09:03). The per-task history is in `run2/work/<task>/logs/task.log`.
- No `GATE:` stop, no audit failure and no score-guard stop. Every editor passed the `single-component` check. Apart from the dry run and the credit-failure attempts, no session in the kept results needed an engagement retry, and `scores.sh` lists no engagement misses.
- **Notification DOM probes r2 and r3 ended `agent_error`** after 270 s, both originally and on the automatic retry. The model call returned an HTML error page (an upstream outage, not credits). They count as non-passes, so the DOM arm on notification is effectively k=1. That changes nothing on that task, where every output scored 0.

**Per-arm results** (passes of 3, mean credit; from `scores.sh` section 1):

| Task | H0 refs (3) | Run 1 local H0 | INV probes (3) | DOM probes (3) | Composed (3) | Selected output | i4b transfer (3) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ft-local-time-human-clock | 2/3 (0.33) | – | **3/3** (0.67) | **3/3** (0.50) | **3/3** (0.50) | dom r2: **pass** | 3/3 (0.50) |
| ft-notification-bundle-window-overlap | 0/3 | – | 0/3 | 0/3 (2 agent_error) | = INV, not rerun | inv r3: 0 | 0/3 |
| ft-card-reactions | 2/3 (0.67) | – | **3/3** (0.90) | **3/3** (1.00) | **3/3** (1.00) | composed r2: **pass** | 3/3 (0.70) |
| ft-card-stalled-quiet-clock | 0/3 | 0/1 (timeout) | **1/3** (0.33) | 0/3 (2 timeouts) | = INV, not rerun | dom r2: 0 | 0/3 (2 timeouts) |
| ft-entropy-sweep | 1/3 (0.33) | 0/1 | 1/3 (0.33) | 0/3 | 1/3 (0.33) | dom r3: 0 | 0/3 (+3: 0/6) |
| ft-mysql-fulltext-search-foundation | 0/3 | 0/1 | 0/3 | 0/3 | = INV, not rerun | dom r2: 0 | 0/3 |

**Pass rate per arm over the stream** (`scores.sh` section 2):

| Arm | Passes | Mean credit |
| --- | --- | --- |
| H0 local refs | 5/18 (28%) | 0.22 |
| INV probes | 8/18 (44%) | 0.37 |
| DOM probes | 6/18 (33%) | 0.25 |
| Composed (3 tasks only) | 7/9 (78%) | 0.61 |
| Meta-Harness i4b | 6/21 (29%) | 0.17 |
| Selected output | 2/6 (33%) | 0.25 |

The composed arm only ran on the three tasks where it differed from both candidates, and those happen to be the three tasks where H0 passed at all. On those tasks H0 passed 5/9, so the fair comparison is 7/9 against 5/9, not 78% against 28%.

**Timing confound.** Every task's H0 refs ran before its probes: tasks 1–3 on Sun Nov 15, tasks 4–6 on Mon morning. The probes ran Mon night to Wed morning. Median seconds per Luna step were clearly lower in the probes on 4 of 6 tasks: notification 53 → 31/38, card-reactions 40 → 27/20, entropy 40 → 24/31, mysql 33 → 24/34 (INV/DOM). They were about equal on local-time (34 → 34/35) and card-stalled (36 → 38/37). So wall-clock gains, such as card-reactions at a 49 → 23–30 min median, can't be credited to the harnesses. The task-3 reflector said this itself: "every non-base arm ran on a later day at about half the time per step". Pass rates depend less on speed, but timeouts count as non-passes.

**What the editors and composer did, per task.**

| Task | INV edit | DOM edit | Composer kept | Composed runs |
| --- | --- | --- | --- | --- |
| local-time | `tool_guidance.md`: python3 and rg are missing, a Ruby example replaces the `newfile.py`/numpy one, an anchor-checking multi-file edit script, system-test facts | skill `time-display` (every display site, the CSS `text-transform` casing trap, a coverage grep over `app saas/app`) | DOM skill as-is, plus a cut-down INV (only the python3/rg line and the Ruby example; anchor script and test facts dropped) | ran |
| notification | `system.md`: time-boxed workflow (`date -u` checks, first test by about minute 20, everything working by minute 55) plus workspace facts | skill `new-model-job-mailer` | INV wholesale; DOM dropped | skipped (= INV) |
| card-reactions | skill `db-migration` (multi-db scoped rollback, revert `cable_schema.rb`, hand-edit `schema.rb`) | skill `card-feature-surfaces` (sibling-stack checklist modelled on comment reactions) | both, revised: no-FK/uuid rule added to `db-migration`; DOM's migration section replaced by a pointer, its hard-coded migration version removed; "add card-level files beside the comment ones" | ran |
| card-stalled | skill `db-migration`, adapted from the card-reactions library entry, plus "roll back before editing a migration that has run" | skill `card-state-and-index` (every cache/etag site, and prove each one) | INV wholesale; DOM dropped as unsafe (2/3 timeouts) | skipped (= INV) |
| entropy | `system.md`: time-boxed workflow and stop rule (modelled on the notification library entry), plus workspace facts | skill `query-performance-change` (scope and sweep must agree, add an index rather than drop one) | both; fixture-count fact corrected, migration facts moved to `system.md` | ran |
| mysql | `tool_guidance.md`: no Python, a Ruby replace that raises when the anchor is missing, a "Tests" section | skill `card-content-search` (5-item contract: AND-match every word, SQL in the controller, …) | INV wholesale; DOM dropped (its contract was followed and made patches worse) | skipped (= INV) |

Patterns: every DOM edit was a skill with one trigger line, and every trigger fired in every run that had it. No base run ever opened `/opt/harness`. On 3 of 6 tasks the INV edit was a fix for the same tool error: `python3` and `rg` are missing from the sandbox, and H0's `tool_guidance.md` example invites Python. Three tasks needed the same multi-database migration fix (card-reactions, card-stalled, and entropy's workspace facts).

## Pre-registered success table

Fixed before the run in `rerun-plan-v1.md`. Filled in whatever the outcome.

| Level | Criterion | Run 1 | Run 2 |
| --- | --- | --- | --- |
| Mechanism | Reflector writes ≥ 2 library entries over the stream | 0 | **met**: 6 (every task) |
| Mechanism | ≥ 1 later task's editor reads and cites a library entry in its notes | n/a (empty) | **met**: 4 citations (card-stalled INV → card-reactions and notification; entropy INV → notification; mysql DOM → card-stalled) |
| Mechanism | ≥ 1 reflector verdict is `helped` or `hurt` (not `confounded`) | 0 | **met**: 14 of 18 (12 `helped`, 2 `hurt`, 4 `confounded`) |
| Outcome | Selected output passes at a rate ≥ local H0 on the stream overall | 0 vs 0 | **met**: 2/6 = 0.33 vs 0.28 |
| Outcome | Strictly better than local H0 on ≥ 1 task, or better mean credit | no | **met**: better on 2 tasks (local-time, card-reactions); mean credit 0.25 vs 0.22 |

How to read the outcome rows: they are met, but only just, and not where it matters. The two tasks where the selected output beat H0 are the ones where H0 already passed 2/3 and 11 of 12 outputs in the pool passed. On the three run-1 tasks the selected output scored 0, just like H0.

## The selector

From `scores.sh` section 3.

| Task | Pool size | Picked (arm, run) | Passing outputs in pool | Pick passed? |
| --- | --- | --- | --- | --- |
| ft-local-time-human-clock | 12 | dom r2 | 11/12 | yes |
| ft-notification-bundle-window-overlap | 9 | inv r3 | 0/9 | no (none could) |
| ft-card-reactions | 12 | composed r2 | 11/12 | yes |
| ft-card-stalled-quiet-clock | 9 | dom r2 | **1/9** (inv r2) | **no** |
| ft-entropy-sweep | 12 | dom r3 | **3/12** (composed r1, inv r2, base r2) | **no** |
| ft-mysql-fulltext-search-foundation | 9 | dom r2 | 0/9 | no (none could) |

It picked an H0 output on 0 of 6 tasks.

**Both misses came from the same preference.** On card-stalled, the selector chose dom r2 because it was "the most complete version of the request", with the badge, cache and ETag handling everywhere. It rejected inv r2, the only passing output, because it "changes `touch:` on many models and adds a backfill migration, which is out of scope". On entropy, it chose dom r3 because it alone updated the Brakeman ignore entry. It rejected composed r1 (a pass) for deleting that entry, and inv r2 and base r2 (both passes) for rewriting the sweep per board. Base r2 also hit the 90-minute limit and still passed. In both cases the selector rewarded scope discipline and operational care that the hidden tests don't check, and penalised changes the tests accepted.

**Stability caveat from the dry run.** On task 1's three H0 patches, the two dry-run selections picked different runs (base r3, then base r2). Both flagged the same small rename as the deciding deviation. Treat each stream pick as a single draw, not a ranking. In the stream, the near-identical pools (local-time, card-reactions) didn't matter, because almost every candidate passed. The pools that mattered had few passes, and there the selector's taste for scope decided the outcome.

## The library

Six entries, one per task (`run2/library/index.md`, copied to `slides/raw/run2/library-index.md`). Each entry holds the full adopted harness plus `EXPERIENCE.md`, which combines the composer's keep/drop decisions with the reflector's edit table. Notification's and mysql's entries hold harnesses with no skills: their composers adopted INV's always-on edit and dropped the DOM skill.

**One entry and the evidence behind it: `ft-card-reactions` → `skills/db-migration`.** The task-3 INV editor wrote this skill after all three H0 refs had worked out the repo's multi-database migration mechanics by trial: base r1 steps 31–38, about 15 steps in base r2, and base r3's failed `db:migrate:down` at step 33. The reflector's edit-table row:

> observed: All 3 inv runs read the skill (inv r2 step 8, inv r3 step 8). Every run that had the skill and had to roll back used the scoped command and it worked first time: inv r3 step 43, composed r2 step 45, composed r3 step 57. Every run without it failed on the first rollback: base r3 step 33 (fixed at step 34), base r2 step 106 (fixed at step 108 after listing the rake tasks at step 107), and dom r2 step 43 (fixed at step 44). […] Step counts did not fall (inv 76/65/67 vs base 75/120/63). The drop from 49 to 30 median minutes cannot be credited to the skill: every non-base arm ran on a later day at about half the time per step […]
>
> verdict: helped

On task 4 (card-stalled), the INV editor opened this entry, "adapted it from the `ft-card-reactions` library skill and re-checked every workspace fact in it against these trajectories". It then added the failure it saw in that task's H0 refs: two of the three edited a migration that had already run and then failed to roll back ("No indexes found"). With the skill, inv r1 ran the scoped `db:migrate:down:primary` before editing the migration, and it went through first time. Reflector verdict: `helped`. INV r2 on that task produced the only passing output on card-stalled in either run. That pass can't be credited to the skill alone: k=3, and the selector then rejected it. Still, it's the clearest case of the library doing what the method intends.

**Other reuse:** the entropy INV editor modelled its time-boxed `system.md` on the notification entry ("This matches the system.md rewrite in the library's ft-notification-bundle-window-overlap"). The mysql DOM editor cited the card-stalled entry.

**Overfitting check** (`run2/logs/library-task-terms.txt`, run 1's task-term grep `entropy|postpone|stall|quiet|burst`): entropy **13** hits, local-time **6**, notification **1**, the other three **0**. The entropy entry is about the entropy task, so its hits are expected, and only task 6 (mysql) could read it; mysql's editors didn't cite it. Local-time's hits are its `time-display` skill naming Fizzy's entropy and stall display code as places where time is shown. Notification's single hit is the word "stall" in its workflow text. No entry carries a solution recipe for a later task the way run 1's i3a skill did.

**Verdicts measure process, not correctness.** The reflector never sees scores, so `helped` means "runs with this edit did what it says, and that removed a failure the base runs had". On local-time, card-reactions and card-stalled, `helped` went along with more passes. On entropy, it didn't: the DOM skill was rated `helped` because all six runs with it kept `due_to_be_postponed` as the one selection. Yet all 3 DOM probes failed, and two of the three passing outputs on that task bypassed the scope with a per-board loop. On mysql, the reflector rated the DOM skill `hurt` (SQL in the controller, bigger patches). That arm scored 0/3, but so did every other arm.

## Run 1 vs run 2 on card, entropy and mysql

| Task | Run 1 local H0 | Run 1 Harness² composed (k=1) | Run 2 H0 refs (3) | Run 2 best Harness² arm | Run 2 selected output |
| --- | --- | --- | --- | --- | --- |
| ft-card-stalled-quiet-clock | 0, timeout (149 steps, 90 min) | 0, timeout | 0/3 (median 114 steps, 68 min) | INV 1/3 | 0 |
| ft-entropy-sweep | 0 (125 steps, 41 min) | 0 | 1/3 (the pass hit the time limit) | INV 1/3, composed 1/3 | 0 |
| ft-mysql-fulltext-search-foundation | 0 (66 steps, 23 min) | 0 | 0/3 | none (0/9 overall) | 0 |

These three were 0/3 for Luna in the published runs. Run 2 produced passes on two of them: H0 on entropy once, and INV on card and entropy once each. The selector delivered none of them. Run 2 runs went faster and finished more often than run 1's local runs (card-stalled H0: 0 of 3 timeouts against run 1's one timeout). These tasks aren't held out: run 1's Meta-Harness searched on card and entropy, and both runs used all three.

## Meta-Harness side: i4b transfer

Run 1's winner i4b, unchanged, from the sealed copy in `run1/`: 3 runs on each stream task, plus 3 extra on entropy (21 runs). All ran Mon Nov 16 morning, in the same window as the H0 refs for tasks 4–6.

| Task | i4b | H0 refs | Note |
| --- | --- | --- | --- |
| ft-local-time-human-clock | 3/3 (0.50) | 2/3 | median 67 min, slowest arm on this task |
| ft-notification-bundle-window-overlap | 0/3 | 0/3 | |
| ft-card-reactions | 3/3 (0.70) | 2/3 | |
| ft-card-stalled-quiet-clock | 0/3 | 0/3 | 2 of 3 hit the time limit |
| ft-entropy-sweep | **0/6** | 1/3 | run 1: i4b 1 of 2, i3a lineage 4 of 6 |
| ft-mysql-fulltext-search-foundation | 0/3 | 0/3 | run 1 held-out: 0 |
| **Total** | **6/21 (29%)** | 5/18 (28%) | |

i4b's skill carries the entropy recipe inherited from i3a, but it went 0 for 6 on entropy. Run 1's entropy result looks like noise, or depended on conditions that didn't repeat. Its two 3/3 tasks are the ones where H0 already passed 2/3 and every Harness² arm passed 3/3, so this is no evidence of transfer. Overall i4b ties H0.

## Costs

| Item | Cost |
| --- | --- |
| Luna rollouts: H0 refs $4.62, i4b transfer $4.37, INV probes $3.38, DOM probes $3.79, composed $1.93 | ≥ $18.09 |
| Improver sessions (Opus 5.5) in the kept results: tasks 1–6 $6.26 / $5.14 / $5.70 / $4.92 / $3.63 / $3.95 (task 1 includes the dry-run rerun) | $29.60 |
| Improver sessions of the discarded task 5–6 attempts (`private/discarded-r2/`) | $8.06 |
| First dry run's composer and selector sessions (stats overwritten by the rerun) | about $0.77 |
| **Total** | **about $57** |

The Luna figure sums the `result.json`/`agent.result.json` cost of every `r2-*` record in `private/raw-runs/`. It's a lower bound, because a rerun under the same label replaced the earlier record. That applies to the probes of the discarded attempts and of the credit-failure attempt. Session stats for task 4's first-attempt composer, selector and reflector were also overwritten (a few dollars at most). The OpenAI and Anthropic billing pages are the reference. Spend stayed far under the $150 cap. The cookbook estimated $55–158.

## Lessons and caveats

What run 2 shows:

- **The Harness² mechanism needs k > 1 and sessions that read.** With both, the reflector rated edits by citing run and step, wrote entries, and later editors reused them. This is the key contrast with run 1. Run 2 changed the improver model at the same time, so the slides should say "k=3 and Opus 5.5".
- **The selector decides what Harness² delivers, and it optimises a different target from the tests.** A better pool (INV 8/18 against H0 5/18) only turned into delivered passes where almost everything passed already.
- **Answer-free verdicts can be confident and wrong about outcomes.** `helped` describes the process, and the hidden tests sometimes reward the opposite.
- **Guard against infrastructure failures that look like data.** API credit errors produced empty sessions and `agent_error` rollouts, and the pipeline treated them as results until `check_session_api` and `check_rollouts` were added.

Caveats to keep on the slides:

- Run 2 changes k and the improver model at the same time. The optional Sonnet ablation (step 5) was not run, so we can't separate the two.
- k=3 is still small: a single flip changes a task's pass rate by 33 points.
- H0 refs ran 1–2.5 days before the probes, and Luna's steps were faster during the probes on 4 of 6 tasks. Wall-clock gains aren't attributable to the harnesses.
- The selector's pick between near-identical candidates was not stable in the dry run (see "The selector").
- Sessions had only Read (and Edit), not Glob/Grep, in both runs.
- Tasks 4–6 are the same tasks as run 1, so they aren't held out for anyone.
- ft-saas-billing was dropped for an arm64 incompatibility, not for its score.
- Tasks 5–6 were rerun after a discarded attempt, and task 4 after a credit failure. The kept results are the ones where every earlier library entry was visible to the editors.
- Notification's DOM arm had 2 of 3 rollouts lost to an upstream API error.

## Timeline (Nov 15–18, 2026, EET)

| Time | Event |
| --- | --- |
| Wed 10:40 | Stream finished (mysql done) |
| Wed 09:03 | Discarded task 5–6 attempts moved to `private/discarded-r2/`; entropy and mysql rerun from the editors on |
| Wed 01:25 | Second attempt of tasks 5–6 done (later discarded: editors predated task 4's library entry) |
| Tue 22:01 | Task 4 (card-stalled) done with a library entry |
| Tue 20:27 | Task 4 rerun from the probes after the OpenAI credit fix |
| Tue 17:32–19:50 | Task 4 and tasks 5–6 run on fake results: OpenAI credits exhausted, every Luna rollout `agent_error` |
| Tue 17:30 | Task 3 reflection rerun after the Anthropic credit fix: card-reactions entry written |
| Tue 02:48 | Task 3 done, but its reflector hit an Anthropic credit error (no entry) |
| Tue 01:43 | Task 2 (notification) done |
| Tue 00:28 | Task 1 (local-time) done |
| Mon 22:30 | Stream started |
| Mon 09:00–11:45 | Refs for tasks 4–6 and the i4b transfer, including reruns after 3 `environment_error`s |
| Mon 08:52 | Dry run rerun after the selector fix: selector chose without a retry |
| Mon 08:41 | Dry run on task 1 done; selector needed the retry to see the candidates |
| Mon 08:36 | Dry run on task 1 started |
| Mon 08:35 | Local H0 candidate tasks committed (`54ab3fa`) |
| Sun 15:26–19:00 | Step 1: local H0 on candidate tasks; ft-saas-billing dropped (arm64); ft-card-reactions added; task gate PASS |

## Artifact index

Paths are relative to `demo/`. Nothing from `private/` goes on a slide.

| Material | Where it is |
| --- | --- |
| Scores and the success table | `slides/raw/run2/scores.md` |
| Library | `run2/library/`, index copied to `slides/raw/run2/library-index.md` |
| Per-task stage log (full history, including restarts) | `run2/work/<task>/logs/task.log` |
| Editor and composer notes | `run2/work/<task>/{inv,dom,compose}/notes.md` |
| Reflector edit tables | `run2/work/<task>/reflect/edits.md` |
| Selector choice and pool map | `run2/work/<task>/select/reply.select.txt`, `select.map.tsv` |
| Session stats and engagement | `run2/work/<task>/logs/*.stats.txt`, `*.engagement.txt`, `engagement.txt` |
| Stream log (last restart only) | `run2/logs/stream.log` |
| Refs and transfer logs | `run2/logs/refs.log`, `run2/logs/transfer.log` |
| Overfitting check | `run2/logs/library-task-terms.txt` |
| Dry run on task 1 | `run2/work/ft-local-time-human-clock/{compose_dry,select_dry}/` and its `logs/` (only the rerun after the fix remains) |
| saas-billing drop | [STEP1-FOLLOWUPS.md](STEP1-FOLLOWUPS.md); raw records in `private/raw-runs/r2-h0-ft-saas-billing-*` |
| Discarded task 5–6 attempts | `private/discarded-r2/` (not for slides) |
| Integrity | `run2/MANIFEST.sha256` (sealed Nov 18) |
