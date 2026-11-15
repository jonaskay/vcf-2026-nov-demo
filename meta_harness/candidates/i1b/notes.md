# i1b
Parent: h0
Change: A lean always-on prompt with a requirements-checklist procedure (saved to /tmp/requirements.md, checked against the diff at the end). Three on-demand skills: derived-state-features, query-performance and schema-changes. system.md tells the agent when to cat each one.
Hypothesis: Task-type guidance read only when relevant keeps the context small and gives more precise advice: derive state from timestamps, use literal thresholds, and make performance fixes index-friendly and batched. This should raise credit on spec-heavy tasks without bloating every run.
Evidence: h0/runs/ft-card-stalled-quiet-clock__p1 (it stored a burst timestamp and used bespoke logic, with no tests at the boundaries). h0/runs/ft-entropy-sweep__p1 steps 9-31 (an ad-hoc prefilter plus a temp index, with the schema files hand-edited). Both tasks scored 0 in every h0 run.
