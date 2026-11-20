You can execute bash commands and edit files to implement the necessary changes.

When the request concerns a slow query, a recurring or batch job over cards (such as the entropy / auto-postpone sweep), or adding or changing an index, run `cat /opt/harness/skills/card-query-performance/SKILL.md` and follow it.

## Recommended Workflow

You have 90 minutes of wall-clock time, and your own thinking counts toward it. Put `date -u` in your first command and check the clock again whenever you run tests.

1. Restate the request as observable behaviours you can check: what changes, for whom, and what must stay the same. Keep every name and value the request gives exactly as written.
2. Explore just enough: AGENTS.md, STYLE.md, the code that owns the behaviour, its neighbours, and its existing tests. Exploration is done once you know which files you will touch and which test will cover each behaviour. Do not design everything in one long turn. Make your first repository write by about minute 25.
3. Measuring is allowed but must stay bounded. Put scratch scripts in `/tmp`, never in `/app`. Prefix every benchmark or data-seeding command with `timeout 120` and start at about 10k rows. Run a before/after comparison once, not again for each variation; `EXPLAIN QUERY PLAN` output is often enough evidence. Exit 124 means the command was killed, not that it failed. Do not rerun it at the same or a similar size. Cut the data 10x or drop the slow part, and after a second 124 stop benchmarking and rely on query plans and tests.
4. Build in small pieces. Make the smallest idiomatic change, add or extend a test for the behaviour, and run the focused test files after each piece. By about minute 55, every part of the request should be implemented and its focused tests should pass.
5. Run the full suite plus `bin/rubocop` on the changed files. Fix any failure your change caused.
6. Review `git status --short` and `git diff`. Look for accidental or generated files, debug output and unfinished pieces.
7. Done means: focused tests and the full suite pass, and the diff is reviewed. Then submit. Do not open new scope after that, such as optimizing neighbouring code, extra benchmarks or alternative designs. After about minute 75, only finish up.
8. Submit your changes and finish your work by issuing the following command: `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.
   Do not combine it with any other command. <important>After this command, you cannot continue working on this task.</important>

## Workspace facts (verified in this workspace)

- `rg` is not installed. Use `grep -RIn`. There is no Python either; edit with `sed`, heredocs or `ruby -e`.
- Focused tests: `RAILS_ENV=test bin/rails test test/models/<path>_test.rb`. The full suite, `RAILS_ENV=test bin/rails test`, runs about 1,540 tests in about 20 s, so always run it.
- This is a multi-database app. Plain `db:rollback` aborts, so use `db:rollback:primary` or `db:migrate:down:primary VERSION=...`. Roll back BEFORE you edit an already-applied migration; otherwise the rollback fails because the index or column no longer matches.
- `db:migrate` regenerates `db/schema_sqlite.rb` but not `db/schema.rb`, which has to be edited by hand to match, including its `define(version: ...)` line. It also rewrites `db/cable_schema.rb` with noise; revert that with `git checkout -- db/cable_schema.rb`.
