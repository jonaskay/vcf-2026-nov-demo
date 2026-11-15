# Task 03 report

Written 2026-11-14, about 15:58 EET.

## Step 0
- syntax: `task.sh`, `stream.sh` and `leak_check.sh` are ok. `scores.sh` fails the syntax check:
  ```
  demo/harness2/scores.sh: line 20: syntax error near unexpected token `('
  ```
  The `case … in inv) …` inside `$(…)` doesn't parse under macOS bash 3.2.57, which is what `#!/usr/bin/env bash` runs here. This task doesn't use `scores.sh`, and I didn't edit it.
- MH loop: running (pid 66063, up 47:00 at the start of the task)
- caffeinate pid: 30821 (`-w 66063`)

## Step 1
```
ft-card-stalled-quiet-clock: instruction      931 bytes, published trials 3
ft-entropy-sweep: instruction      996 bytes, published trials 3
ft-mysql-fulltext-search-foundation: instruction      786 bytes, published trials 3
CLEAN
prompts clean
demo/harness2/library:

demo/harness2/work:
```
- Earlier state: `work/` and `library/` already existed, both empty (created 11:16). So there was no earlier state, but the expected "no earlier Harness² state" line didn't print.

## Step 2: Meta-Harness
```
=== iteration 1 (i1a, i1b) 14:57:03
loop: reusing existing proposal for iteration 1
iteration 1 proposer
{"subtype":"success","cost_usd":0.24890469999999998,"turns":35}
tool calls:
  13 Edit
  21 Read
distinct files read: 21
audit: clean
OK .../demo/meta_harness/candidates/i1a/harness
OK .../demo/meta_harness/candidates/i1b/harness
```
```
| rank | candidate | status | mean reward | mean credit | cost/pass | mean steps | per task |
|---|---|---|---|---|---|---|---|
| 1 | h0 | ok | 0 | 0 | $0.33 | 59 | card-stalled-quiet-clock: r=0 c=0 n=4 agent_timeout×1 completed×3<br>entropy-sweep: r=0 c=0 n=3 completed×3 |
| 2 | i1a | no runs | – | – | – | – |  |
| 3 | i1b | no runs | – | – | – | – |  |
```
- i1 result lines: none. The `i1a/runs/` and `i1b/runs/` folders are empty.
- Iteration 2: no stats, notes or validation files yet.
- Iteration 1 timeouts: **0 of 0 finished runs** (both at 15:44 and at 15:47, when the user said go).

## Step 3: Harness² dry run
Exit status 0, ending with `dry run done`. It took about 1 minute (15:44:31 to 15:45:38), not the expected 15.

```
compose_dry  {"subtype":"success","cost_usd":0.0760,"turns":13}  3 Edit, 9 Read, 9 distinct files  audit: clean
dom          {"subtype":"success","cost_usd":0.1242,"turns":10}  2 Edit, 7 Read, 7 distinct files  audit: clean
inv          {"subtype":"success","cost_usd":0.0784,"turns":10}  1 Edit, 8 Read, 8 distinct files  audit: clean
```
```
OK .../work/ft-card-stalled-quiet-clock/inv/context/harness
OK .../work/ft-card-stalled-quiet-clock/dom/context/harness
OK .../work/ft-card-stalled-quiet-clock/compose_dry/context/harness
no fallbacks
```
```
{"task":"ft-card-stalled-quiet-clock","outcome":"completed","steps":67,"cost_usd":0.14838095999999998,"duration_s":1295.5}
{"task":"ft-card-stalled-quiet-clock","outcome":"completed","steps":53,"cost_usd":0.12691882499999999,"duration_s":1677.4}
{"task":"ft-card-stalled-quiet-clock","outcome":"completed","steps":59,"cost_usd":0.120738815,"duration_s":1175.1}
```
- Improver cost so far: $0.28

### INV notes
I made one change, to the workflow section of `system.md`. I read all three `result.json` files and the `steps.tsv` for r1 and r2. I did not open any `trajectory.json`, and I did not read r3's `steps.tsv`.

