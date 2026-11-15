# Task 03: Harness² dry run and stream start, plus a Meta-Harness check

Same project and layout as tasks 01 and 02. The Meta-Harness search started in task 02 (`loop.sh 1 3`, pid 66063) and is still running. This task checks on it, dry-runs the Harness² pipeline, and starts the Harness² stream after the user says go.

New files, placed by the user:

```
demo/harness2/task.sh       one task: refs -> INV + DOM editors -> probes -> composer -> execute -> reflect
demo/harness2/stream.sh     the tasks in order (each reads the library the previous ones left)
demo/harness2/scores.sh     scores for the slides (NOT used in this task)
demo/harness2/prompts/{editor_inv,editor_dom,composer,reflector}.md
demo/tools/leak_check.sh    hidden-name grep for free text (library entries, notes)
```

## Rules (same as task 02, plus three)

1. Never display hidden check names. Do not print `demo/private/*` (including `raw-runs/`), `ai-evals/tasks/*/verification_test.rb`, or any `checks.json`, `verifier.log` or `evidence.json`.
2. Don't edit anything in `demo/agents`, `demo/tools`, `demo/meta_harness` or `demo/harness2`, or `ai-evals/bench.yml`. If something fails, stop that step and report the exact error.
3. Never print API keys.
4. **Spending.** Step 3 is a dry run: 3 Sonnet sessions, capped at $3 + $3 + $4 (the Meta-Harness proposer needed $0.25, so expect a few dollars at most). Step 6 is the real stream, about $10–40 over the night, and starts **only after the user says go**.
5. Never read `*.jsonl` logs beyond the `jq` commands given here.
6. **New:** don't stop, restart or slow down the Meta-Harness loop, and don't touch anything under `demo/meta_harness/candidates/`.
7. **New:** don't run `demo/harness2/scores.sh`, and never copy a score (reward or credit) into anything under `demo/harness2/`. Harness² must work without ground truth: its sessions read that tree.
8. **New:** the machine must not sleep tonight. Use `caffeinate` exactly as given in steps 0 and 6.

Run all commands from the repo root `vcf-nov-2026-talk/`.

## Step 0: Permissions, the running loop, sleep

```sh
chmod +x demo/harness2/*.sh demo/tools/*.sh
for f in demo/harness2/*.sh demo/tools/leak_check.sh; do bash -n "$f" && echo "syntax ok $f"; done
ps -p 66063 -o pid,etime,command || echo "MH LOOP NOT RUNNING"
nohup caffeinate -i -w 66063 >/dev/null 2>&1 &
echo "caffeinate for the MH loop: pid $!"
```

If the loop isn't running, don't restart it. Report the last 30 lines of `demo/meta_harness/logs/loop.log` and stop at the end of step 2.

## Step 1: Static checks (no cost)

```sh
P=ai-evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max
for t in ft-card-stalled-quiet-clock ft-entropy-sweep ft-mysql-fulltext-search-foundation; do
  echo "$t: instruction $(wc -c < ai-evals/tasks/$t/instruction.md) bytes, published trials $(ls -d $P/${t}__*/ | wc -l | tr -d ' ')"
done
demo/tools/leak_check.sh demo/harness2/prompts
grep -nE "private/|raw-runs|ai-evals|sanity/|meta_harness|checks\.json|verifier\.log|evidence\.json|reward|credit" demo/harness2/prompts/*.md || echo "prompts clean"
ls demo/harness2/work demo/harness2/library 2>/dev/null || echo "no earlier Harness² state (expected)"
```

Expected: each task has an instruction and 3 published trials, `CLEAN`, `prompts clean`, and no earlier state.

## Step 2: Meta-Harness status (no cost)

```sh
tail -n 25 demo/meta_harness/logs/loop.log
cat demo/meta_harness/scoreboard.md
for r in demo/meta_harness/candidates/i1*/runs/*/result.json; do
  echo "$r"; jq -c '{outcome, steps, cost_usd, duration_s, reward, credit}' "$r"
done 2>/dev/null
ls demo/meta_harness/logs/
cat demo/meta_harness/logs/iter2.stats.txt 2>/dev/null && cat demo/meta_harness/candidates/i2a/notes.md demo/meta_harness/candidates/i2b/notes.md 2>/dev/null
cat demo/meta_harness/candidates/i2a/validation.txt demo/meta_harness/candidates/i2b/validation.txt 2>/dev/null
```

Iteration 1 started at 14:57, so its 4 runs may still be going. Report whatever exists.

**Count how many iteration 1 runs ended in `agent_timeout`.** The published H0 runs never timed out (9–28 minutes), but our one local H0 run on the card task did. If 3 or more of the 4 iteration 1 runs timed out, the local setup is probably slower than the published one, and step 6 adds the local H0 run as an extra Harness² reference so the composer sees what the base harness does locally.

## Step 3: Harness² dry run (a few dollars, about 15 minutes)

This runs the INV and DOM editors in parallel on the card task, then the composer, with no Luna runs. The real stream reuses both editor proposals, but not the dry-run composition.

```sh
mkdir -p demo/harness2/logs
DRY=1 demo/harness2/task.sh ft-card-stalled-quiet-clock 2>&1 | tee demo/harness2/logs/dryrun.txt
```

If `claude` rejects a flag (`unknown option` or similar), stop and report the error. The flags are the same ones `loop.sh` used in task 02.

Then collect:

