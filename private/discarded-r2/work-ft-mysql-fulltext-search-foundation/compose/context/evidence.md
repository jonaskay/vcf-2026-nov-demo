# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 69 | 38 | 7: `app/controllers/search_controller.rb`, `app/helpers/search_helper.rb`, `app/models/card.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/search/index.html.erb`, `config/routes.rb` +1 more | +223/-0 | 8 | 0 | yes | 26 | – |
| base | r2 | completed | 39 | 20 | 8: `app/controllers/searches_controller.rb`, `app/helpers/searches_helper.rb`, `app/models/card.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/searches/index.html.erb`, `config/routes.rb` +2 more | +245/-0 | 4 | 0 | no | 13 | – |
| base | r3 | completed | 87 | 62 | 7: `app/controllers/search_controller.rb`, `app/models/card.rb`, `app/views/my/menus/_shortcuts.html.erb`, `app/views/search/index.html.erb`, `config/routes.rb`, `test/controllers/my/menus_controller_test.rb` +1 more | +234/-0 | 12 | 0 | yes | 21 | – |
| inv | r1 | completed | 58 | 26 | 6: `app/controllers/searches_controller.rb`, `app/models/card.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/searches/show.html.erb`, `config/routes.rb`, `test/controllers/searches_controller_test.rb` | +215/-0 | 7 | 0 | yes | 26 | – |
| inv | r2 | completed | 46 | 17 | 7: `app/controllers/searches_controller.rb`, `app/helpers/searches_helper.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/searches/_result.html.erb`, `app/views/searches/show.html.erb`, `config/routes.rb` +1 more | +212/-0 | 10 | 0 | yes | 21 | – |
| inv | r3 | completed | 100 | 30 | 8: `app/controllers/searches_controller.rb`, `app/helpers/searches_helper.rb`, `app/models/card.rb`, `app/models/comment.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/searches/show.html.erb` +2 more | +227/-0 | 21 | 0 | yes | 25 | – |
| dom | r1 | completed | 52 | 22 | 7: `app/controllers/searches_controller.rb`, `app/models/card.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/searches/show.html.erb`, `config/routes.rb`, `test/controllers/my/menus_controller_test.rb` +1 more | +239/-0 | 6 | 0 | yes | 21 | card-text-search |
| dom | r2 | completed | 40 | 20 | 9: `app/controllers/searches_controller.rb`, `app/helpers/searches_helper.rb`, `app/models/card.rb`, `app/models/comment.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/searches/_result.html.erb` +3 more | +258/-0 | 8 | 0 | yes | 16 | card-text-search |
| dom | r3 | completed | 79 | 50 | 7: `app/controllers/searches_controller.rb`, `app/helpers/searches_helper.rb`, `app/models/card.rb`, `app/views/my/menus/_jump.html.erb`, `app/views/searches/show.html.erb`, `config/routes.rb` +1 more | +276/-0 | 10 | 0 | yes | 26 | card-text-search |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 69 | 38 | 2/3 | none |
| inv | 3 | 3 | 0 | 58 | 26 | 3/3 | none |
| dom | 3 | 3 | 0 | 52 | 22 | 3/3 | `skills/card-text-search` (3/3) |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
