I added one skill, `skills/card-query-page/SKILL.md`, and one trigger line for it in `system.md`. I didn't run anything. The skill is built from the three `agent.patch` files and the step list of r2.

- **Why a skill:** all three runs finished in roughly 26 steps with similar designs. Each one re-derived the same facts: `Current.user.accessible_cards`, `.published`, `reverse_chronologically`, pagination, the rich-text tables, and a LIKE scope with escaping. The skill states those facts so a run doesn't have to rediscover them.
- **Facts taken from the patches:** the rich-text record names, `set_page_and_extract_portion_from` with `with_automatic_pagination`, the `_jump.html.erb` navigation entry, the test fixtures, and the helper for creating draft comments in tests.
- **Divergences between runs:**
  - r1 and r3 used `SearchController`; r2 used `SearchesController`.
  - r1 and r3 put the query in model scopes; r2 put it in the controller with JOINs plus `distinct`.
  - r1 and r3 added the navigation link; r2 did not.
  - The skill points to scopes on the model, a thin controller, and a card shown once even when several comments match. It also tells the agent to add the navigation entry.
- **Checklist:** it covers LIKE wildcard escaping, a blank `q`, no duplicate cards, HTML-safe highlighting, tests for each required behaviour, and not leaving scratch files.
- **Not verified:** no run touched migrations or schema files. The task name and tags suggest a search-index approach, but no run tried one. The skill therefore only says to keep schema files in sync if migrations come up, and to say so if LIKE case behaviour on SQLite versus MySQL is unchecked. I did not write either as fact.
