# Query performance / long-running jobs

1. Find the job (`config/recurring.yml` -> job class -> model method -> scope). Print the SQL: `RAILS_ENV=test bin/rails runner 'puts Model.scope.to_sql'`.
2. Run `EXPLAIN QUERY PLAN <sql>` via `ActiveRecord::Base.connection.execute` (SQLite). Look for SCAN of the big table and temp b-trees.
3. Typical fixes, in order: (a) add a cheap, index-friendly pre-filter that never excludes a row the full condition would include (compare a bare column with a computed constant); (b) make sure per-row work is not an N+1 or a function wrapped around an indexed column; (c) process in batches (`find_each`/`in_batches`) so no single query or load is huge; (d) add an index in a migration.
4. Behavior must stay identical: keep existing tests green, and add a test with rows on both sides of the boundary for every distinct configuration (record-level override vs default).
5. Keep SQL portable between SQLite and MySQL; use existing helpers such as `connection.date_subtract`.
6. Unqualified column names break once joins are added; write `table.column`.
