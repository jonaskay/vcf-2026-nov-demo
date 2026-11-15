# Step 1 follow-ups: replace ft-saas-billing

Do these **after the current `refs.sh` run has finished** (the local-time and notification
refs). This file has no scores in it, so it can stay in `run2/`.

## Why

All 6 `ft-saas-billing` H0 attempts (r1–r3 and their automatic retries) ended `agent_error` after
less than 2 s of agent time. Every `result.json` has the same error:

```
jail did not start: unshare: pidfd_open failed: Function not implemented
```

Cause: `ai-evals/tasks/ft-saas-billing/environment/Dockerfile` pins its base image to a digest,
`ghcr.io/evilmartians/lemans-fizzy@sha256:606372223ae2…`. That digest is a single-platform
**amd64** image, not a multi-arch index. On this arm64 Mac, Docker builds the task image as amd64
(`lemans-fb56b6bc09c2…`) and runs it under emulation. The emulator doesn't implement the
`pidfd_open` syscall, so the agent's sandbox jail never starts. Even if it did start, an emulated
Rails task would run much slower than the arm64 tasks and skew the local H0 timing that step 1 is
meant to check.

Run 1 never ran this task locally, so this is the first time the problem has come up. Rerunning
`refs.sh` won't help.

**For the report:** saas-billing was dropped because it **can't run on arm64**, not because it
scored 0/3 locally. Don't count it as a task-gate failure.

## Steps

1. **Run the next candidate.** `ft-card-reactions` has no Dockerfile, only an `environment.patch`,
   like the tasks that run fine:
   ```sh
   harness2/refs.sh ft-card-reactions
   ```
2. **Gate on the new trio** (terminal only, don't redirect into `run2/`):
   ```sh
   harness2/scores.sh --refs ft-local-time-human-clock ft-notification-bundle-window-overlap ft-card-reactions
   ```
   Go on when the last line says `PASS`. If `ft-card-reactions` is 0/3 locally, try the next
   candidates in order: `ft-board-publish-unpublish-public-boundary`, then `ft-activity-feed-api`.
   Both use `environment.patch` only, so they should be arm64-safe. Before using any other
   replacement, check that it has no `environment/Dockerfile` pinning an amd64-only base:
   `docker buildx imagetools inspect <base>` must list `linux/arm64`.
3. **Edit `harness2/stream-tasks.txt`:** put the passing replacement where `ft-saas-billing` is
   (line 3), and keep the three run-1 tasks (card, entropy, mysql) last. Finish this before
   step 3, because `meta_harness/transfer.sh` reads this file.
4. **Update the docs:** in `run2/COOKBOOK.md` step 1, replace `ft-saas-billing` in the commands
   and in the ablation example in step 5 (`T=ft-saas-billing`). Also check `rerun-plan-v1.md` and
   `run2/README.md` for task lists that name it.
5. **Handle the leftover raw dirs:** keep `private/raw-runs/r2-h0-ft-saas-billing-{1,2,3}` and
   their `.failed` copies as evidence for the report. They hold only error records, no scores.
   Check whether `run2/baselines/h0/ft-saas-billing/` exists, and remove it if it does, so
   `scores.sh` and the stream don't pick it up.

## Not chosen: keeping saas-billing

Keeping saas-billing would mean rebuilding `lemans-fizzy` for arm64 at the same revision or
running it on an amd64 host. Either way the task environment would differ from its published
one, which is more work and more risk than step 1 needs.
