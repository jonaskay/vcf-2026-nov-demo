I added one skill, `skills/card-text-search/SKILL.md`, with its trigger line under a new "## Skills" heading in `system.md`. Nothing else changed: `guardrails.md`, `memory.md` and `tool_guidance.md` are untouched, and the submit instruction is unchanged.

**Why a skill:** all three base runs completed (38, 20 and 62 minutes). They did not fail by timing out. They kept rediscovering the same codebase mechanics and shared one blind spot. All of this has a clear trigger (card text search or card visibility), so it costs nothing on unrelated tasks.

**Moments that motivated each section:**

1. **Test-writing facts (§4): the same failure in every run that ran its tests early.**
   - r3 steps 27–28 and r1 step 28: `Validation failed: Creator must exist`, raised at `app/models/concerns/eventable.rb:10` via `card/statuses.rb:8`, when creating published cards in a test.
   - r3 then created cards as drafts and switched them to published with `update_column`. r1 and r2 ended up using `with_current_user` instead, which is defined in `test/test_helpers/session_test_helper.rb` (r1 step 24 output).
   - r3 step 29: `NOT NULL constraint failed: comments.account_id` when saving a draft comment with `validate: false`.
   - These failures and their fixes cost about 10–15 steps per run (r1 steps 25–40, r3 steps 27–41).
   - Fixture facts come from r3 step 5 (cards, comments, boards, accesses and users fixtures) and `revoke_from` from r3 step 6 (`board/accessible.rb`).

2. **Rich-text bodies hold HTML (§1, §2): a risk visible in a trajectory, not yet realised.**
   - All three patches run `LIKE` against `action_text_rich_texts.body`.
   - Evidence that the body is HTML: r3 step 7 grep (`"<p>…</p>"` bodies in `tracked_test.rb:178`, mention markup in `notifications_test.rb:88`) and `_card.json.jbuilder` using `to_plain_text`.
   - r3's view (patch lines 134–135) only shows the description excerpt when the plain text matches. That means a card can be listed with no visible `<mark>`, which suggests the run noticed the mismatch.
   - The skill makes the trade-off explicit and checkable. The default is a live query, because fixtures load without callbacks. If the agent builds a plain-text copy instead, the skill lists everything that route requires.

3. **Visibility, ordering and access facts (§1).** All runs converged on these, but each paid to find them:
   - `accessible_cards` and `CardsController#set_card`: r3 step 5.
   - `reverse_chronologically` and `Comment.chronologically`: r3 step 5.
   - `.published` and `publish` resetting `created_at`: r3 step 5 (`statuses.rb`).
   - The existing title `LIKE` in `prompts/cards_controller.rb:23`: r3 step 6.
   - Pagination: r1 step 9.

4. **Databases and schema files (§1).**
   - `config/database.yml` choosing a file by `Fizzy.db_adapter`, and `database.sqlite.yml` showing tests run on SQLite with `schema_sqlite.rb`: r3 step 6, r1 step 9, r3 step 7.
   - `db/schema.rb` being the MySQL dump (`utf8mb4_0900_ai_ci`): r3 step 5.
   - This guards against raw SQL or a migration that only works on one adapter. I did not copy the earlier library's migration commands, because I could not re-verify them here. I kept only the two-schema-files rule, which this evidence does show.

5. **Routing convention (§3): the runs disagreed.**
   - r1 and r3 used `get "search" → search#index`; r2 used `searches#index`.
   - In this repo a singular resource maps to a plural controller (`resource :landing`, `my/menus_controller.rb`), and STYLE.md asks for CRUD resources (r3 step 5 output). r1 even looked at `landings_controller` at step 59.
   - The skill keeps whatever URL and helper the request asks for, and has the agent confirm them with `bin/rails routes -g`, which r1 ran successfully at step 42.

6. **Done check (§5).** It turns the request's observable rules into items the agent checks against its own tests and commands. It points back to the request for the exact rules and stores none of them.

**What I left out on purpose:** this request's own facts (the route name, `<mark>`, the query parameter), any latest migration version or timestamp, and procedure or time-budget advice.
