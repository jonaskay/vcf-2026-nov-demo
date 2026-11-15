# Task 04 report

**Short answer:** The cause is neither a rate limit nor a setup problem. On the 28th model call, OpenAI rejected the prompt with **`invalid_prompt`: "your prompt was flagged as potentially violating our usage policy"**. The agent had been working normally for 6.5 minutes (27 steps, $0.041), and the sandbox and loader were fine. Diagnosis: **D**, a provider content-filter false positive. It isn't in the A–D list as written; it is closest to A (one-off, not caused by the setup). The step 5 rerun is healthy after 10 minutes (`loader=ok`, editing code and running tests), so the task does run on this machine. Step 7 is not needed.

## Step 0
```
--- before
DONE  r1  r2  r3  r4  task.md
r4/result.json: {"outcome":"agent_error","steps":null,"cost_usd":null,"duration_s":398.9}   <- confirmed as the failed run before deleting
r4 contents: agent.patch (3006 B), result.json, steps.tsv (29 rows), trajectory.json (263 KB, 29 steps)
removed r4   (backup copy kept in the session scratchpad, not in the repo)
--- after
DONE  r1  r2  r3  task.md
--- task folder
refs
```
As expected: three refs, and task 3 not started. r1–r3 all `completed` (27/26/42 steps, $0.058/$0.054/$0.081, 664–813 s).

## Step 1: Failed trial
```
demo/private/raw-runs/h0-local/ft-mysql-fulltext-search-foundation/gpt-6-luna-max/ft-mysql-fulltext-search-foundation__s2TV2wK
  agent.patch         3006
  agent.result.json 629753
  result.json         1613
  trajectory.json   295168

outcome: {"name":"agent_error","scored":false,
  "detail":"miniswen: the model call failed: Invalid prompt: your prompt was flagged as potentially
   violating our usage policy. ... {"error":{"type":"invalid_request_error","code":"invalid_prompt"}}"}

phases:
  environment_setup  14:24:46.816Z -> 14:24:54.754Z   (8 s)
  agent              14:24:54.754Z -> 14:31:25.764Z   (6 m 31 s)
  (no verifier phase)

result.json keys (minus phases): agent duration finished_at index lemans_version metadata model outcome
  profile_digest revision started_at tags task task_digest trial
agent.result.json keys: cache_id cached_tokens cost_source cost_usd error input_tokens messages
  output_tokens status steps submission thinking_tokens version

agent.result.json error fields:
  status: "error"
  error:  (same invalid_prompt message as above)
  steps: 27, cost_usd: 0.041451585 (model_registry, openai/gpt-6-luna#max), input_tokens: 1372393,
  output_tokens: 37947, messages: 74

trajectory: {"n_steps":29,"status":"error",
  "final":{"total_prompt_tokens":1372393,"total_completion_tokens":37947,"total_cached_tokens":1296076,
           "total_cost_usd":0.041451585,"total_steps":27,"extra":{"total_reasoning_tokens":31277}}}

--- entropy trial (same command, worked)
  environment_setup  14:24:46.575Z -> 14:24:54.758Z   (8 s)
  agent              14:24:54.758Z -> 15:05:37.424Z   (40 m 43 s)
  verifier           15:05:37.612Z -> 15:06:04.159Z
  outcome: completed, scored
```
- **The agent did work.** It ran 27 model steps and exploration commands (Rails views, helpers, gems). The last command, at 14:31:16Z, was a `grep` for `filter_hotkey_link`. The tool outputs right before the rejection are ordinary app code (`GearedPagination::Ratios`, `_comment.html.erb`, `My::MenuHelper`). Nothing in them looks policy-sensitive.
- The `null`s in `result.json` (and in the Harness² ref r4) come from export/report code that drops `steps`/`cost_usd` when the outcome is `agent_error`. The real numbers are in `agent.result.json`. The lemans summary also printed **`$0.0000`** for this trial when $0.041 was actually spent, so failed trials are missing from the cost totals.
- Setup took 8 s for both trials, and the mysql setup finished in the same second as entropy's.
- Across all local runs in `demo/private/raw-runs` (10 trials), this is the **only** `invalid_prompt`. The others: 8 completed, 1 agent_timeout.

