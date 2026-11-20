# Skill: adding a database migration in this repository

Goal: a single migration, both schema files consistent with it, and no generated noise in the diff. Following this takes about 5 steps.

## Workspace facts (seen in this repository; re-check with `grep` if in doubt)

- This is a **multi-database** app (primary + cable). Unscoped `bin/rails db:migrate:down VERSION=...` and `bin/rails db:rollback` **fail** with "You're using a multiple database application...". Use `db:migrate:down:primary VERSION=<ts>` or `db:rollback:primary STEP=1`.
- `bin/rails db:migrate` regenerates `db/schema_sqlite.rb` (the SQLite schema). It **also rewrites `db/cable_schema.rb`** in SQLite syntax. That change is noise and does not belong in your diff: `git checkout -- db/cable_schema.rb` after **every** migrate or rollback.
- `db/schema.rb` is the MySQL schema, and `db:migrate` does **not** update it. Edit it by hand to match: bump the `define(version: ...)` line and add the same column and index lines to the table, keeping the MySQL formatting already used in that file.
- The project does not use foreign-key constraints (`db/migrate/20251120194700_remove_all_foreign_key_constraints.rb`). Do not pass `foreign_key: true`; use `add_column ... :uuid` (ids are uuids) plus `add_index`.
- Existing migrations use `ActiveRecord::Migration[8.2]`. Pick the timestamp with `date +%Y%m%d%H%M%S` and check that it sorts after `ls db/migrate | tail -3`.
- After `bin/rails db:migrate` (development), `bin/rails test` runs against the new schema with no extra step. The full suite (`bin/rails test`, about 1540 tests) finishes in about 20 seconds.

## Procedure

1. **Settle the schema design before you write the migration.** Read the model, its tests and the current table in `db/schema_sqlite.rb` first. Every add-then-remove cycle costs about 10 steps.
2. Write the migration with explicit `up`/`down` (or a reversible `change`), then run `bin/rails db:migrate`.
3. Run `git checkout -- db/cable_schema.rb`.
4. Mirror the `git diff db/schema_sqlite.rb` hunks into `db/schema.rb` by hand: the version line plus the table's columns and indexes.
5. Run the narrowest tests for the touched model or controller, then `bin/rails test`.
6. If you must change the migration: run `bin/rails db:migrate:down:primary VERSION=<ts>`, edit it, run `bin/rails db:migrate` again, then repeat steps 3 and 4.

## Done check (run once, before submitting)

```bash
git status --short db/ ; grep -n 'define(version' db/schema.rb db/schema_sqlite.rb ; ls db/migrate | tail -2
```

Expected: exactly one new file in `db/migrate/`; `db/schema.rb` and `db/schema_sqlite.rb` both modified with the **same** version, equal to the newest migration's timestamp; `db/cable_schema.rb` absent; no abandoned migration left behind.
