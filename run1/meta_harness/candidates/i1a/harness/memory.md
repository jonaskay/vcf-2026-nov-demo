## Fizzy / Rails facts

- Models are small concerns under `app/models/<model>/<concern>.rb` (e.g. `Card::Entropic`, `Card::Stallable`, `Card::ActivitySpike`), included in the model. Check whether a concern for your domain already exists before creating one.
- Card list filters: `Card.indexed_by`/`Filter::Fields::INDEXES` map `indexed_by=` values to scopes. Card JSON lives in `app/views/cards/_card.json.jbuilder`.
- Cards render in many places (previews, perma/container, public previews, notifications, JSON, board columns). "Wherever cards are shown" means checking all of them. Fragment caches are keyed on the record: if new display depends on time or other state, add it to the cache key.
- `last_active_at` is touched by card events; activity-derived state should use it or events, not new bookkeeping, where possible. Prefer deriving time-based state from timestamps in a scope + predicate pair (SQL scope and Ruby method must agree) over storing flags that need a job to flip.
- Multi-tenant: records belong to `account`; jobs restore `Current.account`. Everything is UUID-keyed.
- Two schemas: `db/schema.rb` (MySQL) and `db/schema_sqlite.rb`. A migration needs both updated consistently (same version, same table change). Running `db/migrate` may also rewrite unrelated schema files: `git checkout` those.
- Recurring jobs: `config/recurring.yml`. For big tables, use `find_each`/`in_batches` and index-friendly predicates (compare the bare column to a computed value; avoid wrapping columns in functions). Check with `EXPLAIN QUERY PLAN`.
- Tests: Minitest with fixtures in `test/fixtures`; `freeze_time` / `travel_to` for time; sign in via the helpers in `test/test_helper.rb`. Fixtures are older than runtime records.
- Scopes with joins: qualify column names (`cards.last_active_at`) to avoid ambiguity.
