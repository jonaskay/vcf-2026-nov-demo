# Task 04: Why did the local H0 run on the mysql task end in `agent_error`?

Same project and layout as tasks 01–03. Run all commands from the repo root `vcf-nov-2026-talk/`.

## Background

Three pipelines are running and must not be disturbed:
- the Meta-Harness search (`demo/meta_harness/loop.sh`, pid 66063)
- the Harness² stream (`demo/harness2/stream.sh`, started 15:48)
- their `caffeinate` wrappers

At about 16:25 the user started two local runs of the base harness H0, one each on `ft-entropy-sweep` and `ft-mysql-fulltext-search-foundation`:

```sh
demo/tools/run_harness.sh demo/harnesses/h0 h0-local demo/baselines/h0-local \
  ft-entropy-sweep ft-mysql-fulltext-search-foundation
```

The entropy run completed normally (125 steps, 41 minutes). The mysql run ended with `outcome: agent_error` after 398.9 s, with `steps`, `cost_usd`, `reward` and `credit` all null. The agent apparently did no work at all.

The mysql task matters: it is Harness² task 3 tonight and the Meta-Harness held-out task. We need to know whether the failure was a one-off (for example an API rate limit, since up to 8 Luna sessions were running at once) or systematic (the task doesn't run on this machine, for example because a service it needs doesn't start under local Docker). The published runs of this task completed normally, but they didn't run on this machine.

## Rules

1. **Never display hidden check names.** Do not print `demo/private/hidden_check_names.txt`, `ai-evals/tasks/*/verification_test.rb`, or any `checks.json`, `verifier.log` or `evidence.json`. Raw lemans logs under `demo/private/raw-runs/` may contain grading output: read them **only** through the filter-then-`leak_check` pattern in step 3, never with plain `cat`, `head`, `tail` or `less`.
2. **Don't disturb running work.** Don't stop, restart or `renice` any `lemans`, `run_harness.sh`, `loop.sh`, `stream.sh`, `task.sh`, `claude` or `caffeinate` process. Don't stop or remove Docker containers you didn't start in this task, and don't run `docker system prune` or similar.
3. **Don't edit** anything in `demo/agents`, `demo/tools`, `demo/meta_harness`, `demo/harness2`, or `ai-evals/`. Report what you would change instead.
4. **Never print API keys.** Process listings can contain them: always pipe `ps` output through `sed -E 's/(KEY=)[^ ]+/\1<redacted>/g'`.
5. **Spending.** Step 5 starts one Luna run (at most about $0.66 and 100 minutes; if it fails like the first one, a few cents). Step 7 costs the same and starts **only after the user says go**.
6. Don't read the oracle solution or any `*.patch` or `solution*` file under `ai-evals/tasks/`.

## Step 0: Is the broken reference already removed? (no cost)

The failed run must not serve as a Harness² reference. Task 3 hasn't started, so removing it is safe.

```sh
R=demo/harness2/work/ft-mysql-fulltext-search-foundation/refs
ls $R
[ -d $R/r4 ] && rm -rf $R/r4 && echo "removed r4"
ls $R
ls demo/harness2/work/ft-mysql-fulltext-search-foundation
```

Expected at the end: `DONE r1 r2 r3 task.md`, and the task folder holds only `refs` (task 3 not started). If it holds anything else, stop and report.

## Step 1: The failed trial's own record (no cost)

```sh
T=$(dirname "$(ls demo/private/raw-runs/h0-local/ft-mysql-fulltext-search-foundation/*/*/result.json)")
echo "$T"; ls -la "$T"
jq -c '.outcome' "$T/result.json"
jq -c '[.phases[]? | {name, started_at, finished_at}]' "$T/result.json"
jq -c 'del(.phases) | keys' "$T/result.json"
[ -f "$T/agent.result.json" ] && jq -c 'keys' "$T/agent.result.json"
[ -f "$T/trajectory.json" ] && jq -c '{n_steps: (.steps | length), status: .extra.status, final: .final_metrics}' "$T/trajectory.json"
```

If `agent.result.json` has a key like `error`, `message`, `exception` or `status`, print just those keys with `jq -c '{error, message, exception, status}'` (use the key names you found).

Compare with the entropy trial from the same command, which worked:

```sh
E=$(dirname "$(ls demo/private/raw-runs/h0-local/ft-entropy-sweep/*/*/result.json)")
jq -c '[.phases[]? | {name, started_at, finished_at}]' "$E/result.json"
```

## Step 2: How the task differs from the others (no cost)

```sh
ls -la ai-evals/tasks/ft-mysql-fulltext-search-foundation ai-evals/tasks/ft-entropy-sweep
```

Print the configuration files of both tasks (`*.toml`, `*.yml`, `*.yaml`, `*.json`, `Dockerfile*`, `docker-compose*`), but **not** `verification_test.rb`, `instruction.md`, any `*.rb`, `*.patch` or `solution*` file. Look for anything the mysql task needs that the entropy task doesn't: a service (MySQL), a different image, extra setup, a different timeout or resource limit, network hosts.

