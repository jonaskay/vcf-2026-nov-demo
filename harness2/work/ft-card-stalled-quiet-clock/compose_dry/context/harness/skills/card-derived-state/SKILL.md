---
name: card-derived-state
description: Checklist for adding a stored/derived state, badge and index filter to Fizzy cards.
---
Extend Card with a concern (derive state from events/comments/time), query it via a scope + matching predicate, render it everywhere cards appear. Keep names, thresholds and index value exactly as the request words them.

Workspace facts (from earlier runs on a "stalled card" request; verify with grep):
- Card concerns live in `app/models/card/*.rb`; register in the `include` list in `app/models/card.rb`.
- `Card.indexed_by` (`case index`) AND `Filter::Fields::INDEXES` (app/models/filter/fields.rb) must both gain a new index value; that file also has index labels.
- Hooks: `Card::Eventable#event_was_created` (calls `touch_last_active_at`) and `Comment::Eventable#event_was_created`. Exclude system-user comments when counting; `comments.by_user` exists.
- Board auto-close period is `auto_postpone_period` (seconds).
- Schema: keep BOTH `db/schema.rb` and `db/schema_sqlite.rb` in sync with a new migration; run `bin/rails db:test:prepare`.
- Export/import: `Account::DataTransfer::RecordSet` requires every `Card.column_names` key, so a new cards column breaks `check` on older archives; make it optional and test.
- Display surfaces: `cards/display/_preview`, `_public_preview`, `public/cards/show`, `cards/_container`, `cards_helper#card_article_tag`, `cards/_card.json.jbuilder`, `notifications/_notification.json.jbuilder`, `my/menus/_shortcuts`. `grep -rn golden app/views app/helpers` finds the closest analogue.
- Fragment caches key on updated_at, so a purely time-based state serves stale HTML/JSON. Include the state in the cache key (`[card, card.stalled?]`) or override `cache_version`; cover every cached surface incl. turbo_stream previews.

Checks before finishing:
1. Scope and predicate agree at the boundary (>= vs >) and on nil columns; test exactly at the threshold.
2. Any activity resets the state; confirm which writes bump `last_active_at`.
3. Unassign/close/system comments must not trigger burst-like events unless requested.
4. Tests: `test/models/card/<concern>_test.rb` (`travel_to`, `Current.session = sessions(:david)`), plus controller test for index HTML + JSON + card page.
