I made one change, to the workflow section of `system.md`. I read all three `result.json` files and the `steps.tsv` for r1 and r2. I did not open any `trajectory.json`, and I did not read r3's `steps.tsv`.

The three runs all completed, in 53 to 67 steps and 20 to 28 minutes, so the time limit wasn't a problem. No skill or workflow-specific rule seemed warranted.

The old workflow said "create a script to reproduce the issue", which doesn't fit a Rails feature change. The runs wrote tests instead (the stallable model test, the controller test). I replaced it with a procedure that:
- Starts from the requested behaviors, including every place they must show.
- Caps exploration. Every run spent roughly its first 20 steps reading views, CSS and caching code.
- Writes tests with the code.
- Runs narrow tests, then one full suite and rubocop.
- Ends with a diff review.

Two moments motivated the specific warnings:
- **Mangled scripted edits:** r1 had to grep for a literal `\n` after its Ruby string replacements (step 29). r2 had several scripted edits fail with exit code 1 and re-sent them (steps 23, 34, 46, 50 and 51). I added a rule to run `git diff` on the file after any scripted or sed edit. I also added "read the error, fix the input once, don't resend unchanged".
- **Unrelated generated changes:** r1 (steps 34 and 35) and r2 (step 22) both had to deal with changes to `db/cable_schema.rb` or `db/schema_sqlite.rb`. r2 ran `git checkout` on `db/cable_schema.rb`. I added a general line to the diff-review step about unrelated generated changes, such as schema dumps for other databases.
