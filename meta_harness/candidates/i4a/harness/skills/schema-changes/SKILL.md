# Schema changes

- Only add a column or index if the requirement can't be met from existing data.
- Create `db/migrate/<timestamp>_<name>.rb` with the same `ActiveRecord::Migration[x.y]` version as the latest migration; timestamp later than the newest existing one.
- Update both `db/schema.rb` (MySQL syntax) and `db/schema_sqlite.rb` with the same table change and the same `define(version:)`. Columns/indexes are listed alphabetically.
- `RAILS_ENV=test bin/rails db:migrate` may rewrite other schema files (`db/cable_schema.rb` etc.); `git checkout` the unrelated ones and check `git status --short`.
- Tables use UUID primary keys; reference columns are `:uuid`. Include `account_id` on new tenant tables.
- Backfill existing rows if behavior depends on the new column.
