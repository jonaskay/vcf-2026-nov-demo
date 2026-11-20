# Adding persisted state, jobs or email to Fizzy

Use this when a change adds a migration, a model or a `User::Settings` attribute, a job, a mailer, or hooks new behavior onto `Notification`. Names, values and labels come from the request, and this skill never overrides them. It tells you where each part of such a change lives in this codebase and what must stay consistent.

Lines marked **[ws]** are facts verified in this workspace's repository. Treat the rest as checks to run.

## 1. Code you build on (read these before designing)

- **[ws]** `app/models/user/settings.rb` (`User::Settings`, table `user_settings`) is reached through `user.settings` (`has_one` in `app/models/user/configurable.rb`). It is created `after_create ... unless: :system?`, so code that reads it must handle `nil`.
- **[ws]** For enums on string columns, follow the convention: `enum :status, %w[ a b c ].index_by(&:itself), default: :a` (see `app/models/export.rb`, `app/models/access.rb`, `app/models/identity/access_token.rb`). For an allow-list validation, see `validates ... inclusion:` in `app/models/entropy.rb`.
- **[ws]** Settings are updated in place, as in `app/controllers/my/timezones_controller.rb`: `Current.user.settings.update!(...)`. `config/routes.rb` already has `namespace :notifications do resource :settings end`, so `PATCH /notifications/settings` routes to `Notifications::SettingsController#update` without a new route. For a select field, follow `app/views/my/access_tokens/new.html.erb:20` (`form.select ..., {}, class: "input input--select"`).
- **[ws]** `app/models/notifier.rb` keeps one `Notification` row per (user, card): it calls `create_or_find_by(user:, card:)` and, on repeat activity, `update!(source:, creator:, read_at: nil, unread_count: +1)`. There is a unique index on `notifications [user_id, card_id]`. "A new notification" therefore means a create **or** a source change on an existing row. The existing hook to copy is `app/models/notification/pushable.rb`: `after_save_commit :push_later, if: :source_id_previously_changed?`. Its eligibility check is `!creator.system? && user.active? && account.active?`.
- **[ws]** `notification.payload` returns `Notification::{Event,Mention,Default}Payload` (`app/models/notification/*_payload.rb`), with `title`, `body` and `url`. Reuse it for any text that describes a notification.

## 2. Jobs and mail: facts that change the design

- **[ws]** `app/jobs/application_job.rb` prepends `AccountTenanted`. A job captures `Current.account` when it is **enqueued** and restores it when it runs. `ApplicationJob` does not discard on `DeserializationError` by default, so each job declares `discard_on ActiveJob::DeserializationError` itself.
- **[ws]** `config/initializers/active_job.rb` sets `enqueue_after_transaction_commit = true`, so a job enqueued inside a transaction is held until commit.
- **[ws]** `ActionMailer::MailDeliveryJob` prepends `AccountTenanted` (`config/initializers/active_job.rb`) and includes `SmtpDeliveryErrorHandling` (`lib/rails_ext/action_mailer_mail_delivery_job.rb`, concern in `app/jobs/concerns/smtp_delivery_error_handling.rb`). That concern retries timeouts and server-busy errors and ignores bad-recipient errors. **Decision rule:** if your own job sends mail, either call `Mailer.x(...).deliver_later` from it, which keeps that handling, or include `SmtpDeliveryErrorHandling` in your job. A bare `deliver_now` inside a custom job silently drops both.
- **[ws]** `ApplicationMailer` (`app/mailers/application_mailer.rb`) uses `layout "mailer"` and `append_view_path app/views/mailers`. Its `default_url_options` adds `script_name: Current.account.slug` only when `Current.account` is set. Mailer templates live in `app/views/mailers/<mailer_name>/<action>.{html,text}.erb`, as for the account, export, import and magic_link mailers, each of which ships both html and text.
- **[ws]** `app/views/layouts/mailer.html.erb` already styles `.title`, `.subtitle`, `.card__title`, `.notification`, `.notification__author`, `.notification__board`, `.notification__details` and `.footer`. Use those classes and do not invent new CSS.
- **[ws]** Recipient addresses follow `@user.identity.email_address` (see the existing mailers). `user.identity` can be nil for deactivated users (`User#deactivate` sets `identity: nil`).

## 3. Schema contract: every place a migration must show up