The three runs all completed, in 53 to 67 steps and 20 to 28 minutes, so the time limit wasn't a problem. No skill or workflow-specific rule seemed warranted.

The old workflow said "create a script to reproduce the issue", which doesn't fit a Rails feature change. The runs wrote tests instead (the stallable model test, the controller test). I replaced it with a procedure that:
- Starts from the requested behaviors, including every place they must show.
- Caps exploration. Every run spent roughly its first 20 steps reading views, CSS and caching code.
- Writes tests with the code.
- Runs narrow tests, then one full suite and rubocop.
- Ends with a diff review.

Two moments motivated the specific warnings:
- **Mangled scripted edits:** r1 had to grep for a literal `\n` after its Ruby string replacements (step 29). r2 had several scripted edits fail with exit code 1 and re-sent them (steps 23, 34, 46, 50 and 51). I added a rule to run `git diff` on the file after any scripted or sed edit. I also added "read the error, fix the input once, don't resend unchanged".
- **Unrelated generated changes:** r1 (steps 34 and 35) and r2 (step 22) both had to deal with changes to `db/cable_schema.rb` or `db/schema_sqlite.rb`. r2 ran `git checkout` on `db/cable_schema.rb`. I added a general line to the diff-review step about unrelated generated changes, such as schema dumps for other databases.

### DOM notes
I added one skill, `skills/card-derived-state/SKILL.md`, and a trigger line for it in `system.md`. I didn't open the trajectories themselves, only `agent.patch` and `result.json` for each run (r3's patch only up to line 200). The workspace facts in the skill come from those patches.

- **Data transfer (divergence):** Only r2 handled export/import. It made the new `cards` column optional in `Account::DataTransfer::Manifest` and `RecordSet`, so older archives still pass `check`, and it added a test. r1 and r3 skipped this. The skill lists it as something to check.
- **Fragment caches (divergence):** The state is time-based, so cached card HTML and JSON would go stale. r1 and r3 put `[card, card.stalled?]` into the cache keys. r2 overrode `cache_version` instead. The skill tells the agent to cover every cached surface, including the turbo_stream previews. Only r1 touched the turbo_stream and notification JSON caches.
- **Touch points that varied between runs:** The runs differed on:
  - whether `Filter::Fields` got a display label (only r3 added one);
  - whether the `my/menus` shortcut was added (only r2);
  - which card surfaces got the badge.

  The skill names the known surfaces and points to `golden` as the closest existing feature to copy.
- **Fixed points all three runs found:**
  - Card concerns go in `app/models/card/*.rb`, registered in the `include` list in `card.rb`.
  - A new index value must be added to both `Card.indexed_by` and `Filter::INDEXES`.
  - Hooks go in `Card::Eventable` and `Comment::Eventable`.
  - A schema change must be made in both `db/schema.rb` and `db/schema_sqlite.rb`.
  - System-user comments are excluded when counting people.
- **Consistency checks:** The scope/predicate boundary, `last_active_at` as the reset signal, and unassign/system events not triggering a burst come from small differences in how the three runs wrote these.

### Composer notes
- kept -> DOM skill `card-derived-state`, with a trigger line in `system.md` -> The base patches diverged on the same points. Only r2 of the three base rollouts handled export/import. Cache-key handling differed across the three. Display surfaces and the filter label also varied. A skill costs nothing until it is read. I trimmed the text and kept the "verify with grep" caveat. I could not check this edit against a candidate rollout: `result.json` is missing from the candidate folders. The proposer also read only the base patches and not the trajectories.
- revised -> INV workflow rewrite in `system.md` -> The proposer cited scripted-edit mangling in r1 (a literal `\n` found at step 29) and repeated failed edit commands in r2. The "create a repro script" step does not suit a Rails feature change, and the base runs wrote tests instead. I shortened the text to limit always-on cost. I dropped the numeric step-cap detail and the `cat <<'EOF'` advice. The submit instruction is kept. I have no candidate rollout evidence that it helps, so this is a low-confidence edit.
- note -> Base rollouts -> r1 completed in 67 steps and about 22 minutes, and the proposer reports that all three base runs completed, so none timed out and none left an empty patch. I did not open any candidate rollout folder, so I did not check those for a timeout or an empty patch.

