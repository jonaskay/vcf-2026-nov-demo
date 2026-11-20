# Skill: adding a database migration in this repository

Goal: one migration, both schema files consistent with it, no generated noise in the diff. This takes about 5 steps. Reworking a migration that has already run costs 5–10 steps.

## Workspace facts (seen in this repository's command output)

- In this workspace the app has **several databases** (primary + cable; see `config/database.sqlite.yml`). Unscoped `bin/rails db:rollback` / `db:migrate:down` **fail** with "You're using a multiple database application...". Use `bin/rails db:migrate:down:primary VERSION=<ts>` or `bin/rails db:rollback:primary STEP=1`.
- `bin/rails db:migrate` regenerates `db/schema_sqlite.rb` (the `schema_dump` in `config/database.sqlite.yml`). It **also rewrites `db/cable_schema.rb`**. That rewrite is noise: run `git checkout -- db/cable_schema.rb` after **every** migrate or rollback.
- `db/schema.rb` is the MySQL schema. `db:migrate` does **not** update it. Edit it by hand: bump its `define(version: ...)` line and add the same column/index lines the migrate added to `db/schema_sqlite.rb`, in the same position, keeping that file's MySQL formatting.
- Existing migrations use `ActiveRecord::Migration[8.2]`. Get the timestamp from `date -u +%Y%m%d%H%M%S`, and check that it sorts after `ls db/migrate | tail -3`. Do not invent a round number.
- A plain `bin/rails db:migrate` (development) is enough. After it, `bin/rails test` uses the new column. The full suite (`bin/rails test`, about 1,540 tests) takes about 25 seconds.

## Procedure

1. **Settle the whole schema before you migrate**: every column **and every index** the feature's queries need. Look at the scopes you plan to write. Adding an index to a migration after it has run is the costly path below.
2. Write the migration (a reversible `change`) and run `bin/rails db:migrate`.
3. Run `git checkout -- db/cable_schema.rb`.
4. Mirror the `git diff db/schema_sqlite.rb` hunks into `db/schema.rb` by hand. Never hand-edit `db/schema_sqlite.rb`, because the migrate regenerates it.
5. Run the focused tests, then `bin/rails test`.

## Changing a migration that has already run

Roll back **before** you edit the file. Rollback replays the file as it is on disk, so if you edit first, the rollback tries to remove an index or column that the database never got, and fails with "No indexes found...".

1. With the migration file still in its original form, run `bin/rails db:migrate:down:primary VERSION=<ts>`.
2. Edit the migration file, then run `bin/rails db:migrate`.
3. Repeat Procedure steps 3–4.

If you already edited the file and the rollback fails, put the file back to the version that ran, roll back, then reapply your edit. Do not create the missing object by hand with `rails runner`. Do not add a second migration just to get around the failure.

## Done check (run once, before submitting)

```bash
git status --short db/ ; grep -n 'define(version' db/schema.rb db/schema_sqlite.rb ; ls db/migrate | tail -2
```

Expected: the new migration file(s) you meant to add; `db/schema.rb` and `db/schema_sqlite.rb` both modified with the **same** version, equal to the newest migration's timestamp; `db/cable_schema.rb` not listed.
