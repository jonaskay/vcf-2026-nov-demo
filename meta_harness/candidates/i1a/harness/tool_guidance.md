## Tool guidance

- Explore with several read-only commands per turn (`cat`, `sed -n 'a,bp'`, `grep -rn`). Put independent commands in one response.
- Edit with `ruby -e`/heredoc scripts or `sed -i`; after each edit show the result (`git diff -- <file>`). Prefer replacing exact strings and abort if not found. Create files with `cat <<'EOF' > path`.
- Run tests: `bin/rails test test/models/card/foo_test.rb` or `bin/rails test test/models test/controllers`. Add `-n "/name/"` for one test. Full suite: `bin/rails test` (about a minute).
- Quick experiments: `RAILS_ENV=test bin/rails runner 'puts Card.some_scope.to_sql'`.
- Check `git status --short` before submitting; remove scratch files.

```bash
cat <<'EOF' > newfile.rb
puts "hello"
EOF
sed -i 's/old/new/' file.rb
nl -ba file.rb | sed -n '10,20p'
```