### INV diff
```diff
--- demo/harnesses/h0/system.md
+++ .../inv/context/harness/system.md
@@ -4,10 +4,10 @@
-1. Analyze the codebase by finding and reading relevant files
-2. Create a script to reproduce the issue
-3. Edit the source code to resolve the issue
-4. Verify your fix works by running your script again
-5. Test edge cases to ensure your fix is robust
+1. Restate the request as observable behaviors (each trigger, threshold, and every place it must show). Read AGENTS.md/STYLE.md, then the existing code and tests for that domain. Stop exploring after ~15 steps or once you know where each behavior goes; discover the rest while editing.
+2. Write a failing test first or alongside the code (no ad-hoc repro scripts left in /app).
+3. Edit with the smallest idiomatic change. Prefer `cat <<'EOF'` for whole files and Edit-style replacements; after any scripted/sed edit, `git diff` that file, since escaped `\n` in ruby/sed edits has silently mangled files. If an edit command fails, read its error and fix the input once; don't resend it unchanged.
+4. Run the narrowest tests (`bin/rails test <file>`), then `bin/rails test` and `bin/rubocop` on changed files while time remains (a single full-suite run is enough; don't loop on unrelated failures).
+5. Review `git status` and `git diff`: no stray files, debug output, or unrelated generated changes (e.g. schema dumps for other databases); every requested behavior covered.
```

### DOM diff
```diff
Only in .../dom/context/harness/skills: card-derived-state
--- demo/harnesses/h0/system.md
+++ .../dom/context/harness/system.md
@@ -9,5 +9,7 @@
 5. Test edge cases to ensure your fix is robust
+When the request adds a derived card state, a new column on cards, a new `indexed_by` value, or a badge shown on cards, run `cat /opt/harness/skills/card-derived-state/SKILL.md` and follow it.
+
 6. Submit your changes ...
```
(The trigger line sits between steps 5 and 6, which breaks the numbered list. The composer moved it.)

### Composer diff
```diff
Only in .../compose_dry/context/harness/skills: card-derived-state
--- demo/harnesses/h0/system.md
+++ .../compose_dry/context/harness/system.md
@@ -4,10 +4,13 @@
-1. Analyze the codebase by finding and reading relevant files
-2. Create a script to reproduce the issue
-3. Edit the source code to resolve the issue
-4. Verify your fix works by running your script again
-5. Test edge cases to ensure your fix is robust
+1. Restate the request as observable behaviors (each trigger, threshold, and every place it must show). Read AGENTS.md/STYLE.md, then the existing code and tests for that domain. Stop exploring after ~15 steps or once you know where each behavior goes.
+2. Write a failing test first or alongside the code (no ad-hoc repro scripts left in /app).
+3. Edit with the smallest idiomatic change. After any scripted/sed edit, `git diff` that file (escaped `\n` has mangled files before). If an edit command fails, fix the input once; don't resend it unchanged.
+4. Run the narrowest tests, then one full `bin/rails test` and `bin/rubocop` on changed files while time remains.
+5. Review `git status` and `git diff`: no stray files or unrelated generated changes (e.g. schema dumps for other databases); every requested behavior covered.
+
+When the request adds a derived card state, a new column on cards, a new `indexed_by` value, or a badge shown on cards, run `cat /opt/harness/skills/card-derived-state/SKILL.md` and follow it.
+
 6. Submit your changes ...
```
- WARNING lines: 0

## Step 4
- copied: yes. 5 files went to `demo/slides/raw/harness2-dryrun/` and 3 to `demo/slides/raw/meta-harness/`.

## Step 5: Checklist
- [x] The dry run ended with `dry run done`, exit status 0
- [x] Every `*.stats.txt` ends with `audit: clean`
- [x] `inv`, `dom` and `compose_dry` validated `OK` (no fallbacks)
- [x] Exactly 3 reference `result.json` lines, none with `reward` or `credit`
- [x] No `WARNING` lines
- [x] Improver cost $0.28, within the $10 limit
- [x] The MH loop (pid 66063) is still running
- Iteration 1 timeouts: 0 of 0 finished
- User said go at: 15:47

