component: tool_guidance.md
candidates: inv, adopted
change: Replaced the python file-creation example with a ruby one. Added a "no Python in this sandbox" note and a Tests section (run the touched test file, run rubocop, check `git status` for stray files). The adopted version is shortened, and the inv version also asks for a full `bin/rails test` run.
observed: inv finished in 45 steps and the adopted harness in 43, against about 26-27 for the base rollouts. The adopted run took 1460s against 664s for base r1. Nothing shows the python note preventing failed edits or the hygiene lines changing the patch. The extra steps could just as well be the added test and rubocop runs. Every run completed and no result.json carries a score.
verdict: confounded
component: skills/card-query-page/SKILL.md
candidates: dom, adopted
change: Added a new on-demand skill. It holds access-scoping, draft, rich-text, ordering and pagination facts, plus a checklist covering LIKE escaping, blank query, deduplication, `<mark>` escaping, tests and schema sync. The dom version is longer and adds navigation, case-sensitivity and operation notes; the adopted version is trimmed.
observed: dom completed in 60 steps and the adopted run in 43, both slower than the 26-27 step base runs. I found no divergence showing that the skill fixed a base defect. The skill steers toward a LIKE-based search while the task name says fulltext, so it may anchor the approach. A single rollout stands behind each form, and the task has no quality signal.
verdict: confounded
component: system.md
candidates: dom, adopted
change: Added a line to workflow step 5 telling the agent to `cat` the card-query-page skill when the request is a read-only query or page over cards scoped by access.
observed: It only works as the trigger for the skill and cannot be separated from it. The run trajectories show no isolated effect.
verdict: confounded
