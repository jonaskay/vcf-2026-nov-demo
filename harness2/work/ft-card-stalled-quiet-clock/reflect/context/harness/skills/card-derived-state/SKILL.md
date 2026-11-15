---
name: card-derived-state
description: Checklist for adding a stored/derived state, badge and index filter to Fizzy cards.
---
Operation: extend Card with a concern (derive state from events/comments/time), query it via a scope + matching predicate, render it everywhere cards appear. Use the request's exact names, thresholds and index value; do not rename them.

Workspace facts (verify with grep before relying):
- Card behavior lives in concerns `app/models/card/*.rb`; add one and register it in the `include` list in `app/models/card.rb`.
- `Card.indexed_by` scope (card.rb, `case index`) AND `Filter::Fields::INDEXES` (app/models/filter/fields.rb) must both gain a new index value; that file also has index display labels.
- Hooks: `Card::Eventable#event_was_created` (assigned/reopened events, calls `touch_last_active_at`) and `Comment::Eventable#event_was_created`/`track_creation` (comment created). Hook there rather than adding callbacks elsewhere. Exclude system-user comments (`users(:system)` in fixtures) when counting people/comments; `comments.by_user` exists.
- Board auto-close period is `auto_postpone_period` (seconds) on the board.
- Schema: keep BOTH `db/schema.rb` and `db/schema_sqlite.rb` in sync with a new migration (same version, column added in both). Run `bin/rails db:test:prepare` after.
- Export/import: `Account::DataTransfer::RecordSet` requires every `Card.column_names` key in archives, so a new cards column makes older archives fail `check`. Handle it (optional attributes in Manifest/RecordSet + a test).
- Card display surfaces: `cards/display/_preview`, `_public_preview`, `public/cards/show`, `cards/_container`, `cards_helper#card_article_tag`, JSON `cards/_card.json.jbuilder` (add a boolean key), `notifications/_notification.json.jbuilder`, `my/menus/_shortcuts`. Find others with `grep -rn golden app/views app/helpers`: golden is the closest analogue.
- Fragment caches (`cached: true`, `cache card`, `json.cache!`) key on updated_at, so a purely time-based state serves stale HTML/JSON. Include the state in the cache key (`[card, card.stalled?]`) or override `cache_version`; apply to every cached surface, including turbo_stream previews.

Consistency checks before finishing:
1. Scope and predicate agree at the boundary (>= vs >) and on nil columns; test both at exactly the threshold.
2. Any activity resets the state: confirm which writes bump `last_active_at` and that the state derives from it.
3. Unassign/close/system comments must not trigger event-like triggers unless requested.
4. Tests: model test `test/models/card/<concern>_test.rb` (`travel_to`, `Current.session = sessions(:david)`), controller test in `test/controllers/cards_controller_test.rb` for index HTML + JSON + card page.
