# Run 2 cookbook: from a clean checkout to the success table

Step-by-step recipe for running Harness² run 2 (and the small Meta-Harness side) as designed in
[rerun-plan-v1.md](../rerun-plan-v1.md). Each step says what to run, how long it takes, what it
costs, and what you check before going on. The [README](README.md) has the layout and design notes.

All commands run from `vcf-nov-2026-talk/demo`. Run 2 writes only under `demo/run2/`; raw results
with scores go to `demo/private/raw-runs/r2-*/`.

| Step | What | Luna runs | Time | Cost (estimate) |
| --- | --- | --- | --- | --- |
| 0 | Preflight checks | 0 | 5 min | $0 |
| 1 | Local H0 on candidate tasks 1–3, then the task gate | 9 | ~1.5 h | $3–8 |
| 2 | Dry run on task 1 (sessions only) | 0 | ~15 min | $2–10 |
| 3 | Refs for tasks 4–6 + Meta-Harness transfer | 30 | 2–3 h | $10–30 |
| 4 | The Harness² stream, overnight | up to 54 | 6–18 h | $40–110 |
| 5 | Scores and the success table | 0 | 10 min | $0 |
| 6 | Report, seal, slides | 0 | – | $0 |

Hard stop: the stream refuses to start a task once run 2 has spent `COST_CAP` (default $150).

---

## Step 0: Preflight (every session, before anything else)

```sh
cd ~/dev/vcf-nov-2026-talk/demo

# Run 1 is untouched
(cd run1 && shasum -a 256 -c MANIFEST.sha256 --quiet && echo "run 1 intact")

# Keys, Docker, tools
[ -n "$OPENAI_API_KEY" ] && echo "OPENAI_API_KEY set" || echo "OPENAI_API_KEY MISSING"
[ -n "$ANTHROPIC_API_KEY" ] && echo "ANTHROPIC_API_KEY set" || echo "ANTHROPIC_API_KEY MISSING"
docker info --format '{{.NCPU}} CPUs, {{.MemTotal}} bytes'   # need ≥ 8 CPUs, ≥ 12 GB for 8 sandboxes
lemans version; claude --version; jq --version; python3 --version

# The guard refuses run-1 paths (expect "REFUSING")
RUN_ROOT=run1 harness2/scores.sh --refs ft-saas-billing
```

**Go on when:** "run 1 intact", both keys set, Docker has the resources, and the guard refuses.

If Docker has less than 8 CPUs / 12 GB, lower the parallelism for every command below with
`export MAX_SANDBOXES=4` (each sandbox takes 2 CPUs / 2 GB).

Optional, recommended: commit the run-2 code first, so the exact scripts that produced run 2 are
in git.

```sh
git add -A harness2 meta_harness/transfer.sh tools rerun-plan-v1.md run1 run2/README.md run2/COOKBOOK.md \
        slides/raw "Experiment report Meta-Harness and Harness² on Rails tasks.md"
git commit -m "Run 2: freeze run 1, implement the rerun plan"
```

---

## Step 1: Local H0 on candidate tasks 1–3 (Phase 1)

The published pass rates came from another API route, and local runs were 2–3× slower in run 1.
Before committing to the stream, check that the "varying" tasks actually vary locally.

```sh
harness2/refs.sh ft-local-time-human-clock ft-notification-bundle-window-overlap ft-saas-billing
```

Runs 9 Luna rollouts in parallel; it takes as long as the slowest one (≤ 90 min). Progress:
`tail -f run2/logs/refs.log`.

