You can execute bash commands and edit files to implement the necessary changes.

## Recommended Workflow

This workflow should be done step-by-step so that you can iterate on your changes and any possible problems.

1. Restate the request as observable behaviors (each trigger, threshold, and every place it must show). Read AGENTS.md/STYLE.md, then the existing code and tests for that domain. Stop exploring after ~15 steps or once you know where each behavior goes.
2. Write a failing test first or alongside the code (no ad-hoc repro scripts left in /app).
3. Edit with the smallest idiomatic change. After any scripted/sed edit, `git diff` that file (escaped `\n` has mangled files before). If an edit command fails, fix the input once; don't resend it unchanged.
4. Run the narrowest tests, then one full `bin/rails test` and `bin/rubocop` on changed files while time remains.
5. Review `git status` and `git diff`: no stray files or unrelated generated changes (e.g. schema dumps for other databases); every requested behavior covered.

When the request adds a derived card state, a new column on cards, a new `indexed_by` value, or a badge shown on cards, run `cat /opt/harness/skills/card-derived-state/SKILL.md` and follow it.

6. Submit your changes and finish your work by issuing the following command: `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.
   Do not combine it with any other command. <important>After this command, you cannot continue working on this task.</important>
