## Useful command examples

There is NO Python in this sandbox (`python3: command not found`). Write files with a heredoc and do multi-line edits with Ruby.

### Create a new file:

```bash
cat <<'EOF' > app/models/example.rb
class Example
end
EOF
```

### Replace a multi-line block (fails loudly if the old text is not found):

```bash
ruby - <<'RUBY'
path = "app/models/example.rb"
text = File.read(path)
old = <<~'OLD'
  class Example
  end
OLD
raise "old text not found in #{path}" unless text.include?(old)
File.write(path, text.sub(old, "class Example\n  # changed\nend\n"))
RUBY
```

### Edit files with sed:

```bash
# Replace all occurrences
sed -i 's/old_string/new_string/g' filename.py

# Replace only first occurrence
sed -i 's/old_string/new_string/' filename.py

# Replace first occurrence on line 1
sed -i '1s/old_string/new_string/' filename.py

# Replace all occurrences in lines 1-10
sed -i '1,10s/old_string/new_string/g' filename.py
```

### View file content:

```bash
# View specific lines with numbers
nl -ba filename.py | sed -n '10,20p'
```

### Tests (facts verified in this workspace)

- One file: `bin/rails test test/controllers/<name>_test.rb`; one test: add `-i '/pattern/'` (`-n/--name` prints a deprecation notice). The test database is SQLite.
- The whole suite (`bin/rails test`) finishes in about a minute here: run it once after your targeted tests pass, then `bin/rubocop <changed files>`.
- Creating records in a test outside a request needs a current user: `cards.create!(...)` outside it fails with `Creator must exist` from `app/models/concerns/eventable.rb:10` (`track_event` uses `creator: Current.user`). Wrap the setup in `with_current_user(:kevin) do ... end` (defined in `test/test_helpers/session_test_helper.rb`).
- A `Comment` saved with `save!(validate: false)` also needs an explicit `account: accounts("37s")`, or it fails with `NOT NULL constraint failed: comments.account_id`.
- Before submitting: `git status --short && git diff --stat`, and confirm no scratch or untracked files outside the change.

### Any other command you want to run

```bash
anything
```
