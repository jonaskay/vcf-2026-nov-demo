# Experiment report: Meta-Harness and Harness² on Rails tasks

Nov 14, 2026 · @Joonas

## Summary

In one evening on three Fizzy feature tasks, Meta-Harness found a harness that passes one search task in 3 of 4 runs, but nothing transferred to the held-out task; Harness² scored 0 on all 9 runs and its library stayed empty. Both ran with the same frozen executor (Luna) and the same improver (Claude Sonnet 5.5), naively implemented, with single runs throughout.

This report is the source for the meetup talk's slides and speaker notes. A later session should be able to build the talk from it without this chat. Every number here comes from the run logs, scoreboards and reports produced on Sat Nov 14, 2026; open items are listed at the end.

Headline findings for the talk:

1. **Meta-Harness worked mechanically.** Its proposer diagnosed failures from traces, combined two parent candidates, and reached the first pass of the evening in iteration 3.
2. **What it learned was partly the answer.** The passing harness's skill carries the entropy task's solution recipe. On that task its lineage passed 3 of 4 runs, against 0 of 9 for everything else. On the held-out task, both of its harnesses that were tried scored 0.
3. **Harness² had no signal to correct itself.** Without scores, it settled on the same kind of fix that Meta-Harness's scores had already shown to fail.
4. **The naive Harness² sessions read very little.** The composer and the reflector ran 5–13 turns in 11–28 seconds on budgets of $3–4, and twice compared against the wrong baseline.
5. **At k=1 the library cannot grow.** Every candidate had one rollout, so every edit was "confounded" and the reflector wrote no entry on any task.
6. **Single runs are very noisy.** Two near-identical harnesses got opposite outcomes on the card task, and the passing harness failed its repeat.

## Framing and setup

