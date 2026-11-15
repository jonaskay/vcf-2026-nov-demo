# Query / performance change in Fizzy

Operation: derive a cheaper query that returns the SAME rows, plus (if needed) an index; fix the code path the slow SQL comes from.

## Workspace facts (verified in earlier runs on the entropy-sweep task; recheck against the task)
- The auto-postpone sweep lives in `app/models/card/entropic.rb`: scope `due_to_be_postponed` (active + joins board->account + left join board `entropies` + aliased `account_entropies`, cutoff `COALESCE(board period, account period)` via `connection.date_subtract`) and class method `auto_postpone_all_due` (find_each + `card.auto_postpone(user: card.account.system_user)`). Sibling scope `postponing_soon` is in the same file. Board side: `app/models/board/entropic.rb`. Tests: `test/models/card/entropic_test.rb`.
- Effective period = board entropy if present, otherwise the ACCOUNT entropy. Boards usually have no own entropy row, so a rewrite that only reads board entropy silently skips most cards. Keep that fallback.
- `Entropy::AUTO_POSTPONE_PERIODS_IN_SECONDS` lists the allowed periods (its `.min` bounds any cutoff).
- The app keeps TWO schema dumps: `db/schema.rb` (MySQL) and `db/schema_sqlite.rb`. A migration (`db/migrate/`, `ActiveRecord::Migration[8.2]`, timestamp later than the latest existing one, check `ls db/migrate | tail`) must update both dumps: the new `t.index` line (alphabetical position) AND the `define(version:)` in both. The request's install is SQLite.
- Existing cards index: `[account_id, last_active_at, status]`, plus `board_id`, `column_id`. Check the dump before adding an index; don't add a duplicate or one whose leading column the query can't use.

## Checklist
1. Identify the slow SQL's origin (the task quotes it) and every caller of the scope/method; keep its public name and results unless callers are updated.
2. Behavior must be unchanged: same cards postponed, same effective-period rule (board over account), same `system_user` actor, cards in other states untouched. Qualify columns (`cards.last_active_at`) when joins are present.
3. Make the filter sargable: compare the bare indexed column to a precomputed cutoff rather than computing per-row from joined columns (group by period/board/account, or add a prefilter on the minimum period). Avoid N+1.
4. Verify with `EXPLAIN QUERY PLAN` on SQLite that an index is used, not just that tests pass.
5. Add a test in `test/models/card/entropic_test.rb` style (fixtures, `freeze_time`) covering: board-level period, account-default fallback, a boundary card not postponed, and a board with a SHORTER period than the account's.
6. Before finishing confirm: code change, migration, both schema dumps, test; run `bin/rails test test/models/card/entropic_test.rb` plus related model tests; `git status` shows no stray files.
