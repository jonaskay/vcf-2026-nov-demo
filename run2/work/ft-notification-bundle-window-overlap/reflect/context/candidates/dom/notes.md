I changed one component: a new skill, `skills/new-model-job-mailer/SKILL.md`, plus its trigger line in `system.md`. The submit instruction is untouched. `memory.md`, `guardrails.md` and `tool_guidance.md` are unchanged.

**Why a skill.** All 3 base runs finished, and all ran the full suite with a final exit code of 0. They went wrong in two ways:
- **Where they disagreed:** where mailer views go, how mail is sent from a job, and whether old data exports still import.
- **Where they paid to rediscover the same mechanics:** schema files, test-helper gaps, fixture collisions.

All of this applies to any future Fizzy task that adds a migration, a job, a mailer, or behaviour hooked onto Notification, so I put it on demand rather than in always-on text. r2 took 76 of the 90 minutes, so I added no always-on prose beyond the one trigger line.

**What each part of the skill traces to.** Each [ws] fact cites the run, step and file:line the trajectory output showed.

- **Mail delivery inside a custom job (runs disagreed):**
  - r1 called `deliver_later` from its job.
  - r2's job called `deliver_now` with no SMTP error handling.
  - r3 added `SmtpDeliveryErrorHandling` by hand and spent steps 49–63 adding and removing `warn(` debug lines around it.
  - Facts the rule rests on (r3 s50 and s52):
    - `config/initializers/active_job.rb` prepends `AccountTenanted` to `ActionMailer::MailDeliveryJob` and sets `enqueue_after_transaction_commit = true`.
    - `lib/rails_ext/action_mailer_mail_delivery_job.rb` includes `SmtpDeliveryErrorHandling`.
    - The concern's contents are in `app/jobs/concerns/smtp_delivery_error_handling.rb`.
  - The skill turns this into a decision rule: from your own job, either call `deliver_later` or include the concern.
- **Mailer view location (runs disagreed):**
  - r1 left its templates in `app/views/notification_mailer/`.
  - r3 put them there first, then moved them at s33.
  - Fact: `ApplicationMailer` has `append_view_path app/views/mailers` and a `default_url_options` that depends on `Current.account` (r2 s7). Existing templates live under `app/views/mailers/<mailer>/` (r2 s6 listing).
- **Data-transfer compatibility (only r2 handled it, s42–52):**
  - `manifest.rb:30` exports `User::Settings` through the generic `RecordSet`, whose `check_record` raises `missing required fields` for any column absent from the export (r2 s43, r3 s12).
  - r1 and r3 added a `user_settings` column without considering this.
  - The skill doesn't tell the agent what to do here. It names the consequence and asks the agent to decide explicitly and say which way it went.
- **Schema files and migrate side effects (repeated in every run):**
  - r1 (s52) and r2 (s44) both had to revert the noise `db:migrate` writes into `db/cable_schema.rb`.
  - All 3 runs hand-edited `db/schema.rb`, because SQLite's `schema_dump` regenerates only `schema_sqlite.rb` (r3 s10).
  - r3 spent s28–32 and s38 checking `saas/db/saas_schema.rb`, which holds only the separate SaaS database (r3 s29–31).
  - The newest existing migration is `20260709120000` (r2 s8).
- **Test facts (repeated failures):**
  - `assert_emails` is undefined in model tests because `ActiveSupport::TestCase` doesn't include `ActionMailer::TestHelper` (r3 s23).
  - A second Notification for the same user and card raises `RecordNotUnique`, because of the unique index (r3 s25; index shown in r2 s5).
  - r3 spent s43–46 debugging what turned out to be a cached association that needed a reload.
  - `test_helper` sets `Current.account` in setup and its `perform_enqueued_jobs` clears it (r2 s6).
  - The fixture users and events are listed in r2 s7 and r3 s13.
- **Existing anatomy to build on (a risk visible in every run, not a failure):**
  - `Notifier` upserts one row per (user, card) and updates the source on repeat activity.
  - `Pushable` fires `after_save_commit ... if: :source_id_previously_changed?`.
  - Payload classes provide `title`, `body` and `url` (r2 s6, s27).
  - `User::Configurable` creates settings `unless: :system?` (r2 s6).
  - The enum convention is in r2 s8 (export.rb, access.rb, identity/access_token.rb), the `inclusion` validation in r3 s16 (entropy.rb), the timezones controller precedent in r2 s8, and the select-field precedent in `my/access_tokens/new.html.erb:20` (r3 s13).
  - `PATCH /notifications/settings` already routes to `#update` (r3 s51).
  - The mailer layout's notification CSS classes are in r3 s11.
  - Incineration cascades through `Account has_many :users, dependent: :destroy` (r3 s15).
- **Association foreign-key check (a risk seen only in a patch, not stated as a repo fact):**
  - r1's patch declares `has_many :email_bundle_items, foreign_key: :notification_email_bundle_id` on `Notification`, which is the wrong column.
  - The skill states this only as a procedure: "add a test that destroying the owner removes the join rows". r2's patch has such a test.

**Deliberately left out:**
- Nothing about window or overlap semantics: all 3 runs already used a unique index plus a `settings.with_lock`.
- No names or values from this request in durable form.
- Nothing on procedure such as python3 or rg being missing; that belongs to the other candidate.

**Uncertainty:**
- I haven't confirmed the claim that `user.identity` can be nil beyond `User#deactivate` (r2 s6).
- The "fewer than 50 tests run in a single process" line comes from the test-runner output ("parallelization threshold is 50").
