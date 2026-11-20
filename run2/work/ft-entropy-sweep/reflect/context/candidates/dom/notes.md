**What I changed:** I added one component, the skill `skills/query-performance-change/SKILL.md`. Its trigger line is in `system.md`, placed after the workflow list. The submit instruction is unchanged. No other always-on text was touched.

**Why this component.** All three runs agreed on the diagnosis. Each ran EXPLAIN QUERY PLAN and got `SCAN cards`, and each saw that the existing index starts with `account_id`, so a sweep across all accounts can't use it (r1 step 12, r3 step 9–10). Where they differed was the practitioner side of the change:

- **r1** (completed, 31 min): kept `due_to_be_postponed` as the single source of truth. It added a constant range filter, a new index, a migration, and updated both `db/schema.rb` and `db/schema_sqlite.rb`. It reverted the unwanted rewrite of `db/cable_schema.rb` (step 55–56).
- **r2** (timed out at 91 min):
  - rewrote the sweep as a per-board loop;
  - **removed** `index_cards_on_board_id` in its migration;
  - changed `Card::Eventable::SystemCommenter`, which was not requested.
- **r3** (completed): moved the sweep to a per-account loop. It left `due_to_be_postponed` slow and no longer used by the job, so the scope and the sweep now disagree. Its test calls a private method through `Card.send(:due_cards_for, ...)`.

Since the runs split on these choices, the agent can already make each one correctly and mainly needs telling which way to go. The skill encodes:
1. The rule that the scope and the sweep must stay consistent, and that public names stay unchanged.
2. The anatomy of a schema change in this repo: both schema files, reverting `cable_schema.rb`, never dropping an existing index.
3. A rule against touching behaviour next to the requested change, plus testing through the public API.

**Workspace facts in the skill and where each was observed:**
- **Original `card/entropic.rb`, `postponable.rb` (`active`, `auto_postpone`), `entropy.rb`, `Board::Entropic`:** r1 step 6 output.
- **`config/recurring.yml` runs `Card.auto_postpone_all_due`; `config/brakeman.ignore` entries quote the entropic `where` strings (around lines 9–19 and 124–134); `stallable_test.rb:63` calls the sweep:** r1 steps 6–7.
- **`database.sqlite.yml` sets `schema_dump: schema_sqlite.rb`; `date_subtract` comes from `lib/rails_ext/active_record_date_arithmetic.rb`:** r1 steps 7–9.
- **Existing `cards` indexes are at `schema_sqlite.rb` lines 230–233; `schema.rb` has `charset`/`collation` on tables:** r1 steps 8–9 and 54.
- **Latest migration is `20260218120000_...`; `add_search_records.rb` contains `connection.adapter_name == "SQLite"`:** r1 step 7.
- **`db:migrate` rewrites `db/cable_schema.rb`, while `schema.rb` is not regenerated and was hand-edited:** r1 steps 54–56; r2 steps 61 and 66.
- **The test DB has `cards=0` outside test runs:** r1 step 12.
- **`find_each` emits `ORDER BY "cards"."id" ASC LIMIT 1000`, and its plan scans `sqlite_autoindex_cards_1`:** r3 step 10.
- **Test fixtures used in `entropic_test.rb` and the `postponed_by == system_user` assertion:** r1 step 6 (test file) and r3 step 8 (fixtures).

**What I left out on purpose:** r2's timeout came mostly from benchmark rabbit-holes, which is a procedure problem owned by the parallel candidate. I didn't write a timing or budget rule. The skill also doesn't prescribe a particular fix. It only requires that the result set and the public names stay the same, and gives a checklist covering the plan, both schema files and the tests.

**Remaining uncertainty:** I did not check whether `bin/brakeman` runs offline. The skill therefore only says the ignore entries stop matching if those `where` strings are edited, and does not ask the agent to run brakeman.
