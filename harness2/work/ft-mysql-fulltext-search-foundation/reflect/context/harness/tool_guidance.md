## Useful command examples

### Create a new file:

```bash
cat <<'EOF' > newfile.rb
puts "ciao"
EOF
```

### No Python in this sandbox

`python3` is not installed. Do multi-line edits with `ruby`, `sed`, or a full `cat <<'EOF'` rewrite. After any scripted edit, `git diff` to confirm it applied.

### Tests

Run the test file you touched first, read failures fully, fix the cause. Run `bin/rubocop` on changed files and check `git status --short` for stray files before submitting.

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
