---
name: card-query-page
description: Building a new page/query over Fizzy cards and comments scoped by access
---
Verified in earlier runs (re-check with grep before relying):
- Access scoping: `Current.user.accessible_cards` is the access-aware relation; revoking access hides cards without extra code. Never query `Card` globally.
- Drafts: apply `.published` to cards; exclude comments on drafts by querying via published cards.
- Rich text: `action_text_rich_texts` (name 'description' for Card, 'body' for Comment); associations `rich_text_description`, `rich_text_body`. Bodies are HTML.
- Ordering: `Card.reverse_chronologically` exists; reuse it.
- Pagination: `set_page_and_extract_portion_from` in controller, `with_automatic_pagination` in view.
- Query logic in a named model scope; thin controller. Controller tests in test/controllers (`sign_in_as :kevin`); create records inside `Current.set(account: accounts("37s"), user: users(:kevin)) { ... }`.
- Routes: check with `bin/rails routes -g <name>`.

Checklist before finishing:
1. Literal user input in LIKE: escape with `sanitize_sql_like`; test `%`/`_`.
2. Blank/missing `q` renders with no results and no error.
3. A card matching via several comments is returned once.
4. Highlight with `<mark>` on plain text so content is HTML-escaped; test an HTML-bearing title.
5. Tests cover: each searched field, ordering, revoked access, drafts (card and its comment), blank query.
6. Keep every schema file in db/ in sync if you add a migration; otherwise add none.
7. No scratch files in /app.
