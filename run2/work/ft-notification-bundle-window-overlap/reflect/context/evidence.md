# Evidence: every rollout in this workspace, one row each

Built by a script from the exported rollouts, before your session. There is no score here or anywhere: `completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches on the commands and can be wrong; open the trajectory for anything you act on.

| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | r1 | completed | 80 | 42 | 18: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle/delivery_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/notification.rb`, `app/models/notification/email_bundle.rb`, `app/models/notification/email_bundle/item.rb` +12 more | +492/-2 | 8 | 0 | yes | 18 | – |
| base | r2 | completed | 86 | 76 | 21: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/account/data_transfer/manifest.rb`, `app/models/account/data_transfer/record_set.rb`, `app/models/account/data_transfer/user_settings_record_set.rb` +15 more | +521/-6 | 14 | 0 | yes | 26 | – |
| base | r3 | completed | 69 | 65 | 18: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/notification.rb`, `app/models/notification/email_bundle.rb`, `app/models/notification/email_bundle_item.rb` +12 more | +404/-2 | 7 | 0 | yes | 17 | – |
| inv | r1 | completed | 59 | 34 | 18: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/digest_window/delivery_job.rb`, `app/mailers/notification_digest_mailer.rb`, `app/models/notification.rb`, `app/models/notification/digest_window.rb`, `app/models/notification/digestible.rb` +12 more | +450/-3 | 24 | 0 | yes | 9 | – |
| inv | r2 | completed | 43 | 21 | 18: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle/delivery_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/notification.rb`, `app/models/notification/email_bundle.rb`, `app/models/notification/email_bundle_item.rb` +12 more | +384/-3 | 6 | 0 | yes | 11 | – |
| inv | r3 | completed | 49 | 25 | 19: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle_delivery_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/account/data_transfer/manifest.rb`, `app/models/notification.rb`, `app/models/notification/email_bundle.rb` +13 more | +449/-7 | 12 | 0 | yes | 9 | – |
| dom | r1 | completed | 110 | 69 | 26: `app/controllers/notifications/settings_controller.rb`, `app/jobs/notification/email_bundle_job.rb`, `app/jobs/notification/email_delivery_job.rb`, `app/mailers/notification_mailer.rb`, `app/models/account/data_transfer/manifest.rb`, `app/models/account/data_transfer/record_set.rb` +20 more | +806/-11 | 35 | 0 | yes | 12 | new-model-job-mailer |
| dom | r2 | agent_error | 9 | 5 | 0 (empty patch) | +0/-0 | 0 | – | no | – | new-model-job-mailer |
| dom | r3 | agent_error | 3 | 5 | 0 (empty patch) | +0/-0 | 0 | – | no | – | – |

## Per arm

| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |
|---|---|---|---|---|---|---|---|
| base | 3 | 3 | 0 | 80 | 65 | 3/3 | none |
| inv | 3 | 3 | 0 | 49 | 25 | 3/3 | none |
| dom | 3 | 1 | 0 | 9 | 5 | 1/3 | `skills/new-model-job-mailer` (2/3) |

Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or `final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.
