# i3b
Parent: i2b
Change: Tighter process: map issue vocabulary to existing code by one grep each, explore ≤12 steps with the first edit by step ~20, smallest-diff rule, switch approach after the same failure twice, keep /app working. Guardrail against adding callbacks across many models. Derived-state skill gets a work order, sliding-window semantics and "latest X" anchoring. memory.md maps auto-close wording to entropy and mentions Event rows. Query skill unchanged.
Hypothesis: The spec task keeps timing out or getting 0 because the agent spends 40-60 steps reading and then sprawls (after_touch hooks across many models, retry loops). A hard early-edit target and minimal footprint should finish with a coherent, correct core.
Evidence: i2a/runs/ft-card-stalled-quiet-clock__1 steps.tsv: first edit at step 56, 124 steps, hooks added to step/tagging/assignment/comment (steps 126-141), repeated eventable.rb edits 115-131, agent_timeout. i2b: first edit at step 41. All scored 0.
