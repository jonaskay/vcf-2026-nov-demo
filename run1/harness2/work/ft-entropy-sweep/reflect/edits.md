component: skills/rails-query-perf-change/SKILL.md (new skill) and the trigger line in system.md
candidates: dom, adopted
change: Added a skill with task-specific facts and a checklist, plus one line in system.md telling the agent to cat it for query or performance tasks. The facts were the file locations, the board-then-account period fallback, the two schema dumps, and the existing cards index. The checklist covered a sargable cutoff, EXPLAIN QUERY PLAN, a test, and a final confirmation. The adopted harness carries the same edit.
observed: The dom rollout finished in 47 steps and 1211s, well under the limit. The base runs took about 31 steps and 534s (r1). So this run took more steps and more time than r1, with no sign of a timeout. I did not compare the patches to the base patches, so I can't say whether the patch quality changed. The composer's note says the adopted harness's rollout is one more draw, and only one rollout stands behind the skill.
verdict: confounded
component: system.md (always-on workflow additions)
candidates: inv
change: Added three bullets under step 5. They said to state the behavior to preserve and measure the improvement before and after, to run git status after regenerating files, and to run the wider suite and review the diff. The bullets also claimed the base runs finished in under 20 minutes.
observed: The inv rollout took 102 steps and 3504s, about 58 minutes. That is far above the base runs of about 31 steps and 9 minutes, and it came closer to the 90-minute limit. This is one rollout, so the extra time can't be separated from run-to-run variance. The extra-work instructions are the most plausible cause of the slowdown. I did not check whether the extra work improved the patch.
verdict: confounded
