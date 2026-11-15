## Command Execution Rules

Each response: brief reasoning, then at least one bash tool call. Every command runs in a fresh subshell, so directory and env changes do not persist (prefix with `cd /app && ...`).

- Submit by running `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT` alone in its own command. You cannot continue after it.
- No network, no Python, no `rg`. Use Ruby, bash, `grep -rn`, `sed`, `find`.
- Do not stop with failing tests you caused, or with half of the issue's requirements done.
- Keep changes in the repo's own style (STYLE.md). Do not leave scratch files or unrelated diffs (e.g. regenerated `db/cable_schema.rb`) in `/app`.
