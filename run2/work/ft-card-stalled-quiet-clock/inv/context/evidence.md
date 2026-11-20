# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 114 | 68 | 22: `app/assets/stylesheets/cards.css`, `app/helpers/cards_helper.rb`, `app/models/account/data_transfer/manifest.rb`, `app/models/account/data_transfer/record_set.rb`, `app/models/card.rb`, `app/models/card/eventable.rb` +16 more | +296/-15 | 8 | 0 | yes | 38 | – |
| base | r2 | completed | 103 | 66 | 31: `app/assets/stylesheets/cards.css`, `app/controllers/boards/columns/cards_controller.rb`, `app/controllers/boards/columns/closeds_controller.rb`, `app/controllers/boards/columns/not_nows_controller.rb`, `app/controllers/boards/columns/streams_controller.rb`, `app/controllers/boards/columns_controller.rb` +25 more | +292/-21 | 18 | 0 | yes | 26 | – |
| base | r3 | completed | 137 | 77 | 37: `app/assets/stylesheets/cards.css`, `app/helpers/cards_helper.rb`, `app/models/assignment.rb`, `app/models/card.rb`, `app/models/card/burstable.rb`, `app/models/card/eventable.rb` +31 more | +296/-24 | 19 | 0 | yes | 43 | – |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 114 | 68 | 3/3 | none |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