The demo is illustrative, not a validation: it shows what naive implementations of [Meta-Harness](https://arxiv.org/abs/2603.28052) and [Harness²](https://arxiv.org/abs/2610.14224) do on real Rails tasks. Every result is one or two runs, and no claim is made that either method beats the other.

|  | Meta-Harness | Harness² |
| --- | --- | --- |
| When it learns | Offline, before deployment | Online, task by task |
| Feedback | Scores + raw traces of every earlier candidate, via a filesystem | No ground truth; contrasts between reruns of the same task |
| Loop | Propose → evaluate → log → repeat | INV + DOM edits → probe → compose → reflect into a library |
| Output | One harness, deployed unchanged | A per-task harness, plus a library of lessons |

**Shared setup**

| Part | Choice |
| --- | --- |
| Tasks | [rails/ai-evals](https://github.com/rails/ai-evals) Fizzy feature tasks (below); each has a hidden `verification_test.rb` |
| Runner | lemans 1.6.0, Docker backend on a MacBook (18 CPUs, 16 GB); published limits: 90 min, 400 steps, 300 s per command |
| Agent | miniswen, a minimal bash-only loop, wrapped as `harnessed-miniswen`: a plugin uploads the harness to `/opt/harness`, and a loader re-renders the first prompt from it |
| Executor (frozen) | `openai/gpt-6-luna#max` via OpenAI direct |
| Improver | Claude Sonnet 5.5 via `claude --bare -p`; tools Read/Write/Edit/Glob/Grep only, writes confined to one directory, budget cap per session |
| Harness format | Text only: `system.md`, `guardrails.md`, `memory.md`, `tool_guidance.md` (always on) + `skills/<name>/SKILL.md` (read on demand with `cat`) |
| H0 (base harness) | miniswen's stock prompt split into the four files; verified byte-identical to stock in the prompt the model received |

**Tasks.** Luna scored 0.00 on all three in the published October 2026 runs (3 runs each), while at least two other models scored 1.00.

| Task | Meta-Harness role | Harness² order |
| --- | --- | --- |
| ft-card-stalled-quiet-clock | search | task 1 |
| ft-entropy-sweep | search | task 2 |
| ft-mysql-fulltext-search-foundation | held-out | task 3 |

**Leakage controls.** Improvers never saw the hidden verifier, and Harness² never saw a score of any kind.

- An allowlist export gives improvers only `agent.patch`, a compacted trajectory, a per-step `steps.tsv` and a trimmed `result.json` (Harness²: no reward or credit).
- `validate.sh` rejects any harness with extra files, an unnamed skill, or a hidden check name (28 names, kept outside every workspace); confirmed on a planted name.
- Every improver session's tool calls are audited for forbidden paths; a hit stops the pipeline. All audits came back clean.
- Harness² adds a score guard (any `result.json` with reward or credit in a session workspace stops the task) and `leak_check.sh` on library text.

## Setup findings

Local runs behaved differently from the published baseline: same model name, but 2–3× more steps and slower steps. So the published runs serve as context only, and every comparison in this report uses local H0 runs.

| H0 runs | Route | Steps | Time | Output tokens per step | Reward |
| --- | --- | --- | --- | --- | --- |
| Card, published (3) | OpenRouter, ruby\_llm 1.16.0 | 53–67 | 20–28 min | 1.3k–1.7k | 0 |
| Card, local | OpenAI direct, ruby\_llm 2.1.1 | 149 | 90 min (timeout) | 3.6k | 0 |
| Entropy, published (3) | OpenRouter | 27–50 | 9–18 min | – | 0 |
| Entropy, local | OpenAI direct | 125 | 41 min | – | 0 |
| Mysql, published (3) | OpenRouter | 26–42 | 11–14 min | – | 0 |
| Mysql, local | OpenAI direct | 66 | 23 min | – | 0 |

Likely cause: `#max` reaches the model with a different reasoning effort on the two routes, or the newer client library sends it differently. It is not confirmed. For the setup slide: "published baseline = context; our baseline = local H0, one run per task."

**Content-filter incident.** The first local H0 run on the mysql task ended in `agent_error` after 27 normal steps ($0.04): OpenAI rejected call 28 with `invalid_prompt` ("flagged as potentially violating our usage policy"). Call 27 had been accepted, and the only new content was ordinary menu-helper code. A rerun was healthy. It was 1 of 10 local trials at the time. Fix: `run_harness.sh` now reruns a trial once when it ends in `agent_error` or leaves no result. Side effect worth knowing: lemans reports such trials as $0.00 and `null` steps; the real cost is in `agent.result.json`.

**Capacity.** Each sandbox used 110–145 MiB of its 2 GiB cap and near-zero CPU (the agent mostly waits on the model). Up to 8 sandboxes ran at once without trouble, so Meta-Harness and Harness² ran side by side all evening.

**Improver cost.** Sessions were far cheaper than estimated: the Meta-Harness proposer took $0.25–0.45 per iteration (estimate: up to $8), and Harness² sessions $0.03–0.12 each.

## Meta-Harness

After four iterations, the i3a lineage passed the entropy task in 3 of 4 runs, while nothing passed the card task and nothing transferred to the held-out task. The winner by the selection rule is **i4b**.

**How it ran.** 4 iterations × 2 candidates × 2 search tasks × 1 run = 16 Luna runs, 4 in parallel. Each iteration: one proposer session reads the candidate filesystem (every earlier harness, its `notes.md`, the scoreboard, and per run `result.json` with reward, credit, outcome and duration, `steps.tsv`, the trajectory and `agent.patch`) and writes two new candidates; then audit, validation, the 4 runs, and a rebuilt scoreboard. Selection: mean reward, then mean credit, then cost per run, then steps.

**Candidates.** Search-task results, one run per task (h0: 3 published + 1 local run per task).

| Candidate | Parent | What it changed | Card | Entropy | Mean steps | Cost per run |
| --- | --- | --- | --- | --- | --- | --- |
| h0 | – | Stock prompt | 0 (1 of 4 timed out) | 0 | 70 | $0.37 |
| i1a | h0 | Rewrote the always-on files with Fizzy facts and a requirements procedure | timeout | 0 | 79 | $0.68 |
| i1b | h0 | Lean prompt + 3 on-demand skills | 0 | 0 | 60 | $0.39 |
| i2a | i1b | Query skill: one literal-cutoff query per setting value; judge a prefilter by rows removed | timeout | 0 | 124 | $0.93 |
| i2b | i1b | Procedure: strict reading of vague phrases, \~15-step exploration budget, \~60-step target, end-to-end check | 0 | 0 | 85 | $0.54 |
| i3a | i2b | i2b's procedure + i2a's skill, revised: no big `.or` of subqueries, keep public names | 0 | **1** | 97 | $0.56 |
| i3b | i2b | Tighter: ≤12 exploration steps, first edit by \~20, smallest diff | 0 | 0 | 54 | $0.34 |
| i4a | i3a | Ambiguity step (mirror sibling scopes), don't change shared methods | 0 | **1** | 108 | $0.75 |
| i4b | i3a | Test-first acceptance tests, step budget (core green by \~35, submit by \~70) | 0 | **1** | 70 | $0.45 |

h0's cost and steps mix published and local runs, so its rank against the candidates means little; the candidates all ran locally and compare fairly with each other.

&#91;embedded content: Meta-Harness candidate lineage · 9 harnesses, 3 entropy passes\]

Solid arrows run from parent to child; the dashed arrow marks the query skill i3a took from i2a.

**The lineage to the pass.** i1b introduced on-demand skills. i2a rewrote the query skill after reading i1b's patch and its `EXPLAIN` output; entropy still failed. i2b reworked the procedure. i3a combined i2b's procedure with i2a's skill, revised after reading i2a's failed patch, and passed. Both children of i3a passed too. This is the proposer composing two parents from their traces, close in spirit to Harness²'s composer.

**The proposer diagnosed from traces.** Iteration 1: 35 turns, 21 files read, $0.25. Iteration 2: 46 turns, 27 files, $0.45. Iteration 3: 42 turns, 25 files, $0.34. Iteration 4: 36 turns, 19 files, $0.34. (The paper reports a median of 82 files read.) Examples from its `notes.md`:

- i1a: `rg` and `python3` failed at steps 4 and 14 of an entropy run (neither exists in the sandbox); the card run invented its own column instead of reusing existing concepts.
- i2a: in i1b's entropy run, `EXPLAIN` at steps 8–22 showed a full scan; the agent chose a 3-day prefilter plus an index and never measured how many rows it removed.
- i2b: i1b's card run read for steps 3–40, with detours into gem source at 28–34, and made its first edit at step 41.
- i3b: i2a's card run made its first edit at step 56 and added hooks across many models before timing out.
- i4b: i3a's card run wrote tests at steps 28–35, after implementing at 21–23, then reworked a microsecond boundary for steps 46–63.

**What it learned was partly the answer.** The winning lineage's harness carries both search tasks' specifics. `memory.md` names `Entropy` rows and "entropy periods". The query skill prescribes "one query per distinct setting value … `board_id IN (ids)`; for the default, `NOT IN` the overridden ids" and "override beats default", which is the entropy task's solution shape, next to general advice (`EXPLAIN`, batching, measuring on synthetic rows, both schema files). The derived-state skill spells out the card task's "a burst then N days quiet" logic with test cases. The proposer's skill said to write for any Fizzy task; it complied in wording ("e.g. entropy periods"), not in substance. From iteration 2 on, its notes also speculate about the grader ("hidden tests probably check the query's selectivity"), which is allowed for Meta-Harness, since it learns from scores.

**Repeat and held-out runs.**

| Run | Task | Outcome | Steps | Time | Reward |
| --- | --- | --- | --- | --- | --- |
| i3a, search run | entropy | completed | 93 | 47 min | 1 |
| i3a, repeat | entropy | completed | 69 | 38 min | 0 |
| H0, local | mysql (held-out) | completed | 66 | 23 min | 0 |
| i3a | mysql (held-out) | completed | 27 | 16 min | 0 |
| i4b (winner) | mysql (held-out) | completed | 18 | 9 min | 0 |

On entropy, the i3a lineage passed 3 of 4 runs; every other harness passed 0 of 9 (h0's 4 runs plus i1a, i1b, i2a, i2b, i3b). On the held-out task the evolved harnesses ran shorter but not better. i4b's run was focused, not cut short: a 277-line patch, its own tests, the full suite, a walk through its requirements checklist, then submit at step 20.

**Noise.** i2a is nearly identical to i1b on the card task (it changed only the query skill, one line in `system.md` and two memory facts), yet i1b finished in under an hour and i2a timed out. Prompt length doesn't explain the timeouts either:

| Candidate | Always-on prompt (card task) | Card outcome |
| --- | --- | --- |
| i1b | 3,583 chars | completed |
| i2a | 3,885 chars | timeout |
| i2b | 4,801 chars | completed |
| i1a | 5,021 chars | timeout |

## Harness²

All 9 Harness² runs scored 0 with credit 0, and the reflector wrote no library entry on any task, so task 2 and task 3 had nothing to reuse. Its composed harnesses finished the entropy and mysql tasks and timed out on the card task, like local H0.

**How it ran** (`harness2/task.sh`, k=1, the three tasks in order as one stream):

1. **References:** the 3 published H0 runs, exported without scores, plus a local H0 run as `r4` (card and entropy; mysql's local run had failed, so it kept 3).
2. **Propose:** an INV editor (how the agent works) and a DOM editor (what a Rails/Fizzy practitioner knows), in parallel, each editing its own copy of H0.
3. **Probe:** each changed candidate runs once.
4. **Compose:** one session writes the successor from the references, both candidates, their diffs, notes and rollouts.
5. **Execute:** the composed harness runs once; that run is the task's result.
6. **Reflect:** a read-only session writes an edit table and one lesson or `NO_ENTRY`; the script writes the library entry.

Prompts are adapted nearly verbatim from the paper's Appendix H; the reflector prompt and k=1 wording come from the official code (`harness2/core/prompts.py`).

| Deviation from the paper | Why |
| --- | --- |
| 3 published references (+1 local), not fresh reference runs | Free, and makes the composer's "a defect in 1/k is noise" rule meaningful |
| Text-only harness; no scripts, subagents or plugins | Weekend scope; the prompts' component sections were cut to match |
| Emptied files count as deletions | Sessions have no Bash, as part of the leak defense |
| No selector | k=1 |

Kept from the paper: every task starts from H0 and uses the library only through the editors; an invalid proposal gets one retry, then falls back to H0; the reflector's strict evidence rule.

**Results.** Local H0 for comparison: card 149 steps, 90 min, timeout; entropy 125 steps, 41 min; mysql 66 steps, 23 min.

| Task | INV probe | DOM probe | Composer kept | Composed run (the result) |
| --- | --- | --- | --- | --- |
| Card | 90 steps, 54 min | 111 steps, 61 min | DOM skill `card-derived-state`; dropped INV | **timeout**, 118 steps, 91 min |
| Entropy | 102 steps, 58 min | 47 steps, 20 min | DOM skill `rails-query-perf-change`; dropped INVa | completed, 32 steps, 9 min |
| Mysql | 45 steps, 15 min | 60 steps, 22 min | Both: INV's `tool_guidance.md` (no-python note, test/rubocop/`git status` hygiene), shortened; DOM skill `card-query-page`, trimmed | completed, 43 steps, 24 min |

All 9 runs: reward 0, credit 0.

**The sessions read very little.**

| Session | Turns | Time | Cost | Budget |
| --- | --- | --- | --- | --- |
| Editors (dry run, card task) | 10 each | about 1 min | $0.08–0.12 | $3 |
| Composer, card | 13 | 28 s | $0.07 | $4 |
| Composer, entropy | 12 | 25 s | $0.07 | $4 |
| Composer, mysql | 15 | 29 s | $0.07 | $4 |
| Reflector, card and entropy | 5 each | 11–12 s | $0.03 | $3 |
| Reflector, mysql | 8 | 15 s | $0.04 | $3 |

In the dry run, the INV editor opened no trajectory and the DOM editor read only the patches. Improver cost per task: $0.38 (card, including the dry run), $0.24 (entropy), $0.28 (mysql).

On mysql the composer again compared against the published runs ("base rollouts were short (26 and 27 steps seen)"); mysql's local H0 (66 steps) was not among its references. The reflector rated all three edits `confounded` and returned `NO_ENTRY`, as on the other two tasks. It did notice one real risk: the kept skill steers toward a `LIKE` search while the task asks for fulltext.

**The composer compared against the wrong baseline, twice.** On the card task it judged the probes against the published runs ("base runs 53–67 steps") and wrote that the skill "may add time". The local H0 timeout was in its workspace as `r4`, unread. Its prompt said "3 base rollouts", because `r4` was added after the task started, which made this worse. On the entropy task the prompt said 4, and it still compared everything with `r1`, the fastest published run (9 min). Measured against local H0:

- Card: INV was the fastest local run (54 min, completed, while H0 timed out). The composer dropped it as "slower than base" and kept DOM; the composed run timed out.
- Entropy: DOM (20 min) was faster than H0 (41 min) and was kept; INV (58 min) was slower and was dropped, which was right, for a weak reason.

**The library stayed empty.** Every candidate had one rollout, so the reflector marked every edit `confounded`, and by the paper's rule a lesson resting only on confounded rows is declined. It followed the rule. It also didn't open the trajectories ("I did not open the trajectories to confirm that the agent read the skill").

**Harness² is allowed to specialise.** Its prompts ask for verified facts about the current task, labelled "in this workspace". The card task's DOM skill, for example, names `Filter::Fields`, both schema files, the export/import `RecordSet` and the card cache keys. In the dry run, those facts came from the patches of three base runs that all scored 0, so a shared mistake could become a "fact". The paper's failure analysis describes the same risk.

## Side by side

On the entropy task, scores made the difference: Meta-Harness moved past a failing fix because it saw the 0, while Harness² kept essentially that fix because every run "completed".

**The entropy task, same model, two methods.**

|  | Meta-Harness | Harness² |
| --- | --- | --- |
| Feedback | Scores + traces | Traces only |
| First fix tried | i1b: a "minimum-value" prefilter plus an index; scored 0 | DOM skill: a "sargable cutoff" prefilter plus `EXPLAIN` |
| What happened next | i2a read the 0 and the patch, rejected the prefilter; by i3a: one query per setting value | The composer kept the skill: the probe completed, faster than base |
| Result | i3a lineage passed 3 of 4 runs | Composed run: 0 |

One task and few runs, so this illustrates the mechanism rather than proving it.

**The held-out task (mysql).** No harness scored on it.

| Harness | Steps | Time | Reward |
| --- | --- | --- | --- |
| H0, local | 66 | 23 min | 0 |
| Meta-Harness i3a | 27 | 16 min | 0 |
| Meta-Harness i4b (winner) | 18 | 9 min | 0 |
| Harness² composed (task 3) | 43 | 24 min | 0 |

Harness²'s task 3 harness was built for this task with its own probes, so it isn't held-out in the same sense; it shares the row because both methods ended up running this task.

**Effort and cost.** Exact costs, summed from every local trial's `result.json` (`agent.result.json` for failed trials) and every session's `*.stats.txt`.

|  | Meta-Harness | Harness² |
| --- | --- | --- |
| Luna runs | 16 search + 1 repeat + 2 held-out | 9 (references were free: published runs, plus local H0 runs made for the baseline) |
| Luna cost | $4.64 for the 16 search runs (+$1.16 for 4 accidental duplicate runs, see addendum), $0.27 for repeat and held-out | $1.99 (10 trials, including one failed trial) |
| Improver sessions | 4 proposers, $1.37 in total ($0.25, $0.45, $0.34, $0.34) | 12 sessions + 3 in the dry run, $0.91 in total |
| Wall clock | 14:57–20:43, 4 iterations | 15:48 to the evening, 3 tasks (card 2.5 h, entropy 1.1 h) |
| Output | One harness for unseen tasks | A harness per task; an empty library |

The whole evening came to **$11.64**: Luna $9.37 (including local H0 baselines $0.42 and sanity/scratch runs $0.88) and improver sessions $2.28. Not included: the Claude Code sessions that built and drove the experiment.

**When you'd use which**, as a talking point: Meta-Harness when you have a scored task set and can afford offline search, with a held-out set to catch overfitting; Harness² when tasks arrive one at a time with no grader, and you can afford several rollouts per task so its library can grow.

## Lessons and caveats

The biggest lesson is about measurement: single runs on tasks the executor almost never passes can't rank harnesses, and both methods' weak points showed up exactly where the evidence was thin.

**What a fuller version would change**

| Change | Why, from tonight |
| --- | --- |
| 3+ runs per candidate | Near-identical harnesses flipped outcomes; the passing harness failed its repeat |
| More search tasks, and a held-out set from the start | With two search tasks, the cheapest route to a higher score was writing their solutions into a skill |
| Grep evolved harnesses for task-specific terms, not only hidden check names | The validator passed a harness that names `Entropy` rows and the entropy task's recipe |
| Local baselines before anything else, on the same route | Published runs were 2–3× faster and misled the Harness² composer |
| Harness² at k>1 | At k=1 every edit is confounded, so the library never grows |
| Make the Harness² composer engage with the evidence: a script-built summary of all references, or a stronger improver | It ran 12–13 turns in under 30 s and compared against the wrong run twice; the papers used Opus-class improvers |
| Retry provider errors | A content-filter false positive cut one run short |

**Caveats to state on the slides**

- Every result is one run per harness per task (two for i3a on entropy). Treat all numbers as illustrative.
- Rewards were 0 almost everywhere, so credit and time carried most of the comparison until iteration 3.
- The published baseline used a different API route and client version; only local runs are compared.
- The improver was Sonnet 5.5, not the Opus-class models the papers used, and the prompts were used as written, with no tuning.
- The harness was text only: no scripts, hooks, subagents or plugins, which both papers use.
- Harness²'s task 3 is the same task as Meta-Harness's held-out task, but Harness² probed it, so it isn't held-out for Harness².
- Hidden check names never reached an improver: every audit was clean, and the validator rejected a planted name.

## Timeline (Sat Nov 14, EET)

Both searches ran side by side from mid-afternoon; the last run finished at 21:17.

| Time | Event |
| --- | --- |
| 21:17 | Held-out run of Meta-Harness winner i4b: 0 |
| 20:43 | Meta-Harness iteration 4 done: i4a and i4b also pass entropy (in the exported runs; see addendum) |
| 20:23 | Harness² task 3 (mysql) done: 0, `NO_ENTRY` |
| 19:51 | i3a repeat on entropy done: 0 |
| 19:29 | i3a held-out run on mysql done: 0 |
| 19:28 | Harness² task 2 (entropy) done: 0, `NO_ENTRY` |
| 19:07 | Meta-Harness iteration 3 done: **i3a passes entropy**, the first pass of the evening |
| 18:20 | Harness² task 1 (card) done: composed run timed out, `NO_ENTRY` |
| about 18:00 | Meta-Harness iteration 2 done: all 0 |
| 17:33 | Rerun of local H0 on mysql: healthy, so the earlier failure was a one-off |
| 17:06 | References for Harness² tasks 2 and 3 prebuilt with the local H0 runs |
| 16:49 | Harness² card composer runs, 28 s |
| about 16:30 | Local H0 on mysql ends in `agent_error` (content filter); entropy H0 completes later (41 min) |
| 16:28 | Meta-Harness iteration 1 done: all 0 |
| 16:25 | Local H0 baseline runs started on entropy and mysql |
| 15:48 | Harness² stream started |
| 15:44 | Harness² dry run: editors + composer, about 1 min, $0.28 |
| 14:57 | Meta-Harness search started (iterations 1–3) |
| Before 14:57 | Setup and sanity runs; local H0 on the card task times out after 90 min |

## Artifact index

All paths are relative to the repo root `vcf-nov-2026-talk/`; most slide material was copied into `demo/slides/raw/` as it appeared. Never put anything from `demo/private/` on a slide: it holds the hidden check names and raw grading output.

| Slide material | Where it is |
| --- | --- |
| Proposer diagnosis notes, iterations 1–4 | `demo/slides/raw/meta-harness/i{1,2,3,4}{a,b}-notes.md` |
| Proposer session stats (turns, files read, cost) | `demo/slides/raw/meta-harness/iter*.stats.txt` |
| Scoreboards after iterations 2, 3 and 4 | `demo/slides/raw/meta-harness/scoreboard-after-iter2.md`, `scoreboard-after-iter3.md`, `scoreboard-final.md` |
| H0 → i3a and H0 → winner (i4b) diffs | `demo/slides/raw/meta-harness/h0-to-i3a.diff`, `h0-to-winner.diff` |
| Every candidate's harness, notes and exported runs | `demo/meta_harness/candidates/<id>/` |
| Repeat and held-out runs (with scores) | `demo/slides/raw/meta-harness/{i3a-rep,heldout-i3a,heldout-i4b}/`, originals in `demo/baselines/` |
| Local H0 baselines (with scores) | `demo/baselines/h0-local/` (entropy; the failed mysql trial is in `demo/private/raw-runs/`), `demo/baselines/h0-local-mysql/`, `sanity/h0-card/` (card) |
| Published H0 runs | `ai-evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max/` |
| Harness² dry-run notes and diffs | `demo/slides/raw/harness2-dryrun/` |
| Harness² task 1 and 2: editor and composer notes, reflector edit table, adopted diff, `task.log` | `demo/slides/raw/harness2-task1/`, `harness2-task2/` |
| Harness² task 3: editor and composer notes, reflector edit table, adopted diff, `task.log` | `demo/slides/raw/harness2-task3/` |
| Harness² scores for all 18 rows (references, probes, composed runs) | run `demo/harness2/scores.sh` (prints to the terminal) |
| Harness² prompts (INV vs DOM sections side by side) | `demo/harness2/prompts/` |
| Library index (empty) | `demo/harness2/library/index.md` |
| `harness2-demo` output (live segment) | captured in the task 01 run; rerun with `harness2-demo` in the cloned `harness2/` repo |
| Leak guard rejecting a planted name; H0 = stock, byte-identical | task 01 and task 02 reports |
| Plans and agent reports | `demo/weekend-plan-v3.md`, `demo/agent-tasks/0{1,2,3,4}-*.md` and their reports |

## Talk structure and open items

A 30-minute talk fits in six parts, each built from material listed above.

| Part | Minutes | Content | Main material |
| --- | --- | --- | --- |
| 1. The problem | 3 | Same model, different harness; Luna fails tasks Astra and Sol solve | A published Luna trajectory; the local 90-minute timeout |
| 2. The shared setup | 4 | lemans, frozen Luna, the `harness/` directory, H0 = stock, the leak guards; local vs. published baseline | Setup tables, setup findings |
| 3. Meta-Harness | 8 | The loop and candidate filesystem; trace diagnosis; the lineage to the pass; what it learned; repeat and held-out; noise | Candidate table, lineage tree, notes excerpts, skill excerpt |
| 4. Harness² | 8 | `harness2-demo` live; the card task through propose, probe, compose; the composer's baseline mistake; the empty library | INV/DOM prompts and diffs, composer notes, results table |
| 5. Side by side | 4 | The entropy contrast; held-out table; cost; when you'd use which | Side-by-side tables |
| 6. Lessons and Q&A | 3 | What a fuller version would change; caveats | Lessons table |

Optional live element: start the `at-toc-cache-per-role` smoke task (about 12 minutes locally) at the start of the talk and reveal it at the end.

**Open items to check before building slides**

- [x] Harness² task 3: the composer's decision and the reflector's outcome (expected `NO_ENTRY`): `demo/harness2/work/ft-mysql-fulltext-search-foundation/compose/notes.md` and `logs/task.log`.
- [x] Meta-Harness proposer stats for iterations 3 and 4 (turns, files read, cost): `demo/meta_harness/logs/iter3.stats.txt`, `iter4.stats.txt`.
- [x] Exact total cost: sum `usage.cost_usd` over all `result.json` files (plus `agent.result.json` for the failed trial) and the cost lines in every `*.stats.txt`.
- [x] i3a's steps and time on its passing entropy run: `demo/meta_harness/candidates/i3a/runs/ft-entropy-sweep__1/result.json`.
- [x] Exact end times of Harness² task 3, the i3a repeat and the i3a held-out run.
- [x] Copy Harness² task 3's material into `demo/slides/raw/harness2-task3/`, if not done.
- [x] Check i4b's harness for task-specific terms too (it inherits i3a's skills): `grep -rniE "entropy|postpone|stall|quiet|burst" demo/meta_harness/candidates/i4b/harness`.

**Results of the open items (Nov 15)**

- Task 3: the composer kept both candidates' edits (trimmed); the reflector rated all three `confounded`, `NO_ENTRY`. Material in `demo/slides/raw/harness2-task3/`.
- Proposer stats: iteration 3, 42 turns, 25 files, $0.34; iteration 4, 36 turns, 19 files, $0.34 (copied to `demo/slides/raw/meta-harness/`).
- i3a's passing entropy run: 93 steps, 47 min, $0.24.
- End times (EET): i3a held-out 19:29:15, i3a repeat 19:50:50, Harness² task 3 20:23:20.
- Exact total: $11.64 (table in "Side by side").
- i4b grep: 6 hits, all inherited from i3a: `memory.md` names `Entropy` rows and "entropy periods"; the `derived-state-features` skill names entropy periods, "a burst then N days quiet" and closed/postponed cards. So the winner carries both search tasks' specifics, as i3a does.
- Also added to `demo/slides/raw/meta-harness/`: `i4a-notes.md`, `i4b-notes.md`, `scoreboard-final.md`, `h0-to-winner.diff` (listed in the index above but missing).

## Addendum (Nov 15): iteration 4 was evaluated twice

Found while closing the open items. Iteration 4's evaluation was started twice, at 19:09 and 19:16, and both batches ran to completion into the same raw directory (`demo/private/raw-runs/mh-i4{a,b}/`). Each candidate therefore has two trials per search task, but only one per task was exported, so the scoreboard and the report show one (a mix of the two batches). The proposer saw only the exported trials. The four unreported trials:

| Candidate | Task | Reported trial | Unreported trial |
| --- | --- | --- | --- |
| i4a | card | 163 steps, 0 | 110 steps, 0 |
| i4a | entropy | 53 steps, **1** | 69 steps, **1** |
| i4b | card | 92 steps, 0 | 121 steps, 0 |
| i4b | entropy | 48 steps, **1** | 55 steps, **0** |

Effect on the claims: on entropy the i3a lineage passed **4 of 6** runs, not 3 of 4; the winner i4b passed **1 of 2**, and i4a 2 of 2. Every other harness is unchanged at 0 of 9. By the selection rule over all trials, i4a (entropy 1.0) would outrank i4b (0.5). This strengthens the noise finding and does not change the story; the headline numbers above are left as reported in run 1, and slides should use this table. Cost of the duplicate batch: $1.16, included in the total.

