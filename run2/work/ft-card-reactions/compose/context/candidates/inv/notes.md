I changed one component: a new on-demand skill, `skills/db-migration/SKILL.md`, with its trigger line added at the end of `system.md`. The trigger reads: "When your change needs a database migration … run `cat /opt/harness/skills/db-migration/SKILL.md` and follow it before you run `db:migrate`." No other file was touched, and the submit instruction is unchanged.

**Why this edit.** All three base runs finished, in 45 to 55 minutes. All three ran the full suite and rubocop. The one process failure they all repeated was the database migration: each run lost steps finding the same multi-database and two-schema mechanics, and two runs hit the same tool error.
- **r1:** steps 31 to 38. It ran `bin/rails db:migrate`, then noticed at step 34 that `db/cable_schema.rb` had been rewritten. At step 38 it reverted that file and edited `db/schema.rb` by hand.
- **r2:** about 15 steps across 65–71, 92–93, 98, 106–108 and 113–114.
  - It reverted `db/cable_schema.rb` twice.
  - Step 67 was a hand edit of `db/schema.rb` that exited with code 1.
  - It added a counter_cache migration (92–93), then backed it out: at step 106, `db:rollback` failed under multi-database, and it used `-T` at 107 to find `db:rollback:primary`, which worked at 108.
- **r3:** steps 26 to 35.
  - At step 33, `db:migrate:down` failed with "You're using a multiple database application… db:migrate:down:primary and db:migrate:down:cable"; `db:migrate:down:primary` worked at step 34.

This is a repeated tool error plus a repeated generated-noise cleanup, and it has a clear trigger (the change needs a migration). That makes it a skill, not always-on prose. It costs nothing on tasks without a migration.

**Workspace facts in the skill, and where each comes from** (all from command output, none from a patch alone):
- **Multi-database rollback:** unscoped `db:migrate:down` fails with the message quoted above (r3 step 33). The `:primary` forms work (r3 step 34, r2 step 108), and the `-T` listing shows `db:rollback:primary` and `db:rollback:cable` (r2 step 107).
- **`db:migrate` rewrites `db/cable_schema.rb` in SQLite syntax:** `charset`/`collation` are dropped and `size: :long` becomes `limit: 4294967295`. Shown in the `git diff` at r3 step 27 and r1 step 34.
- **`db:migrate` regenerates `db/schema_sqlite.rb` but not `db/schema.rb`:** r3 step 26 shows the `schema.rb` reactions table still has `comment_id … null: false` after the migrate, while `schema_sqlite.rb` changed. All three runs mirrored the change into `schema.rb` by hand (r1 step 38, r2 steps 67/71, r3 patch). The skill describes that as what the runs did, not as a project rule.
- **Migration header `ActiveRecord::Migration[8.2]`:** seen in `db/migrate/20251120194700_remove_all_foreign_key_constraints.rb`, printed at r3 step 33.
- **Tests after migrating:** after `bin/rails db:migrate` in development, `bin/rails test` passed with no extra step (r1 step 31, then 96 tests passed at step 40). The full suite is 1542 runs in about 18 seconds (r2 step 112).
- **Versions match:** `db/schema.rb` and `db/schema_sqlite.rb` carry the same version as the newest migration (r2 step 112 grep, `2026_11_15_154500`). This backs the skill's final check.

**Procedure in the skill:**
- Settle the schema design before migrating. This traces to r2's counter_cache add-then-remove cycle (steps 92–110, about 6 minutes).
- Revert `db/cable_schema.rb` after every migrate or rollback.
- Mirror the schema change into `db/schema.rb`.
- Run narrow tests, then the full suite.
- Finish with a one-command check on `db/`: one new migration, matching versions, no `cable_schema.rb`, no abandoned migration.

**Deliberately not encoded:**
- **Foreign-key convention:** r3 found at step 32 that the project removes foreign keys. That is a Fizzy rule, which belongs to the domain candidate.
- **Scope of the diff:** the patches touched 38 to 46 files, partly by refactoring the comment-reaction views. Whether that scope is right is a judgment about the deliverable, not about procedure.
- **Exploration time:** the first repository write came at about 19 to 22 minutes, and no run came near the time limit, so there is nothing to fix there.
