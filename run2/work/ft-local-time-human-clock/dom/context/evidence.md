# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 84 | 48 | 31: `app/controllers/concerns/current_timezone.rb`, `app/helpers/bridge_helper.rb`, `app/helpers/entropy_helper.rb`, `app/helpers/time_helper.rb`, `app/javascript/controllers/bridge/share_controller.js`, `app/javascript/controllers/bridge/stamp_controller.js` +25 more | +419/-80 | 14 | 0 | yes | 16 | – |
| base | r2 | completed | 83 | 47 | 27: `app/assets/stylesheets/comments.css`, `app/controllers/concerns/current_timezone.rb`, `app/helpers/bridge_helper.rb`, `app/helpers/time_helper.rb`, `app/javascript/controllers/bridge/share_controller.js`, `app/javascript/controllers/bridge/stamp_controller.js` +21 more | +354/-83 | 8 | 0 | yes | 25 | – |
| base | r3 | completed | 43 | 49 | 27: `app/controllers/concerns/current_timezone.rb`, `app/helpers/bridge_helper.rb`, `app/helpers/entropy_helper.rb`, `app/helpers/time_helper.rb`, `app/javascript/controllers/bridge/share_controller.js`, `app/javascript/controllers/bridge/stamp_controller.js` +21 more | +250/-64 | 9 | 0 | yes | 15 | – |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 83 | 48 | 3/3 | none |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
