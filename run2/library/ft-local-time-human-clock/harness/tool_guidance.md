## Useful command examples

`python3` and `rg` are NOT installed here. Search with `git grep -n` or `grep -RIn`; script edits with `ruby` (plain `ruby` needs `require "pathname"` before `Pathname`; `File.read`/`File.write` need nothing).

### Create a new file:

```bash
cat <<'EOF' > app/helpers/example_helper.rb
module ExampleHelper
end
EOF
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

### Any other command you want to run

```bash
anything
```
