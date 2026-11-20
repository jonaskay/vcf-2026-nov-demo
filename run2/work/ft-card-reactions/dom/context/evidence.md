# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 75 | 49 | 46: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/controllers/cards/comments/reactions_controller.rb`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/public/boards/columns/closeds_controller.rb`, `app/controllers/public/boards/columns/not_nows_controller.rb` +40 more | +403/-143 | 14 | 0 | yes | 21 | – |
| base | r2 | completed | 120 | 55 | 43: `app/assets/stylesheets/card-columns.css`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/my/pins_controller.rb`, `app/controllers/public/boards/columns/closeds_controller.rb`, `app/controllers/public/boards/columns/not_nows_controller.rb`, `app/controllers/public/boards/columns/streams_controller.rb` +37 more | +366/-66 | 7 | 0 | yes | 44 | – |
| base | r3 | completed | 63 | 45 | 38: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/helpers/reactions_helper.rb`, `app/models/card.rb` +32 more | +378/-58 | 4 | 0 | yes | 18 | – |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 75 | 49 | 3/3 | none |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
