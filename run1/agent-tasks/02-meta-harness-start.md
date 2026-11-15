# Task 02: Fix-ups, baseline facts, proposer dry run, start the Meta-Harness search

Same project and layout as task 01. The new files are `demo/tools/export_run.sh`, `demo/tools/run_harness.sh` and `demo/meta_harness/{SKILL.md,loop.sh,seed_h0.sh,scoreboard.sh}`. The user has placed them.

## Rules (same as task 01, plus two)

1. Never display hidden check names. Do not print `demo/private/*`, `ai-evals/tasks/*/verification_test.rb`, or any `checks.json`, `verifier.log` or `evidence.json`.
2. Don't edit anything in `demo/agents`, `demo/tools` or `demo/meta_harness`, or `ai-evals/bench.yml`. If something fails, stop that step and report the exact error.
3. Never print API keys.
4. **Spending.** Step 5 costs up to $8 (one Sonnet session). Step 7 is the real search, about $20–40 over 6 hours, and starts **only after the user says go**.
5. **New:** never read `demo/meta_harness/logs/*.jsonl` beyond the `jq` commands given here. They can be large.
6. **New:** don't touch or delete anything under `demo/meta_harness/candidates/` except through the scripts.

Run all commands from the repo root `vcf-nov-2026-talk/` unless a step says otherwise.

## Step 0: Permissions and prerequisites

```sh
chmod +x demo/tools/*.sh demo/meta_harness/*.sh
ls -l demo/tools demo/meta_harness
claude --version
[ -n "$ANTHROPIC_API_KEY" ] && echo "ANTHROPIC_API_KEY set" || echo "ANTHROPIC_API_KEY MISSING"
```