## Step 6: Stream
- EXTRA_REFS set: **no.** The timeout count couldn't be made (0 finished runs). It also wouldn't have mattered. The dry run had already finished the card task's `refs` stage, and `task.sh` skips finished stages (`is_done refs`), so `EXTRA_REFS` would never have been read for that task. For the other two tasks it only uses extra refs from the same task, and the local H0 run is a card run.
- Started at 15:48:05, pid 36850 (`caffeinate -i stream.sh`). Still running at 15:58.

Measurements at 15:58:
```
lemans-860f645592ba-proxy 14.46MiB / 15.63GiB 0.00%
lemans-96c386b289d1-proxy 12.98MiB / 15.63GiB 0.00%
lemans-96c386b289d1 110.7MiB / 2GiB 0.01%
lemans-860f645592ba 125.1MiB / 2GiB 0.01%
lemans-8fb089e925be-proxy 12.32MiB / 15.63GiB 0.00%
lemans-8fb089e925be 141.1MiB / 2GiB 0.01%

lemans-96c386b289d1: loader=ok visible_to_commands=true skills=1 prompt_chars=3553   (DOM probe)
lemans-860f645592ba: loader=ok visible_to_commands=true skills=0 prompt_chars=4180   (INV probe)
lemans-8fb089e925be: loader=ok visible_to_commands=true skills=0 prompt_chars=5021   (Meta-Harness, up ~60 min)
```
```
stream.log:
=== stream: ft-card-stalled-quiet-clock starting Sat 15:48:05
task.sh [ft-card-stalled-quiet-clock] 15:48:05 start (dry=0)
task.sh [ft-card-stalled-quiet-clock] 15:48:05 refs: 3 base rollout(s)
task.sh [ft-card-stalled-quiet-clock] 15:48:05 inv: reusing earlier proposal
task.sh [ft-card-stalled-quiet-clock] 15:48:05 dom: reusing earlier proposal
```
```
task.log tail: the dry-run lines (15:44–15:45), then the same four 15:48:05 lines as stream.log
```
```
loop.log tail (unchanged since 14:57):
  21 Read
distinct files read: 21
audit: clean
OK .../candidates/i1a/harness
OK .../candidates/i1b/harness
MH loop pid 66063: running, 1:01:06
```

## Anything else unexpected
- **Meta-Harness iteration 1 is unusually slow.** Its sandboxes went from 3 at 15:44 to 2 at 15:47 to 1 at 15:58, yet `i1a/runs/` and `i1b/runs/` are still empty and the scoreboard hasn't changed. Either results are only written once a candidate's whole evaluation ends, or some runs are ending without output. The remaining sandbox has been up about 60 minutes. The published runs took 9–28 minutes, so long run times locally are likely. I haven't touched the loop.
- **All containers show about 0% CPU,** including the 60-minute Meta-Harness one. This is probably the agents waiting on the model API. If the probes are still at 0% CPU much later, check whether they're stuck.
- **The dry run took about 1 minute,** not the expected 15.
- **`demo/harness2/scores.sh` doesn't parse under bash 3.2** (see Step 0). It needs fixing, or a newer bash, before the slides are made.
- **`demo/harness2/work/` and `library/` already existed,** empty (see Step 1).

## For the user
- **Skip task 3 tonight:** `touch demo/harness2/STOP` ends the stream after the task in progress.
- **If a task fails:** `nohup caffeinate -i demo/harness2/stream.sh <remaining tasks...> > demo/harness2/logs/stream2.log 2>&1 &`. The failed task resumes from its last finished stage.
- **Meta-Harness iteration 4,** after `loop.sh 1 3` finishes: `nohup caffeinate -i demo/meta_harness/loop.sh 4 4 > demo/meta_harness/logs/loop4.log 2>&1 &`.
