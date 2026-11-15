#!/usr/bin/env bash
# Harness² RUN 2 (rerun plan v1) on one task. Run 1's k=1 version is in demo/run1/scripts/.
#
#   refs:     H0 x NREF               local, prebuilt by refs.sh (same route and client as all runs)
#   propose:  INV editor, DOM editor  one component edit each; the library is read via editors only
#   probe:    INV x K, DOM x K
#   compose:  composer reads evidence.md + candidates -> successor
#   execute:  composed x KFINAL       (reuses a set instead if the successor equals base or a candidate)
#   select:   selector picks one output from the anonymous, shuffled pool of every rollout
#   reflect:  edit table (helped / hurt / no observed effect / confounded) -> lesson or NO_ENTRY
#
#   demo/harness2/task.sh <task>
#   DRY=1 demo/harness2/task.sh <task>   # editors, composer, selector on the H0 refs only; no Luna runs
#
# Writes only under $RUN_ROOT (default demo/run2; see tools/run2_env.sh for the guard).
# Resumable: each finished stage leaves work/<task>/<stage>/DONE and a rerun skips it; a dry run's
# editor proposals are reused by the real run, its composition and selection are not.
#
# The improver never sees a score: every rollout is exported --no-score, a guard stops the task if a
# result.json in a session workspace carries one, and scores are read only by scores.sh, afterwards.
#
# Env: K (probe rollouts per candidate, 3), KFINAL (composed rollouts, 3), NREF (H0 refs, 3),
#      IMPROVER_MODEL (claude-opus-5-5), EDITOR_BUDGET (3), COMPOSER_BUDGET (6), SELECTOR_BUDGET (4),
#      REFLECTOR_BUDGET (4), MAX_TURNS (60), MAX_SANDBOXES (8), MODEL (for run_harness.sh).
set -euo pipefail

task=${1:?usage: task.sh <task>}
h2=$(cd "$(dirname "$0")" && pwd -P)
. "$h2/../tools/run2_env.sh"
base="$demo/harnesses/h0"
lib="$R2_LIB"
w="$R2_WORK/$task"
logs="$w/logs"
K=${K:-3}; KFINAL=${KFINAL:-3}; NREF=${NREF:-3}
dry=${DRY:-0}
improver=${IMPROVER_MODEL:-claude-opus-5-5}
max_turns=${MAX_TURNS:-60}
py() { python3 -I "$h2/r2.py" "$@"; }
mkdir -p "$logs"
take_lock "$w"
rm -f "$logs/AUDIT_FAILED"

log() { echo "task.sh [$task] $(date '+%H:%M:%S') $*" | tee -a "$logs/task.log"; }
die() { log "ERROR: $*"; exit 1; }
is_done() { [[ -f $w/$1/DONE ]]; }
mark() { date '+%H:%M:%S' > "$w/$1/DONE"; }
check_audit() { [[ ! -f $logs/AUDIT_FAILED ]] || { log "stopping: $(cat "$logs/AUDIT_FAILED")"; exit 3; }; }
same_tree() { diff -rq -x .keep -x .DS_Store "$1" "$2" >/dev/null 2>&1; }
note() { echo "$*" >> "$logs/engagement.txt"; log "$*"; }

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

audit() { # <label> <stream-json log> <session dir>: stats, then stop on any forbidden path
  local label=$1 f=$2 sd=$3 bad outside
  {
    echo "$label"
    jq -cR 'fromjson? | select(.type == "result") | {subtype, cost_usd: .total_cost_usd, turns: .num_turns}' "$f"
    echo "tool calls:"
    jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' "$f" | sort | uniq -c
    echo "distinct files read: $(jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Read") | .input.file_path' "$f" | sort -u | wc -l | tr -d ' ')"
  } > "$logs/$label.stats.txt"
  bad=$(jq -rR --arg sd "$(cd "$sd" && pwd -P)" --arg sd2 "$sd" 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input | tostring
               | split($sd) | join("") | split($sd2) | join("")
               | select(test("private/|raw-runs|ai-evals|sanity/|meta_harness|run1/|checks\\.json|verifier\\.log|evidence\\.json|\\.map\\.tsv|\\.pool\\.tsv|refs\\.labels|\\.run1-labels"))' "$f" | wc -l | tr -d ' ')
  outside=$(py paths-outside "$f" "$sd" | wc -l | tr -d ' ')
  if [[ $bad != 0 || $outside != 0 ]]; then
    echo "audit: $label made $bad tool call(s) on forbidden paths and $outside outside its workspace" | tee -a "$logs/$label.stats.txt" > "$logs/AUDIT_FAILED"
    log "AUDIT FAILED $label: $bad forbidden, $outside outside the workspace (see $logs/$label.stats.txt)"
    exit 3
  fi
  echo "audit: clean" >> "$logs/$label.stats.txt"
}

