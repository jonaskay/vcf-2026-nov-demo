# Shared setup for every run-2 script (rerun plan v1). Source it; don't execute it.
#
#   . "$demo/tools/run2_env.sh"
#
# Sets: demo, evals, RUN_ROOT (absolute), R2_LIB, R2_WORK, R2_LOGS, R2_BASE.
# Refuses to continue if RUN_ROOT would write into run 1's material (demo/run1, or the
# run-1 trees that still live in their original places), or into an ancestor of them.
#
# Also provides:
#   slot_acquire / slot_release   at most MAX_SANDBOXES (default 8) Luna runs at once, across
#                                 every run-2 process (stale slots of dead processes are freed)
#   run_one <harness> <label> <dest> <task>
#                                 one Luna run through run_harness.sh --no-score, exported to
#                                 <dest>/ (result.json, steps.tsv, trajectory.json, agent.patch),
#                                 or <dest>/NO_ROLLOUT.txt on an infrastructure failure.
#                                 Skips if <dest>/result.json already exists (resumable).
#                                 R2_RUN_HARNESS overrides the runner (plumbing tests only).
#   take_lock <dir>               refuse to start if another live process holds <dir>/.lock
#                                 (run 1's iteration 4 was evaluated twice by accident).

demo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
evals=$(cd "$demo/../ai-evals" && pwd -P)

r2_refuse() { echo "run2: REFUSING: $*" >&2; exit 2; }

r2_resolve() { # absolute path of $1 without creating it; its parent must exist
  local p=$1 parent
  [[ $p == /* ]] || p="$PWD/$p"
  parent=$(cd "$(dirname "$p")" 2>/dev/null && pwd -P) || return 1
  echo "$parent/$(basename "$p")"
}

RUN_ROOT=${RUN_ROOT:-$demo/run2}
_abs=$(r2_resolve "$RUN_ROOT") || r2_refuse "RUN_ROOT=$RUN_ROOT: parent directory does not exist"
[[ -d $_abs ]] && _abs=$(cd "$_abs" && pwd -P)
for _p in run1 harness2 meta_harness baselines slides private agent-tasks harnesses tools agents; do
  _q="$demo/$_p"; [[ -e $_q ]] && _q=$(cd "$_q" && pwd -P)
  case "$_abs/" in "$_q/"*) r2_refuse "RUN_ROOT=$_abs is inside run-1 or shared material ($_q)" ;; esac
  case "$_q/" in "$_abs/"*) r2_refuse "RUN_ROOT=$_abs contains run-1 or shared material ($_q)" ;; esac
done
RUN_ROOT=$_abs
unset _abs _p _q
mkdir -p "$RUN_ROOT"
R2_LIB="$RUN_ROOT/library"; R2_WORK="$RUN_ROOT/work"; R2_LOGS="$RUN_ROOT/logs"; R2_BASE="$RUN_ROOT/baselines"
mkdir -p "$R2_LIB" "$R2_WORK" "$R2_LOGS" "$R2_BASE" "$RUN_ROOT/.slots"
export RUN_ROOT

MAX_SANDBOXES=${MAX_SANDBOXES:-8}

_mypid() { sh -c 'echo $PPID'; } # pid of the calling (sub)shell; bash 3.2 has no BASHPID

slot_acquire() { # sets R2_SLOT
  local i pid me; me=$(_mypid)
  while :; do
    for i in $(seq 1 "$MAX_SANDBOXES"); do
      if mkdir "$RUN_ROOT/.slots/$i" 2>/dev/null; then
        echo "$me" > "$RUN_ROOT/.slots/$i/pid"; R2_SLOT=$i; return 0
      fi
      pid=$(cat "$RUN_ROOT/.slots/$i/pid" 2>/dev/null || true)
      if [[ -n $pid ]] && ! kill -0 "$pid" 2>/dev/null; then rm -rf "$RUN_ROOT/.slots/$i"; fi
    done
    sleep 20
  done
}
slot_release() { [[ -n ${R2_SLOT:-} ]] && rm -rf "$RUN_ROOT/.slots/$R2_SLOT"; R2_SLOT=; }

run_one() { # <harness> <label> <dest> <task>
  local h=$1 label=$2 dest=$3 task=$4 tmp t
  [[ -f $dest/result.json ]] && return 0
  case $label in r2-*) ;; *) r2_refuse "run-2 labels must start with r2- (got $label)" ;; esac
  rm -rf "$dest"; mkdir -p "$dest"
  tmp="$dest.tmp"; rm -rf "$tmp"
  slot_acquire
  "${R2_RUN_HARNESS:-$demo/tools/run_harness.sh}" --no-score "$h" "$label" "$tmp" "$task" > "$dest.eval.log" 2>&1 || true
  slot_release
  t=$(ls -d "$tmp"/*/ 2>/dev/null | head -1 || true)
  if [[ -n $t && -f $t/result.json ]]; then
    rm -rf "$dest"; mv "$t" "$dest"
  else
    echo "Not rolled out: the run produced no record (an infrastructure failure, not a property of the harness)." > "$dest/NO_ROLLOUT.txt"
  fi
  rm -rf "$tmp"
  [[ -f $dest/result.json ]]
}

take_lock() { # <dir>
  local d=$1/.lock pid
  mkdir -p "$1"
  if ! mkdir "$d" 2>/dev/null; then
    pid=$(cat "$d/pid" 2>/dev/null || true)
    if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
      r2_refuse "$1 is already being worked on by pid $pid (delete $d if that is wrong)"
    fi
    rm -rf "$d"; mkdir "$d"
  fi
  echo $$ > "$d/pid"
  trap 'rm -rf "'"$d"'"' EXIT
}

r2_luna_cost() { # total Luna cost so far over every r2-* trial (failed trials via agent.result.json)
  python3 -I - "$demo/private/raw-runs" <<'EOF'
import json, glob, os, sys
tot = 0.0
for r in glob.glob(os.path.join(sys.argv[1], "r2-*", "**", "result.json"), recursive=True):
    if r.endswith("agent.result.json"): continue
    try: c = (json.load(open(r)).get("usage") or {}).get("cost_usd")
    except Exception: c = None
    a = os.path.join(os.path.dirname(r), "agent.result.json")
    if c is None and os.path.exists(a):
        try: c = json.load(open(a)).get("cost_usd")
        except Exception: c = None
    tot += c or 0
print(f"{tot:.2f}")
EOF
}

r2_improver_cost() { # total improver cost so far over every run-2 session
  { cat "$R2_WORK"/*/logs/*.stats.txt 2>/dev/null || true; } \
    | jq -sR '[scan("\"cost_usd\":([0-9.]+)") | .[0] | tonumber] | add // 0 | . * 100 | round / 100'
}
