component: skills/db-migration/SKILL.md
candidates: inv, adopted
change: Added a new skill on how migrations work in this repo. It says the app has two databases, so unscoped `db:rollback` and `db:migrate:down` fail and the `:primary` forms must be used. It says to revert `db/cable_schema.rb` after every migrate, to copy the `schema_sqlite.rb` changes into the MySQL `db/schema.rb` by hand, to take the timestamp from `date`, and to settle the schema design before migrating. It ends with a done check. The adopted copy also adds the no-foreign-key / uuid rule.
observed: All 3 inv runs read the skill (inv r2 step 8, inv r3 step 8). Every run that had the skill and had to roll back used the scoped command and it worked first time: inv r3 step 43, composed r2 step 45, composed r3 step 57. Every run without it failed on the first rollback: base r3 step 33 (fixed at step 34), base r2 step 106 (fixed at step 108 after listing the rake tasks at step 107), and dom r2 step 43 (fixed at step 44). Migrating, reverting cable_schema and editing schema.rb went cleanly in a few steps (inv r2 steps 35-37). Step counts did not fall (inv 76/65/67 vs base 75/120/63). The drop from 49 to 30 median minutes cannot be credited to the skill: every non-base arm ran on a later day at about half the time per step, including dom (dom r1: 69 steps in 23 min, vs base r1: 75 steps in 49 min).
verdict: helped

component: skills/card-feature-surfaces/SKILL.md
candidates: dom
change: Added a new skill mapping every part of the existing comment-reaction feature: model, controller, route, views, JSON link and tests. It says comment behavior must stay as it is, sets out the choice between a polymorphic and an additive data model, and lists both preview templates, the CSS selectors to update, caching/touch, `docs/api`, the commentable gate and test coverage. It also hard-codes workspace facts, including "the latest migration is 20260709120000".
observed: All 3 dom runs read it at the start (dom r1 step 4, dom r3 steps 3-7). All 3 kept the comment stack as it was and added card-level files beside it, for example copying the comment `_menu` partial at dom r2 step 51. Lines deleted were -12/-11/-20, against -143/-66/-58 for base and -109/-95/-64 for inv; base r1 rewrote the comment reactions controller as a subclass at base r1 step 72. Dom runs documented the API in `docs/api` (dom r1 step 60, dom r2 step 42), which no base run did. Side effect: 2 of 3 dom runs took the hard-coded version as the next migration timestamp, `20260710120000` (dom r2 step 19, dom r3 step 40). dom r2 then had to roll back and rename it (steps 43-44), and dom r3 submitted the made-up timestamp. dom r1 used `date` (step 28).
verdict: helped

component: system.md
candidates: inv, dom, adopted
change: Added one trigger line per skill telling the agent to `cat` it when the situation fits: a migration (inv) or extending a comment feature to cards (dom). The adopted harness has both lines.
observed: Every skill was read in every run that had its trigger line (inv 3/3, dom 3/3, composed 6/6 reads). Reads came early: dom r1 step 4, inv r2 step 8, composed r1 step 6 (migration skill). No base run opened anything under /opt/harness. Beyond getting the skills read, the line changed nothing on its own.
verdict: helped

component: skills/card-feature-surfaces/SKILL.md (adopted revision)
candidates: adopted
change: The composer replaced the skill's migration/schema section with a pointer to db-migration, removing the hard-coded 20260709120000 version and the line numbers. It also added the sentence "prefer adding card-level files beside the comment ones over refactoring the comment stack".
observed: All 3 composed runs took real `date` timestamps (composed r1 step 32, composed r3 step 17, composed r2 migration 20261117003341 at step 29). None repeated dom's made-up 20260710 stamp. Patches stayed small (-20/-23/-17), but dom was already at -12/-11/-20 without the new sentence. These revisions only ran merged with the migration skill, so no run isolates them.
verdict: confounded
