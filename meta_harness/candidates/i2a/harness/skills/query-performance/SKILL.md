# Query performance / long-running jobs

1. Find the job (`config/recurring.yml` -> job class -> model method -> scope). Print the SQL: `RAILS_ENV=test bin/rails runner 'puts Model.scope.to_sql'`.
2. Run `EXPLAIN QUERY PLAN <sql>` via `ActiveRecord::Base.connection.execute` (SQLite). Look for SCAN of the big table, temp b-trees, and a condition whose cutoff is computed per row from a JOINED table (that forces visiting every row; no index can serve it).
3. Fix by making the work proportional to the rows that actually need it, not to the table:
   - Split by the configuration that drives the per-row value. If the cutoff depends on a per-record setting (record override vs default), run one query per distinct setting value with a bare-column comparison against a literal computed cutoff (`last_active_at <= now - period`), restricted to the records having that setting, so each query can use an index on the big table. Keep the combined result identical to the old condition.
   - A generic "minimum possible value" prefilter is NOT enough when most rows already pass it: an index search that returns nearly the whole table is still a full scan. Judge a prefilter by how many rows it removes on realistic data, not by whether EXPLAIN says SEARCH.
   - Process in batches (`find_each`/`in_batches`) with the per-row work small; avoid per-row lookups of shared objects (preload or hoist them out of the loop).
   - Add an index only if the final query's plan needs one.
4. Measure, don't guess: build a few thousand to 100k+ synthetic rows in the test DB with `insert_all` inside a runner script (mixed settings, mostly NOT due), then compare query counts/time and EXPLAIN before and after. Delete the data afterwards (or use a transaction + rollback).
5. Behavior must stay identical: keep existing tests green, and add tests with rows on both sides of the boundary for every distinct configuration, plus a test that the sweep still handles every account/board (including ones with no override).
6. Keep SQL portable between SQLite and MySQL; use existing helpers such as `connection.date_subtract`. Qualify columns (`table.column`) once joins exist. Use `Time.current`, not `Time.now`.
