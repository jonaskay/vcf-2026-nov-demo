#!/usr/bin/env bash
# Harness² (naive reimplementation, k=1) on one task:
#   refs -> INV + DOM editors -> probes -> composer -> execute -> reflect -> library
#
#   demo/harness2/task.sh <task>
#   DRY=1 demo/harness2/task.sh <task>    # editors + composer only, no Luna runs (~15 min)
#
# Every task starts from H0 (paper §2.3); the library is read for reuse, never inherited.
# Resumable: each finished stage leaves work/<task>/<stage>/DONE, and a rerun skips it.
# A dry run's editor proposals are therefore reused by the real run; its composition is not.
#
# The improver never sees a score: references and probes are exported with --no-score, a
# guard stops the task if any result.json in a session workspace carries one, and the
# hidden verifier output stays in demo/private/raw-runs/.
#
# Env: NREF (published H0 rollouts used as references, default 3), EXTRA_REFS (space-separated
#      extra H0 trial dirs; those of other tasks are skipped), MODEL (for run_harness.sh),
#      IMPROVER_MODEL (default claude-sonnet-5-5), EDITOR_BUDGET (3), COMPOSER_BUDGET (4),
#      REFLECTOR_BUDGET (3), MAX_TURNS (150), PUBLISHED (published trials dir).
set -euo pipefail

task=${1:?usage: task.sh <task>}
h2=$(cd "$(dirname "$0")" && pwd)
demo=$(cd "$h2/.." && pwd)
evals=$(cd "$demo/../ai-evals" && pwd)
published=${PUBLISHED:-$evals/runs/2026-10-06-feature-tasks-revamped/gpt-6-luna-max}
base="$demo/harnesses/h0"
lib="$h2/library"
w="$h2/work/$task"
logs="$w/logs"
nref=${NREF:-3}
dry=${DRY:-0}
improver=${IMPROVER_MODEL:-claude-sonnet-5-5}
max_turns=${MAX_TURNS:-150}
mkdir -p "$logs" "$lib"
rm -f "$logs/AUDIT_FAILED"

log() { echo "task.sh [$task] $(date '+%H:%M:%S') $*" | tee -a "$logs/task.log"; }
die() { log "ERROR: $*"; exit 1; }
is_done() { [[ -f $w/$1/DONE ]]; }
mark() { date '+%H:%M:%S' > "$w/$1/DONE"; }
check_audit() { [[ ! -f $logs/AUDIT_FAILED ]] || { log "stopping: $(cat "$logs/AUDIT_FAILED")"; exit 3; }; }
same_as_base() { diff -rq -x .keep "$base" "$1" >/dev/null 2>&1; }

# ---------- guards ----------

guard_no_scores() { # <dir>: stop if any result.json under it carries a score
  local f
  while IFS= read -r f; do
    if jq -e 'has("reward") or has("credit")' "$f" >/dev/null 2>&1; then
      echo "score guard: $f carries a score" > "$logs/AUDIT_FAILED"
      log "SCORE GUARD: a result.json in an improver workspace carries a score"
      exit 3
    fi
  done < <(find "$1" -name result.json)
}

audit() { # <label> <stream-json log>: stats, then stop on any forbidden path in a tool input
  local label=$1 f=$2 bad
  {
    echo "$label"
    jq -cR 'fromjson? | select(.type == "result") | {subtype, cost_usd: .total_cost_usd, turns: .num_turns}' "$f"
    echo "tool calls:"
    jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' "$f" | sort | uniq -c
    echo "distinct files read: $(jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Read") | .input.file_path' "$f" | sort -u | wc -l | tr -d ' ')"
  } > "$logs/$label.stats.txt"
  bad=$(jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input | tostring
               | select(test("private/|raw-runs|ai-evals|sanity/|meta_harness|checks\\.json|verifier\\.log|evidence\\.json"))' "$f" | wc -l | tr -d ' ')
  if [[ $bad != 0 ]]; then
    echo "audit: $label made $bad tool call(s) on forbidden paths" | tee -a "$logs/$label.stats.txt" > "$logs/AUDIT_FAILED"
    log "AUDIT FAILED $label: $bad tool call(s) touched forbidden paths"
    exit 3
  fi
  echo "audit: clean" >> "$logs/$label.stats.txt"
}

