I added one component: a new skill, `skills/card-state-and-index/SKILL.md`. I also added its trigger line to `system.md`, above the workflow list: "When the request adds a card state, flag, badge or `indexed_by` list, or changes what counts as card activity, run `cat /opt/harness/skills/card-state-and-index/SKILL.md` and follow it." No other file changed, and the submit instruction is still there.

**Why a skill.** All 3 base runs completed but took 66–77 minutes of the 90. Each spent its first 25–43 steps working out the same map: concerns, activity hooks, filter wiring, the partials that show a card, and the cache sites. Where they disagreed, at least one run had already found the right fact, so this is cheap to tell the agent. A skill costs nothing on unrelated tasks and can be reused by any later card-state task.

**What each section rests on (run, step, file:line):**

- **§1 Model: concern, scope and matching predicate.** Card's include list, `indexed_by` case, Golden, Entropic and Postponable read at r1 step 6 and step 8. Checking the scope and predicate at the boundary comes from r1's boundary tests (step 63).

- **§2 Activity hooks.**
  - Card::Eventable, Comment::Eventable, Event `after_create`, and Reaction `register_card_activity`: r1 steps 6–8.
  - SystemCommenter and `Comment.by_user`: r1 steps 6 and 8.
  - Client-set comment `created_at`: r2 step 94 (`comments_controller.rb:2` and `:60`).
  - `auto_postpone_period` delegation: r1 step 6.
  - **The `was_just_published` pitfall is a repeated failure that cost time.**
    - r1 step 71: the reset assertion failed on a card created as published.
    - r1 step 72: r1 fixed it by clearing the flag.
    - r1 step 109: the full suite then failed `statuses_test.rb:54`, `:65` and `mentions_test.rb:17`.
    - r1 steps 110–112: it reworked the fix again.
    - r3 steps 53–59 also added debug `warn`s around the same issue.
    - r2 step 62 and r3 step 57 landed on `was_just_published? && event.action.card_published?`, the condition the skill suggests.

- **§3 Listing wiring.**
  - `INDEXES`, `Filter#cards`, `include_closed_cards?` and `include_not_now_cards?`: r1 step 6.
  - Shortcuts menu: r1 step 21.
  - Divergence: r3 included closed and Not Now cards in the list (its `filter.rb` change and its test); r1 and r2 did not. The skill makes the agent decide and test it, without picking a side.

- **§4 Display surfaces.**
  - `_stamp` is rendered by `_preview` and `_public_preview` (r1 step 8) and by `public/cards/show` (r1 step 25).
  - Notification header: r1 step 30. Event layout: r1 step 25. Pin partial: r1 step 7.
  - Divergence: r2 changed only `_stamp`. r1 also changed notifications. r3 also changed the events, search and public card views. The skill lists the surfaces that bypass the stamp partial.
  - I did not verify whether `cards/_container` renders the stamp, so the skill tells the agent to grep rather than asserting it.

- **§5 Caching.**
  - `cached:` sites: r1 step 26.
  - `cache card` and the card-related etags: r1 step 29.
  - The full `fresh_when` list: r2 step 96.
  - Divergence: only r2 fixed the board-column etags (r2 step 103, with a 304 test in `columns_controller_test`). r1 overrode `cache_key_with_version` and r3 used per-site keys; neither touched those etags.

- **§6 Schema.**
  - `cable_schema` noise: r1 step 101 (`git checkout`) and r3 step 83.
  - `db/schema.rb` edited by hand: r1 step 87 and r3 steps 79–80.
  - Unscoped `db:rollback` fails: r2 step 82.
  - Late index changes forced re-migration: r1 steps 79–87 and r2 steps 80–88.
  - The required-columns import check: `record_set.rb` `check_record` at r1 step 108. 2 of 3 runs patched it; r3 did not and still passed the full suite (r3 step 137). So the skill states it as an open decision to keep small, not a requirement. This follows the library lesson that this kind of rule drives scope sprawl.

- **§7 Tests.**
  - Fixtures: r1 step 28.
  - Shipping is closed: r1 step 8, `closeable_test`.
  - Suite size and runtime (1,540 tests in 17 s): r1 step 109.

**What I left out:** request-specific values (thresholds, the column name, the label), any fixture entropy value I could not confirm, and anything about procedure or timing.
