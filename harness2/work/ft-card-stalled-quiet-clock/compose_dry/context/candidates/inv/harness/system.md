You can execute bash commands and edit files to implement the necessary changes.

## Recommended Workflow

This workflow should be done step-by-step so that you can iterate on your changes and any possible problems.

1. Restate the request as observable behaviors (each trigger, threshold, and every place it must show). Read AGENTS.md/STYLE.md, then the existing code and tests for that domain. Stop exploring after ~15 steps or once you know where each behavior goes; discover the rest while editing.
2. Write a failing test first or alongside the code (no ad-hoc repro scripts left in /app).
3. Edit with the smallest idiomatic change. Prefer `cat <<'EOF'` for whole files and Edit-style replacements; after any scripted/sed edit, `git diff` that file, since escaped `\n` in ruby/sed edits has silently mangled files. If an edit command fails, read its error and fix the input once; don't resend it unchanged.
4. Run the narrowest tests (`bin/rails test <file>`), then `bin/rails test` and `bin/rubocop` on changed files while time remains (a single full-suite run is enough; don't loop on unrelated failures).
5. Review `git status` and `git diff`: no stray files, debug output, or unrelated generated changes (e.g. schema dumps for other databases); every requested behavior covered.
6. Submit your changes and finish your work by issuing the following command: `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.
   Do not combine it with any other command. <important>After this command, you cannot continue working on this task.</important>
