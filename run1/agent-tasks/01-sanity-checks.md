# Task 01: Build H0, test the validator, run the sanity runs

You are setting up a meetup demo of Meta-Harness and Harness² on Rails tasks. The executor is a frozen model (Luna) driven by miniswen inside lemans. Its prompts come from an editable `harness/` directory, loaded by a custom lemans agent plugin. This task checks that the plugin and the base harness (H0) work before any search runs.

Work through the steps in order. When you're done, fill in the report template at the end and give it to the user. Another assistant will read the report, so follow the template exactly.

## Layout

The repo root is `vcf-nov-2026-talk/`. All paths below are relative to it unless a step says otherwise.

```
vcf-nov-2026-talk/
  ai-evals/                 # task corpus + bench.yml; lemans runs from here
  lemans/                   # lemans source, for reading only
  demo/
    agents/harnessed_miniswen.rb   # lemans agent plugin
    agents/harness_loader.rb       # loaded into miniswen in the sandbox
    tools/make_h0.rb               # builds H0 and checks render identity
    tools/validate.sh              # harness validator
    private/hidden_check_names.txt # SECRET, see rules
```

## Rules (read before doing anything)

1. **Never display hidden check names.** Do not `cat`, `head`, `less`, `grep` with output, or otherwise print the contents of any of these:
   - `demo/private/hidden_check_names.txt`
   - `ai-evals/tasks/*/verification_test.rb`
   - any `checks.json`, `verifier.log` or `evidence.json`
   - `/tmp/leak/memory.md` (step 3)

   Commands that read them without printing them, such as the step 3 pipeline or `validate.sh`, are fine. Never paste their content into the report.
2. **Don't edit** `demo/agents/*`, `demo/tools/*` or `ai-evals/bench.yml`. If something fails, stop that step and report the exact error. Don't patch the code to make it pass.
3. **Don't remove Docker containers you didn't start.** A stale sandbox (`lemans-0840b744719b` and its proxy) may be running from an earlier session. Report it and leave it alone.
4. **Never print API keys.** Check that they're set, never what they contain.
5. **Spending.** Step 4 is the only step that costs money, about $1 total. Don't start any other model runs.

## Step 1: Preflight

```sh
cd vcf-nov-2026-talk
ruby -v                                   # need 3.4+
lemans version 2>/dev/null || gem list lemans
gem list miniswen
[ -n "$OPENAI_API_KEY" ] && echo "OPENAI_API_KEY set" || echo "OPENAI_API_KEY MISSING"
docker info --format 'CPUs={{.NCPU}} Mem={{.MemTotal}}'
docker ps --format '{{.Names}}  {{.Status}}'
ls demo/agents demo/tools demo/private
```

Requirements: Docker needs at least **8 CPUs and 12 GB** (`MemTotal` ≥ 12000000000), because step 4 runs 3 sandboxes of 2 CPUs / 2 GB each, and later runs need 4. If it has less, or if `OPENAI_API_KEY` is missing, **stop and tell the user**. Changing Docker Desktop's resources is a manual setting the user has to make.

## Step 2: Build H0

```sh
ruby demo/tools/make_h0.rb demo/harnesses/h0
ls -la demo/harnesses/h0 demo/harnesses/h0/skills
```

- Expected: a line starting with `IDENTICAL`, followed by a character count for each file.
- If it prints `DIFFERENT`, record the three lines it prints and continue with step 3. Skip step 4, because the harnessed runs would not be a valid H0.

## Step 3: Validator tests

```sh
demo/tools/validate.sh demo/harnesses/h0
```

Expected: `OK demo/harnesses/h0`.

Leak test. This appends one hidden check name, in its spaced form, to a copy of H0 without displaying it. The validator must reject the copy.

```sh
rm -rf /tmp/leak && cp -r demo/harnesses/h0 /tmp/leak
cut -f2 demo/private/hidden_check_names.txt | head -1 | sed 's/^VerifierTest#test_//; s/_/ /g' >> /tmp/leak/memory.md
demo/tools/validate.sh /tmp/leak; echo "exit=$?"
rm -rf /tmp/leak
```

Expected: `REJECT /tmp/leak: hidden check name found in: /tmp/leak/memory.md` and `exit=1`.

## Step 4: Three sanity runs in parallel

Skip this step if step 2 printed `DIFFERENT`.

