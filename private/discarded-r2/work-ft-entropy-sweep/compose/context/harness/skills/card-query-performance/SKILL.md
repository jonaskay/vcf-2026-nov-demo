# Skill: card query and batch-job performance in Fizzy

Use this when a request is about a slow query, a recurring/batch job over cards, or an index. The request text says WHAT is slow; read it from the request itself. This skill says where that code lives, what it must keep doing, and how to check the fix.

## Workspace facts (seen in this repository; re-check with `grep -n` if a line moved)

Entry points
- Recurring jobs are declared in `config/recurring.yml`. Many are bare `command:` strings with no job class. The auto-postpone sweep is `auto_postpone_all_due: command: "Card.auto_postpone_all_due"`, run every hour at minute 50. The class method name is called from YAML, so keep it.
- `app/models/card/entropic.rb` (`Card::Entropic`) holds:
  - `scope :due_to_be_postponed`: `active`, then `.joins(board: :account)`, then `.left_outer_joins(board: :entropy)`, then a raw `LEFT OUTER JOIN entropies AS account_entropies`. Its filter is `last_active_at <= connection.date_subtract('?', 'COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period)')`, bound to `Time.now`.
  - `scope :postponing_soon`: the same joins, with the window `now - period < last_active_at <= now - 0.75*period`.
  - `auto_postpone_all_due`: `due_to_be_postponed.find_each { |card| card.auto_postpone(user: card.account.system_user) }`.
- Callers: `due_to_be_postponed` is used only inside `entropic.rb`. `postponing_soon` is also used by `Card.indexed_by("postponing_soon")` (`app/models/card.rb`), by `Filter::Fields::INDEXES` and by the "Cards closing soon" shortcut (`app/views/my/menus/_shortcuts.html.erb`).
- Tests: `test/models/card/entropic_test.rb` (sweep and both scopes, including the cross-account cases) and `test/models/card/stallable_test.rb`, which also calls `Card.auto_postpone_all_due`.

Domain rules the sweep must keep
- Period resolution: a board's own `Entropy` overrides the account's (`Board::Entropic#entropy` is `super || account.entropy`). Every account gets an entropy on create (`Account::Entropic`, 30 days).
- `Entropy` validates `auto_postpone_period` against `AUTO_POSTPONE_PERIODS_IN_SECONDS` (built from `AUTO_POSTPONE_PERIODS_IN_DAYS` in `app/models/entropy.rb`). Stored values can still fall outside that list: `test/models/entropy_test.rb` writes `999.days` with `update_column`, and `Account::DataTransfer::EntropyRecordSet` uses `insert_all!`. A prefilter bounded by the constant's min or max silently assumes stored data obeys it; a bound taken from the stored entropies does not.
- `Card.active` is `open.published.where.missing(:not_now)` (`Card::Postponable`). Drafted, closed and already-postponed cards are excluded.
- `Account#system_user` is `users.find_by!(role: :system)` (`app/models/account.rb`), one query per call. The tests assert `postponed_by == accounts("37s").system_user`.
- `card.auto_postpone` → `postpone(event_name: :auto_postponed)` runs a transaction per card: back to triage, reopen, destroy activity_spike, create not_now, track_event.

