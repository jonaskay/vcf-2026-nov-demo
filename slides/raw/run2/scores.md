## Run 2: every rollout, per task and arm

| task | arm | passes | mean credit | outcomes | median steps | median time |
|---|---|---|---|---|---|---|
| ft-local-time-human-clock | H0 local (refs) | 2/3 | 0.33 | completed×3 | 83 | 48 min |
| ft-local-time-human-clock | INV probes | 3/3 | 0.67 | completed×3 | 88 | 50 min |
| ft-local-time-human-clock | DOM probes | 3/3 | 0.50 | completed×3 | 71 | 46 min |
| ft-local-time-human-clock | composed | 3/3 | 0.50 | completed×3 | 72 | 40 min |
| ft-local-time-human-clock | Meta-Harness i4b (transfer) | 3/3 | 0.50 | completed×3 | 76 | 67 min |
| ft-notification-bundle-window-overlap | H0 local (refs) | 0/3 | 0.00 | completed×3 | 80 | 65 min |
| ft-notification-bundle-window-overlap | INV probes | 0/3 | 0.00 | completed×3 | 49 | 25 min |
| ft-notification-bundle-window-overlap | DOM probes | 0/3 | 0.00 | agent_error×2, completed×1 | 0 | 5 min |
| ft-notification-bundle-window-overlap | composed (= inv, not rerun) | – | – | – | – | – |
| ft-notification-bundle-window-overlap | Meta-Harness i4b (transfer) | 0/3 | 0.00 | completed×3 | 63 | 51 min |
| ft-card-reactions | H0 local (refs) | 2/3 | 0.67 | completed×3 | 75 | 49 min |
| ft-card-reactions | INV probes | 3/3 | 0.90 | completed×3 | 67 | 30 min |
| ft-card-reactions | DOM probes | 3/3 | 1.00 | completed×3 | 69 | 23 min |
| ft-card-reactions | composed | 3/3 | 1.00 | completed×3 | 60 | 25 min |
| ft-card-reactions | Meta-Harness i4b (transfer) | 3/3 | 0.70 | completed×3 | 53 | 28 min |
| ft-card-stalled-quiet-clock | H0 local (refs) | 0/3 | 0.00 | completed×3 | 114 | 68 min |
| ft-card-stalled-quiet-clock | H0 local, run 1 (4th data point) | 0/1 | 0.00 | agent_timeout×1 | 149 | 100 min |
| ft-card-stalled-quiet-clock | INV probes | 1/3 | 0.33 | completed×3 | 91 | 69 min |
| ft-card-stalled-quiet-clock | DOM probes | 0/3 | 0.00 | agent_timeout×2, completed×1 | 146 | 91 min |
| ft-card-stalled-quiet-clock | composed (= inv, not rerun) | – | – | – | – | – |
| ft-card-stalled-quiet-clock | Meta-Harness i4b (transfer) | 0/3 | 0.00 | agent_timeout×2, completed×1 | 79 | 91 min |
| ft-entropy-sweep | H0 local (refs) | 1/3 | 0.33 | agent_timeout×1, completed×2 | 67 | 41 min |
| ft-entropy-sweep | H0 local, run 1 (4th data point) | 0/1 | 0.00 | completed×1 | 125 | 41 min |
| ft-entropy-sweep | INV probes | 1/3 | 0.33 | completed×3 | 42 | 26 min |
| ft-entropy-sweep | DOM probes | 0/3 | 0.00 | completed×3 | 47 | 25 min |
| ft-entropy-sweep | composed | 1/3 | 0.33 | completed×3 | 37 | 14 min |
| ft-entropy-sweep | Meta-Harness i4b (transfer) | 0/6 | 0.00 | completed×6 | 55.5 | 46 min |
| ft-mysql-fulltext-search-foundation | H0 local (refs) | 0/3 | 0.00 | completed×3 | 69 | 38 min |
| ft-mysql-fulltext-search-foundation | H0 local, run 1 (4th data point) | 0/1 | 0.00 | completed×1 | 66 | 23 min |
| ft-mysql-fulltext-search-foundation | INV probes | 0/3 | 0.00 | completed×3 | 49 | 22 min |
| ft-mysql-fulltext-search-foundation | DOM probes | 0/3 | 0.00 | completed×3 | 46 | 26 min |
| ft-mysql-fulltext-search-foundation | composed (= inv, not rerun) | – | – | – | – | – |
| ft-mysql-fulltext-search-foundation | Meta-Harness i4b (transfer) | 0/3 | 0.00 | completed×3 | 40 | 19 min |

## Pass rate per arm, whole stream

| arm | passes | mean credit |
|---|---|---|
| H0 local | 5/18 (28%) | 0.22 |
| INV probes | 8/18 (44%) | 0.37 |
| DOM probes | 6/18 (33%) | 0.25 |
| composed | 7/9 (78%) | 0.61 |
| Meta-Harness i4b | 6/21 (29%) | 0.17 |

## Selector

| task | picked | reward | credit | passing outputs in pool | picked a best one | H0 local pass rate |
|---|---|---|---|---|---|---|
| ft-local-time-human-clock | c09 = dom r2 | 1 | 0.50 | 11/12 | yes | 0.67 |
| ft-notification-bundle-window-overlap | c01 = inv r3 | 0 | 0.00 | 0/9 | yes | 0.00 |
| ft-card-reactions | c09 = composed r2 | 1 | 1.00 | 11/12 | yes | 0.67 |
| ft-card-stalled-quiet-clock | c01 = dom r2 | 0 | 0.00 | 1/9 | no | 0.00 |
| ft-entropy-sweep | c12 = dom r3 | 0 | 0.00 | 3/12 | no | 0.33 |
| ft-mysql-fulltext-search-foundation | c03 = dom r2 | 0 | 0.00 | 0/9 | yes | 0.00 |

Picked an H0 output on 0 of 6 tasks.

## Success criteria (pre-registered in rerun-plan-v1.md)

| Level | Criterion | Run 2 | Met |
|---|---|---|---|
| Mechanism | Reflector writes ≥ 2 library entries | 6 (ft-card-reactions, ft-card-stalled-quiet-clock, ft-entropy-sweep, ft-local-time-human-clock, ft-mysql-fulltext-search-foundation, ft-notification-bundle-window-overlap) | yes |
| Mechanism | ≥ 1 later editor reads and cites a library entry | 4 (ft-card-stalled-quiet-clock inv → ft-card-reactions; ft-card-stalled-quiet-clock inv → ft-notification-bundle-window-overlap; ft-entropy-sweep inv → ft-notification-bundle-window-overlap; ft-mysql-fulltext-search-foundation dom → ft-card-stalled-quiet-clock) | yes |
| Mechanism | ≥ 1 verdict helped / hurt / no observed effect | 14 (all verdicts: {'helped': 12, 'confounded': 4, 'hurt': 2}) | yes |
| Outcome | Selected passes at a rate ≥ local H0 | 2/6 = 0.33 vs H0 0.28 | yes |
| Outcome | Strictly better than H0 on ≥ 1 task, or better mean credit | better on 2 task(s); mean credit 0.25 vs 0.22 | yes |

## Engagement misses and retries (reported, not hidden)

none