```sh
W=demo/harness2/work/ft-card-stalled-quiet-clock
cat $W/logs/*.stats.txt
cat $W/inv/validation.txt $W/dom/validation.txt $W/compose_dry/validation.txt
ls $W/inv/fallback.txt $W/dom/fallback.txt $W/compose_dry/fallback.txt 2>/dev/null || echo "no fallbacks"
for r in $W/refs/r*/result.json; do jq -c . "$r"; done
echo "== INV notes"; cat $W/inv/notes.md
echo "== DOM notes"; cat $W/dom/notes.md
echo "== composer notes"; cat $W/compose_dry/notes.md
diff -ru demo/harnesses/h0 $W/inv/context/harness
diff -ru demo/harnesses/h0 $W/dom/context/harness
diff -ru demo/harnesses/h0 $W/compose_dry/context/harness
grep -c WARNING demo/harness2/logs/dryrun.txt || true
```

All three harnesses passed `validate.sh`, so their contents are safe to print.

## Step 4: Copy talk material (no cost)

```sh
W=demo/harness2/work/ft-card-stalled-quiet-clock
mkdir -p demo/slides/raw/harness2-dryrun demo/slides/raw/meta-harness
cp $W/inv/notes.md demo/slides/raw/harness2-dryrun/inv-notes.md
cp $W/dom/notes.md demo/slides/raw/harness2-dryrun/dom-notes.md
cp $W/compose_dry/notes.md demo/slides/raw/harness2-dryrun/composer-notes.md
diff -ru demo/harnesses/h0 $W/inv/context/harness > demo/slides/raw/harness2-dryrun/inv.diff || true
diff -ru demo/harnesses/h0 $W/dom/context/harness > demo/slides/raw/harness2-dryrun/dom.diff || true
cp demo/meta_harness/candidates/i1a/notes.md demo/slides/raw/meta-harness/i1a-notes.md
cp demo/meta_harness/candidates/i1b/notes.md demo/slides/raw/meta-harness/i1b-notes.md
cp demo/meta_harness/logs/iter1.stats.txt demo/slides/raw/meta-harness/
```

`demo/slides/` is outside every improver's workspace, so copying there is safe.

## Step 5: Go/no-go

The stream may start only if **all** of these hold:

- [ ] Step 3 ended with `dry run done`, and its exit status was 0
- [ ] every `*.stats.txt` ends with `audit: clean`
- [ ] `inv`, `dom` and `compose_dry` all validated `OK` (a fallback doesn't block the go, but list it)
- [ ] exactly 3 reference `result.json` lines, none with `reward` or `credit`
- [ ] no `WARNING` lines in the dry run
- [ ] improver cost of the dry run (last `improver cost so far` line) ≤ $10
- [ ] the MH loop (pid 66063) is still running, or has finished cleanly

Show the user the checklist with each item ticked or not, plus the step 2 timeout count. **Wait for the user to say go.**

## Step 6: Start the stream (after go)

If step 2 found 3 or more timeouts among the iteration 1 runs, first set the extra reference:

```sh
export EXTRA_REFS="$(ls -d $PWD/sanity/h0-card/*/ft-card*/ | head -1)"   # only if 3+ timeouts
```

Then start the stream:

```sh
mkdir -p demo/harness2/logs
nohup caffeinate -i demo/harness2/stream.sh > demo/harness2/logs/stream.log 2>&1 &
echo "stream pid $!"
```

Task 1 reuses the dry-run editor proposals and starts its two probe runs right away. The stream runs the three tasks in order; each takes up to about 4 hours.

About 10 minutes in, take these measurements and add them to the report:

```sh
docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}' | grep lemans
for c in $(docker ps --format '{{.Names}}' | grep '^lemans-' | grep -v -- '-proxy$'); do
  echo "$c: $(docker exec "$c" cat /tmp/lemans-harness.status 2>/dev/null || echo 'no status yet')"
done
tail -n 20 demo/harness2/logs/stream.log
tail -n 20 demo/harness2/work/ft-card-stalled-quiet-clock/logs/task.log
tail -n 5 demo/meta_harness/logs/loop.log
```

Expected: 2 Harness² sandboxes (the probes), plus up to 4 Meta-Harness ones if an iteration is evaluating. Then report. Don't wait for the stream to finish.

## Report template

````markdown
# Task 03 report

## Step 0
- syntax: ok | errors
- MH loop: running (elapsed) | not running
- caffeinate pid:

## Step 1
```
<instruction sizes + trial counts, leak_check, prompt grep, earlier state>
```

## Step 2: Meta-Harness
```
<loop.log tail>
<scoreboard.md>
<i1 result lines>
<iter2 stats, notes and validation, if they exist>
```
- iteration 1 timeouts: N of M finished runs

## Step 3: Harness² dry run
```
<stats files>
<validation lines, fallbacks>
<reference result lines>
<INV, DOM, composer notes>
<three diffs>
```
- WARNING lines:

## Step 4
- copied: yes | errors

## Step 5: Checklist
<ticked list>
- User said go at: <time> | not yet

## Step 6: Stream
- EXTRA_REFS set: yes | no
- Started at, pid:
```
<docker stats, loader status, stream.log tail, task.log tail, loop.log tail>
```

## Anything else unexpected
<free text, or "none">
````

## For the user, after the report

- **Skip task 3 tonight:** `touch demo/harness2/STOP` ends the stream after the task in progress.
- **If a task fails:** rerun `nohup caffeinate -i demo/harness2/stream.sh <remaining tasks...> > demo/harness2/logs/stream2.log 2>&1 &`. The failed task resumes from its last finished stage.
- **Meta-Harness iteration 4** fits next to the stream, since memory isn't a constraint. After `loop.sh 1 3` finishes: `nohup caffeinate -i demo/meta_harness/loop.sh 4 4 > demo/meta_harness/logs/loop4.log 2>&1 &`.
