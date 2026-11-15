## Fizzy facts

- Models are concerns under `app/models/<model>/<concern>.rb`; check if one for your domain already exists (look at siblings of the model you touch).
- Cards render in many places (previews, perma container, public previews, JSON, columns). Fragment caches are keyed on the record, so state not in the record must go in the cache key.
- Tests: Minitest + fixtures; `bin/rails test <path>`; full suite takes about a minute.
- Two schema files: `db/schema.rb` (MySQL) and `db/schema_sqlite.rb`.
- Recurring jobs are declared in `config/recurring.yml`; a `command:` entry is plain Ruby, usually a class method on a model.
- Per-record settings (e.g. entropy periods) can come from a board override or an account default, and only a fixed list of values is valid.
