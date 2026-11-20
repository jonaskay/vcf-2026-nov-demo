# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 67 | 31 | 6: `app/models/card/entropic.rb`, `app/models/entropy.rb`, `db/migrate/20261116000000_add_entropy_sweep_index_to_cards.rb`, `db/schema.rb`, `db/schema_sqlite.rb`, `test/models/card/entropic_test.rb` | +32/-4 | 6 | 0 | yes | 26 | – |
| base | r2 | timeout | 112 | 91 | 7: `app/models/card/entropic.rb`, `app/models/card/eventable/system_commenter.rb`, `db/migrate/20261116120000_add_entropy_sweep_index_to_cards.rb`, `db/schema.rb`, `db/schema_sqlite.rb`, `test/models/card/entropic_test.rb` +1 more | +55/-7 | 9 | 0 | yes | 51 | – |
| base | r3 | completed | 62 | 41 | 2: `app/models/card/entropic.rb`, `test/models/card/entropic_test.rb` | +80/-2 | 10 | 0 | yes | 30 | – |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 2 | 1 | 67 | 41 | 3/3 | none |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
