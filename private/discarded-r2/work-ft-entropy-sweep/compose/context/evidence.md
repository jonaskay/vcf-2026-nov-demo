# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 67 | 31 | 6: `app/models/card/entropic.rb`, `app/models/entropy.rb`, `db/migrate/20261116000000_add_entropy_sweep_index_to_cards.rb`, `db/schema.rb`, `db/schema_sqlite.rb`, `test/models/card/entropic_test.rb` | +32/-4 | 6 | 0 | yes | 26 | – |
| base | r2 | timeout | 112 | 91 | 7: `app/models/card/entropic.rb`, `app/models/card/eventable/system_commenter.rb`, `db/migrate/20261116120000_add_entropy_sweep_index_to_cards.rb`, `db/schema.rb`, `db/schema_sqlite.rb`, `test/models/card/entropic_test.rb` +1 more | +55/-7 | 9 | 0 | yes | 51 | – |
| base | r3 | completed | 62 | 41 | 2: `app/models/card/entropic.rb`, `test/models/card/entropic_test.rb` | +80/-2 | 10 | 0 | yes | 30 | – |
| inv | r1 | completed | 58 | 23 | 5: `app/models/card/entropic.rb`, `db/migrate/20260219120000_add_board_activity_index_to_cards.rb`, `db/schema.rb`, `db/schema_sqlite.rb`, `test/models/card/entropic_test.rb` | +38/-12 | 11 | 0 | yes | 31 | – |
| inv | r2 | completed | 55 | 19 | 5: `app/jobs/card/auto_postpone_all_due_job.rb`, `app/models/card/entropic.rb`, `config/recurring.yml`, `test/jobs/card/auto_postpone_all_due_job_test.rb`, `test/models/card/entropic_test.rb` | +50/-4 | 4 | 0 | yes | 35 | – |
| inv | r3 | completed | 38 | 21 | 2: `app/models/card/entropic.rb`, `test/models/card/entropic_test.rb` | +26/-4 | 8 | 0 | yes | 13 | – |
| dom | r1 | completed | 35 | 23 | 3: `app/models/card/entropic.rb`, `config/brakeman.ignore`, `test/models/card/entropic_test.rb` | +93/-6 | 7 | 0 | yes | 13 | card-query-performance |
| dom | r2 | completed | 77 | 42 | 6: `app/models/card/entropic.rb`, `config/brakeman.ignore`, `db/migrate/20261117202534_add_board_status_last_active_index_to_cards.rb`, `db/schema.rb`, `db/schema_sqlite.rb`, `test/models/card/entropic_test.rb` | +153/-15 | 8 | 0 | yes | 9 | card-query-performance |
| dom | r3 | completed | 63 | 48 | 3: `app/models/card/entropic.rb`, `config/brakeman.ignore`, `test/models/card/entropic_test.rb` | +101/-14 | 9 | 0 | yes | 29 | card-query-performance |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 2 | 1 | 67 | 41 | 3/3 | none |
| inv | 3 | 3 | 0 | 55 | 21 | 3/3 | none |
| dom | 3 | 3 | 0 | 63 | 42 | 3/3 | `skills/card-query-performance` (3/3) |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
