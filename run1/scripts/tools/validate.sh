#!/usr/bin/env bash
# Validates a harness before any run. Exit 0 = OK, 1 = rejected.
#
#   demo/tools/validate.sh demo/harnesses/h0
#
# 1. Only text files: the four always-on files and skills/<name>/SKILL.md.
# 2. Every skills/<name>/ is named in system.md.
# 3. No hidden check name appears anywhere (underscore or spaced form, case-insensitive).
#    Only file names are printed, never the matched text, so the names can't leak
#    into logs an improver might read.
set -euo pipefail

h=${1:?usage: validate.sh <harness_dir>}
demo=$(cd "$(dirname "$0")/.." && pwd)
names="$demo/private/hidden_check_names.txt"
fail=0
reject() { echo "REJECT $h: $*"; fail=1; }

[[ -d $h ]] || { echo "REJECT $h: not a directory"; exit 1; }
[[ -f $names ]] || { echo "validate.sh: $names missing"; exit 1; }

for f in system.md guardrails.md memory.md tool_guidance.md; do
  [[ -f $h/$f ]] || reject "missing $f"
done

# Rule 1: allowlisted files only
while IFS= read -r f; do
  case $f in
    ./system.md|./guardrails.md|./memory.md|./tool_guidance.md|./skills/.keep) ;;
    ./skills/*/SKILL.md) [[ $(dirname "${f#./skills/}") != */* ]] || reject "nested skill file $f" ;;
    *) reject "file not allowed in a text-only harness: $f" ;;
  esac
done < <(cd "$h" && find . -type f)

# Rule 2: every skill is named in system.md
if [[ -d $h/skills ]]; then
  for d in "$h"/skills/*/; do
    [[ -d $d ]] || continue
    name=$(basename "$d")
    [[ -f $d/SKILL.md ]] || reject "skills/$name has no SKILL.md"
    grep -qF "$name" "$h/system.md" 2>/dev/null || reject "skill '$name' is not named in system.md"
  done
fi

# Rule 3: hidden check names, in both forms
patterns=$(mktemp); trap 'rm -f "$patterns"' EXIT
cut -f2 "$names" | sed 's/^VerifierTest#test_//' | grep -v '^$' > "$patterns"
cut -f2 "$names" | sed 's/^VerifierTest#test_//' | tr '_' ' ' | grep -v '^$' >> "$patterns"
if hits=$(grep -rliF -f "$patterns" "$h"); then
  reject "hidden check name found in: $(echo "$hits" | tr '\n' ' ')"
fi

[[ $fail -eq 0 ]] && echo "OK $h"
exit $fail
