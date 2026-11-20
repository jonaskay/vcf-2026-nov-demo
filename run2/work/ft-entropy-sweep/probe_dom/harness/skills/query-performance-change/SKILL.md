# Query-performance change in Fizzy (slow scope, overrunning sweep, new index)

The analytic move is QUERY + (maybe) MIGRATE: same records selected, cheaper plan.
The deliverable is the code change in `/app`; the result set must not change.

## 1. Pin the contract before redesigning anything

- Find the entry point: recurring work is declared in `config/recurring.yml`
  (`command:` or `class:`); the named model method is the public contract.
- List every public name that touches the selection (scopes, class methods,
  predicates) and every caller: `grep -rn '<scope_name>' app test config`.
  These names stay; their result sets stay identical.
- RULE: a scope and the job that sweeps "the same" records must agree. If you
  rewrite the job's loop, either keep it built on the scope, or change the scope
  identically. Never leave the old slow scope in place while the job silently
  uses a different selection.
- Edge semantics to preserve: boundary inclusivity (`<=` vs `<`), NULL/fallback
  handling (COALESCE of override vs default), cross-account behaviour, and who
  is recorded as the actor.

## 2. Diagnose with the plan, not intuition

- `bin/rails runner -e test 'puts ActiveRecord::Base.connection.execute("EXPLAIN QUERY PLAN #{<relation>.to_sql}").map { _1["detail"] }'`
  `SCAN cards` = full table scan. A predicate like `col <= f(joined_col)` cannot
  use an index on `col`; a constant range (`col <= ?`) can.
- `find_each` adds `ORDER BY id LIMIT 1000` and re-runs the query per batch;
  check the plan of THAT query (`relation.order(:id).limit(1000)`), and of any
  custom `cursor:` you introduce.
- Index column order matters: an index led by a column the query does not
  constrain (e.g. `account_id` in a global sweep) is not used.

## 3. Schema-change anatomy (only if you add/alter an index)

Workspace facts, verified in this repository:
- Two schema files are kept: `db/schema.rb` (MySQL dump: `charset`/`collation`
  on tables) and `db/schema_sqlite.rb` (SQLite dump; `config/database.sqlite.yml`
  sets `schema_dump: schema_sqlite.rb`). BOTH need the new `t.index` line and the
  bumped `define(version: ...)`.
- `bin/rails db:migrate` (test env, SQLite) rewrites `db/schema_sqlite.rb` and
  ALSO rewrites `db/cable_schema.rb` with SQLite-flavoured noise — restore it
  with `git checkout -- db/cable_schema.rb`. `db/schema.rb` is not regenerated:
  hand-edit it, mirroring the SQLite line at the same position.
- Migrations: `db/migrate/<timestamp>_<name>.rb`,
  `class X < ActiveRecord::Migration[8.2]`, latest existing is
  `20260218120000_restore_unique_index_on_board_publication_key.rb`; your
  timestamp must sort after it.
- Existing `cards` indexes (`db/schema_sqlite.rb` ~230-233):
  `[account_id, last_active_at, status]`, `[account_id, number]` unique,
  `[board_id]`, `[column_id]`. Do NOT remove an existing index to make room
  (`[board_id]` serves every `board.cards` lookup) — add, don't replace.
- SQLite-only migration behaviour, where needed, follows the existing pattern
  `connection.adapter_name == "SQLite"` (see `db/migrate/20251120110206_add_search_records.rb`).

## 4. Entropy/auto-postpone domain (workspace facts)

- `app/models/card/entropic.rb`: scopes `due_to_be_postponed`, `postponing_soon`
  and class method `auto_postpone_all_due` (run hourly via `config/recurring.yml`
  `command: "Card.auto_postpone_all_due"`). Period = COALESCE(board entropy,
  account entropy) in seconds, via `connection.date_subtract` from
  `lib/rails_ext/active_record_date_arithmetic.rb` (MySQL `DATE_SUB`, SQLite `datetime(...)`).
- `active` = `open.published.where.missing(:not_now)` (`app/models/card/postponable.rb`);
  `auto_postpone(user:)` creates the `not_now`, so a processed card leaves the set.
- `Entropy::AUTO_POSTPONE_PERIODS_IN_SECONDS` (`app/models/entropy.rb`) is the
  validated whitelist of periods; `Board#entropy` falls back to `account.entropy`.
- `config/brakeman.ignore` holds entries whose `code` is the literal text of the
  interpolated `where` strings in `card/entropic.rb`. If you edit those strings,
  note that the ignore entries no longer match; keep the interpolated fragments
  unchanged where possible.
- Tests: `test/models/card/entropic_test.rb` (fixtures `cards(:logo, :shipping,
  :layout, :radio)`, `entropies(:writebook_board, "37s_account",
  :miltons_wish_list_board)`; asserts `postponed_by == accounts("37s").system_user`),
  plus `test/models/card/stallable_test.rb` (line ~63 calls `Card.auto_postpone_all_due`)
  and the related `test/models/card/postponable_test.rb`. The test DB is empty outside test runs (fixtures
  load only inside tests).

## 5. Scope discipline

- Change only what the slow path needs. Do not "fix" neighbouring behaviour you
  notice (comment authorship, event creators, notifications) — that changes the
  deliverable.
- Test through public API (`Card.<scope>`, `Card.auto_postpone_all_due`), not
  `send(:private_method)`. Add at least one test pinning the boundary/fallback
  semantics your rewrite could break.

## Before finishing, confirm

- [ ] Public names unchanged; scope and sweep select the same records.
- [ ] Boundary, fallback (board→account), cross-account and actor behaviour kept.
- [ ] Plan for the new query (per-batch form) no longer shows `SCAN cards`.
- [ ] If an index was added: migration + `db/schema.rb` + `db/schema_sqlite.rb`
      (index line and version) all agree; `db/cable_schema.rb` unchanged; no
      existing index removed.
- [ ] `bin/rails test test/models/card/` (or the relevant model dir) and then
      `bin/rails test` pass.