The proposer runs `claude --bare`, which needs `ANTHROPIC_API_KEY` (a subscription token doesn't work with `--bare`). If the key is missing, stop and tell the user.

## Step 1: Redo check 5b properly (no cost)

Task 01's check 5b compared the wrong string. The first match in the trajectory is the stock template stored in `agent.extra.agent_config`, which is the same in every run. This version compares the first user message the model actually received.

```sh
S=$(ls -d sanity/stock/*/at-toc*/ | head -1); H=$(ls -d sanity/h0-toc/*/at-toc*/ | head -1)
jq -r '[.steps[].source] | unique | join(",")' "$S/trajectory.json"
um() { jq -r '[.steps[] | select(.source == "user") | .message][0]' "$1"; }
diff <(um "$S/trajectory.json") <(um "$H/trajectory.json") && echo SAME
um "$H/trajectory.json" | wc -m
```

- Expected: `SAME`, and a character count close to the loader's `prompt_chars=3583` for at-toc.
- If the source values don't include `user`, report the list from the first `jq` command, then rerun `um` with the value that looks like the user or prompt role.

## Step 2: Published baseline facts (no cost)

```sh
P=ai-evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max
for r in $P/ft-card-stalled-quiet-clock__*/result.json $P/ft-entropy-sweep__*/result.json $P/ft-mysql-fulltext-search-foundation__*/result.json; do
  jq -c '{task, outcome: .outcome.name, reward, credit, steps: .usage.steps, cost: .usage.cost_usd, duration}' "$r"
done
ls "$(ls -d $P/ft-card-stalled-quiet-clock__*/ | head -1)"
jq -c '{task, outcome: .outcome.name, reward, credit, steps: .usage.steps, cost: .usage.cost_usd, duration}' sanity/h0-card/*/*/result.json
```

This prints scores and durations only, no check names. It tells us whether the published Luna runs also ran into the 90-minute limit.

## Step 3: Export test (no cost)

```sh
T=$(ls -d sanity/h0-card/*/ft-card*/ | head -1)
rm -rf /tmp/export-test && demo/tools/export_run.sh "$T" /tmp/export-test
ls -la /tmp/export-test
du -h "$T/trajectory.json" /tmp/export-test/trajectory.json
jq '.steps | length' /tmp/export-test/trajectory.json
cat /tmp/export-test/result.json
head -5 /tmp/export-test/steps.tsv
demo/tools/export_run.sh "$T" /tmp/export-test-ns --no-score && cat /tmp/export-test-ns/result.json
rm -rf /tmp/export-test /tmp/export-test-ns
```

Expected: exactly four files (`agent.patch`, `result.json`, `steps.tsv`, `trajectory.json`). The first `result.json` has `reward` and `credit`, and the `--no-score` one has neither.

## Step 4: Seed h0 (no cost)

```sh
demo/meta_harness/seed_h0.sh "$(ls -d sanity/h0-card/*/ft-card*/ | head -1)"
ls demo/meta_harness/candidates/h0/runs
demo/meta_harness/scoreboard.sh
```

Expected: 3 published trials per search task, plus 1 local trial, and a scoreboard with one row for h0.

## Step 5: Proposer dry run (up to $8, about 10–20 minutes)

This runs one Sonnet 5.5 proposer session that writes candidates `i1a` and `i1b`, audits it, and validates both candidates. It starts no Luna runs. The real search later reuses this proposal for iteration 1.

```sh
EVAL=0 demo/meta_harness/loop.sh 1 1 2>&1 | tee demo/meta_harness/logs/dryrun.txt
```

If `claude` rejects a flag (`unknown option` or similar), stop. Report the error and the output of `claude --help | head -80`.

Then collect:

```sh
cat demo/meta_harness/logs/iter1.stats.txt
cat demo/meta_harness/candidates/i1a/validation.txt demo/meta_harness/candidates/i1b/validation.txt
cat demo/meta_harness/candidates/i1a/notes.md demo/meta_harness/candidates/i1b/notes.md
diff -ru demo/meta_harness/candidates/h0/harness demo/meta_harness/candidates/i1a/harness
diff -ru demo/meta_harness/candidates/h0/harness demo/meta_harness/candidates/i1b/harness
grep -c "WARNING" demo/meta_harness/logs/dryrun.txt || true
```

The candidates passed `validate.sh`, so their contents are safe to print.

## Step 6: Go/no-go

The search may start only if **all** of these hold:

- [ ] Step 1 printed `SAME`
- [ ] Step 3 exported exactly four files, and `--no-score` dropped `reward`/`credit`
- [ ] Step 5: `audit: clean`, both candidates `OK`, proposer cost ≤ $8, both `notes.md` exist, no `WARNING` line
- [ ] Docker still has 18 CPUs and ≥ 16 GB (`docker info --format 'CPUs={{.NCPU}} Mem={{.MemTotal}}'`)

Show the user the checklist with each item ticked or not. **Wait for the user to say go.**

## Step 7: Start the search (after go)

This runs iterations 1–3. Iteration 1 reuses the dry-run proposal. Each iteration starts 4 Luna runs in parallel, which can take up to about 100 minutes, plus a proposer session.

```sh
nohup demo/meta_harness/loop.sh 1 3 > demo/meta_harness/logs/loop.log 2>&1 &
echo "loop pid $!"
```

About 10 minutes in, take these three measurements and add them to the report:

```sh
# a) memory per sandbox (names and memory only)
docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}' | grep lemans
# b) loader status inside each running sandbox (not the -proxy containers)
for c in $(docker ps --format '{{.Names}}' | grep '^lemans-' | grep -v -- '-proxy$'); do
  echo "$c: $(docker exec "$c" cat /tmp/lemans-harness.status 2>/dev/null || echo 'no status yet')"
done
# c) loop progress
tail -n 20 demo/meta_harness/logs/loop.log
```

After that, report. Don't wait for the loop to finish.

## Report template

````markdown
# Task 02 report

## Step 0
- chmod done; claude version:
- ANTHROPIC_API_KEY: set | missing

## Step 1: First user message
- source values:
- Result: SAME | DIFFERENT (diff below)
- Character count:

## Step 2: Published baseline
```
<jq lines verbatim, published + local>
<ls of one published trial dir>
```

## Step 3: Export test
```
<ls, du, step count, both result.json, steps.tsv head>
```

## Step 4: Seed
```
<runs listing + scoreboard>
```

## Step 5: Proposer dry run
```
<iter1.stats.txt>
<both validation.txt>
<both notes.md>
<both diffs>
```
- WARNING lines:

## Step 6: Checklist
<ticked list>
- User said go at: <time> | not yet

## Step 7: Search started
- Started at, pid:
```
<docker stats lines>
<loader status lines>
<loop.log tail>
```

## Anything else unexpected
<free text, or "none">
````
