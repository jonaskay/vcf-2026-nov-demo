# ft-local-time-human-clock

- adopted: the composed harness (Harness² run 2: 3 base rollouts, 3 per candidate, composed: composed)
- components: skills 1, always-on text 3087 characters

## Why this harness (composer decisions)

kept -> DOM skill `skills/time-display/SKILL.md` plus its trigger line in system.md, copied verbatim -> the agent read the skill in 3/3 dom rollouts. In dom r1 it read the skill at step 3, then at step 4 ran the skill's grep over `-- app saas/app`, and at steps 13 and 27 checked text-transform. The comment `text-transform: capitalize` conflict was fixed in 3/3 dom patches (comments.css in each) but in only 1/3 base (r2) and 1/3 inv. Dom r2's patch converts both SaaS views and keeps the name `bridge_share_card_description`; base r2 renamed it to `bridge_share_card_details`. All 3 dom runs finished (median 46 min against base 48), with no timeout and no empty patch.
revised -> INV tool_guidance edit -> kept only one line saying python3 and rg are missing (with the Pathname note), and swapped the `newfile.py`/numpy example for a Ruby one. Base runs hit `rg` exit 127 in 3/3 (step 4) and `python3` exit 127 in 3/3 (r1 s21, r2 s25, r3 s15), and base r2 s26 failed on Pathname. Inv r1 and r2 show no python3 or rg 127s, so the line did its job. The always-on cost is about the same as the base example it replaces.
dropped -> INV multi-file Ruby anchor-check script and its retry rule -> inv runs did use the pattern (r1 s39) but still had many exit-1 Ruby edits (inv r2 s28, s30, s53-58, s94). Inv r2 took 70 min, slower than every base run (47-49), and the inv median was 50 min against base 48. That is about 15 lines of always-on prose with no measured gain.
dropped -> INV system-test facts block (chromium, execute_async_script, execute_cdp) -> the execute_async_script failure happened in only 1/3 base (r1 s38). Explicit-path system tests and the CDP timezone override are already in the on-demand skill (item 8), so keeping it always-on would duplicate them.
note -> no rollout in any arm timed out or left an empty patch. All 9 completed, and every one ran the full suite with a last test exit of 0.

## What each edit did

component: skills/time-display/SKILL.md
candidates: dom, adopted
change: Adds a new on-demand skill for this codebase. It lists every place time is displayed, including the two SaaS-engine views and the bridge share description, and the places that are not display and should be left alone. It describes the existing pieces (TimeHelper, the CurrentTimezone etag, the day-timeline cache key, the timezone meta / date_helpers / bubble trio, fragment caches), then gives an 8-item checklist: timezone-neutral `<time>` output, building calendar days as local dates, one shared formatter, local-calendar-day relative words, CSS text-transform rules that change the literal wording, the caching claim, a coverage grep over app and saas/app, and helper plus system tests.
observed: The agent read the skill as its first action in 6/6 runs (dom r1 step 3, dom r2 step 3, dom r3 step 3, composed r1 step 3) and then did what it says. The very next command was the skill's grep over `-- app saas/app` (dom r1 step 4, dom r2 step 4, composed r1 step 4). It then inspected text-transform (dom r1 step 13 and step 27, dom r3 step 6 reading comments.css 155-190, composed r1 step 15) and edited the stylesheet (composed r1 step 32 removes `text-transform: capitalize` from comments.css). comments.css is in 3/3 dom patches and 3/3 composed patches, but only 1/3 base (r2) and 1/3 inv (r2). Base r1 and r3 never touched it (base r3's patch converts the comment permalink with no CSS change), so "yesterday" there would still render as "Yesterday". The SaaS-view coverage it asks for was not a differentiator: base r3's patch already converts both saas views. Runtime was about the same (dom median 46 min against base 48).
verdict: helped

component: system.md
candidates: dom, adopted
change: Adds one line telling the agent to `cat /opt/harness/skills/time-display/SKILL.md` and follow it whenever a change touches how dates or times are displayed, formatted, cached or timezone-adjusted.
observed: This line is the only way the skill got read, and it fired in every run that carried it (dom r1 step 3, dom r2 step 3, dom r3 step 3, composed r1 step 3, each the first command after pwd). No base or inv run opened any harness file (evidence table: skills read "–"). Its effect cannot be separated from the skill's contents, but the trigger itself worked 6/6.
verdict: helped

component: tool_guidance.md
candidates: inv, adopted
change: Two forms were tried. inv rewrote the file: python3 and rg are absent, plain ruby needs `require "pathname"` for Pathname, a Ruby example replaces the python one, a multi-file Ruby edit script that checks every anchor before writing plus a retry rule, and a 'Tests in this workspace' block (chromium, execute_async_script, execute_cdp, rerun system tests by path). The adopted form keeps only the python3/rg/Pathname line and the Ruby example.
observed: Base runs hit rg exit 127 in 3/3 (base r1 step 4, base r2 step 4, base r3 step 4) and python3 exit 127 in 3/3 (base r1 step 21, base r2 step 25, base r3 step 15). base r2 step 26 also failed on an un-required Pathname. inv runs had no rg or python3 127s in 3/3 and searched with git grep from the start (inv r1 step 3, inv r3 step 4). dom, which lacked the line, still hit python3 127 (dom r2 step 17, dom r3 step 28). The anchor-check script was used (inv r1 step 39) but Ruby edits that exited 1 stayed common (inv r2 step 28, inv r2 step 30, inv r3 step 23, inv r3 step 40). inv was not faster: median 50 min against 48, and inv r2 took 70 min. The gain is about one wasted step per run. The anchor-script and test-facts parts showed no effect.
verdict: helped

## Transferable lesson

- **cue**: The request specifies literal user-visible wording (exact phrases or casing such as "yesterday" or "in 3 days"), and the elements that will show it already carry stylesheet rules that rewrite text, such as text-transform capitalize or uppercase, or utility classes like txt-capitalize.
- **lesson**: In the domain skill (skills/<domain>/SKILL.md), add a finish-line checklist item that names, by file:line, each CSS rule or utility class on the target elements that changes rendered text, says what it would turn the requested wording into, and tells the agent to decide per site whether to change the rule. Trigger the skill with a one-line `cat` instruction in system.md so the agent reads it before its first edit.
- **evidence**: Rows for skills/time-display/SKILL.md and system.md. With the skill, the agent inspected text-transform and edited the stylesheet in 6/6 runs (dom r1 step 13, dom r3 step 6, composed r1 step 15 then step 32). Without it, the casing conflict was fixed in only 1/3 base and 1/3 inv runs; base r1 and r3 left `.comment__permalink-title { text-transform: capitalize }` in place.
- **confidence**: medium. The contrast holds 6/6 against 2/6, and each run traces from the skill read to the CSS edit. But it is a single task, there is no score to confirm the CSS edit mattered to the result, and the skill also changed other behavior at the same time.
