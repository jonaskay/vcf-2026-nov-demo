# ft-mysql-fulltext-search-foundation

- adopted: the composed harness (Harness² run 2: 3 base rollouts, 3 per candidate, composed: inv)
- components: skills 0, always-on text 4155 characters

## Why this harness (composer decisions)

kept -> INV tool_guidance.md (no-Python warning plus a Ruby block-replace example that raises if the old text is missing; replaces the misleading `newfile.py`/numpy example) -> the trajectories bear out the proposer's claim that all 3 base rollouts tried `python3 - <<'PY'` (r1 step 28 exited 1; r1 step 33 then ran `python3 --version` and switched to perl/ruby). In 0/3 INV rollouts did the agent call python. All 3 used the `ruby - <<'RUBY' … raise "… not found" unless text.include?` form from the guidance: inv r1 steps 26/28/31, inv r2 steps 32-47, inv r3 steps 25-41.
kept -> INV "Tests" section (Creator must exist / with_current_user, Comment account_id, -i flag, run the full suite once, git status before submitting) -> the base set rediscovered the test-setup rules: r1 rewrote its test file across steps 26-40, and per the proposer r2 spent steps 13-18 and r3 steps 21-53 on the same. INV ran the full suite in 3/3 rollouts against 2/3 for base (r2 skipped it). INV median time was 22 min against 38 for base, and the slowest INV run took 26 min against 62 for r3. Every INV run checked `git status`/`git diff --stat` before submitting (inv r1 step 47, r2 step 50, r3 step 45). The always-on cost is about 12 lines, partly paid for by deleting the numpy example.
dropped -> DOM skill card-content-search and its trigger line in system.md -> it was read in 3/3 DOM rollouts and was followed, which is the problem. Contract item 1 imposes "every word must match" (AND) semantics that the request never states. That changes the deliverable, and dom r2's patch shows it: one LIKE condition is chained per word, and the test asserts "logo big"/"big logo". Item 5 also tells the agent to keep LIKE and treat an index as optional, which steers the scope of the change. DOM brought no gain in process or time over INV (median 26 min against 22; full suite 3/3 in both arms). Its patches were bigger (+291 to +296 lines against +210 to +248), and dom r1 put the raw SQL in the controller rather than the model. The skill is also too specific to this one task to belong in the library.
note -> safety check: 9/9 candidate rollouts and 3/3 base rollouts finished with outcome completed. None hit agent_timeout and none left an empty patch.

## What each edit did

component: tool_guidance.md
candidates: inv, adopted
change: Removed the `newfile.py`/numpy example. Added a line saying there is no Python, a heredoc example for creating a file, and a `ruby - <<'RUBY'` block-replace pattern that raises when the old text is missing. Added a "Tests" section with the `-i` flag, running the full suite once and then rubocop, `with_current_user` for "Creator must exist", `account:` on comments saved with `save!(validate: false)`, and a `git status`/`git diff --stat` check before submitting.
observed: All 3 base runs tried Python and got "python3: command not found" (base r1 step 28, base r3 step 27). The dom arm still had the old guidance and also tried it (dom r2 step 16, dom r3 step 14). No inv run tried Python; all 3 used the raising Ruby replace from the guidance (inv r1 step 26, inv r2 step 32, inv r3 step 25), and the raise caught a missing anchor at inv r2 step 32, which was fixed at step 33. inv r2 step 35 used the `-i` flag, and every inv run checked git status before submitting (inv r1 step 47, inv r3 step 45). The full suite ran in 3/3 inv runs against 2/3 base. Median time was 22 min against 38 for base; the slowest inv run took 26 min, the slowest base run 62 (base r3 step 47 came after a 9-minute gap). The first test file still failed in some inv runs (inv r2 step 28 exit 1), so the test-setup facts did not clearly avoid that failure.
verdict: helped
component: skills/card-content-search/SKILL.md
candidates: dom
change: Added a domain skill with facts about this checkout (accessible_cards, the published enum, ordering scopes, rich text stored as HTML, SQLite in tests, the existing Prompts::CardsController search). It also set a 5-item contract: AND-match every word, highlight with the word array, `sanitize_sql_like` with `ESCAPE '!'`, visibility enforced in SQL, and LIKE accepted with an index marked optional. Its test facts covered board access and draft comments.
observed: All 3 dom runs read the skill at step 3 (dom r1 step 3, dom r2 step 3, dom r3 step 3) and followed the contract. The dom r3 patch splits the query and chains one `LIKE … ESCAPE '!'` condition per word, which no base patch does. All 3 put the raw SQL in the controller instead of the Card model (dom r1 step 37 `CARD_MATCH_SQL`, dom r2 step 23 `CARD_CONTENT_MATCH_SQL`, dom r3 step 23 `SEARCH_CONDITION`); every base and inv run added a Card scope instead. Process did not improve: Python was still tried (dom r2 step 16, dom r3 step 14), and the first test file still failed (dom r2 step 14, dom r3 step 9). Patches were larger (+291 to +296 lines), and as in base, no run added an index or migration.
verdict: hurt
component: system.md
candidates: dom
change: Added a trigger line telling the agent to `cat` the card-content-search skill whenever a request asks to search cards or comments by their text.
observed: The trigger fired every time: each dom run read the skill as its first action (dom r1 step 3, dom r2 step 3, dom r3 step 3). Its only effect on behavior is through the skill it loads, so it cannot be judged apart from that skill's content.
verdict: confounded

## Transferable lesson

- **cue**: Base runs repeatedly fail on the same environment mismatch: the always-on command examples show a tool or language the sandbox lacks (for example a Python heredoc where only Ruby or bash exists), and every run tries it, hits "command not found", and switches tools by hand.
- **lesson**: In tool_guidance.md, replace any example written for a missing interpreter with the same operation in an interpreter the sandbox has. State the missing tool in one line, and give a multi-line replace that raises when its anchor text is absent, so a failed edit stops loudly instead of silently leaving the file unchanged. Check it with this test: zero runs call the missing tool.
- **evidence**: The tool_guidance.md row (helped). Python was tried in 3/3 base runs (base r1 step 28, base r3 step 27) and in 2/3 dom runs, which kept the old examples (dom r2 step 16, dom r3 step 14). It was tried in 0/3 inv runs, which used the guidance's raising Ruby replace (inv r1 step 26, inv r2 step 32, inv r3 step 25). The raise caught a bad anchor at inv r2 step 32, and the run recovered at the next step.
- **confidence**: medium. The contrast holds across all 3 inv runs, and the dom arm acts as a control that kept the old examples and still made the error. But each failed Python call cost only a step or two, and the time gain cannot be separated from the test-facts section added in the same edit.
