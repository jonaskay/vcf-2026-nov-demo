## Tool guidance

- Run independent read-only commands together in one response.
- Edit with `sed -i`, or Ruby scripts that abort if the target string is missing; show `git diff -- <file>` after.
- Tests: `bin/rails test path/to_test.rb`, `-n "/name/"` for one test.
- Experiments: `RAILS_ENV=test bin/rails runner '...'`.
- Don't read framework gem source unless a test fails for a reason you can't explain; prefer a one-line experiment in a runner.

```bash
cat <<'EOF' > newfile.rb
puts "hello"
EOF
nl -ba file.rb | sed -n '10,20p'
```
