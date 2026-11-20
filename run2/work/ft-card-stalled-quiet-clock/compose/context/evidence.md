# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 114 | 68 | 22: `app/assets/stylesheets/cards.css`, `app/helpers/cards_helper.rb`, `app/models/account/data_transfer/manifest.rb`, `app/models/account/data_transfer/record_set.rb`, `app/models/card.rb`, `app/models/card/eventable.rb` +16 more | +296/-15 | 8 | 0 | yes | 38 | – |
| base | r2 | completed | 103 | 66 | 31: `app/assets/stylesheets/cards.css`, `app/controllers/boards/columns/cards_controller.rb`, `app/controllers/boards/columns/closeds_controller.rb`, `app/controllers/boards/columns/not_nows_controller.rb`, `app/controllers/boards/columns/streams_controller.rb`, `app/controllers/boards/columns_controller.rb` +25 more | +292/-21 | 18 | 0 | yes | 26 | – |
| base | r3 | completed | 137 | 77 | 37: `app/assets/stylesheets/cards.css`, `app/helpers/cards_helper.rb`, `app/models/assignment.rb`, `app/models/card.rb`, `app/models/card/burstable.rb`, `app/models/card/eventable.rb` +31 more | +296/-24 | 19 | 0 | yes | 43 | – |
| inv | r1 | completed | 87 | 69 | 21: `app/assets/stylesheets/cards.css`, `app/helpers/cards_helper.rb`, `app/models/card.rb`, `app/models/card/eventable.rb`, `app/models/card/stallable.rb`, `app/models/comment/eventable.rb` +15 more | +258/-17 | 8 | 0 | yes | 46 | db-migration |
| inv | r2 | completed | 127 | 71 | 51: `app/assets/stylesheets/cards.css`, `app/controllers/boards/columns/cards_controller.rb`, `app/controllers/boards/columns/not_nows_controller.rb`, `app/controllers/boards/columns/streams_controller.rb`, `app/controllers/boards/columns_controller.rb`, `app/controllers/boards_controller.rb` +45 more | +446/-35 | 11 | 0 | yes | 36 | db-migration |
| inv | r3 | completed | 91 | 57 | 17: `app/assets/stylesheets/cards.css`, `app/models/card.rb`, `app/models/card/burstable.rb`, `app/models/card/eventable.rb`, `app/models/comment/eventable.rb`, `app/models/filter/fields.rb` +11 more | +264/-4 | 10 | 0 | yes | 18 | db-migration |
| dom | r1 | timeout | 121 | 91 | 39: `app/assets/stylesheets/cards.css`, `app/controllers/boards/columns/cards_controller.rb`, `app/controllers/boards/columns/closeds_controller.rb`, `app/controllers/boards/columns/not_nows_controller.rb`, `app/controllers/boards/columns/streams_controller.rb`, `app/controllers/boards/columns_controller.rb` +33 more | +392/-20 | 5 | 0 | no | 39 | card-state-and-index |
| dom | r2 | completed | 147 | 75 | 62: `app/assets/stylesheets/cards.css`, `app/controllers/boards/columns/cards_controller.rb`, `app/controllers/boards/columns/closeds_controller.rb`, `app/controllers/boards/columns/not_nows_controller.rb`, `app/controllers/boards/columns/streams_controller.rb`, `app/controllers/boards/columns_controller.rb` +56 more | +500/-51 | 8 | 0 | yes | 51 | card-state-and-index |
| dom | r3 | timeout | 146 | 91 | 44: `app/assets/stylesheets/cards.css`, `app/controllers/application_controller.rb`, `app/controllers/notifications/trays_controller.rb`, `app/controllers/notifications_controller.rb`, `app/helpers/cards_helper.rb`, `app/models/account/data_transfer/record_set.rb` +38 more | +587/-15 | 8 | 0 | yes | 58 | card-state-and-index |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 114 | 68 | 3/3 | none |
| inv | 3 | 3 | 0 | 91 | 69 | 3/3 | `skills/db-migration` (3/3) |
| dom | 3 | 1 | 2 | 146 | 91 | 2/3 | `skills/card-state-and-index` (3/3) |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
