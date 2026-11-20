I changed one component: a new skill, `skills/card-feature-surfaces/SKILL.md`. Its trigger line is in `system.md`, as the second paragraph, ahead of the workflow. Nothing was added to always-on text beyond that one line. The submit instruction is untouched.

**Why a skill.** All three base runs completed, every last test run exited 0, and each ran the full suite. So there was no shared failure to fix. What varied was the practitioner details, and those apply whenever a feature is attached to cards. That gives a clear trigger, so this belongs in a skill rather than always-on text.

**What the skill encodes, and the trajectory moment behind each part:**

1. **Sibling-stack checklist** (model, controller, route, views, JSON link, tests), using comment reactions as the reference. Source: r1 step 5 grep output: `comment.rb:7`, `comment.rb:14`, `_comment.json.jbuilder:19`, `routes.rb:103`, `flat_json_params_test.rb:159`, `manifest.rb:51`. All three runs rebuilt this inventory themselves, spending about 15–20 minutes before their first write (r1's first write was step 21, r3's step 18, r2's step 44).

2. **Data-model decision rule.** This is a divergence. r1 made reactions polymorphic (`reactionable`); r2 and r3 added a nullable `card_id` plus an exactly-one-parent validation. Evidence that both fit the codebase:
   - polymorphic precedent (`concerns/eventable.rb`, `mentions.rb`, `notifiable.rb`, `event.rb:7`): r1 step 8
   - dual optional-FK precedent (`search/result.rb:7-8`): r1 step 8
   - data transfer handles polymorphic types generically (`record_set.rb`): r1 step 53
   
   I named what each option obliges the agent to do rather than forcing one. The `card.rb:50` `def card` fact is from r1 step 55.

3. **Migration and schema contract.**
   - The MySQL `db/schema.rb` has to be edited by hand. All three runs did this: r1 step 38, r2 step 67, r3 step 35.
   - `db:migrate` rewrites `db/cable_schema.rb`, which must be reverted. All three runs hit this: r1 step 38, r2 steps 71 and 114, r3 step 35.
   - The project uses no foreign keys. r3 used `foreign_key: true` and had to roll it back (steps 33–35). The `remove_all_foreign_key_constraints` migration appears in r1 step 7's listing.
   - The base migration version 20260709120000: r1 step 7.

4. **Where card behavior renders.**
   - Previews:
     - All the places previews are rendered, including the pins tray and the cached collections: r2 steps 115–116.
     - Comments indicator to copy (`_comments.html.erb`): r1 step 7.
     - `trays.css` is a divergence: only r3 added `.card__boosts` to the tray's hide list (r3 patch). r1 and r2 left boost counts visible in the pins tray, where comment counts are hidden.
     - Counter-cache detour: r2 steps 99–113, about 5 minutes lost.
   - Caching, touch and broadcast facts:
     - `card.rb:18`, `card_scoped.rb:18`: r2 step 31.
     - `Card::Broadcastable`: r3 step 37.
   - `--reaction-size` defined only in `comments.css`: r1 step 8 grep. r1 and r3 had to add perma CSS for it.
   - Detail view structure (`show.html.erb` renders container then messages): r1 step 7. Placement diverged: r1 and r3 used `_container`, r2 used `_messages`.

5. **Gating decision.** Another divergence: only r2 refused card-reaction creation on non-commentable (draft) cards. The evidence is `Cards::CommentsController#ensure_card_is_commentable`, r2 step 32. The request says card reactions should behave like comment reactions in every other respect. A comment can only exist on a card that passed this gate, so I made the rule reproduce it.

6. **Tests.**
   - Integration tests need an explicit `reacter:`, otherwise the create fails with "Reacter must exist" (r3 step 36).
   - Copy the sibling test structure (r1 step 6).
   - Public column test path (r1 patch context; r1 step 46 cat).
   - Full suite size and run time (r3 step 50).

**Risk that hasn't happened yet:** `docs/api/` exists (r2 step 33, "docs/api: Is a directory"), and no run checked it or updated it. The skill tells the agent to grep it, not to assume what it contains.

I took workspace facts only from command output in the trajectories, not from the `agent.patch` files. The one exception is line-number hints such as "~line 198" in `cards_controller_test.rb`, which come from the patch hunk context lines; those are unchanged repository content.