fp_outside() { # fingerprint of a session dir, excluding the editable harness
  (cd "$1" && find . -type f ! -path './context/harness/*' -print0 | sort -z | xargs -0 shasum 2>/dev/null | shasum | cut -c1-16)
}

reply_text() { # final reply text of a session (result event, else all assistant text)
  local t
  t=$(jq -rR 'fromjson? | select(.type == "result") | .result // empty' "$1")
  [[ -n $t ]] || t=$(jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$1")
  printf '%s\n' "$t"
}

block() { # <tag> <file>: inner text of the first <tag>...</tag>
  perl -0ne 'if (/<'"$1"'>\s*(.*?)\s*<\/'"$1"'>/s) { print "$1\n" }' "$2"
}

# ---------- workspaces ----------

ensure_index() { [[ -f $lib/index.md ]] || rebuild_index; }

rebuild_index() {
  {
    echo "# Library: Fizzy feature tasks"
    echo
    echo "Each entry is an earlier task whose harness was adopted, stored with its FULL component tree and the lessons from refining it. Browse this index, then open the entries that look relevant to the request in front of you."
    echo
    local n=0 d name skills chars cue
    for d in "$lib"/*/; do
      [[ -f $d/EXPERIENCE.md ]] || continue
      n=$((n + 1)); name=$(basename "$d")
      skills=$(find "$d/harness/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
      chars=$(cat "$d"/harness/{system,guardrails,memory,tool_guidance}.md 2>/dev/null | wc -c | tr -d ' ')
      cue=$(sed -n 's/^- \*\*cue\*\*: //p' "$d/EXPERIENCE.md" | head -1)
      echo "## \`$name/\`"
      echo "- harness: \`$name/harness/\` (skills: $skills, always-on text: $chars characters)"
      echo "- why:     \`$name/EXPERIENCE.md\`"
      [[ -z $cue ]] || echo "- cue:     $cue"
      echo
    done
    [[ $n -gt 0 ]] || echo "_(empty: this is the first task)_"
  } > "$lib/index.md"
}

new_ws() { # <stage>: fresh session workspace with the shared evidence
  local sd="$w/$1"
  rm -rf "$sd"; mkdir -p "$sd/context/references"
  cp "$w/refs/task.md" "$sd/context/task.md"
  cp -R "$w"/refs/r* "$sd/context/references/"
  ensure_index; cp -R "$lib" "$sd/context/library"
}

add_candidates() { # <session_dir>: both candidates with harness, diff, notes and rollout
  local sd=$1 dim c
  cp -R "$base" "$sd/context/base_harness"
  for dim in inv dom; do
    c="$sd/context/candidates/$dim"; mkdir -p "$c"
    cp -R "$w/$dim/context/harness" "$c/harness"
    cp "$w/$dim/notes.md" "$c/notes.md"
    (cd "$sd/context" && diff -ruN -x .keep base_harness "candidates/$dim/harness" > "candidates/$dim/harness.diff") || true
    if [[ $dry == 1 ]]; then
      echo "Not rolled out: this is a dry run of the pipeline, so no candidate was executed." > "$c/NO_ROLLOUT.txt"
    elif [[ -d $w/probe_$dim/rollout ]]; then
      cp -R "$w/probe_$dim/rollout" "$c/rollout"
    else
      cp "$w/probe_$dim/NO_ROLLOUT.txt" "$c/NO_ROLLOUT.txt"
    fi
  done
}

# ---------- sessions ----------

session() { # <stage> <label> <prompt file> <edit|read> <budget> [extra text]
  local st=$1 label=$2 pf=$3 mode=$4 budget=$5 extra=${6:-}
  local sd="$w/$st" f="$logs/$label.jsonl" prompt tools before
  prompt=$(cat "$h2/prompts/$pf"); prompt=${prompt//__NREF__/$nref_used}
  [[ -z $extra ]] || prompt="$prompt"$'\n\n'"$extra"
  local allow=("Read(./**)" "Glob" "Grep")
  if [[ $mode == edit ]]; then
    tools="Read,Write,Edit,Glob,Grep"; allow+=("Write(./context/harness/**)" "Edit(./context/harness/**)")
  else
    tools="Read,Glob,Grep"
  fi
  guard_no_scores "$sd/context"
  before=$(fp_outside "$sd")
  log "$label: session start (budget \$$budget)"
  # Session dirs sit at demo/harness2/work/<task>/<stage>, so ../../../.. is demo/.
  ( cd "$sd" && claude --bare -p "$prompt" \
      --model "$improver" \
      --tools "$tools" \
      --permission-mode dontAsk \
      --allowedTools "${allow[@]}" \
      --disallowedTools "Read(../../../../private/**)" "Read(../../../../meta_harness/**)" \
                        "Read(../../../../../ai-evals/**)" "Read(../../../../../sanity/**)" \
      --max-budget-usd "$budget" --max-turns "$max_turns" \
      --output-format stream-json --verbose > "$f" ) || log "$label: claude exited non-zero (see $f)"
  audit "$label" "$f"
  [[ $before == "$(fp_outside "$sd")" ]] || log "$label: WARNING session changed files outside context/harness"
  reply_text "$f" > "$sd/reply.$label.txt"
  log "$label: $(jq -cR 'fromjson? | select(.type == "result") | {cost: .total_cost_usd, turns: .num_turns}' "$f" | tail -1)"
}

tidy_harness() { # an emptied file is a deletion (sessions have no delete tool)
  local hd=$1
  (cd "$hd" && find . -type f -size 0 ! -path ./system.md ! -path ./guardrails.md ! -path ./memory.md \
     ! -path ./tool_guidance.md ! -path ./skills/.keep -delete)
  find "$hd" -mindepth 1 -type d -empty ! -path "$hd/skills" -delete
}

validate_ws() { # <stage>: validate context/harness into <stage>/validation.txt
  local sd="$w/$1" hd="$w/$1/context/harness"
  tidy_harness "$hd"
  if "$demo/tools/validate.sh" "$hd" > "$sd/validation.txt" 2>&1; then return 0; fi
  return 1
}

edit_stage() { # <stage> <prompt> <budget>: one editing session, one retry, then fall back to the base
  local st=$1 pf=$2 budget=$3 msg
  session "$st" "$st" "$pf" edit "$budget"
  if ! validate_ws "$st"; then
    log "$st: proposal failed validation, retrying once"
    msg=$(sed -e "s#$w/$st/context/harness#context/harness#g" -e 's/hidden check name found in/a disallowed phrase was found in/' "$w/$st/validation.txt")
    session "$st" "$st.retry" "$pf" edit "$budget" "# YOUR PREVIOUS PROPOSAL FAILED VALIDATION

Your edits are still in \`context/harness/\`. Fix them in place so the harness passes, changing nothing else. The validator said:

$msg"
    if ! validate_ws "$st"; then
      log "$st: failed validation twice; falling back to the unmodified harness"
      rm -rf "$w/$st/context/harness"; cp -R "$base" "$w/$st/context/harness"
      echo "FALLBACK: the proposal failed validation twice, so this stage inherited the unmodified harness." > "$w/$st/fallback.txt"
      validate_ws "$st" || die "$st: the unmodified harness fails validation"
    fi
  fi
  { cat "$w/$st/fallback.txt" 2>/dev/null || true
    local r; for r in "$w/$st"/reply.*.txt; do block notes "$r" || true; done
  } > "$w/$st/notes.md"
  [[ -s $w/$st/notes.md ]] || cat "$w"/$st/reply.*.txt > "$w/$st/notes.md"
  "$demo/tools/leak_check.sh" "$w/$st/notes.md" >/dev/null || log "$st: WARNING leak_check flagged notes.md"
}

probe() { # <dim>: one rollout of a candidate (skipped when it equals the base)
  local dim=$1 st="probe_$1" hd="$w/$1/context/harness" t
  is_done "$st" && return 0
  rm -rf "$w/$st"; mkdir -p "$w/$st"
  if same_as_base "$hd"; then
    echo "Not rolled out: this candidate is identical to the unmodified harness (KEEP_BASE), so the base rollouts are its evidence." > "$w/$st/NO_ROLLOUT.txt"
    log "$st: KEEP_BASE candidate, not probed"
  else
    "$demo/tools/run_harness.sh" --no-score "$hd" "h2-$task-$dim" "$w/$st/out" "$task" > "$logs/$st.eval.log" 2>&1 || true
    grep '^run_harness:' "$logs/$st.eval.log" | tail -2 | while IFS= read -r l; do log "$st: $l"; done
    t=$(ls -d "$w/$st"/out/*/ 2>/dev/null | head -1 || true)
    if [[ -n $t && -f $t/result.json ]]; then
      mv "$t" "$w/$st/rollout"; rm -rf "$w/$st/out"
      log "$st: $(jq -c . "$w/$st/rollout/result.json")"
    else
      echo "Not rolled out: the run produced no record (an infrastructure failure, not a property of the harness)." > "$w/$st/NO_ROLLOUT.txt"
      log "$st: WARNING no rollout recorded (see $logs/$st.eval.log)"
    fi
  fi
  guard_no_scores "$w/$st"
  mark "$st"
}

# ---------- stages ----------

log "start (dry=$dry)"

# 1. References: published H0 rollouts, exported without scores, plus the request.
if ! is_done refs; then
  rm -rf "$w/refs"; mkdir -p "$w/refs"
  [[ -f $evals/tasks/$task/instruction.md ]] || die "no instruction.md for $task"
  cp "$evals/tasks/$task/instruction.md" "$w/refs/task.md"
  n=0
  for d in "$published/${task}__"*/; do
    [[ -f $d/result.json && $n -lt $nref ]] || continue
    n=$((n + 1)); "$demo/tools/export_run.sh" "$d" "$w/refs/r$n" --no-score
  done
  [[ $n -gt 0 ]] || die "no published reference runs under $published"
  for d in ${EXTRA_REFS:-}; do  # extra H0 trials (e.g. a local run); only those of this task are used
    [[ -f $d/result.json ]] || die "EXTRA_REFS: no result.json in $d"
    [[ $(jq -r .task "$d/result.json") == "$task" ]] || continue
    n=$((n + 1)); "$demo/tools/export_run.sh" "$d" "$w/refs/r$n" --no-score
    log "refs: r$n is an extra H0 trial"
  done
  guard_no_scores "$w/refs"
  mark refs
fi
nref_used=$(ls -d "$w"/refs/r*/ | wc -l | tr -d ' ')
log "refs: $nref_used base rollout(s)"

# 2. Propose: INV and DOM editors in parallel, each on its own copy of H0.
run_editor() {
  local dim=$1
  is_done "$dim" && { log "$dim: reusing earlier proposal"; return 0; }
  new_ws "$dim"; cp -R "$base" "$w/$dim/context/harness"
  edit_stage "$dim" "editor_$dim.md" "${EDITOR_BUDGET:-3}"
  if same_as_base "$w/$dim/context/harness"; then log "$dim: KEEP_BASE"; else log "$dim: $(head -1 "$w/$dim/validation.txt")"; fi
  mark "$dim"
}
run_editor inv & p1=$!
run_editor dom & p2=$!
rc=0; wait $p1 || rc=$?; wait $p2 || rc=$?
check_audit; [[ $rc == 0 ]] || die "an editor stage failed (exit $rc)"

# 3. Probe: run each changed candidate once, in parallel (skipped in a dry run).
if [[ $dry != 1 ]]; then
  probe inv & p1=$!
  probe dom & p2=$!
  rc=0; wait $p1 || rc=$?; wait $p2 || rc=$?
  check_audit; [[ $rc == 0 ]] || die "a probe stage failed (exit $rc)"
fi

# 4. Compose: one session writes the successor from the reference, candidates and rollouts.
cst=compose; [[ $dry == 1 ]] && cst=compose_dry
if [[ $dry == 1 ]] || ! is_done "$cst"; then
  new_ws "$cst"; add_candidates "$w/$cst"; cp -R "$base" "$w/$cst/context/harness"
  edit_stage "$cst" composer.md "${COMPOSER_BUDGET:-4}"
  if same_as_base "$w/$cst/context/harness"; then log "$cst: KEEP_BASE"; else log "$cst: $(head -1 "$w/$cst/validation.txt")"; fi
  mark "$cst"
fi
if [[ $dry == 1 ]]; then
  cat "$logs"/*.stats.txt | jq -sR '[scan("\"cost_usd\":([0-9.]+)") | .[0] | tonumber] | add // 0 | "improver cost so far: $\(. * 100 | round / 100)"' -r | while IFS= read -r l; do log "$l"; done
  log "dry run done: see $w/{inv,dom,compose_dry}/"
  exit 0
fi

# 5. Execute: run the composed harness once. This rollout is the task's result.
if ! is_done final; then
  rm -rf "$w/final"; mkdir -p "$w/final"
  "$demo/tools/run_harness.sh" --no-score "$w/compose/context/harness" "h2-$task-final" "$w/final/out" "$task" > "$logs/final.eval.log" 2>&1 || true
  grep '^run_harness:' "$logs/final.eval.log" | tail -2 | while IFS= read -r l; do log "final: $l"; done
  t=$(ls -d "$w"/final/out/*/ 2>/dev/null | head -1 || true)
  if [[ -n $t && -f $t/result.json ]]; then
    mv "$t" "$w/final/rollout"; rm -rf "$w/final/out"
    log "final: $(jq -c . "$w/final/rollout/result.json")"
  else
    echo "Not rolled out: the run produced no record (an infrastructure failure, not a property of the harness)." > "$w/final/NO_ROLLOUT.txt"
    log "final: WARNING no rollout recorded (see $logs/final.eval.log)"
  fi
  guard_no_scores "$w/final"
  mark final