The runs take about 21 minutes for the longest one. Start all three in the background with logs, then poll. Don't wait in the foreground.

```sh
cd ai-evals
rm -rf ../sanity && mkdir -p ../sanity/logs
M='openai/gpt-6-luna#max'

nohup lemans run --backend docker --model "$M" --task at-toc-cache-per-role \
  --runs-dir ../sanity/stock > ../sanity/logs/stock.log 2>&1 &

HARNESS_DIR=../demo/harnesses/h0 nohup lemans -r ../demo/agents/harnessed_miniswen.rb run \
  --backend docker --agent harnessed-miniswen --model "$M" --task at-toc-cache-per-role \
  --runs-dir ../sanity/h0-toc > ../sanity/logs/h0-toc.log 2>&1 &

HARNESS_DIR=../demo/harnesses/h0 nohup lemans -r ../demo/agents/harnessed_miniswen.rb run \
  --backend docker --agent harnessed-miniswen --model "$M" --task ft-card-stalled-quiet-clock \
  --runs-dir ../sanity/h0-card > ../sanity/logs/h0-card.log 2>&1 &

echo started
```

Poll every few minutes until all three logs show a `report` section or an error:

```sh
tail -n 5 ../sanity/logs/*.log
docker ps --format '{{.Names}}  {{.Status}}'
```

If a run fails within the first few minutes (a configuration error, `unknown agent`, a network or proxy error), capture the last 40 lines of its log. Don't retry more than once.

## Step 5: Checks

Run from `ai-evals/`.

**5a. Loader status lines.** The plugin prints one line per harnessed run.

```sh
grep -h "harnessed-miniswen \[" ../sanity/logs/*.log
```

Expected: two lines, each containing `loader=ok`. Record `visible_to_commands=true|false` for each. `NO STATUS FILE` means the run silently used stock prompts. Report that prominently.

**5b. First user message: stock vs. H0.**

```sh
first() { jq -r '[.. | strings | select(startswith("Please solve this issue"))][0]' "$1"; }
S=$(ls -d ../sanity/stock/*/at-toc*/ | head -1); H=$(ls -d ../sanity/h0-toc/*/at-toc*/ | head -1)
diff <(first "$S/trajectory.json") <(first "$H/trajectory.json") && echo SAME
first "$S/trajectory.json" | wc -c
```

Expected: `SAME`, plus a character count. If the outputs differ, include the full `diff` output in the report. It contains only prompt text, never check names. If `first` prints `null`, report that, along with the output of 5d for that trajectory.

**5c. Results and cost.**

```sh
for f in ../sanity/*/*/*/result.json; do
  jq -c --arg f "$f" '{run: ($f|split("/")[2]), task, agent, model, reward, outcome: .outcome.name,
    steps: .usage.steps, cost_usd: .usage.cost_usd, in: .usage.input_tokens,
    cached: .usage.cached_tokens, out: .usage.output_tokens, duration}' "$f"
done
```

The key question is whether `cost_usd` is a non-zero number with OpenAI direct, or `0`/`null`.

**5d. Trajectory structure (keys only).**

```sh
jq -r 'paths | map(if type=="number" then "[]" else . end) | join(".")' "$S/trajectory.json" | sort -u | head -60
ls "$S"
```

## Report template

Fill this in and give it to the user. Paste command output verbatim where the template says so. Keep it free of hidden check names, API keys and the contents of `checks.json`, `verifier.log` and `evidence.json`.

````markdown
# Task 01 report

## Step 1: Preflight
- Ruby / lemans / miniswen versions:
- OPENAI_API_KEY: set | missing
- Docker CPUs / memory:
- Containers running before step 4 (names only):

## Step 2: H0
```
<make_h0.rb output, verbatim>
```

## Step 3: Validator
- H0: <OK line>
- Leak test: <REJECT line>, exit=<n>

## Step 4: Runs
- Started at / all finished at:
- Errors or retries (last 40 log lines for any failure):

## Step 5
### 5a Loader status
```
<grep output, verbatim>
```
### 5b First user message
- Result: SAME | DIFFERENT (diff below) | null
- Character count:
### 5c Results
```
<one JSON line per run, verbatim>
```
### 5d Trajectory keys
```
<paths output, verbatim>
<ls of the trial dir>
```

## Anything else unexpected
<free text, or "none">
````
