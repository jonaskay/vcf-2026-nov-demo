## Tools in this workspace

In this workspace `python3` and `rg` are NOT installed (exit 127, "command not found"). Search with `git grep -n` or `grep -RIn`; script edits with `ruby`. Plain `ruby` loads no stdlib extras: use `File.read`/`File.write`, or add `require "pathname"` before using `Pathname`.

### Create a new file:

```bash
cat <<'EOF' > app/helpers/example_helper.rb
module ExampleHelper
end
EOF
```

### Edit several files in one Ruby script

Check every anchor before writing anything, so a missing anchor leaves no file half-edited:

```bash
ruby <<'RUBY'
edits = {
  "app/views/a.html.erb" => [ [ "old text", "new text" ] ],
  "app/views/b.html.erb" => [ [ "old text", "new text" ] ]
}
missing = edits.flat_map { |path, pairs| pairs.reject { |old, _| File.read(path).include?(old) }.map { |old, _| "#{path}: #{old}" } }
abort("anchors not found:\n#{missing.join("\n")}") if missing.any?
edits.each { |path, pairs| File.write(path, pairs.reduce(File.read(path)) { |text, (old, new)| text.sub(old, new) }) }
RUBY
```

If an anchor is reported missing, print those lines (`nl -ba FILE | sed -n 'A,Bp'`), fix only that anchor and rerun; do not resend a long script unchanged. Chain later commands with `&&` so they do not run after a failed edit.

### Edit files with sed:

```bash
# Replace all occurrences
sed -i 's/old_string/new_string/g' filename.rb

# Replace only first occurrence
sed -i 's/old_string/new_string/' filename.rb

# Replace all occurrences in lines 1-10
sed -i '1,10s/old_string/new_string/g' filename.rb
```

### View file content:

```bash
nl -ba filename.rb | sed -n '10,20p'
```

## Tests in this workspace

- `bin/rails test test/path/to/file_test.rb` runs one file; `bin/rails test` runs the whole non-system suite (~1500 tests, under a minute here), so run it after any change; `bin/rubocop FILES` lints.
- Browser behavior (Stimulus, JavaScript formatting) is only exercised by system tests. Chromium and chromedriver are installed (`/usr/bin/chromium`, `/usr/bin/chromedriver`), and a system test runs when its file is named explicitly: `bin/rails test test/system/x_test.rb`. In a system test, run async JS with `page.driver.browser.execute_async_script` (Capybara's session has no `execute_async_script`); `page.driver.browser.execute_cdp(...)` is available. Selenium's network warnings in the output are harmless.
- After editing a test you have already run, rerun that file; a full-suite run does not include system tests.
