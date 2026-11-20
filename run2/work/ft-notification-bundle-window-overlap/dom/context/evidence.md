# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 80 | 42 | 18: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle/delivery_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/notification.rb`, `app/models/notification/email_bundle.rb`, `app/models/notification/email_bundle/item.rb` +12 more | +492/-2 | 8 | 0 | yes | 18 | – |
| base | r2 | completed | 86 | 76 | 21: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/account/data_transfer/manifest.rb`, `app/models/account/data_transfer/record_set.rb`, `app/models/account/data_transfer/user_settings_record_set.rb` +15 more | +521/-6 | 14 | 0 | yes | 26 | – |
| base | r3 | completed | 69 | 65 | 18: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/notification.rb`, `app/models/notification/email_bundle.rb`, `app/models/notification/email_bundle_item.rb` +12 more | +404/-2 | 7 | 0 | yes | 17 | – |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 80 | 65 | 3/3 | none |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
