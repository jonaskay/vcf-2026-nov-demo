You can execute bash commands and edit files to implement the necessary changes.

## Recommended Workflow

You have 90 minutes of wall-clock time, and your own thinking counts toward it. If you hit the limit, whatever is in /app at that moment is what gets delivered. Put `date -u` in your first command and check the clock again every time you run tests.

1. Restate the request as observable behaviour: what must change (for a performance report, that means which query or loop must stop growing with table size) and which existing behaviour must stay exactly as it is. Keep every name and value the request gives.
2. Explore just enough. Read AGENTS.md and STYLE.md, the code that owns the behaviour, its neighbours, and its existing test file. Exploration is done once you know which files you will change and which test file will prove each behaviour. By about minute 25 your first repository edit (code, test or migration) should exist.
3. Make the smallest idiomatic change. Run the focused test files after each piece of work. By about minute 55 every part of the request should be implemented and its focused tests should pass.
4. Experiments (benchmarks, EXPLAIN, synthetic data) are evidence, not deliverables. Write them under /tmp, never in /app. Start with at most 10,000 rows, run them as `timeout 120 bin/rails runner /tmp/x.rb` with `STDOUT.sync = true`, and roll the data back. If a command dies at the 300 s limit (exit 124 / "timed out"), that is a timeout, not a code failure. Shrink the input 10× and rerun it once. If it times out again, drop that experiment and rely on the tests.
5. Run the full suite plus `bin/rubocop` on the files you changed, and fix any failure your change caused.
6. Review `git status --short` and `git diff`: look for accidental or generated files, debug output, unfinished pieces, and edits outside the request's scope.
7. Stop rule: once steps 5–6 are clean, submit. Do not start new optimisations or edit other classes after a green full suite. After about minute 75, only finish up.
8. Submit your changes and finish your work by issuing the following command: `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.
   Do not combine it with any other command. <important>After this command, you cannot continue working on this task.</important>

## Workspace facts (verified in this workspace)

- `rg` is not installed (exit 127). Use `grep -RIn` instead.
- Focused tests: `RAILS_ENV=test bin/rails test test/models/<path>_test.rb`. The full suite is `RAILS_ENV=test bin/rails test`: about 1,540 tests in roughly 20 s. Always run it.
- The test database holds only fixtures (8 cards). Volume experiments therefore need synthetic rows inside a transaction that ends in `raise ActiveRecord::Rollback`.
- This is a multi-database app. `RAILS_ENV=test bin/rails db:migrate` updates `db/schema_sqlite.rb` only. It does NOT update `db/schema.rb`, so edit that file by hand to match, including its `define(version: ...)` line. It also rewrites `db/cable_schema.rb`, which is noise: revert it with `git checkout -- db/cable_schema.rb`. Plain `db:rollback` is refused. Use `db:rollback:primary` or `db:migrate:down:primary VERSION=...`. Finalise a migration before you run it: rolling back a migration you edited after applying it fails.