- **[ws]** Migrations use `ActiveRecord::Migration[8.2]` with `id: :uuid` and `t.uuid` foreign keys, and no FK constraints. The newest existing migration is `20260709120000_*`, so your timestamp must be later.
- **[ws]** Two schema files describe the primary database, and both must change: `db/schema.rb` (MySQL dialect, every table carries `charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci"`) and `db/schema_sqlite.rb`. The checkout runs SQLite (`config/database.sqlite.yml` → `schema_dump: schema_sqlite.rb`), so `bin/rails db:migrate` regenerates **only** `db/schema_sqlite.rb`. Edit `db/schema.rb` by hand so it mirrors what `db:migrate` wrote into `schema_sqlite.rb`: same tables at the same alphabetical position, same columns and indexes, plus the MySQL `charset`/`collation` options. Bump `define(version:)` in both files to your migration's timestamp.
- **[ws]** `bin/rails db:migrate` also rewrites `db/cable_schema.rb` with adapter noise. Restore it with `git checkout -- db/cable_schema.rb`. `saas/db/saas_schema.rb` holds only the separate SaaS database (console1984, account_storage_exceptions …). App tables never go there.
- **[ws]** Data transfer: `app/models/account/data_transfer/manifest.rb` exports `::User::Settings` and `::Notification` through the generic `Account::DataTransfer::RecordSet`. Its `check_record` raises `IntegrityError, "... is missing required fields"` for any `model.column_names` entry missing from the imported JSON. **Decision rule:** a column added to an exported model makes exports taken before the change fail the import check. Decide explicitly whether to keep old exports importable (default the missing attribute), and say which you chose in your final message. New tables that are not in the manifest are neither exported nor imported. That is right for transient delivery state, but say so.
- **[ws]** Account deletion: `Account::Incineratable#incinerate` calls `account.destroy`, which cascades through `has_many :users, dependent: :destroy`. `test/models/account/incineratable_test.rb` lists the tables expected to be empty afterwards. A new per-user or per-account table needs a `dependent:` association from `User` or `Account` so that rows do not outlive their owner.

## 4. Consistency checks before you finish

- [ ] For each new `has_many`/`has_one`/`belongs_to`, check that the `foreign_key:` names the column pointing **at the declaring model's owner** on the other table. A copy-pasted `foreign_key:` from the reverse side is a silent bug. Add a test that destroys the owner (user, notification) and asserts the dependent/join rows are gone.
- [ ] Any "only one open X per user" rule is enforced by a unique DB index **and** by the code path under a row lock (e.g. `settings.with_lock`). Test the index directly with a duplicate insert that must raise `ActiveRecord::RecordNotUnique`.
- [ ] Any scope or predicate meaning "open/active/pending" has exactly one definition, and the scheduling job and the "find the current one" path both use it.
- [ ] The hook fires for both a newly created notification **and** a re-notification (source change on the existing row). Write one test for each.
- [ ] Links in rendered email include the account slug. `test/models/notification_test.rb` "broadcast job renders account-scoped URLs" is the precedent: assert `account.slug` appears in the body.
- [ ] Turning the setting off (or deactivating the user) leaves nothing pending that would still send.
- [ ] Both schema files changed, `db/cable_schema.rb` is unchanged, and `git status` shows no scratch or debug files and no leftover `warn(`/`puts` debugging.

## 5. Test facts in this workspace

- **[ws]** `ActiveSupport::TestCase` (`test/test_helper.rb`) includes `ActiveJob::TestHelper` but **not** `ActionMailer::TestHelper`. `assert_emails` is undefined in model tests unless you `include ActionMailer::TestHelper`, or use `ActionMailer::TestCase` for mailer tests (as `test/mailers/*_test.rb` do).
- **[ws]** The test helper sets `Current.account = accounts("37s")` in setup. Its `perform_enqueued_jobs` override clears `Current.account` while jobs run, so a job that renders URLs must have captured the account at enqueue time.
- **[ws]** Fixtures: users `david`, `jz`, `jason`, `kevin` (account `37s`, each with an identity and `user/settings.yml` row), `system` (role system) and `mike` (account `initech`). Because of the (user, card) unique index, creating a second `Notification` for the same user and card raises `RecordNotUnique`, and that includes cards that already have a row in `test/fixtures/notifications.yml` (e.g. kevin on `layout`). Use a user/card pair that is not there yet, and events on different cards (e.g. `events(:layout_published)`, `events(:buy_domain_sent_back_to_triage)`, `events(:text_published)`, `events(:shipping_closed)`).
- After adding to a `has_many :through` from a callback, `reload` the owner before asserting on the association. A cached association looks like a lost insert.
- Fewer than 50 tests run in a single process. Run the new and touched test files first, then `bin/rails test` for the full suite and `bin/rubocop` (it excludes `db/schema*.rb` and `db/migrate`).
