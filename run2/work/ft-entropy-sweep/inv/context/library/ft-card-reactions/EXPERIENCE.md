# ft-card-reactions

- adopted: the composed harness (Harness² run 2: 3 base rollouts, 3 per candidate, composed: composed)
- components: skills 2, always-on text 3194 characters

## Why this harness (composer decisions)

kept -> INV skill `skills/db-migration` and its trigger line in system.md -> In the base runs, the agent worked out the migration mechanics by trial in 3/3: r1 steps 31–38, about 15 steps in r2 including a failed `db:rollback` at step 106, and r3's failed `db:migrate:down` at step 33. All 3 INV runs read the skill (`cat` at inv r2 step 8). inv r2 then did the migrate, the cable_schema revert and the hand edit of schema.rb cleanly in steps 35–37. INV median time was 30 min against 49 for base. All 3 completed, none hit the time limit, no patch was empty.
revised -> db-migration skill -> Added the no-foreign-key / uuid convention, which base r3 had to roll back at steps 33–35 and the DOM skill already recorded. Removed the base-run commentary. Procedure and done check are unchanged.
kept -> DOM skill `skills/card-feature-surfaces` and its trigger line in system.md -> Read in 3/3 DOM runs (dom r1 step 4, dom r3 step 3). Agents acted on it: dom r1 documented the card endpoints in docs/api at steps 49–60 (no base run did), and dom r1 and r3 both added `.card__boosts` to trays.css (only 1/3 base runs did). DOM median time was 23 min against 49 for base. Patches were far more scoped: −12/−11/−20 deleted lines against base's −143/−66/−58. All 3 completed, none hit the time limit, no patch was empty.
revised -> DOM skill section 3 (migration/schema) -> It duplicated the db-migration skill, so I replaced it with a pointer to that skill. Brittle line numbers, the hard-coded 20260709120000 version and the r1/r2/r3 references were removed so the skill still reads correctly in later tasks.
revised -> DOM skill section 1 -> Added "prefer adding card-level files beside the comment ones over refactoring the comment stack". This is my addition, not a candidate edit. Evidence: base r1 rewrote the comment reactions controller as a subclass (step 72), and base patches deleted 58–143 lines against 11–20 for DOM. It guides how the agent works and renames nothing the request specifies.
kept -> no change to guardrails.md, memory.md or tool_guidance.md -> No base-set failure points at always-on text. No base run timed out (45–55 min), and all 3 ran the full suite and exited 0. The only always-on additions are the two trigger lines. The submit instruction is unchanged.

## What each edit did

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

## Transferable lesson

- **cue**: A feature request needs a schema migration in a repo where the Rails db tasks work differently from the defaults: several databases, more than one schema dump, or generated files that should not ship. The harness skill is written from facts copied out of one checkout.
- **lesson**: In skills/<migration skill>/SKILL.md, write commands the agent can run instead of copied values. Give the exact scoped commands (`db:migrate:down:primary VERSION=<ts>`, `git checkout -- <regenerated side schema>`). Tell it to derive the new version with `date +%Y%m%d%H%M%S` and check it against `ls db/migrate | tail`. Do not write the current latest migration version, or any other one-time value the agent might reuse as a new identifier. Check: search the skill for long literal timestamps or ids and replace each with the command that produces it.
- **evidence**: Rows skills/db-migration/SKILL.md (helped) and skills/card-feature-surfaces/SKILL.md (helped, with a side effect). With the scoped-command skill, every rollback worked first time (inv r3 step 43, composed r2 step 45, composed r3 step 57). Without it, every rollback failed first (base r3 step 33, base r2 step 106, dom r2 step 43). The dom skill's hard-coded "latest migration 20260709120000" was turned into the made-up stamp 20260710120000 in dom r2 step 19 and dom r3 step 40. Runs told to use `date` produced real stamps (inv r2 step 29, dom r1 step 28).
- **confidence**: medium. The rollback contrast holds in all 6 runs that rolled back, across four arms. The timestamp effect shows in 2 of 3 dom runs. Each instance saves only a few steps, and the time savings cannot be credited to the skill.
