I made one change: a new skill, `skills/card-query-performance/SKILL.md`, plus its trigger line at the top of `system.md`. Nothing else changed. The submit instruction is untouched, and no other always-on text was added.

**Why a skill.** The three base runs disagreed on where the fix belongs and what it must keep doing, which is a divergence rather than a shared failure:
- **r1** kept `due_to_be_postponed` as the sweep's only source and added a sargable minimum-period prefilter, a `[status, last_active_at, id]` index and a `cursor:`.
- **r2** looped over every board, dropped `index_cards_on_board_id` in its migration, edited `Card::Eventable::SystemCommenter`, and timed out at 91 minutes.
- **r3** grouped by account and period on the existing account-leading index, with no migration.

In both r2 and r3 the sweep stopped using `due_to_be_postponed`, but the scope stayed in place. That leaves two definitions of "due" that can drift apart; r2 step 108 grepped for the scope's callers after the rewrite. The skill turns this into checkable rules: one definition of "due", behaviour to keep, the fix stays in `Card::Entropic`, and the index is chosen from the query actually shipped.

**Workspace facts in the skill, with where each was seen:**
- **Sweep entry point:** `config/recurring.yml`, `auto_postpone_all_due: command: "Card.auto_postpone_all_due"`, every hour at minute 50 (r1 step 7).
- **Scopes, sweep and callers:**
  - Full text of `due_to_be_postponed`, `postponing_soon` and `auto_postpone_all_due` in `app/models/card/entropic.rb` (r1 step 6).
  - Callers, from r1 step 7 grep: `card.rb:31` `indexed_by`, `filter/fields.rb:4`, `_shortcuts.html.erb:4`, `stallable_test.rb:63`.
- **Period rules:**
  - `Board::Entropic#entropy` is `super || account.entropy`, and `Account::Entropic` creates a 30-day entropy on create (r1 step 6).
  - The `Entropy` validation and the `[3, 7, 30, 90, 365, 11]` constant are in `app/models/entropy.rb` (r1 step 6).
  - Stored values can fall outside that list: `entropy_test` writes `999.days` with `update_column` (r1 step 6), and `EntropyRecordSet` uses `insert_all!` (r1 step 6 grep). r1's minimum-period prefilter depends on the list being respected, and it never said so.
- **Card behaviour:**
  - `Card.active`, `auto_postpone` and `postpone` are in `Card::Postponable` (r1 step 6).
  - `Account#system_user` is `users.find_by!(role: :system)` (r3 step 12, `account.rb`).
- **Indexes:**
  - `cards` indexes are at `db/schema_sqlite.rb:230-233` (r1 step 9).
  - `[last_active_at, status]` was replaced by the account-leading index in `20251113163145_ensure_account_id_index.rb` (r1 step 8).
  - `entropies` indexes are at `schema.rb:293-294` (r1 step 6).
- **Baseline query plans:** `SCAN cards` (r1 step 12), and `SCAN cards USING INDEX sqlite_autoindex_cards_1` once find_each orders by id (r3 step 10).
- **Adapters and lint:**
  - `date_subtract` for MySQL and SQLite is in `lib/rails_ext/active_record_date_arithmetic.rb` (r1 step 9).
  - `config/brakeman.ignore` lines 12 and 127 hold fingerprints of the scopes' SQL (r1 steps 6–7). r1 edited that text and no run ran `bin/brakeman`; this risk is visible but not yet realised.
- **Test database and fixtures:**
  - `bin/rails runner -e test` shows `cards=0` (r1 step 12).
  - Fixture cards, boards and accounts are from r3 step 8.
  - The `find_each` `cursor:`/`order:` docs and the tiebreaker note are from r3 step 10.
  - The SQLite guard `ActiveRecord::Base.connection.adapter_name == "SQLite"` is at `test/jobs/search_reindex_job_test.rb:71` (r1 step 7).
- **Migration mechanics:**
  - `cable_schema.rb` is rewritten on migrate and has to be reverted (r1 steps 55–56).
  - Plain `db:rollback` fails; it worked once r2 listed the rake tasks and switched to `db:rollback:primary` (r2 steps 66–68).
  - `db/schema.rb` has to be edited by hand (r1 step 56).

These were cross-checked against the library's `db-migration` skill. I gave the timestamp as `date +%Y%m%d%H%M%S` rather than a literal value, following the library lesson.

**Deliberately left out:**
- Which fix is correct (prefilter, regrouping or new index). The runs disagree and nothing establishes an answer, so the skill gives the consistency checks and asks the agent to state any assumption about stored periods.
- Procedure and time budgeting, such as r2's 100k-row benchmarks that hit the 300-second command limit (exit 124 at steps 79 and 81). That belongs to the parallel candidate. The skill only says to confirm the plan with `EXPLAIN QUERY PLAN` rather than wall-clock timings on synthetic data.
