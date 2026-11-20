## Tools and editing

There is no `python3` in this sandbox (`command not found`). Use bash, `sed`, and Ruby.

### Create or fully rewrite a file

```bash
cat <<'EOF' > app/models/example.rb
class Example
end
EOF
```

### Edit part of an existing file with Ruby

```bash
ruby - <<'EDIT' && git diff -- app/models/example.rb
path = "app/models/example.rb"
text = File.read(path)
old = <<~'OLD'
  def old_method
  end
OLD
new = <<~'NEW'
  def new_method
  end
NEW
text.sub!(old, new) or abort "anchor not found in #{path}"
File.write(path, text)
EDIT
```

Edits like this break silently in three ways:
- In Ruby a single-quoted `'...\n...'` holds a literal backslash and `n`, not a newline. That anchor never matches, and `sub!` returns nil without raising. Use `<<~'OLD'` heredocs or double quotes for multi-line anchors.
- The outer bash delimiter (`EDIT`) must not appear inside the script. Using `RUBY` both as the outer delimiter and as an inner heredoc ends the script early.
- Chaining with `;` hides a failed edit, because the exit code comes from the last command. Chain with `&&`.

For a one-line change, `sed -i 's/old/new/' file` works. Afterwards, always check the result with `git diff -- <file>` or `grep -n`. A command that exits 0 does not prove the file changed.

### View file content

```bash
nl -ba app/models/card.rb | sed -n '10,40p'
```

## Testing in this workspace

- Run one file with `bin/rails test test/controllers/<name>_test.rb` (well under a second) and one test with `bin/rails test <file>:<line>`.
- The full suite, `bin/rails test`, finished 1504 tests in about 15 seconds. It is cheap, so run it after your targeted tests pass and again before you submit.
- Tests run on SQLite (`storage/test.sqlite3`; errors appear as `SQLite3::...`). There are two schema files, `db/schema.rb` and `db/schema_sqlite.rb`.
- Lint the files you touched with `bin/rubocop <files>`.
- Before you submit, run `git status --short` and `git diff`. Remove any scratch files, and check that every file you meant to change is listed.
