# Weekend demo plan v3: Meta-Harness and Harness² on Rails tasks

Updated Sat Nov 14, 2026, late afternoon · @Joonas · supersedes v2 (same day)

v3 records the task 02 results, the Harness² pipeline as built, and a schedule that runs both methods side by side tonight. The Meta-Harness search has been running since 14:57.

## 0. Status at a glance

| Area | Status |
|---|---|
| Tooling, executor (OpenAI direct), Docker backend, agent plugin + loader, H0, validator | ✅ done (v2) |
| `export_run.sh`, `run_harness.sh` | ✅ verified on real data in task 02 (4 files, `--no-score` drops reward/credit) |
| H0 = stock, checked on the first user message the model received | ✅ `SAME` (task 02 step 1) |
| Meta-Harness: seed, proposer dry run, audit | ✅ audit clean, both candidates valid, $0.25 |
| **Meta-Harness search, iterations 1–3** | ⏳ running since 14:57 (pid 66063), 4 sandboxes |
| Harness² `task.sh`, `stream.sh`, `scores.sh`, 4 prompts (Appendix H), `leak_check.sh` | ✅ written, mock-tested end to end |
| Agent task 03: H² dry run, go/no-go, start the stream | ⏳ next |
| Harness² stream (3 tasks) | ⏳ tonight, next to the MH search |
| MH iteration 4, held-out run of the winner | ⏳ tonight / Sunday morning |
| Slides | ⏳ Sunday |

Spent so far: about $1.05 (sanity runs $0.80, proposer dry run $0.25).

**Action for you:** the first API key was printed in the task 02 session transcript. Revoke it if you haven't already.

## 1. Goal and framing (unchanged)