### What input was flagged? (follow-up question)
- OpenAI doesn't say which part of a prompt its filter flagged. The rejected call (#28) sent the whole conversation: 74 messages, about 226k chars. That was the system message (63), the H0/task prompt (3,203), 27 assistant turns (1,411 chars, almost all bare tool calls with empty text) and 45 tool outputs (222k chars of repository content).
- **Call 27 sent messages 0–71 and was accepted.** The only new content in call 28 was:
  - msg 72: `grep -R "def filter_hotkey_link" -n app/helpers && sed -n '1,180p' app/helpers/my/menu_helper.rb; grep -R "filter_hotkey_link" -n app`
  - msg 73: the output, 2,615 chars: `My::MenuHelper` (jump field, board/tag/user/filter menu items) and three `filter_hotkey_link` call sites ("Home", "Assigned to me", "Added by me").
  None of that is plausibly policy-relevant.
- A keyword scan of all tool outputs (violence, sexual, drugs, self-harm, hacking, credentials, prompt-injection or "reveal reasoning" phrasing, email addresses) found only ordinary Rails auth code: `Authentication` concern, `session_token` cookie helper, Passkeys view, schema dump, Action View `highlight`. leak_check: CLEAN.
- One blind spot: the assistant turns carry `thinking_signature`, so the model's encrypted reasoning goes back to OpenAI on every call. If the filter also looks at that reasoning, the trigger could be in text we can't read.
- Conclusion: **no identifiable trigger in the input.** It looks like a false positive from a filter that isn't deterministic. The visible part of the prompt grew only by benign menu-helper code between an accepted call and the rejected one.

## Step 2: Task configuration
```
ai-evals/tasks/ft-entropy-sweep:
  RATIONALE.md 1117, environment.patch 10932, instruction.md 996, solution.patch 4516, verification_test.rb 5057
ai-evals/tasks/ft-mysql-fulltext-search-foundation:
  RATIONALE.md 1213, environment.patch 108974, instruction.md 786, solution.patch 108932, verification_test.rb 8345

Config files (*.toml, *.yml, *.yaml, *.json, Dockerfile*, docker-compose*): none in either task.

grep -n -i "mysql|service" ai-evals/bench.yml: no matches
bench.yml (global, applies to every task): cpus 2, memory 2GB, build_timeout 30m, network public during
  setup, agent timeout 90m, exec_timeout 300, verifier timeout 10m. No per-task entries for either task.
```
- Differences that matter: **none on the configuration side.** Neither task declares a service, its own image, or its own limits, and bench.yml treats them the same. The only visible difference is that mysql's `environment.patch` is about 10× larger (109 KB vs 11 KB). Per rule 6 I did not open it. Despite its name, the task doesn't start a MySQL service, and its setup phase took 8 s with no errors.

## Step 3: Filtered log
The log has only 9 lines, so the head -40 and tail -40 outputs are the whole file. All three filtered files came back **CLEAN** from `leak_check.sh`.
```
## error filter: CLEAN
1: run  ft-mysql-fulltext-search-foundation  attempt 1/1  ft-mysql-fulltext-search-foundation__s2TV2wK
2: harnessed-miniswen [ft-mysql-fulltext-search-foundation] h0: loader=ok visible_to_commands=true skills=0 prompt_chars=3203
3: invalid  ft-mysql-fulltext-search-foundation  agent_error   398.9s
4: error  miniswen: the model call failed: Invalid prompt: your prompt was flagged as potentially violating our usage policy. ...
6: report  collecting results from .../raw-runs/h0-local/ft-mysql-fulltext-search-foundation
8: ft-mysql-fulltext-search-foundation  harnessed-miniswen  gpt-6-luna#max  -  agent_error  -  -  -  6m 39s  ..._s2TV2wK

## head -40 / tail -40 (whole file): CLEAN
  (same lines as above, plus the summary table header and)
  1 trials: 0 scored, 1 invalid, 0 solved · $0.0000
```
- `loader=ok`, so **the first run had already passed the loader**. The task file assumes the run died before `loader=ok`, and that's wrong: it died later, in the middle of the agent loop.
- No 429, rate-limit, connection, timeout, OOM or MySQL errors.

## Step 4: Machine (17:33:37, just before the rerun)
```
lemans-047de83bc107-proxy  Up 44 minutes      17.2MiB / 15.63GiB  0.00%
lemans-047de83bc107        Up 44 minutes     134.6MiB / 2GiB      0.01%   (Harness² ft-card-stalled-quiet-clock)
lemans-74c6c0154551-proxy  Up About an hour   17.8MiB             0.00%
lemans-74c6c0154551        Up About an hour   143MiB / 2GiB       0.02%   (Meta-Harness i2a/i2b)
lemans-ce52d40977ce-proxy  Up About an hour   16.1MiB             0.00%
lemans-ce52d40977ce        Up About an hour   142MiB / 2GiB       0.02%   (Meta-Harness i2a/i2b)

images: lemans-40b9ba32… 138MB, lemans-a11ea245… 3.23GB, lemans-a437e71a… 1.9GB (all 6 h old), plus unrelated
  non-lemans images (postgres:18, devcontainers, gcloud emulators, alpine)

processes (redacted):
  21320/21350/21351  run_harness.sh --no-score …/harness2/work/ft-card-stalled-quiet-clock/… (lemans, 44 min)
  94176/94178/94247/94249/94253/94255  run_harness.sh …/meta_harness/candidates/i2a + i2b (lemans, 63 min)
  plus the docker exec children and the claude sessions
```
Three sandboxes are running, using little memory and CPU, and there is no resource pressure. `demo/baselines/h0-local-mysql.log` did not exist, so step 5 runs.

