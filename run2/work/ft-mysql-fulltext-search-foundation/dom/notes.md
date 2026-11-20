**Change:** I added one component, the skill `skills/card-content-search/SKILL.md`, with its trigger line in `system.md` (line 3). Nothing else changed. The submit instruction is still there.

**Why**

All 3 base runs built the same thing: a `LIKE '%q%'` over `cards.title` and over `action_text_rich_texts.body`, treating the whole query as one phrase:
- r1: `Card.matching_search_term`
- r2: `matching_search_term`
- r3: `Card.searching`

Since the runs agree, the problems are shared omissions, not divergences. The skill turns them into checks:

1. **Words, not one phrase (contract item 1).** The request says "matched words wrapped in `<mark>`". Every patch treats `q` as one phrase: one `LIKE` pattern and `highlight(card.title, @query)`. A query such as `logo big` would not find the fixture card "The logo isn't big enough". The skill asks for per-word AND matching, highlighting with a word array, and a test on that fixture card.
2. **The stored body is HTML (contract items 2 and 5).** Repository evidence:
   - The schema shows `body` as a long text column (r1 step 7: `db/schema.rb` and `db/schema_sqlite.rb`, around line 88).
   - `test/controllers/cards_controller_test.rb` stores `<action-text-attachment sgid=...>` in a description (r1 step 8, r2 step 6).
   - Runs saved `<p>…</p>` bodies in their own tests (r3 step 43).

   So `LIKE` on `body` also matches markup and misses `&amp;`. In r3 the selection and the snippet disagree: r3 step 43 selects with SQL `LIKE` on HTML but chooses the snippet with a Ruby regex on `to_plain_text`. The skill states the limit. It makes a plain-text index (migration + callbacks) explicitly OPTIONAL, with its full requirements. Following the library lesson in `ft-card-stalled-quiet-clock`, nothing beyond the request is mandatory, because r3 already took 62 minutes.
3. **Workspace facts, so the next run doesn't have to rediscover them.** Each is backed by command output in a trajectory:
   - `accessible_cards` comes from `user/accessor.rb` (r1 step 6).
   - The drafted/published enum is in `Card::Statuses` (r1 step 6, r2 step 7).
   - `reverse_chronologically` is defined in `app/models/card.rb` (r1 step 5).
   - Tests run on SQLite; `db/schema.rb` is MySQL: `config/database.sqlite.yml` (r1 step 9), `config/database.yml` (r1 step 8), and the MySQL collation in `db/schema.rb` (r1 step 7).
   - `ExcerptHelper` already exists (r1 step 8). r1's new `SearchHelper` repeated its `to_plain_text` line.
   - Pagination helpers live in `app/helpers/pagination_helper.rb` (r1 step 9).
   - An existing card search, `Prompts::CardsController#search_cards`, is at line 21 of its controller (r1 step 5 grep output).
   - Menu partials and the `icon--search` icon (r1 steps 5 and 7).
4. **Test facts that cost the runs steps:**
   - `revoke_from` does nothing on an all-access board (`Board::Accessible`, r1 step 5). r2's test had to set `all_access: false` first.
   - Fixture access rows (r1 step 8).
   - The `commentable?` validation on comments means draft comments need `save!(validate: false)` and an `account` on the rich-text row. r1 rewrote this test setup across steps 26–40, and r3 across steps 27–40.

**Divergences I left alone**
- **Controller and route name:** `SearchController#index` in r1 and r3, `SearchesController` in r2.
- **Menu placement:** the jump hotkey in r1 and r2, the shortcuts list in r3.

Both are harmless, and the skill lists the menu only as an optional entry point.

**Risk to watch:** the per-word AND rule is my reading of "matched words". Compare candidate runs against base to see whether it changes which results come back. The optional index section is there to name the fixture/callback trap, not to grow the scope.