Also check `ai-evals/bench.yml` for per-task or per-service settings that mention mysql:

```sh
grep -n -i -A3 -B3 "mysql\|service" ai-evals/bench.yml
```

## Step 3: The lemans log, filtered (no cost)

The log is `demo/private/raw-runs/h0-local/ft-mysql-fulltext-search-foundation.log`. Never print it directly. Filter it into a temp file, check that file with `leak_check.sh`, and print it only if it comes back `CLEAN`:

```sh
L=demo/private/raw-runs/h0-local/ft-mysql-fulltext-search-foundation.log
wc -l "$L"
grep -inE "error|exception|fail|refused|denied|429|rate.?limit|timeout|timed out|mysql|health|exit|killed|oom" "$L" \
  | grep -viE "verif|test_|check" | tail -60 > /tmp/mysql-errors.txt
demo/tools/leak_check.sh /tmp/mysql-errors.txt && cat /tmp/mysql-errors.txt
```

Do the same with the first 40 lines and the last 40 lines of the log (`head -40` / `tail -40` into the temp file, then `leak_check.sh`, then `cat`). If `leak_check.sh` reports `LEAK`, don't print that file; say so in the report.

## Step 4: What the machine looks like now (no cost)

```sh
docker ps --format '{{.Names}}  {{.Status}}' | grep lemans
docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}' | grep lemans
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}} {{.CreatedSince}}' | head -20
ps -axo pid,etime,command | grep -E "lemans|run_harness|claude" | grep -v grep | sed -E 's/(KEY=)[^ ]+/\1<redacted>/g' | cut -c1-200
```

## Step 5: Rerun the mysql task alone, and watch it (one Luna run)

Skip this step if `demo/baselines/h0-local-mysql.log` already exists (the user may have started it); then just monitor that run.

```sh
mkdir -p demo/baselines
nohup caffeinate -i demo/tools/run_harness.sh demo/harnesses/h0 h0-local-mysql demo/baselines/h0-local-mysql \
  ft-mysql-fulltext-search-foundation > demo/baselines/h0-local-mysql.log 2>&1 &
echo "rerun pid $!"
```

Then, every 2 minutes for the first 10 minutes, record:

```sh
date '+%H:%M:%S'
docker ps --format '{{.Names}}  {{.Status}}' | grep lemans
for c in $(docker ps --format '{{.Names}}' | grep '^lemans-' | grep -v -- '-proxy$'); do
  echo "$c: $(docker exec "$c" cat /tmp/lemans-harness.status 2>/dev/null || echo 'no status yet')"
done
cat demo/baselines/h0-local-mysql.log
```

The new sandbox is the one that appeared after you started the rerun. Once it has a `loader=ok` status, it's past the point where the first run seems to have died. If it gets that far, also check that the agent is taking steps:

```sh
docker exec <new sandbox> sh -c 'ls -la /app | head -5; ps aux | head -15' | sed -E 's/(KEY=)[^ ]+/\1<redacted>/g'
```

- **If the rerun fails again within 10 minutes:** repeat steps 1 and 3 on the new trial (label `h0-local-mysql`) and compare.
- **If it is still running after 10 minutes with a `loader=ok` status:** the first failure was likely transient. Report, and leave the run going. It can take up to 100 minutes.

## Step 6: Diagnosis

Using everything above, say which of these fits best, and why:
- **A. Transient API problem** (rate limit, connection reset, provider error) on the first run, rerun healthy
- **B. A setup problem specific to this task** (a service or database that doesn't start, image build or pull, resource limit)
- **C. A problem in our agent plugin or loader** for this task only
- **D. Something else**, or not enough information

If B or C, propose the smallest fix, as a description. Don't apply it.

## Step 7: Only if the diagnosis is B or C, and only after the user says go

Check whether the fallback held-out task runs on this machine, with one H0 run:

```sh
nohup caffeinate -i demo/tools/run_harness.sh demo/harnesses/h0 h0-local-cancel demo/baselines/h0-local-cancel \
  ft-cancelled-account-cleanup > demo/baselines/h0-local-cancel.log 2>&1 &
```

Monitor it the same way as step 5 for 10 minutes, then report. Don't wait for it to finish.

## Report template

````markdown
# Task 04 report

## Step 0
```
<refs listing before/after, task folder listing>
```

## Step 1: Failed trial
```
<trial dir listing, outcome, phases, keys, agent.result.json error fields, trajectory summary>
<entropy phases for comparison>
```

## Step 2: Task configuration
```
<file listings, config files of both tasks, bench.yml grep>
```
- Differences that matter:

## Step 3: Filtered log
```
<leak_check result + filtered error lines, head, tail>
```

## Step 4: Machine
```
<docker ps, stats, images, processes (redacted)>
```

## Step 5: Rerun
- started at, pid | skipped (already running)
```
<the 2-minute observations>
```
- status after 10 minutes: running with loader=ok | failed (with the step 1/3 comparison)

## Step 6: Diagnosis
- A | B | C | D, with the evidence
- proposed fix (if B or C):

## Step 7
- not needed | waiting for go | started (observations)

## Anything else unexpected
````