The demo shows what naive implementations of [Meta-Harness](https://arxiv.org/abs/2603.28052) and [Harness²](https://arxiv.org/abs/2610.14224) look like on [rails/ai-evals](https://github.com/rails/ai-evals) tasks. It is **illustrative, not a validation**: single runs, no claim that either method wins, and the slides say so.

|  | Meta-Harness | Harness² |
| --- | --- | --- |
| When | Offline, before deployment | Online, task by task |
| Feedback | Scores + raw traces of every prior candidate, via a filesystem | No ground truth; contrasts between reruns of the same task |
| Loop | Propose → evaluate → log everything → repeat | Propose (INV + DOM edits) → Probe → Compose → Reflect into a library |
| Output | One harness, deployed unchanged | A per-task harness, plus a library and `EXPERIENCE.md` lessons |

**Improver for both: Claude Sonnet 5.5** via `claude --bare -p`, with Read/Write/Edit/Glob/Grep only, writes confined to one directory, and a budget cap.

**Never cut:** improvers never see the hidden verifier. Harness² additionally never sees a score of any kind.

## 2. What task 02 taught us

- **The published Luna runs never timed out.** All 9 completed in 534–1,677 s with 26–67 steps, all at reward 0 and credit 0. Our only timeout is the local H0 run on the card task (6,027 s, 149 steps). So Luna's 0.00 is not mainly a time-management failure, as v2 suspected. One open question remains: is the local route (OpenAI direct) slower or more verbose than the published one (OpenRouter), or was that run just unlucky? **Meta-Harness iteration 1's durations answer it**, and task 03 checks them before the Harness² stream starts.
- **The proposer is fast and cheap.** The dry run took 1.5 minutes, 35 turns, 21 file reads and $0.25, against an estimate of 10–20 minutes and up to $8. An iteration's wall-clock time is the Luna runs, nothing else.
- **The proposer diagnosed from traces, as the paper describes.** i1a cites `rg` and `python3` failing at steps 4 and 14 of an entropy-sweep run, and the card run inventing its own column instead of reusing existing concepts. That's slide material already (section 8). It read 21 files, against the paper's median of 82.
- **i1a's memory names concepts seen in the search tasks' traces** (`Card::Stallable`, `Card::ActivitySpike`). They are real classes in the Fizzy codebase, not hidden check names, so the validator passes them. Whether they help on other tasks is exactly what the held-out run tests. It's a good talk point on overfitting.
- **Memory isn't a constraint.** Each sandbox uses 113–125 MiB of its 2 GiB cap and each proxy 11–14 MiB, so 6 sandboxes need under 1 GB. **Harness² can run next to Meta-Harness right away**; v2's 19:30-or-22:00 decision is gone.
- **The loader works in real candidates.** i1a showed `skills=0` and 5,021–5,062 prompt characters; i1b `skills=3` and 3,583–3,624 characters. All four were `visible_to_commands=true`.
- **Small things:** create a `logs/` directory before any `tee` or `nohup` redirect into it (the redirect opens the file before the script runs). A missing `skills/` directory is fine.

## 3. Shared foundation (unchanged from v2)

lemans 1.6.0 with the Docker backend and the published limits (90 min, 400 steps, 300 s per command). Executor `openai/gpt-6-luna#max`. The `harnessed-miniswen` plugin uploads the text-only harness to `/opt/harness`, and the loader re-renders the first user message from it. Leakage controls are the allowlist export, `validate.sh` before every run, sandboxed improver sessions, and an audit of every session's tool calls that stops the pipeline on a forbidden path.

New in v3: `tools/leak_check.sh` applies `validate.sh`'s hidden-name grep to free text that isn't a harness, such as library `EXPERIENCE.md` entries and notes.

## 4. Task selection (unchanged)

| Task | Luna (published) | Others | Meta-Harness | Harness² stream |
| --- | --- | --- | --- | --- |
| ft-card-stalled-quiet-clock | 0.00 | Astra, Sol 1.00 | search | task 1 |
| ft-entropy-sweep | 0.00 | Astra, Sol 1.00 | search | task 2 |
| ft-mysql-fulltext-search-foundation | 0.00 | Opus-xhigh, Astra, Sol 1.00 | held-out | task 3 |

## 5. Project layout (as built)

```
demo/
  agents/  harnesses/h0/  private/  tools/{make_h0.rb, validate.sh, export_run.sh, run_harness.sh, leak_check.sh}
  agent-tasks/01-…, 02-meta-harness-start.md, 03-harness2-start.md
  meta_harness/  SKILL.md loop.sh seed_h0.sh scoreboard.sh scoreboard.md candidates/ logs/
  harness2/
    task.sh  stream.sh  scores.sh
    prompts/{editor_inv,editor_dom,composer,reflector}.md
    library/{index.md, <task>/{harness/, EXPERIENCE.md}}
    work/<task>/
      refs/{task.md, r1..r3/}                         published H0 rollouts, no scores
      inv/  dom/  compose/  reflect/                  one session workspace each: context/ + notes.md
      probe_inv/  probe_dom/  final/                  rollout/ or NO_ROLLOUT.txt
      logs/{task.log, <stage>.jsonl, <stage>.stats.txt, <stage>.eval.log}
    logs/stream.log
  slides/raw/
```

## 6. Meta-Harness (running)

3 iterations × 2 candidates × 2 search tasks, 4 runs in parallel, `loop.sh 1 3` started at 14:57. Iteration 1 reuses the dry-run proposal (i1a: rewritten always-on files with Fizzy facts and a requirements procedure; i1b: a lean prompt plus three on-demand skills). These are two genuinely different hypotheses, as the skill asks.

- **Iteration 4** fits tonight next to Harness². Queue it after iteration 3 finishes (command in task 03's closing notes).
- **Held-out run of the winner** on `ft-mysql-fulltext-search-foundation`: one run, up to 100 minutes. Run it tonight after the last iteration if you're still up, otherwise Sunday morning.
- **Selection** as in v2: mean reward, then mean credit, then cost per pass, then steps. With a 0.00 baseline, credit and time will probably decide.

## 7. Harness² (built)

**k=1 over 3 tasks, as one stream.** Each task is one contrastive step from the paper: the editors propose, the probes run, the composer combines, the composed harness runs, and the reflector writes a lesson into the library. Tasks run in order because each reads the library the earlier ones left. Up to about 4 hours per task: editors about 10 minutes, probes up to 100 minutes in parallel, composer about 10 minutes, execute up to 100 minutes, reflect about 5 minutes.

### Per task (`harness2/task.sh <task>`)

1. **References.** The 3 published H0 rollouts of the task, exported with `--no-score`, plus the task's `instruction.md`.
2. **Propose.** INV and DOM editor sessions in parallel, each editing its own copy of **H0**.
3. **Probe.** Each candidate that differs from H0 runs once, in parallel.
4. **Compose.** One session reads the references, both candidates with diffs, notes and rollouts, and writes the successor. Its notes use the form `kept|revised|dropped -> edit -> trajectory evidence`.
5. **Execute.** The composed harness runs once. This rollout is the task's result.
6. **Reflect.** A read-only session writes an `<edits>` table and either one `<experience>` lesson (cue, lesson, evidence, confidence) or `NO_ENTRY`. The script writes the library entry from that reply and rebuilds `library/index.md`.

Each session gets a workspace with a `context/` directory, as in the paper's code: `task.md`, `harness/` (editable), `references/`, `library/` (a copy), and for the composer and reflector also `base_harness/`, `candidates/{inv,dom}/` and `final/`. Every stage leaves a `DONE` marker, so a rerun resumes. A dry run (`DRY=1`) runs the editors and the composer only, and the real run reuses its editor proposals.

### Where this differs from the paper, and why

| Paper | Here | Why |
|---|---|---|
| Fresh reference rollout(s), k at k=1 = 1 | 3 published H0 rollouts | Free, and it makes the composer's base-set rule ("a defect in 1/k is noise") meaningful. `EXTRA_REFS` can add a local H0 run |
| 8 components incl. scripts, subagents, plugins | Text only: 4 always-on files + skills | Weekend scope; the prompts' component sections are cut to match, and skills load with `cat /opt/harness/skills/<name>/SKILL.md` |
| Skill trigger in systemprompt.md or guardrails.md | Trigger in `system.md` only | Matches `validate.sh` |
| Jinja brace rule | Dropped | The loader concatenates files; no templating |
| Editors can delete files | Emptied files count as deletions | No Bash tool in sessions, by design (leak defense) |
| Benchmark-specific "work" block | Written for Fizzy + miniswen: limits, no Python, time limit grades the current `/app` | Same role as WorkBuddy's code block |
| Selector at k>1 | None | k=1 |
| Library entry written by the pipeline from the reflector's reply | Same | Copied from the official code; the reflector can't write anything |

Kept as in the paper: every task starts from H0 and reuses the library only through the editors (v2 wrongly said "the library's best match"). An invalid proposal gets one retry with the validator's message, then falls back to H0. Candidates identical to H0 (KEEP_BASE) aren't probed. The workspace-facts paragraph stays too, so **a Harness² harness may encode facts about the current task**, while Meta-Harness's rule 4 forbids that. That contrast is worth a slide.

### Guards beyond the shared ones

- **Score guard:** before every session, and after every export, any `result.json` in the workspace with `reward` or `credit` stops the task.
- **No Meta-Harness reads:** MH candidate runs carry scores, so sessions deny `meta_harness/` and the audit flags it.
- **Library leak check:** `leak_check.sh` runs on the lesson, the edit table and the composer notes before they enter the library. A hit skips the entry.

All of this is mock-tested with fake `lemans` and `claude`: dry run and resume, retry and fallback, KEEP_BASE, a failed probe, `NO_ENTRY`, an audit stop on a forbidden read, the score guard on a planted reward, and a full three-task stream with the library growing.

## 8. Talk material

| Slide material | Source | When |
| --- | --- | --- |
| Stock miniswen failing a Fizzy task; the local 90-minute timeout | Published trajectory, `sanity/h0-card` | ✅ |
| `harness2-demo` output, H0 = stock, leak guard rejecting a planted name | Tasks 01–02 | ✅ |
| **Proposer diagnosis from traces** (rg/python3 at steps 4 and 14; invented column) | `i1a/notes.md`, `i1b/notes.md` | ✅ |
| Files read per proposer session (21 vs the paper's 82) | `logs/iter*.stats.txt` | ✅ / tonight |
| INV vs DOM prompt sections side by side | `harness2/prompts/` | ✅ |
| INV/DOM diffs and notes, composer decisions | `harness2/work/<task>/` | dry run today, real runs tonight |
| `EXPERIENCE.md` lessons, and whether task 2 or 3 reused one | `harness2/library/`, task 2–3 editor notes | Sunday morning |
| Scoreboard, H0 → winner diff, held-out result | `meta_harness/` | Sunday morning |
| Results table ("single runs, illustrative only") | `meta_harness/scoreboard.md`, `harness2/scores.sh` | Sunday afternoon |

Task 03 copies the first batch into `slides/raw/`.

## 9. Schedule (revised)

| When | Hands-on | Machine |
| --- | --- | --- |
| Sat now–~16:30 | Place files, run agent task 03: static checks, MH status, H² dry run, go | MH iteration 1 evals |
| Sat ~16:30 | **Go** for the Harness² stream | MH iterations 1–3 + H² task 1 (up to 6 sandboxes) |
| Sat evening | Free; glance at `stream.log` and `loop.log` | MH iterations 2–3, H² tasks 1–2 |
| Sat ~20:30 | Queue MH iteration 4 | MH iteration 4, H² task 2 |
| Sat bedtime | Held-out run of the current MH winner if iteration 4 is done; otherwise leave it | H² tasks 2–3 overnight |
| Sun morning | Collect artifacts; held-out run if not done | Held-out run |
| Sun afternoon | Results table, slides, rehearsal | – |

Worst case, with every Luna run taking the full 100 minutes and the stream starting at 16:30: H² task 1 finishes around 20:00, task 2 around 24:00 and task 3 around 03:30; MH iteration 3 finishes around 20:30 and iteration 4 around 22:30. If local runs take as long as the published ones (9–28 minutes), everything finishes before midnight.

## 10. Cost (revised)

| Item | Volume | Est. cost |
| --- | --- | --- |
| Spent: sanity runs + proposer dry run | – | $1.05 |
| MH evals (Luna) | 12 runs (16 with iteration 4) | ≤ $8 (≤ $11) |
| MH proposers (Sonnet 5.5) | 2–3 more sessions, $8 cap each | ~$1–6 |
| H² probes + executes (Luna) | 9 runs | ≤ $6 |
| H² sessions (Sonnet 5.5) | 3 (dry run) + 12, caps $3–4 each | ~$5–15 likely, ≤ $50 at the caps |
| Held-out run | 1 run | ≤ $0.66 |
| **Total** | | **~$15–35 likely, hard cap $100** |

## 11. Talk flow (about 30 minutes, unchanged)

1. **The problem** (3 min): same model, different harness. A published Luna run failing a Fizzy task that Astra and Sol solve.
2. **The shared setup** (4 min): lemans, frozen Luna, the `harness/` directory, H0 = stock byte for byte, and the leak guards.
3. **Meta-Harness** (8 min): the loop, the candidate filesystem, the proposer's trace diagnosis, the scoreboard, H0 → winner diff, held-out result.
4. **Harness²** (8 min): `harness2-demo` live, then one real task through Propose → Probe → Compose, the INV and DOM prompts, the library and `EXPERIENCE.md`.
5. **Side by side** (4 min): one general harness vs. per-task harnesses plus a library; "must generalise" vs. "may specialise"; results table with caveats; cost and time.
6. **What we cut and Q&A** (3 min): Docker instead of Daytona, text-only harness, single runs, k=1, published references.

## 12. Risks and fallbacks

| Risk | Fallback |
| --- | --- |
| Local runs are much slower than published ones | Task 03 counts MH iteration 1 timeouts; with 3+, the H² stream starts with the local H0 run as an extra reference. Still slow: `touch demo/harness2/STOP` to skip task 3 |
| The laptop sleeps overnight | `caffeinate -i` around the stream and `caffeinate -w` on the MH loop (task 03) |
| 6 concurrent Luna sessions hit an OpenAI rate limit | Runs fail as infrastructure errors (`NO_ROLLOUT.txt`, a warning in `task.log`); rerun the stream, which resumes |
| An editor fails validation twice | Falls back to H0 for that candidate (as in the paper); it shows in `fallback.txt` and the notes |
| The agent's own test names collide with a hidden check name, so `validate.sh` rejects a harness that quotes them | Retry with a neutral message, then fallback; note it on the slide if it happens |
| Every candidate scores reward 0 | Rank by credit and time; present "no improvement" honestly |
| The H² stream fails overnight | It resumes from the last finished stage; at worst present task 1 alone |
| Proposer edits other candidates | Fingerprint warning (none so far) |
| Runaway Sonnet session | Per-session caps, audit stops, $100 global cap |

### Stretch goals, in order

1. Held-out run of the Meta-Harness winner.
2. Meta-Harness iteration 4.
3. A second attempt per run, to show how noisy single runs are.
4. The `at-toc-cache-per-role` smoke task, started at the beginning of the talk and revealed at the end.

## 13. Next actions

1. **You:** revoke the leaked key; place the new files; run agent task 03 (`demo/agent-tasks/03-harness2-start.md`); give the go at step 5.
2. **Tonight:** queue MH iteration 4 after iteration 3; start the held-out run if the search is done before bed.
3. **Sunday morning, in this chat:** bring the scoreboard, the H² `task.log` files and the library; I'll draft the results table and slide outline.

## 14. References

- Meta-Harness paper: [arXiv 2603.28052](https://arxiv.org/abs/2603.28052) ([HTML](https://arxiv.org/html/2603.28052v1)); code: [reference implementation](https://github.com/stanford-iris-lab/meta-harness)
- Harness² paper: [arXiv 2610.14224](https://arxiv.org/abs/2610.14224) ([HTML](https://arxiv.org/html/2610.14224v1)), Appendix H for the prompts; code: [google-research/harness2](https://github.com/google-research/harness2) (`harness2/core/prompts.py` for the reflector prompt and k=1 wording, `harness2/core/library.py` for the library format)
- Tasks and run data: [rails/ai-evals](https://github.com/rails/ai-evals); lemans and miniswen: [rails/lemans](https://github.com/rails/lemans)