## Step 5: Rerun
- started at 17:33:47, pid 81175 (`nohup caffeinate -i run_harness.sh … h0-local-mysql …`)
- new sandbox: `lemans-c4aac25bf24d` (+ `-proxy`), the only container that appeared after the start
```
17:35:55  lemans-c4aac25bf24d  Up 2 minutes   loader=ok visible_to_commands=true skills=0 prompt_chars=3203
17:37:56  lemans-c4aac25bf24d                 loader=ok (same)
17:39:56  lemans-c4aac25bf24d                 loader=ok (same)
17:41:56  lemans-c4aac25bf24d                 loader=ok (same)
17:43:56  lemans-c4aac25bf24d                 loader=ok (same)
h0-local-mysql.log at every check:
  OK /Users/jk/dev/vcf-nov-2026-talk/demo/harnesses/h0
  run_harness: h0-local-mysql starting 1 task(s) at 17:33:47
rerun pid 81175 alive at every check. The other three sandboxes were unchanged and all loader=ok.

17:44 inside the sandbox:
  ps: timeout 5760 … miniswen -q --no-refresh-registry --jail -m openai/gpt-6-luna#max …  (running)
  git status in /app:  M app/models/card.rb
                       M config/routes.rb
                      ?? app/controllers/search_controller.rb
                      ?? app/views/search/  (index.html.erb, _result.html.erb)
                      ?? test/controllers/search_controller_test.rb
  log/test.log last written 17:39:37 (the agent ran tests)
```
- status after 10 minutes: **running with loader=ok.** The agent is editing code and running tests, and it is already further along than the first run got (the first run was still exploring at 6.5 minutes). I left it running. It can take up to 100 minutes; the time limit is 96 minutes (`timeout 5760`).

## Step 6: Diagnosis
- **D, closest to A.** It was a transient provider-side rejection, but a content-filter false positive (`invalid_prompt`, "flagged as potentially violating our usage policy"), not a rate limit or a connection error.
  - The provider's error message says so directly, in `result.json`, `agent.result.json` and the lemans log. There is no 429, timeout or connection error anywhere.
  - It is not B: the configuration is the same as entropy's (no service, image or limit specific to the task), setup took 8 s for both, there was no resource pressure, and the agent ran 27 steps in a working sandbox.
  - It is not C: the loader reported `loader=ok` in both runs, and our plugin doesn't touch model calls.
  - It is not systematic: r1–r3 (published) completed, the rerun on this machine is healthy past 10 minutes, and it is the only `invalid_prompt` in 10 local trials. The call before the rejection was accepted, and the only new content in the rejected call was benign menu-helper code (see "What input was flagged?" above).
- No B/C fix is needed. Things I would change, but have **not** applied (they are in `demo/tools` or upstream):
  1. **Tonight's risk:** a single `invalid_prompt` ends a trial with no retry. If it hits Harness² task 3 or the Meta-Harness held-out run, that trial is lost. The smallest mitigation is in `run_harness.sh` (or the scripts that call it): when the outcome is `agent_error` **and** the detail contains `invalid_prompt`, rerun that trial once, under a new label. A retry inside miniswen would be better, but it is upstream.
  2. The export/summary reports `steps`/`cost_usd` as `null` and `$0.0000` for `agent_error` trials, but `agent.result.json` has steps 27 and $0.041. Budget totals undercount failed trials, so the exporter should fall back to `agent.result.json`.

## Step 7
- **not needed.** The diagnosis is D, not B or C. The mysql task runs on this machine, so the fallback held-out task doesn't need checking. Nothing was started.

## Anything else unexpected
- The task file assumed the first run died before `loader=ok`. It didn't: its log shows `loader=ok`, and it died 6.5 minutes into the agent loop.
- The "agent did no work" impression came only from the nulls in `result.json` and the r4 export. The agent had taken 27 steps.
- Cost: the first run cost $0.041 (not $0). The rerun is in progress, and its cap is about $0.66.
