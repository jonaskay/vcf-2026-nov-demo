# Query performance / long-running jobs

1. Find the job (`config/recurring.yml` -> job class -> model method -> scope). Print the SQL: `RAILS_ENV=test bin/rails runner 'puts Model.scope.to_sql'`.
2. Run `EXPLAIN QUERY PLAN <sql>` via `ActiveRecord::Base.connection.execute` (SQLite). Look for SCAN of the big table, temp b-trees, and a condition whose cutoff is computed per row from a JOINED table (that forces visiting every row; no index can serve it).
3. Fix by making the work proportional to the rows that actually need it, not to the table:
   - Split by the configuration that drives the per-row value: one query per distinct setting value, each a bare-column comparison against a literal cutoff (`cards.last_active_at <= now - period`), restricted to the records having that setting (e.g. `board_id IN (ids)`; for the default, `NOT IN` the overridden ids, scoped by account). Combined result must equal the old condition (override beats default; records with no override use the default).
   - Prefer simple ANDed conditions per query over a big `.or(...)` of subqueries: OR across subselects often stops SQLite from using the index. Run the queries one after another (union in Ruby or just loop) rather than OR-ing them.
   - A generic "minimum possible value" prefilter is NOT enough when most rows already pass it. Judge a prefilter by rows removed on realistic data, not by EXPLAIN saying SEARCH.
   - Process in batches (`find_each`/`in_batches`) with small per-row work; hoist shared lookups (account, system user) out of the loop or preload them.
   - Add an index only if the final query's plan needs one; if you add one, write a migration and update BOTH schema files.
4. Keep the original scope/method names and return types working (callers and tests use them); put the new logic behind them.
5. Measure: build a few thousand to 100k synthetic rows with `insert_all` in a runner (mixed settings, mostly NOT due) and compare EXPLAIN and timing before/after. Delete the data afterwards.
6. Behavior must stay identical: keep existing tests green, and add tests with rows on both sides of the boundary for every distinct configuration, including records with no override, and across more than one batch.
7. Keep SQL portable between SQLite and MySQL; use helpers such as `connection.date_subtract`. Qualify columns (`table.column`) once joins exist. Use `Time.current`, not `Time.now`.