Schema and query plan
- `cards` indexes (`db/schema_sqlite.rb` and `db/schema.rb`, cards table): `[account_id, last_active_at, status]`, `[account_id, number]` unique, `[board_id]`, `[column_id]`. The old `[last_active_at, status]` index was replaced by the account-leading one in `db/migrate/20251113163145_ensure_account_id_index.rb`, so no index leads with `last_active_at` or `status`.
- `entropies` indexes: unique `[container_type, container_id]` and `[container_type, container_id, auto_postpone_period]`.
- Baseline `EXPLAIN QUERY PLAN` of `Card.due_to_be_postponed` on SQLite is `SCAN cards`. With find_each's `ORDER BY id LIMIT 1000` it becomes `SCAN cards USING INDEX sqlite_autoindex_cards_1`, followed by index lookups for boards, accounts, entropies (twice), closures and not_now. The per-row `COALESCE`/`datetime(...)` comparison cannot use an index.
- Both adapters are supported. `lib/rails_ext/active_record_date_arithmetic.rb` gives `connection.date_subtract` for MySQL and SQLite. `db/schema.rb` is the MySQL dump and `db/schema_sqlite.rb` the SQLite one. The env default is `DATABASE_ADAPTER=sqlite`.
- `config/brakeman.ignore` holds fingerprinted entries whose `code` is the exact text of both scopes' interpolated `where`. If you edit that text, run `bin/brakeman` and update the ignore entry if a warning reappears.
- In this Rails, `find_each` accepts `cursor:` (column or array) and `order:` (see activerecord `relation/batches.rb`). Its docs require a unique tiebreaker column (for example `id`) in the cursor.
- `bin/rails runner -e test` sees an EMPTY test database (`cards=0`): fixtures load only inside tests. `EXPLAIN QUERY PLAN` still works there. Behaviour checks belong in a test.
- Fixtures: cards `logo`, `layout`, `text`, `shipping`, `buy_domain` are on board `writebook` (account `37s`). `radio` and `paycheck` are on `miltons_wish_list` (account `initech`). `unfinished_thoughts` is drafted. Entropies: `writebook_board`, `miltons_wish_list_board`, `private_board`, `"37s_account"`.

## If you add or change an index
- Use `ActiveRecord::Migration[8.2]`. Take the timestamp from `date +%Y%m%d%H%M%S`. Rollback, schema-dump and `db/cable_schema.rb` handling are in the Workspace facts of the system prompt.
- Do not drop an existing index (for example `index_cards_on_board_id`, which backs `board.cards`) as a side effect of a performance fix unless you show that nothing else needs it.

## Decision rules
1. **One definition of "due".** The sweep and `due_to_be_postponed` must select the same cards.
   - Preferred: make the scope fast and keep the sweep calling it.
   - If you rewrite the sweep around a different query, update or remove the scope in the same change so it cannot silently diverge.
   - Check: in a test, set up mixed board and account periods, then assert that the cards the sweep postpones are exactly `Card.due_to_be_postponed` taken before the sweep.
2. **Keep behaviour.** These must all still hold:
   - the inclusive boundary (`<=`);
   - the board-over-account override;
   - cross-account sweeps;
   - `postponed_by` is that account's system user;
   - drafted, closed and postponed cards are skipped;
   - `postponing_soon` still agrees with the due boundary (a card is never both "due" and "postponing soon").
3. **Stay in the domain.**
   - The fix belongs in `Card::Entropic`, plus a migration if an index is needed.
   - Do not rework commenting or eventing (`Card::Eventable::SystemCommenter`, `Event`) or other concerns to save per-card queries. Memoising `system_user` per account inside the sweep is enough.
4. **Choose the index from the query you ship.**
   - An index only helps if its leading columns match equality filters and its next column matches the range or order the query actually uses.
   - Confirm with `EXPLAIN QUERY PLAN`, not with wall-clock timings on synthetic data. If you use only existing indexes, confirm in the plan which one serves the query.

## Done check
- [ ] `EXPLAIN QUERY PLAN` of each per-batch query the sweep now runs shows no bare `SCAN cards`.
- [ ] A new test in `test/models/card/entropic_test.rb` covers the changed selection logic (mixed board and account periods, boundary). Any plan assertion in a test is guarded by `ActiveRecord::Base.connection.adapter_name == "SQLite"`, which is the existing pattern in `test/jobs/search_reindex_job_test.rb`.
- [ ] `bin/rails test test/models/card/entropic_test.rb test/models/card/stallable_test.rb` passes, then `bin/rails test` passes.
- [ ] Code is adapter-neutral: no SQLite-only SQL in models; use `connection.date_subtract` or Ruby-computed cutoffs.
- [ ] `git status --short` shows only the intended files: no `db/cable_schema.rb`, no scratch scripts in `/app`. If an index was added, `db/schema.rb` and `db/schema_sqlite.rb` both carry it with the same version.
