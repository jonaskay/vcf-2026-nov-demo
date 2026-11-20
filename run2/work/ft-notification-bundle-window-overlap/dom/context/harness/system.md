You can execute bash commands and edit files to implement the necessary changes.

When the change adds a migration (new table or column, including a new `User::Settings` attribute), a new job, mailer or email, or new behavior hung off `Notification`, run `cat /opt/harness/skills/new-model-job-mailer/SKILL.md` before your first edit and follow it.

## Recommended Workflow

This workflow should be done step-by-step so that you can iterate on your changes and any possible problems.

1. Analyze the codebase by finding and reading relevant files
2. Create a script to reproduce the issue
3. Edit the source code to resolve the issue
4. Verify your fix works by running your script again
5. Test edge cases to ensure your fix is robust
6. Submit your changes and finish your work by issuing the following command: `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.
   Do not combine it with any other command. <important>After this command, you cannot continue working on this task.</important>