fi

# 6. Reflect: read the whole record; write a library entry only if the contrasts support a lesson.
if ! is_done reflect; then
  new_ws reflect; add_candidates "$w/reflect"
  cp -R "$w/compose/context/harness" "$w/reflect/context/harness"
  mkdir -p "$w/reflect/context/final"
  cp "$w/compose/notes.md" "$w/reflect/context/final/composer_notes.md"
  (cd "$w/reflect/context" && diff -ruN -x .keep base_harness harness > final/harness.diff) || true
  if [[ -d $w/final/rollout ]]; then cp -R "$w/final/rollout" "$w/reflect/context/final/rollout"
  else cp "$w/final/NO_ROLLOUT.txt" "$w/reflect/context/final/NO_ROLLOUT.txt"; fi
  session reflect reflect reflector.md read "${REFLECTOR_BUDGET:-3}"
  r="$w/reflect/reply.reflect.txt"
  block edits "$r" > "$w/reflect/edits.md" || true
  block experience "$r" | perl -ne '
    if (/^\s*(cue|lesson|evidence|confidence)\s*:\s*(.*?)\s*$/i) { $k = lc $1; $v{$k} = $2; push @o, $k unless $s{$k}++ }
    elsif ($k && /\S/) { chomp; s/^\s+//; $v{$k} .= " $_" }
    END { print "- **$_**: $v{$_}\n" for @o }' > "$w/reflect/experience.md" || true
  if ! grep -q '^- \*\*cue\*\*: ' "$w/reflect/experience.md" || ! grep -q '^- \*\*lesson\*\*: ' "$w/reflect/experience.md" \
     || ! grep -q '^- \*\*evidence\*\*: ' "$w/reflect/experience.md"; then
    log "reflect: NO_ENTRY (no supported lesson); library unchanged"
  elif ! "$demo/tools/leak_check.sh" "$w/reflect/experience.md" "$w/reflect/edits.md" "$w/compose/notes.md" >/dev/null; then
    log "reflect: WARNING leak_check flagged the entry; library unchanged (inspect by hand)"
  else
    d="$lib/$task"; rm -rf "$d"; mkdir -p "$d"
    cp -R "$w/compose/context/harness" "$d/harness"
    {
      echo "# $task"
      echo
      echo "- adopted: the composed harness (Harness² k=1, $nref_used base rollouts)"
      echo "- components: skills $(find "$d/harness/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' '), always-on text $(cat "$d"/harness/{system,guardrails,memory,tool_guidance}.md | wc -c | tr -d ' ') characters"
      echo
      echo "## Why this harness (composer decisions)"
      echo
      cat "$w/compose/notes.md"
      echo
      echo "## What each edit did"
      echo
      cat "$w/reflect/edits.md"
      echo
      echo "## Transferable lesson"
      echo
      cat "$w/reflect/experience.md"
    } > "$d/EXPERIENCE.md"
    rebuild_index
    log "reflect: library entry written ($d)"
  fi
  mark reflect
fi

cat "$logs"/*.stats.txt | jq -sR '[scan("\"cost_usd\":([0-9.]+)") | .[0] | tonumber] | add // 0 | "improver cost: $\(. * 100 | round / 100)"' -r | while IFS= read -r l; do log "$l"; done
log "done"
