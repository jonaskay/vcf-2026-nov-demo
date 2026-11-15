I added one skill, `skills/card-derived-state/SKILL.md`, and a trigger line for it in `system.md`. I didn't open the trajectories themselves, only `agent.patch` and `result.json` for each run (r3's patch only up to line 200). The workspace facts in the skill come from those patches.

- **Data transfer (divergence):** Only r2 handled export/import. It made the new `cards` column optional in `Account::DataTransfer::Manifest` and `RecordSet`, so older archives still pass `check`, and it added a test. r1 and r3 skipped this. The skill lists it as something to check.
- **Fragment caches (divergence):** The state is time-based, so cached card HTML and JSON would go stale. r1 and r3 put `[card, card.stalled?]` into the cache keys. r2 overrode `cache_version` instead. The skill tells the agent to cover every cached surface, including the turbo_stream previews. Only r1 touched the turbo_stream and notification JSON caches.
- **Touch points that varied between runs:** The runs differed on:
  - whether `Filter::Fields` got a display label (only r3 added one);
  - whether the `my/menus` shortcut was added (only r2);
  - which card surfaces got the badge.

  The skill names the known surfaces and points to `golden` as the closest existing feature to copy.
- **Fixed points all three runs found:**
  - Card concerns go in `app/models/card/*.rb`, registered in the `include` list in `card.rb`.
  - A new index value must be added to both `Card.indexed_by` and `Filter::INDEXES`.
  - Hooks go in `Card::Eventable` and `Comment::Eventable`.
  - A schema change must be made in both `db/schema.rb` and `db/schema_sqlite.rb`.
  - System-user comments are excluded when counting people.
- **Consistency checks:** The scope/predicate boundary, `last_active_at` as the reset signal, and unassign/system events not triggering a burst come from small differences in how the three runs wrote these.
