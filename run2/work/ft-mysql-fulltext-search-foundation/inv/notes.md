I changed one component, `tool_guidance.md`, and nothing else. No skills were added. There's no new trigger line to keep in sync, and the submit instruction in `system.md` and `guardrails.md` is unchanged. I'm going on the trajectory outputs only; nothing was run.

**What the edit addresses.** All three base runs made the same two avoidable failures:

1. **They tried to edit with Python, which isn't installed.**
   - r1 step 28, r2 step 14 and r3 step 27 each ran `python3 - <<'PY' …` and got `bash: line 1: python3: command not found`.
   - In r1 and r2 the test run chained after that command still ran, against a file that hadn't changed. That cost them a failing run they then had to work through again.
   - The old `tool_guidance.md` made this likelier: its only "create a file" example was `newfile.py` with `import numpy`.
   - Change: I replaced that example. The file now says there's no Python, and gives a Ruby block-replace pattern that raises an error if the old text isn't found. r2 step 33 and r3 step 35 wrote that kind of check themselves after failed edits.

2. **Their first test file failed on setup before it reached the feature.** Every run had to rediscover the same test-data rules:
   - r1 step 28, r2 step 13 and r3 step 21 all got `ActiveRecord::RecordInvalid: Validation failed: Creator must exist` at `app/models/concerns/eventable.rb:10`. Step 22 of r3 and step 16 of r2 show that file, with `track_event(... creator: Current.user ...)` at line 8.
   - Each run then found `with_current_user(:kevin)`. r2 step 15 shows it at `test/test_helpers/session_test_helper.rb:48`.
   - r2 steps 13 and 15 hit `SQLite3::ConstraintException: NOT NULL constraint failed: comments.account_id` from `Comment.new(...).save!(validate: false)`, even inside `with_current_user`. r2 step 18 fixed it by passing `account: accounts("37s")`, and r2 step 37 then passed the whole test file (exit 0).
   - The same exception message shows the test database is SQLite.
   - That churn took roughly 6 minutes in r1 (steps 25–40), 5 minutes in r2 (steps 13–18), and more than 30 minutes of mixed test and implementation edits in r3 (steps 21–53).
   - Change: I wrote these as labelled workspace facts in a short "Tests" section, so the first test file can be right on the first try.

**Two smaller facts in the same section, from a disagreement between runs:**
- **Full suite.** r2 never ran it. r1 and r3 did, and it was cheap: r3 step 54 ran the full suite plus rubocop in about 33 seconds. The guidance now says to run `bin/rails test` once after the targeted tests pass, then `bin/rubocop` on the changed files.
- **Picking one test.** r1 step 26 shows `Please switch from -n/--name to -i/--include`, so the guidance recommends `-i '/pattern/'`.

**Final check before submitting.** I added a one-line `git status --short && git diff --stat` step. r2 step 39 wrote a scratch file, `/tmp/search_route_test_snippet`; it was outside `/app` and harmless, but the line makes the habit explicit. It takes up a single line.

**Cost.** The added always-on text is partly paid for by deleting the misleading Python/numpy example.

**What I deliberately left alone:**
- All three runs searched with LIKE, though the task's tags mention migrations, raw SQL and callbacks. That is subject matter, so it's left to the parallel candidate.
- r3's long reasoning gaps (9 minutes between steps 46 and 47) are a time-budget issue. That would be a separate component; I kept to one.
