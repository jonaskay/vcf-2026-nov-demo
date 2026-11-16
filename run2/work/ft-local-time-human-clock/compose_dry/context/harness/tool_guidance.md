## Tools in this workspace

`python3` and `rg` are NOT installed (exit 127). Search with `git grep -n` or `grep -RIn`; script edits with `ruby`. Plain `ruby` loads no stdlib extras: use `File.read`/`File.write`, or `require "pathname"` first. In a multi-file Ruby edit, check that every anchor is present before writing any file, and chain later commands with `&&` so they do not run after a failed edit.

### Create a new file:

```bash
cat <<'EOF' > app/helpers/example_helper.rb
module ExampleHelper
end
EOF
```

### Edit and view files:

```bash
sed -i 's/old_string/new_string/g' filename.rb
nl -ba filename.rb | sed -n '10,20p'
```

### Tests

`bin/rails test test/path/to/file_test.rb` runs one file; `bin/rails test` runs the whole non-system suite (under a minute); `bin/rubocop FILES` lints. System tests run only when named explicitly: `bin/rails test test/system/x_test.rb`.
