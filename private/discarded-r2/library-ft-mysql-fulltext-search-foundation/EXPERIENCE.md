# ft-mysql-fulltext-search-foundation

- adopted: the composed harness (Harness² run 2: 3 base rollouts, 3 per candidate, composed: composed)
- components: skills 1, always-on text 4288 characters

## Why this harness (composer decisions)

kept -> INV `tool_guidance.md` rewrite (no-python3 line, `ruby - <<'EDIT' ... sub! or abort && git diff` recipe, testing facts) -> every base run tried `python3` and got `command not found` (3/3: r1 step 28, r2 step 14, r3 step 27). The DOM runs, which kept the base tool_guidance, did the same (3/3: r1 step 30, r2 step 21, r3 step 28). INV runs made no python3 attempts (0/3), and they used the recipe as written, `ruby - <<'EDIT' && ...` (inv r1 step 28, r2 step 25, r3 step 27). Base r3 lost about 15 steps to broken edits: single-quoted `\n` anchors and a clashing `RUBY` delimiter (steps 27–40, 62 minutes in total). INV took 26/17/30 minutes against base 38/20/62. INV ran the full suite in 3/3 runs, base in 2/3. The file replaces one of about the same length, so the always-on cost does not grow.
kept (revised) -> DOM skill `skills/card-text-search` plus its trigger line in `system.md` -> the agent read it at step 3 in 3/3 DOM runs and followed it. dom r2's draft-comment test uses the §4 recipe as written (`account: accounts("37s")`, `rich_text_body.account`, `save!(validate: false)`), and its excerpts come from `to_plain_text` as §2 says. dom r1 (step 43) and dom r2 (steps 36–37) ran the §2 markup probe. The time gain is not separable from INV (DOM 22/20/50 minutes against INV 26/17/30), so this rests on the moments where the agent followed the skill, not on speed. It is an on-demand skill, so it costs nothing when unread. No DOM run timed out or left an empty patch.
revised -> DOM skill "a blank query should give an empty result" (§3 and Done-check item 6) -> removed. The request does not ask for this, and a harness must not shape the deliverable. The skill still says the request's names and values are fixed.
revised -> DOM skill §2 probe step and the Done check -> the probe now points to `bin/rails runner` or a temporary test, and a new check item says no scratch files may remain. dom r1 (step 43) and dom r2 (steps 36–37) wrote probe test files into `/app`. Their final patches came out clean, but that risk came from this skill's own instruction.
revised -> DOM skill Done-check items 1 and 3 -> tied back to "the fields / the exclusions the request names" instead of restating this task's fields, so the library copy does not carry this request's facts as rules.
safety -> no rollout in any arm produced an empty `agent.patch` or `agent_timeout` (base 3/3, inv 3/3, dom 3/3 completed); the submit instruction in `system.md` is unchanged.

## What each edit did

component: tool_guidance.md
candidates: inv, adopted
change: Replaced the generic Python-flavoured examples (`newfile.py`, sed recipes) with three things: a line saying the sandbox has no `python3`, a Ruby anchor-edit recipe (`ruby - <<'EDIT' && git diff`, heredoc anchors, `sub! or abort`), and warnings about three silent edit failures (single-quoted `'\n'` anchors, a clashing heredoc delimiter, `;` chaining). It also added testing facts: one-file and full-suite commands, SQLite, two schema files, rubocop, and a `git status` check before submitting.
observed: Every run without this file tried `python3` and got command-not-found (base r2 step 14, base r3 step 27, dom r1 step 30, dom r2 step 21). Runs without it also hit the single-quoted `'\n'` anchor trap: base r3 steps 28-47 had repeated failed `sub!` edits, and dom r2 steps 30-35 needed four tries on one test edit. No inv or composed run called `python3`, and all used the recipe as written (inv r1 step 28, inv r2 step 25, inv r3 step 27, composed r1 step 31, composed r3 step 25). inv ran the full suite in 3/3 runs against 2/3 for base. Anchor misses still happened with the file (inv r3 steps 57 and 61, composed r2 steps 30 and 36), but they aborted loudly instead of passing silently. The drop in minutes (inv 26/17/30 against base 38/20/62) cannot be credited to this file because base ran on a different day.
verdict: helped

component: skills/card-text-search/SKILL.md
candidates: dom, adopted
change: Added a new domain skill. It covers visibility through `Current.user.accessible_cards` and `.published`, ordering and pagination idioms, the fact that ActionText `body` is HTML (so build excerpts from `to_plain_text` and probe a markup term), the SQLite/MySQL dual-schema rules, EXISTS subqueries on a Card scope as the default design, test-writing traps (`with_current_user`, drafted comments needing an explicit `account`), and a done check. The dom form also said a blank query should return nothing. The adopted form drops that rule, routes the probe through `bin/rails runner` or a temporary test, makes the done-check items generic, and adds a no-scratch-files check.
observed: The skill was read at step 3 in 6/6 runs (dom r1 step 3, dom r2 step 3, composed r1 step 3, composed r2 step 3, composed r3 step 3), and agents acted on it. Following §4, dom r2 built its drafted comment with an explicit `account`, the step where base r2 failed on a missing account at step 18. dom r1 step 43 and dom r2 steps 36-37 wrote markup-probe test files as §2 says, and composed r3 step 38 still wrote one into /app even after the revision. The probe also widened scope. After composed r1 probed the HTML body at step 56, it added a migration, a plain-text column, an ActionText initializer change and data-transfer model edits (steps 57-89, 16 files, +362/-4). After composed r2 step 49, it added HTML-escaped search patterns. Composed runs took longer (44/41/29 min) than dom (22/20/50). No run isolates whether this changed the quality of the result, and the dom and composed sets differ in their tool guidance.
verdict: confounded

component: system.md
candidates: dom, adopted
change: Appended one trigger line: when a request finds, filters or lists cards by text or by visibility, `cat /opt/harness/skills/card-text-search/SKILL.md` and follow it.
observed: The skill was read in every run that had this line (dom 3/3, composed 3/3; e.g. dom r1 step 3, composed r2 step 3). No base or inv run opened anything under /opt/harness (e.g. base r3 step 3 starts with `ls`/`find`). Beyond getting the skill read, the line changed nothing on its own.
verdict: helped

## Transferable lesson

- **cue**: Base runs in a sandbox without Python keep editing files by scripted string substitution: they try `python3` first, then Ruby `sub!` with single-quoted multi-line anchors that silently fail to match, and so lose steps to edits that did not happen.
- **lesson**: In tool_guidance.md, replace the generic language-neutral edit examples with one anchor-edit recipe in a language the sandbox does have. Use a quoted heredoc for the anchor, abort on a miss (`sub!(old, new) or abort`), chain with `&&` into `git diff -- <file>`, and state outright which interpreter is absent. Check: no example in the file names a missing tool, and the recipe fails loudly when the anchor is wrong.
- **evidence**: tool_guidance.md row (helped). Every run without the file tried `python3` (base r2 step 14, base r3 step 27, dom r1 step 30, dom r2 step 21) and hit single-quoted `'\n'` anchor misses (base r3 steps 28-47, dom r2 steps 30-35). No run with the file called `python3`, and all used the recipe as written (inv r1 step 28, inv r2 step 25, composed r1 step 31).
- **confidence**: medium. The python3 contrast holds in 6/6 runs with the file against every inspected run without it, across arms. The anchor trap is the kind of failure this guidance targets, but the time savings cannot be credited to it because base ran on a different day.
