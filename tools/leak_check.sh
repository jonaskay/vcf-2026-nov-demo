#!/usr/bin/env bash
# Greps files or directories for hidden check names, with the same patterns as validate.sh
# rule 3 (underscore or spaced form, case-insensitive). For free text that validate.sh
# doesn't cover: library EXPERIENCE.md entries, composer and editor notes.
# Prints only file names, never the matched text. Exit 0 = clean, 1 = leak.
#
#   demo/tools/leak_check.sh <file_or_dir>...
set -euo pipefail
(( $# > 0 )) || { echo "usage: leak_check.sh <file_or_dir>..." >&2; exit 2; }
demo=$(cd "$(dirname "$0")/.." && pwd)
names="$demo/private/hidden_check_names.txt"
[[ -f $names ]] || { echo "leak_check: $names missing" >&2; exit 2; }

patterns=$(mktemp); trap 'rm -f "$patterns"' EXIT
cut -f2 "$names" | sed 's/^VerifierTest#test_//' | grep -v '^$' > "$patterns"
cut -f2 "$names" | sed 's/^VerifierTest#test_//' | tr '_' ' ' | grep -v '^$' >> "$patterns"

if hits=$(grep -rliF -f "$patterns" "$@" 2>/dev/null); then
  echo "LEAK hidden check name found in: $(echo "$hits" | tr '\n' ' ')"
  exit 1
fi
echo "CLEAN"
