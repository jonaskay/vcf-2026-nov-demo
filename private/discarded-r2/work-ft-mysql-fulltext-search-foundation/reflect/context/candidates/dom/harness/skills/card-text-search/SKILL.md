# Card text search and visibility (Fizzy)

Use this when a change matches cards by their text or limits cards to what a user may see. Names, URLs, ordering and markup the request specifies are fixed; this skill only covers how to build them in this codebase. Re-read the request for its exact rules (which fields, ordering, highlighting, who sees what) and check each one against the list at the end.

## 1. Workspace facts (verified in this checkout; `sed -n` the file before relying on a detail)

Visibility
- `Current.user.accessible_cards` (`app/models/user/accessor.rb`: `has_many :accessible_cards, through: :boards, source: :cards`, plus `accessible_comments`) is the access rule the app already uses. `CardsController#set_card` does `Current.user.accessible_cards.find_by!(number: ...)`. Start any user-facing card query from it, not from `Card` or `Current.account.cards`.
- Access is a live `accesses` row. `board.accesses.revoke_from(user)` deletes it (`app/models/board/accessible.rb`), so a query that joins through accesses on each request is always current. That method is a no-op on `all_access` boards. Anything copied or cached per user (index rows, cached fragments, etags) goes stale when access is revoked.
- Drafts: `Card::Statuses` (`app/models/card/statuses.rb`) defines `enum :status, drafted/published`, so `.published` and `.drafted` scopes exist. `Card#publish` resets `created_at` to now. Comments on drafts are blocked by validation (`Comment#card_is_commentable` → `Card::Commentable#commentable?` = `published?`), but rows can still exist. Exclude drafts with `.published` on the card side, which also excludes draft cards' comments.

Ordering and paging
- `Card.reverse_chronologically` = `order created_at: :desc, id: :desc` (newest first). `Comment.chronologically` is `created_at: :asc, id: :desc`.
- Listing controllers use `set_page_and_extract_portion_from <relation>` (geared_pagination) and views use `with_automatic_pagination :name, @page do ... end` (`app/helpers/pagination_helper.rb`).

Text sources
- `cards.title` is a plain string column. `prompts/cards_controller.rb` already filters on it with `where("title LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(...)}%")`.
- `Card has_rich_text :description` and `Comment has_rich_text :body` are stored in `action_text_rich_texts` (`record_type`, `record_id`, `name` = "description"/"body", `account_id` NOT NULL, `body` long text). `Comment.joins(:rich_text_body)` produces that join.
- **`body` holds HTML, not the text people see.** Tests build bodies like `"<p>...</p>"`, and mentions and attachments are stored as `<action-text-attachment ...>` markup (`test/integration/notifications_test.rb`, `test/models/storage/tracked_test.rb`). Plain text comes from `.to_plain_text` (`app/views/cards/_card.json.jbuilder`). `app/helpers/excerpt_helper.rb` has `format_excerpt(content, length: 200)`, and ActionView's `highlight`/`excerpt` produce `<mark>`.

Databases
- `config/database.yml` loads `config/database.#{Fizzy.db_adapter}.yml`. Tests run on SQLite (`storage/test.sqlite3`, `schema_dump: schema_sqlite.rb`). `db/schema.rb` is the MySQL dump (`utf8mb4_0900_ai_ci`). Raw SQL must be valid on both. `LIKE ... ESCAPE '!'` with `sanitize_sql_like(term, "!")` works on both. MySQL-only syntax (FULLTEXT, `MATCH ... AGAINST`) cannot run in the SQLite test suite unless you branch on the adapter.
- A schema change must appear in **both** `db/schema_sqlite.rb` and `db/schema.rb`, in each file's existing style (uuid ids).

## 2. Decision: where matching happens

Default: query live tables (cards + `action_text_rich_texts` + comments) through `EXISTS` subqueries inside one card scope on `Card`. This returns each card once, needs no backfill, and sees fixture data. Fixtures (`test/fixtures/cards.yml`, `comments.yml`, `action_text/rich_texts.yml`) load without callbacks.

Because `body` is HTML, a LIKE on it also matches markup and misses text the editor stored escaped. State this limitation in your reasoning and handle the view side:
- build excerpts from `to_plain_text`, never from raw `body`;
- before finishing, try a query such as `strong`, `href` or `action-text-attachment` and confirm what it returns. A result card whose visible text has no `<mark>` shows the mismatch.

If you instead keep a plain-text copy (a new table or column filled by callbacks), all of these are required:
- a migration, and the change in both schema files;
- callbacks on every write path: card create/update (title, description, publish), comment create/update/destroy, card destroy;
- existing fixtures stay unindexed until you add fixture rows or a reindex that tests can call;
- visibility is still filtered live through `accessible_cards.published`. Never copy access into the index.

## 3. Placement (Fizzy conventions)

- Put query logic in a named scope or class method on the model (`app/models/card.rb` or a `Card::` concern). Keep controllers thin (STYLE.md "vanilla Rails"). Expanded conditionals beat guard clauses (STYLE.md).
- Routes are CRUD resources. A singular resource maps to a plural controller: `resource :landing` → `LandingsController`, and `namespace :my { resource :menu }` → `My::MenusController`. For a page at `/x`, `resource :x, only: :show` gives `x_path`. Confirm the helper and URL with `bin/rails routes -g <name>`.
- A blank query should give an empty result, not every accessible card.

## 4. Writing the tests (failures every base run hit)

- Creating a **published** card in an integration test without a current user fails with `Validation failed: Creator must exist`, raised from `Eventable#track_event` (`app/models/concerns/eventable.rb:10`, triggered by `card/statuses.rb` `after_create`). Wrap creation in `with_current_user(:kevin) { ... }` (`test/test_helpers/session_test_helper.rb`).
- To plant a comment on a draft you must skip validation. `belongs_to :account, default:` only runs during validation, so with `save!(validate: false)` pass `account: accounts("37s")` explicitly, or the insert fails with `NOT NULL constraint failed: comments.account_id`. Its rich text also needs `account_id`.
- Access fixtures: `boards(:writebook)` is all_access. `boards(:private)` is `all_access: false` with only kevin (`accesses.yml: private_kevin`), so jz cannot see it. Account `initech` (mike, `miltons_wish_list`, draft card `unfinished_thoughts`) is a separate tenant. `sign_in_as :kevin` / `logout_and_sign_in_as :jz` switch the viewer.
- Request pages through route helpers (`get x_path, params: {...}`), not literal paths. Integration tests run under an account `script_name` (`test/test_helper.rb`).

## 5. Done check

Confirm each item with a test or a command you ran:
1. Every field the request names matches: title, description, a comment body.
2. Ordering matches the request, tie-broken by id.
3. Draft cards and their comments never appear.
4. A user without access sees nothing, and revoking access removes the result on the next request.
5. Matches are wrapped exactly as requested, and user text stays escaped (`highlight` sanitizes; never `raw`/`html_safe` card text).
6. `%`/`_` in the query are literal, and a blank query returns nothing.
7. A cross-account card never appears.
8. If the schema changed, both `db/schema.rb` and `db/schema_sqlite.rb` reflect it, and nothing else regenerated is left in the diff.
