# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 75 | 49 | 46: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/controllers/cards/comments/reactions_controller.rb`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/public/boards/columns/closeds_controller.rb`, `app/controllers/public/boards/columns/not_nows_controller.rb` +40 more | +403/-143 | 14 | 0 | yes | 21 | – |
| base | r2 | completed | 120 | 55 | 43: `app/assets/stylesheets/card-columns.css`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/my/pins_controller.rb`, `app/controllers/public/boards/columns/closeds_controller.rb`, `app/controllers/public/boards/columns/not_nows_controller.rb`, `app/controllers/public/boards/columns/streams_controller.rb` +37 more | +366/-66 | 7 | 0 | yes | 44 | – |
| base | r3 | completed | 63 | 45 | 38: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/helpers/reactions_helper.rb`, `app/models/card.rb` +32 more | +378/-58 | 4 | 0 | yes | 18 | – |
| inv | r1 | completed | 76 | 34 | 41: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/comments/reactions_controller.rb`, `app/controllers/cards/reactions_controller.rb`, `app/helpers/reactions_helper.rb` +35 more | +372/-109 | 4 | 0 | yes | 10 | db-migration |
| inv | r2 | completed | 65 | 27 | 36: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/controllers/cards/reactions_controller.rb`, `app/helpers/reactions_helper.rb`, `app/models/card.rb`, `app/models/reaction.rb` +30 more | +396/-95 | 5 | 0 | yes | 18 | db-migration |
| inv | r3 | completed | 67 | 30 | 44: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/public/boards/columns/closeds_controller.rb`, `app/controllers/public/boards/columns/not_nows_controller.rb`, `app/controllers/public/boards/columns/streams_controller.rb` +38 more | +396/-64 | 11 | 0 | yes | 22 | db-migration |
| dom | r1 | completed | 69 | 23 | 34: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/models/card.rb`, `app/models/reaction.rb` +28 more | +383/-12 | 4 | 0 | yes | 25 | card-feature-surfaces |
| dom | r2 | completed | 58 | 26 | 33: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/models/card.rb`, `app/models/reaction.rb` +27 more | +408/-11 | 7 | 0 | yes | 18 | card-feature-surfaces |
| dom | r3 | completed | 78 | 20 | 38: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/columns/cards/drops/streams_controller.rb`, `app/controllers/my/pins_controller.rb` +32 more | +397/-20 | 4 | 0 | yes | 34 | card-feature-surfaces |
| composed | r1 | completed | 60 | 23 | 41: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/columns/cards/drops/streams_controller.rb`, `app/controllers/my/pins_controller.rb` +35 more | +393/-20 | 3 | 0 | yes | 21 | card-feature-surfaces, db-migration |
| composed | r2 | completed | 57 | 25 | 40: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/columns/cards/drops/streams_controller.rb`, `app/controllers/my/pins_controller.rb` +34 more | +472/-23 | 5 | 0 | yes | 18 | card-feature-surfaces, db-migration |
| composed | r3 | completed | 67 | 25 | 39: `app/assets/stylesheets/card-columns.css`, `app/assets/stylesheets/card-perma.css`, `app/assets/stylesheets/trays.css`, `app/controllers/cards/reactions_controller.rb`, `app/controllers/my/pins_controller.rb`, `app/controllers/public/boards/columns/closeds_controller.rb` +33 more | +385/-17 | 12 | 0 | yes | 20 | card-feature-surfaces, db-migration |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 75 | 49 | 3/3 | none |
| inv | 3 | 3 | 0 | 67 | 30 | 3/3 | `skills/db-migration` (3/3) |
| dom | 3 | 3 | 0 | 69 | 23 | 3/3 | `skills/card-feature-surfaces` (3/3) |
| composed | 3 | 3 | 0 | 60 | 25 | 3/3 | `skills/card-feature-surfaces` (3/3), `skills/db-migration` (3/3) |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