Then the gate (prints scores to the terminal; don't redirect it into `run2/`):

```sh
harness2/scores.sh --refs ft-local-time-human-clock ft-notification-bundle-window-overlap ft-saas-billing
```

**Go on when:** the last line says `PASS` (≥ 2 of the 3 tasks have a pass or credit > 0 locally).

**If a task is 0/3 locally,** swap it for the next candidate and test that:

```sh
harness2/refs.sh ft-card-reactions
harness2/scores.sh --refs ft-card-reactions
# candidates, in order: ft-card-reactions, ft-board-publish-unpublish-public-boundary, ft-activity-feed-api
```

Then edit `harness2/stream-tasks.txt` so the varying tasks come first and the three run-1 tasks
(card, entropy, mysql) stay last. **Finish this file before step 3**, because the Meta-Harness
transfer runs read it.

Also fine: if a run ends `agent_error` (for example the content filter), `run_harness.sh` reruns it
once by itself. If it still has no record, rerun `refs.sh` with the same arguments: finished
rollouts are skipped.

---

## Step 2: Dry run on task 1 (Phase 2 gate)

Editors, composer and selector with Opus 5.5 on task 1's three H0 refs. No probes and no Luna runs.

```sh
DRY=1 harness2/task.sh "$(head -1 harness2/stream-tasks.txt)"
```

Then inspect `run2/work/<task1>/`:

```sh
T=$(head -1 harness2/stream-tasks.txt); W=run2/work/$T
cat $W/logs/task.log                                  # every stage, single-component OK lines, the pick
grep -h -A1 '^{' $W/logs/*.stats.txt                  # turns and cost per session
grep -h 'distinct files read\|audit' $W/logs/*.stats.txt
cat $W/logs/*.engagement.txt                          # what each checked session opened
cat $W/logs/engagement.txt 2>/dev/null                # misses and retries (absent = none)
cat $W/inv/notes.md $W/dom/notes.md $W/compose_dry/notes.md
diff -ru harnesses/h0 $W/inv/context/harness; diff -ru harnesses/h0 $W/dom/context/harness
tools/leak_check.sh $W/inv/notes.md $W/dom/notes.md $W/compose_dry/notes.md
```

**Go on when:**

- every `audit: clean`, and `leak_check` says `CLEAN`
- each editor changed exactly one component (`single-component: OK` in `task.log`), or said KEEP_BASE
- the composer read `evidence.md` and at least one H0 trajectory (only one arm exists in a dry run)
- the DOM editor's facts cite a run, step and file:line from command output, not from a patch
- the selector opened all 3 candidates and named one in a `choice` block
- sessions took more than a handful of turns. Run 1's composer took 12–13 turns in under 30 s, and
  that was the problem; if you see the same here, stop and look at the prompts before spending.

**If you change a prompt after the dry run,** delete the editor proposals, or the real run reuses
them: `rm -rf run2/work/<task1>/{inv,dom}`. (`compose_dry` and `select_dry` are never reused.)

---

## Step 3: Remaining refs + Meta-Harness transfer (Phase 3)

Both in parallel; together they share the `MAX_SANDBOXES` limit.

```sh
harness2/refs.sh $(tail -3 harness2/stream-tasks.txt) > /dev/null &
meta_harness/transfer.sh > /dev/null &
wait
tail -n 40 run2/logs/refs.log run2/logs/transfer.log
```

`transfer.sh` runs run 1's winner i4b, unchanged, 3× on each stream task plus 3 extra on entropy
(21 runs), from the sealed copy in `run1/`.

**Go on when:** every line in both logs shows an outcome (`completed` or `agent_timeout`), none
says `NO RECORD`. Re-running either script fills only the gaps.

---

## Step 4: The stream, overnight (Phase 4)

```sh
nohup harness2/stream.sh > run2/logs/stream.log 2>&1 &
```

Per task: editors (~minutes) → 6 probes in parallel (≤ 90 min) → composer → 3 composed runs
(≤ 90 min, skipped if the composed harness equals H0 or a candidate) → selector → reflector.

**Watch it:**

```sh
tail -f run2/logs/stream.log                               # one line per task, with spend so far
tail -f run2/work/*/logs/task.log                          # stage by stage
docker ps --format '{{.Names}}' | grep -c lemans           # sandboxes running (≤ MAX_SANDBOXES)
bash -c '. tools/run2_env.sh; echo "Luna \$$(r2_luna_cost), improver \$$(r2_improver_cost)"'
```

**Gate after task 1.** If the reflector rated every edit `confounded`, the stream stops with exit 5
and a `GATE:` line. Before spending on tasks 2–6, read `run2/work/<task1>/reflect/edits.md`,
`reply.reflect*.txt` and `logs/engagement.txt`. Then:

- the mechanism looks right but this task gave no contrast → rerun `stream.sh` (task 1 is skipped)
- something is wrong (sessions not reading, broken validator) → fix it, then
  `rm -rf run2/work/<task1>` and the library entry `run2/library/<task1>` if one was written, and start
  again. Every probe rollout is still in `private/raw-runs/` but will be rerun.

**Other stops and what to do:**

| Exit / sign | Meaning | Action |
| --- | --- | --- |
| `exit 3`, `AUDIT FAILED` or `SCORE GUARD` | a session touched a forbidden path, or a score reached a workspace | **Don't just rerun.** Read `work/<task>/logs/AUDIT_FAILED` and the session's `.jsonl`; fix the cause first |
| `exit 4`, `COST CAP reached` | run 2 spent ≥ `COST_CAP` | review spend; continue with `COST_CAP=200 harness2/stream.sh` if justified |
| `exit 5`, `GATE:` | see above | |
| `exit 1`, `failed` | a stage errored (`ERROR:` in `task.log`) | fix, then rerun `stream.sh`: the task resumes from its last finished stage |
| `REFUSING: ... already being worked on` | another stream/task holds the lock | check `ps`; a dead process's lock clears itself |
| `ENGAGEMENT MISS after the retry` | a session still skipped required files | nothing to do now; it's logged and goes in the report |

To end after the current task: `touch run2/STOP`. To restart later: run the same `nohup` command.
Finished tasks (`work/<task>/DONE`) are skipped.

**Don't** run two streams, or `task.sh` by hand on a task the stream is working on. The locks
refuse it; run 1's iteration 4 was evaluated twice exactly this way.

---

## Step 5: Scores and the success table (Phase 5)

Only after the stream has finished, because scores must never be where a session can read them.

```sh
harness2/scores.sh                                    # whole stream, terminal only
```

It prints:

1. every arm per task: H0 refs, run 1's local H0 (card, entropy, mysql), INV, DOM, composed, i4b transfer
2. pass rate per arm over the stream
3. the selector: what it picked, whether a passing output was in the pool, how often it picked H0
4. the pre-registered success table (mechanism and outcome criteria)
5. every engagement miss and retry

When the stream and all sessions are done, keep a copy for the report and slides:

```sh
mkdir -p slides/raw/run2 && harness2/scores.sh > slides/raw/run2/scores.md
cp run2/library/index.md slides/raw/run2/library-index.md
cat run2/logs/library-task-terms.txt                  # overfitting check: task terms in library entries
tools/leak_check.sh run2/library run2/work/*/compose/notes.md run2/work/*/reflect/edits.md slides/raw/run2
```

### Optional: Sonnet ablation on one task (no new Luna runs)

Separates "Opus vs Sonnet" from "k=3" for the selector and reflector, on the same rollouts. (A
composer ablation would need new composed runs, so it's out of this recipe.)

```sh
T=ft-saas-billing                          # pick a finished task
mkdir -p run2-ablation/work run2-ablation/library
cp -R run2/work/$T run2-ablation/work/
cp -R run2/library/. run2-ablation/library/; rm -rf run2-ablation/library/$T
rm -rf run2-ablation/work/$T/{select,select.map.tsv,select.pool.tsv,select.selected.tsv,reflect,DONE}
RUN_ROOT=run2-ablation IMPROVER_MODEL=claude-sonnet-5-5 harness2/task.sh $T
RUN_ROOT=run2-ablation harness2/scores.sh $T
```

Every earlier stage has its `DONE` file, so only selection and reflection run again.

---

## Step 6: Report, seal, slides

1. **Write the run-2 report** in the same format as run 1's (`run1/Experiment report …md`): summary,
   setup differences from run 1 (k=3 *and* Opus 5.5: say both), the success table filled in whatever
   the outcome, the per-arm table, one library entry with the evidence behind it, the selector's
   picks against per-arm pass rates, card/entropy/mysql run 1 vs run 2, i4b transfer, costs, timeline.
   Material: `slides/raw/run2/`, `run2/work/*/logs/task.log`, `run2/work/*/{inv,dom,compose}/notes.md`,
   `run2/work/*/reflect/edits.md`, `run2/library/`, `run2/logs/stream.log`.
2. **Seal run 2** the same way as run 1 (not in the plan, but it protects the talk numbers):
   ```sh
   (cd run2 && find . -type f ! -name MANIFEST.sha256 ! -path './.slots/*' -print0 | sort -z \
      | xargs -0 shasum -a 256 > MANIFEST.sha256) && chmod -R a-w run2
   ```
3. **Slides**: every slide says which run it shows; run-1 numbers come from `run1/`, run-2 numbers
   from `run2/` and `slides/raw/run2/`. Nothing from `private/` goes on a slide.
4. **Before the talk:**
   ```sh
   (cd run1 && shasum -a 256 -c MANIFEST.sha256 --quiet && echo "run 1 intact")
   (cd run2 && shasum -a 256 -c MANIFEST.sha256 --quiet && echo "run 2 intact")
   ```

---

## Quick reference

| Knob | Default | Where |
| --- | --- | --- |
| `RUN_ROOT` | `demo/run2` | every run-2 script |
| `MAX_SANDBOXES` | 8 | concurrent Luna runs, across all run-2 processes |
| `NREF` / `K` / `KFINAL` | 3 / 3 / 3 | refs / probes per candidate / composed runs |
| `IMPROVER_MODEL` | `claude-opus-5-5` | all Harness² sessions |
| `EDITOR_BUDGET` / `COMPOSER_BUDGET` / `SELECTOR_BUDGET` / `REFLECTOR_BUDGET` | 3 / 6 / 4 / 4 USD | per session |
| `MAX_TURNS` | 60 | per session |
| `COST_CAP` | 150 USD | checked by `stream.sh` before each task |
| `CONTINUE_AFTER_GATE` | 0 | 1 skips the task-1 gate |
| `DRY` | 0 | 1 = sessions only, on the existing refs |
| `K` / `REPEAT` for `transfer.sh` | 3 / 3 | i4b runs per task / extra entropy repeats |
