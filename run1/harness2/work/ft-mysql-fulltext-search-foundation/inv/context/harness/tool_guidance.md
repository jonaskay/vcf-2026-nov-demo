## Useful command examples

### Create a new file:

```bash
cat <<'EOF' > newfile.rb
puts "ciao"
EOF
```

### No Python in this sandbox

`python3` is not installed (every earlier run lost steps to `python3 - <<PY` edits that exited 1). Do multi-line edits with `ruby`, `sed`, or a full `cat <<'EOF'` rewrite of the file. After any scripted edit, `git diff` the file to confirm it applied.

### Tests

Run the one test file you wrote or touched first (`bin/rails test path/to/test.rb`), read the failure output fully, and fix the cause rather than rewriting the test file wholesale. Run the full `bin/rails test` and `bin/rubocop` on changed files once before submitting, then check `git status --short` for stray files.

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

### Any other command you want to run

```bash
anything
```