fp_outside() { # fingerprint of a session dir, excluding the editable harness
  (cd "$1" && find . -type f ! -path './context/harness/*' ! -name 'reply.*' -print0 | sort -z | xargs -0 shasum 2>/dev/null | shasum | cut -c1-16)
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

new_ws() { # <stage> <with_library 0|1>: fresh session workspace with the request and the H0 refs
  local sd="$w/$1"
  rm -rf "$sd"; mkdir -p "$sd/context/references"
  cp "$w/refs/task.md" "$sd/context/task.md"
  cp -R "$w"/refs/r* "$sd/context/references/"
  if [[ $2 == 1 ]]; then
    [[ -f $lib/index.md ]] || rebuild_index
    cp -R "$lib" "$sd/context/library"
  fi
}

add_candidates() { # <session_dir>: both candidates with harness, diff, notes and rollouts
  local sd=$1 dim c
  cp -R "$base" "$sd/context/base_harness"
  for dim in inv dom; do
    c="$sd/context/candidates/$dim"; mkdir -p "$c"
    cp -R "$w/$dim/context/harness" "$c/harness"
    cp "$w/$dim/notes.md" "$c/notes.md"
    (cd "$sd/context" && diff -ruN -x .keep base_harness "candidates/$dim/harness" > "candidates/$dim/harness.diff") || true
    if [[ $dry == 1 ]]; then
      echo "Not rolled out: this is a dry run of the pipeline, so no candidate was executed." > "$c/NO_ROLLOUT.txt"
    elif [[ -f $w/probe_$dim/NO_ROLLOUT.txt ]]; then
      cp "$w/probe_$dim/NO_ROLLOUT.txt" "$c/NO_ROLLOUT.txt"
    else
      copy_rollouts "$w/probe_$dim" "$c/rollouts"
    fi
  done
}

copy_rollouts() { # <src with r<i>/> <dest>: every rollout that has a record
  local src=$1 dest=$2 r
  mkdir -p "$dest"
  for r in "$src"/r*/; do
    [[ -f $r/result.json ]] && cp -R "$r" "$dest/$(basename "$r")"
  done
  if [[ -z $(ls "$dest") ]]; then
    rmdir "$dest"
    echo "Not rolled out: every run produced no record (an infrastructure failure, not a property of the harness)." > "$(dirname "$dest")/NO_ROLLOUT.txt"
  fi
}

# ---------- sessions ----------

session() { # <stage> <label> <prompt file> <edit|read> <budget> [extra text]
  local st=$1 label=$2 pf=$3 mode=$4 budget=$5 extra=${6:-}
  local sd="$w/$st" f="$logs/$label.jsonl" prompt tools before
  prompt=$(cat "$h2/prompts/$pf")
  prompt=${prompt//__NREF__/$nref_used}; prompt=${prompt//__K__/$K}
  prompt=${prompt//__KFINAL__/${kfinal_used:-$KFINAL}}; prompt=${prompt//__NPOOL__/${npool:-0}}
  [[ -z $extra ]] || prompt="$prompt"$'\n\n'"$extra"
  local allow=("Read(./**)" "Glob" "Grep")
  if [[ $mode == edit ]]; then
    tools="Read,Write,Edit,Glob,Grep"; allow+=("Write(./context/harness/**)" "Edit(./context/harness/**)")
  else
    tools="Read,Glob,Grep"
  fi
  guard_no_scores "$sd/context"
  before=$(fp_outside "$sd")
  log "$label: session start ($improver, budget \$$budget)"
  ( cd "$sd" && claude --bare -p "$prompt" \
      --model "$improver" \
      --tools "$tools" \
      --permission-mode dontAsk \
      --allowedTools "${allow[@]}" \
      --disallowedTools "Read(/$demo/private/**)" "Read(/$demo/run1/**)" "Read(/$demo/meta_harness/**)" \
                        "Read(/$demo/harness2/work/**)" "Read(/$demo/harness2/library/**)" \
                        "Read(/$evals/**)" "Read(/$demo/../sanity/**)" \
      --max-budget-usd "$budget" --max-turns "$max_turns" \
      --output-format stream-json --verbose > "$f" ) || log "$label: claude exited non-zero (see $f)"
  audit "$label" "$f" "$sd"
  [[ $before == "$(fp_outside "$sd")" ]] || log "$label: WARNING session changed files outside context/harness"
  reply_text "$f" > "$sd/reply.$label.txt"
  log "$label: $(jq -cR 'fromjson? | select(.type == "result") | {cost: .total_cost_usd, turns: .num_turns}' "$f" | tail -1)"
}

engaged() { # <role> <label> <stage> [edits.md]: 0 if the session read what it must; misses in $logs/<label>.misses
           # A retry passes "<first>+<retry>" as the label is checked on both sessions' reads together.
  local role=$1 labels=$2 st=$3 edits=${4:-} label l
  label=${labels##*+}
  : > "$logs/$label.all.jsonl"
  for l in $(echo "$labels" | tr '+' ' '); do cat "$logs/$l.jsonl" >> "$logs/$label.all.jsonl"; done
  py engagement "$role" "$logs/$label.all.jsonl" "$w/$st" ${edits:+"$edits"} > "$logs/$label.engagement.txt" || true
  rm -f "$logs/$label.all.jsonl"
  cat "$logs/$label.engagement.txt" >> "$logs/$label.stats.txt"
  grep '^MISS: ' "$logs/$label.engagement.txt" | sed 's/^MISS: /- /' > "$logs/$label.misses" || true
  [[ ! -s $logs/$label.misses ]]
}

tidy_harness() { # an emptied file is a deletion (sessions have no delete tool)
  local hd=$1
  (cd "$hd" && find . -type f -size 0 ! -path ./system.md ! -path ./guardrails.md ! -path ./memory.md \
     ! -path ./tool_guidance.md ! -path ./skills/.keep -delete)
  find "$hd" -mindepth 1 -type d -empty ! -path "$hd/skills" -delete
}

validate_ws() { # <stage> <single 0|1>: validate context/harness into <stage>/validation.txt
  local sd="$w/$1" hd="$w/$1/context/harness"
  tidy_harness "$hd"
  "$demo/tools/validate.sh" "$hd" > "$sd/validation.txt" 2>&1 || return 1
  if [[ $2 == 1 ]]; then py single-component "$base" "$hd" >> "$sd/validation.txt" 2>&1 || return 1; fi
  return 0
}

edit_stage() { # <stage> <prompt> <budget> <single 0|1> [role]: session, one retry on a failed validation
               # or engagement check, then fall back to the base harness if still invalid
  local st=$1 pf=$2 budget=$3 single=$4 role=${5:-} msg retry=""
  session "$st" "$st" "$pf" edit "$budget"
  if ! validate_ws "$st" "$single"; then
    msg=$(sed -e "s#$w/$st/context/harness#context/harness#g" -e 's/hidden check name found in/a disallowed phrase was found in/' "$w/$st/validation.txt")
    retry="# YOUR PREVIOUS PROPOSAL FAILED VALIDATION

Your edits are still in \`context/harness/\`. Fix them in place so the harness passes, changing nothing else. The validator said:

$msg"
    log "$st: proposal failed validation, retrying once"
  elif [[ -n $role ]] && ! engaged "$role" "$st" "$st"; then
    retry="# BEFORE YOUR PROPOSAL IS ACCEPTED

Your edits are still in \`context/harness/\`. A check of your session found that you decided without reading the evidence it rests on:

$(cat "$logs/$st.misses")

Read those files now. Then keep, revise or undo your edits in place according to what they show, and reply with your full \`<notes>\` block again."
    note "$st: engagement miss, retrying once: $(tr '\n' ' ' < "$logs/$st.misses")"
  fi
  if [[ -n $retry ]]; then
    session "$st" "$st.retry" "$pf" edit "$budget" "$retry"
    if [[ -n $role ]] && ! engaged "$role" "$st+$st.retry" "$st"; then
      note "$st: ENGAGEMENT MISS after the retry (proceeding; reported, not hidden): $(tr '\n' ' ' < "$logs/$st.retry.misses")"
    fi
    if ! validate_ws "$st" "$single"; then
      log "$st: failed validation twice; falling back to the unmodified harness"
      rm -rf "$w/$st/context/harness"; cp -R "$base" "$w/$st/context/harness"
      echo "FALLBACK: the proposal failed validation twice, so this stage inherited the unmodified harness." > "$w/$st/fallback.txt"
      validate_ws "$st" 0 || die "$st: the unmodified harness fails validation"
    fi
  fi
  { cat "$w/$st/fallback.txt" 2>/dev/null || true
    local r last=""
    for r in "$w/$st"/reply.*.txt; do [[ -n $(block notes "$r") ]] && last=$r; done
    [[ -z $last ]] || block notes "$last"
  } > "$w/$st/notes.md"
  [[ -s $w/$st/notes.md ]] || cat "$w"/$st/reply.*.txt > "$w/$st/notes.md"
  "$demo/tools/leak_check.sh" "$w/$st/notes.md" >/dev/null || log "$st: WARNING leak_check flagged notes.md"
}

probe() { # <dim>: K rollouts of a candidate in parallel (skipped when it equals the base)
  local dim=$1 st="probe_$1" hd="$w/$1/context/harness" i pids="" n
  is_done "$st" && return 0
  mkdir -p "$w/$st"; rm -f "$w/$st/NO_ROLLOUT.txt"
  if same_tree "$base" "$hd"; then
    echo "Not rolled out: this candidate is identical to the unmodified harness (KEEP_BASE), so the base rollouts are its evidence." > "$w/$st/NO_ROLLOUT.txt"
    log "$st: KEEP_BASE candidate, not probed"
  else
    rm -rf "$w/$st/harness"; cp -R "$hd" "$w/$st/harness"   # the exact tree that was run
    for i in $(seq 1 "$K"); do
      run_one "$w/$st/harness" "r2-h2-$task-$dim-$i" "$w/$st/r$i" "$task" &
      pids="$pids $!"
    done
    for i in $pids; do wait "$i" || true; done
    n=$(ls "$w/$st"/r*/result.json 2>/dev/null | wc -l | tr -d ' ')
    log "$st: $n of $K rollouts recorded"
    for i in $(seq 1 "$K"); do
      [[ -f $w/$st/r$i/result.json ]] && log "$st r$i: $(jq -c . "$w/$st/r$i/result.json")"
    done
  fi
  guard_no_scores "$w/$st"
  mark "$st"
}

# ---------- stages ----------

log "start (dry=$dry, K=$K, KFINAL=$KFINAL, improver=$improver, RUN_ROOT=$RUN_ROOT)"

# 1. References: local H0 rollouts (refs.sh), exported without scores, plus the request.
if ! is_done refs; then
  if [[ $dry != 1 ]]; then "$h2/refs.sh" "$task" || true; fi
  rm -rf "$w/refs"; mkdir -p "$w/refs"; : > "$w/refs.labels.tsv"
  [[ -f $evals/tasks/$task/instruction.md ]] || die "no instruction.md for $task"
  cp "$evals/tasks/$task/instruction.md" "$w/refs/task.md"
  n=0
  for i in $(seq 1 "$NREF"); do
    d="$R2_BASE/h0/$task/r$i"
    [[ -f $d/result.json ]] || continue
    n=$((n + 1)); cp -R "$d" "$w/refs/r$n"
    printf 'r%s\tr2-h0-%s-%s\n' "$n" "$task" "$i" >> "$w/refs.labels.tsv"
  done
  [[ $n -gt 0 ]] || die "no local H0 references in $R2_BASE/h0/$task (run harness2/refs.sh $task)"
  [[ $n == "$NREF" ]] || log "refs: WARNING only $n of $NREF H0 references have a record"
  guard_no_scores "$w/refs"
  mark refs
fi
nref_used=$(ls -d "$w"/refs/r*/ | wc -l | tr -d ' ')
log "refs: $nref_used local H0 rollout(s)"

# 2. Propose: INV and DOM editors in parallel, each on its own copy of H0, one component each.
run_editor() {
  local dim=$1
  is_done "$dim" && { log "$dim: reusing earlier proposal"; return 0; }
  new_ws "$dim" 1; cp -R "$base" "$w/$dim/context/harness"
  py evidence "$w/$dim/context" > /dev/null
  edit_stage "$dim" "editor_$dim.md" "${EDITOR_BUDGET:-3}" 1
  if same_tree "$base" "$w/$dim/context/harness"; then log "$dim: KEEP_BASE"; else log "$dim: $(tail -1 "$w/$dim/validation.txt")"; fi
  mark "$dim"
}
run_editor inv & p1=$!
run_editor dom & p2=$!
rc=0; wait $p1 || rc=$?; wait $p2 || rc=$?
check_audit; [[ $rc == 0 ]] || die "an editor stage failed (exit $rc)"

# 3. Probe: K rollouts of each changed candidate, all in parallel (skipped in a dry run).
if [[ $dry != 1 ]]; then
  probe inv & p1=$!
  probe dom & p2=$!
  rc=0; wait $p1 || rc=$?; wait $p2 || rc=$?
  check_audit; [[ $rc == 0 ]] || die "a probe stage failed (exit $rc)"
fi

# 4. Compose: evidence.md + candidates -> successor. No library here: it reaches a task via the editors.
cst=compose; [[ $dry == 1 ]] && cst=compose_dry
if [[ $dry == 1 ]] || ! is_done "$cst"; then
  new_ws "$cst" 0; add_candidates "$w/$cst"; cp -R "$base" "$w/$cst/context/harness"
  py evidence "$w/$cst/context" > /dev/null
  edit_stage "$cst" composer.md "${COMPOSER_BUDGET:-6}" 0 composer
  if same_tree "$base" "$w/$cst/context/harness"; then log "$cst: KEEP_BASE"; else log "$cst: $(head -1 "$w/$cst/validation.txt")"; fi
  mark "$cst"
fi

# 5. Execute: KFINAL rollouts of the successor. If it equals the base or a candidate, that set is reused.
if [[ $dry != 1 ]] && ! is_done final; then
  mkdir -p "$w/final"; rm -f "$w/final/SOURCE"
  hd="$w/compose/context/harness"
  if same_tree "$base" "$hd"; then echo base > "$w/final/SOURCE"
  elif [[ ! -f $w/probe_inv/NO_ROLLOUT.txt ]] && same_tree "$w/probe_inv/harness" "$hd"; then echo inv > "$w/final/SOURCE"
  elif [[ ! -f $w/probe_dom/NO_ROLLOUT.txt ]] && same_tree "$w/probe_dom/harness" "$hd"; then echo dom > "$w/final/SOURCE"
  else
    echo composed > "$w/final/SOURCE"
    rm -rf "$w/final/harness"; cp -R "$hd" "$w/final/harness"
    pids=""
    for i in $(seq 1 "$KFINAL"); do
      run_one "$w/final/harness" "r2-h2-$task-final-$i" "$w/final/r$i" "$task" &
      pids="$pids $!"
    done
    for p in $pids; do wait "$p" || true; done
    for i in $(seq 1 "$KFINAL"); do
      [[ -f $w/final/r$i/result.json ]] && log "final r$i: $(jq -c . "$w/final/r$i/result.json")"
    done
  fi
  log "final: source=$(cat "$w/final/SOURCE")"
  guard_no_scores "$w/final"
  mark final
fi

# 6. Select: one output from the anonymous, shuffled pool of every distinct rollout of this task.
sst=select; [[ $dry == 1 ]] && sst=select_dry
if [[ $dry == 1 ]] || ! is_done "$sst"; then
  sd="$w/$sst"; rm -rf "$sd"; mkdir -p "$sd/context/candidates"
  cp "$w/refs/task.md" "$sd/context/task.md"
  pool="$w/$sst.pool.tsv"; : > "$pool"   # arm, run, rollout dir, raw label (outside the session dir)
  for r in "$w"/refs/r*/; do r=${r%/}
    printf 'base\t%s\t%s\t%s\n' "$(basename "$r")" "$r" "$(awk -F'\t' -v k="$(basename "$r")" '$1 == k { print $2 }' "$w/refs.labels.tsv")" >> "$pool"; done
  if [[ $dry != 1 ]]; then
    for dim in inv dom; do
      for r in "$w/probe_$dim"/r*/; do r=${r%/}; [[ -f $r/result.json ]] || continue
        printf '%s\t%s\t%s\t%s\n' "$dim" "$(basename "$r")" "$r" "r2-h2-$task-$dim-${r##*/r}" >> "$pool"; done
    done
    if [[ $(cat "$w/final/SOURCE") == composed ]]; then
      for r in "$w"/final/r*/; do r=${r%/}; [[ -f $r/result.json ]] || continue
        printf 'composed\t%s\t%s\t%s\n' "$(basename "$r")" "$r" "r2-h2-$task-final-${r##*/r}" >> "$pool"; done
    fi
  fi
  npool=$(wc -l < "$pool" | tr -d ' ')
  # Shuffle and assign ids c01..cNN; the map stays outside the session dir.
  python3 -I -c '
import random, sys
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip()]
random.shuffle(rows)
with open(sys.argv[2], "w") as f:
    for i, r in enumerate(rows, 1):
        f.write("c%02d\t%s\n" % (i, "\t".join(r)))
' "$pool" "$w/$sst.map.tsv"
  while IFS=$'\t' read -r id arm run dir label; do
    cp "$dir/agent.patch" "$sd/context/candidates/$id.patch"
  done < "$w/$sst.map.tsv"
  session "$sst" "$sst" selector.md read "${SELECTOR_BUDGET:-4}"
  pick() { perl -0ne 'if (/```choice\s*\n?\s*(c\d+)\s*\n?\s*```/s) { print "$1" }' "$1"; }
  choice=$(pick "$sd/reply.$sst.txt")
  miss=""
  [[ -n $choice ]] && grep -q "^$choice	" "$w/$sst.map.tsv" || miss="- your reply has no valid \`\`\`choice\`\`\` block naming one of the candidate ids"
  if ! engaged selector "$sst" "$sst"; then miss="$miss"$'\n'"$(cat "$logs/$sst.misses")"; fi
  if [[ -n ${miss//[$'\n ']/} ]]; then
    note "$sst: selector miss, retrying once: $(echo "$miss" | tr '\n' ' ')"
    session "$sst" "$sst.retry" selector.md read "${SELECTOR_BUDGET:-4}" "# BEFORE YOUR CHOICE IS ACCEPTED

A check of your session found:

$miss

Do that now, then give your reasoning and choice again in the output format."
    engaged selector "$sst+$sst.retry" "$sst" || note "$sst: ENGAGEMENT MISS after the retry (proceeding; reported, not hidden): $(tr '\n' ' ' < "$logs/$sst.retry.misses")"
    choice=$(pick "$sd/reply.$sst.retry.txt")
  fi
  if [[ -n $choice ]] && grep -q "^$choice	" "$w/$sst.map.tsv"; then
    grep "^$choice	" "$w/$sst.map.tsv" > "$w/$sst.selected.tsv"
    log "$sst: picked $choice = $(cut -f2,3 "$w/$sst.selected.tsv" | tr '\t' ' ') (pool of $npool)"
  else
    : > "$w/$sst.selected.tsv"
    log "$sst: WARNING no valid choice after the retry; no output selected"
  fi
  mark "$sst"
fi

if [[ $dry == 1 ]]; then
  log "improver cost so far: \$$(cat "$logs"/*.stats.txt | jq -sR '[scan("\"cost_usd\":([0-9.]+)") | .[0] | tonumber] | add // 0 | . * 100 | round / 100')"
  log "dry run done: see $w/{inv,dom,compose_dry,select_dry}/ and $logs/"
  exit 0
fi

# 7. Reflect: read the whole record; write a library entry only if the contrasts support a lesson.
if ! is_done reflect; then
  new_ws reflect 1; add_candidates "$w/reflect"
  cp -R "$w/compose/context/harness" "$w/reflect/context/harness"
  fin="$w/reflect/context/final"; mkdir -p "$fin"
  cp "$w/compose/notes.md" "$fin/composer_notes.md"
  (cd "$w/reflect/context" && diff -ruN -x .keep base_harness harness > final/harness.diff) || true
  src=$(cat "$w/final/SOURCE"); kfinal_used=0
  case $src in
    composed) copy_rollouts "$w/final" "$fin/rollouts"; kfinal_used=$(ls "$fin/rollouts" 2>/dev/null | wc -l | tr -d ' ') ;;
    base) echo "Not rolled out again: the adopted harness is identical to the unmodified harness, so the base rollouts in context/references/ are its evidence." > "$fin/NO_ROLLOUT.txt" ;;
    *) echo "Not rolled out again: the adopted harness is identical to the $src candidate, so that candidate's rollouts in context/candidates/$src/rollouts/ are its evidence." > "$fin/NO_ROLLOUT.txt" ;;
  esac
  py evidence "$w/reflect/context" > /dev/null
  r="$w/reflect/reply.reflect.txt"
  session reflect reflect reflector.md read "${REFLECTOR_BUDGET:-4}"
  block edits "$r" > "$w/reflect/edits.md" || true
  py edits-check "$w/reflect/edits.md" > "$logs/reflect.edits-check.txt" || true
  engaged reflector reflect reflect "$w/reflect/edits.md" || true
  misses=$( { grep '^MISS: ' "$logs/reflect.edits-check.txt" | sed 's/^MISS: /- /' || true; cat "$logs/reflect.misses"; } )
  if [[ -n $misses ]]; then
    note "reflect: miss, retrying once: $(echo "$misses" | tr '\n' ' ')"
    session reflect reflect.retry reflector.md read "${REFLECTOR_BUDGET:-4}" "# YOUR PREVIOUS REPLY WAS REJECTED

A check of your session and reply found:

$misses

Open the trajectories you need, then write BOTH blocks again in full (the \`<edits>\` block, and the \`<experience>\` block or NO_ENTRY)."
    r="$w/reflect/reply.reflect.retry.txt"
    block edits "$r" > "$w/reflect/edits.md" || true
    py edits-check "$w/reflect/edits.md" > "$logs/reflect.edits-check.txt" || note "reflect: EDIT TABLE STILL FAILS the step-reference check after the retry (kept; reported)"
    engaged reflector "reflect+reflect.retry" reflect "$w/reflect/edits.md" || note "reflect: ENGAGEMENT MISS after the retry (proceeding; reported, not hidden): $(tr '\n' ' ' < "$logs/reflect.retry.misses")"
  fi
  log "reflect: $(tail -1 "$logs/reflect.edits-check.txt")"
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
      echo "- adopted: the composed harness (Harness² run 2: $nref_used base rollouts, $K per candidate, composed: $src)"
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
    # Overfitting check (report only): run 1's task-term grep over the new entry
    hits=$( { grep -rniE "entropy|postpone|stall|quiet|burst" "$d/harness" "$w/reflect/experience.md" || true; } | wc -l | tr -d ' ')
    echo "$task: $hits task-term hit(s) in library/$task" >> "$R2_LOGS/library-task-terms.txt"
    [[ $hits == 0 ]] || log "reflect: NOTE library entry has $hits run-1 task-term hit(s) (see $R2_LOGS/library-task-terms.txt)"
  fi
  mark reflect
fi

mkdir -p "$w"; date '+%a %H:%M:%S' > "$w/DONE"
log "improver cost: \$$(cat "$logs"/*.stats.txt | jq -sR '[scan("\"cost_usd\":([0-9.]+)") | .[0] | tonumber] | add // 0 | . * 100 | round / 100')"
log "done"
