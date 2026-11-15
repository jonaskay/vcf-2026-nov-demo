# Run status report — 2026-11-14 (~16:16 local)

Working dir: `/Users/jk/dev/vcf-nov-2026-talk`. OPENAI_API_KEY values in process args are redacted below.

## 1. Live processes (lemans / run_harness)

| Run | Task | Elapsed | Notes |
|---|---|---|---|
| `mh-i1a` (meta_harness candidate i1a) | ft-card-stalled-quiet-clock | 1:19:08 | Still running. lemans PID 66259, docker exec PID 66723 into `lemans-8fb089e925be`. miniswen limits: `--max-time 5400` (90 min), outer `timeout 5760` (96 min), so it hits the cap in ~11–17 min. |
| `h2-ft-card-stalled-quiet-clock-inv` (harness2, `--no-score`) | ft-card-stalled-quiet-clock | 28:06 | lemans PID 36993, docker exec PID 37326 into `lemans-860f645592ba` |
| `h2-ft-card-stalled-quiet-clock-dom` (harness2, `--no-score`) | ft-card-stalled-quiet-clock | 28:06 | lemans PID 37000, docker exec PID 37327 into `lemans-96c386b289d1` |

`mh-i1b` has no live process, so it has finished.

All runs use model `openai/gpt-6-luna#max` with agent `harnessed-miniswen`, `--max-steps 400 --max-cost 60`.

## 2. result.json files present

- **mh-i1a**: 1 of 2
  - `demo/private/raw-runs/mh-i1a/ft-entropy-sweep/gpt-6-luna-max/ft-entropy-sweep__e1VFGPr/result.json`
  - ft-card-stalled-quiet-clock has **no result yet** (still running, see above)
- **mh-i1b**: 2 of 2
  - `demo/private/raw-runs/mh-i1b/ft-card-stalled-quiet-clock/gpt-6-luna-max/ft-card-stalled-quiet-clock__q2lnuQR/result.json`
  - `demo/private/raw-runs/mh-i1b/ft-entropy-sweep/gpt-6-luna-max/ft-entropy-sweep__XrTOele/result.json`

## 3. Eval logs

`demo/meta_harness/logs/iter1.i1a.eval.log`
```
OK /Users/jk/dev/vcf-nov-2026-talk/demo/meta_harness/candidates/i1a/harness
run_harness: mh-i1a starting 2 task(s) at 14:57:04
```
There are no per-task lines yet. Unlike i1b, i1a has not logged its `harness: loader=...` lines; those may only be written when the run finishes.

`demo/meta_harness/logs/iter1.i1b.eval.log`
```
OK /Users/jk/dev/vcf-nov-2026-talk/demo/meta_harness/candidates/i1b/harness
run_harness: mh-i1b starting 2 task(s) at 14:57:04
run_harness: mh-i1b ft-card-stalled-quiet-clock: harnessed-miniswen [ft-card-stalled-quiet-clock] harness: loader=ok visible_to_commands=true skills=3 prompt_chars=3583
run_harness: mh-i1b ft-entropy-sweep: harnessed-miniswen [ft-entropy-sweep] harness: loader=ok visible_to_commands=true skills=3 prompt_chars=3624
run_harness: mh-i1b done at 15:57:22
```
i1b took about 60 min in total.

## 4. Usage: ft-card-stalled-quiet-clock, baseline vs sanity h0

Base: `ai-evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max/`

| Run | input_tokens | output_tokens | cached_tokens | steps | cost_usd | priced via |
|---|---|---|---|---|---|---|
| baseline `__Dlb1Xjf` | 7,658,431 | 98,104 | 7,460,421 | 67 | 0.1484 | openrouter, ruby_llm 1.16.0 |
| baseline `__heE9FPX` | 5,793,593 | 91,826 | 5,592,765 | 53 | 0.1269 | openrouter, ruby_llm 1.16.0 |
| baseline `__imnQPSN` | 6,188,605 | 77,063 | 6,011,674 | 59 | 0.1207 | openrouter, ruby_llm 1.16.0 |
| **sanity/h0-card `__pNrQIGm`** | **26,822,625** | **537,080** | **26,517,726** | **149** | **0.6617** | openai direct, ruby_llm 2.1.1 (registry 2026-11-14) |

The sanity h0-card run used about 2.5× the steps (149 vs 53–67), about 4× the input tokens and about 6× the output tokens of the three baseline runs, and cost about 5× as much.

It is not a like-for-like comparison:
- **Provider:** the baselines went through `openrouter/openai/gpt-6-luna`; h0 went directly to `openai/gpt-6-luna`.
- **Pricing library:** the baselines were priced with ruby_llm 1.16.0; h0 was priced with ruby_llm 2.1.1.
