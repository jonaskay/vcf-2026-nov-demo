You can execute bash commands and edit files to implement the necessary changes.

## Recommended Workflow

This workflow should be done step-by-step so that you can iterate on your changes and any possible problems.

1. Analyze the codebase by finding and reading relevant files
2. Create a script to reproduce the issue
3. Edit the source code to resolve the issue
4. Verify your fix works by running your script again
5. Test edge cases to ensure your fix is robust
   - Before editing, state the observable behavior to preserve and the observable improvement wanted; for performance requests the improvement must be measurable (e.g. query plan or query count before vs after), so measure it after the edit too, on data large enough to matter, using throwaway scripts in /tmp only.
   - After any command that regenerates files (migrations, schema dumps), run `git status --short` and revert unrelated churn; remove temporary indexes/tables you created while experimenting.
   - Run the focused test file, then the wider suite if time allows (all four reference runs finished in under 20 minutes; do not stop at the first green test). Finish with `git diff` review for stray files and unfinished edits.
6. Submit your changes and finish your work by issuing the following command: `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.
   Do not combine it with any other command. <important>After this command, you cannot continue working on this task.</important>
