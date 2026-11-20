#!/usr/bin/env bash
# Run-2 scores, FOR THE REPORT AND SLIDES ONLY (rerun plan v1, Phase 5). Run 1's version is in
# demo/run1/scripts/scores.sh. Prints to stdout; NEVER redirect the output anywhere under
# $RUN_ROOT or demo/harness2/ (improver sessions read those trees, and Harness² must never see a
# score). Reads raw lemans results in demo/private/raw-runs/r2-*/ and run-2 work files.
#
#   demo/harness2/scores.sh [task...]          # per-arm table, selector, success criteria
#   demo/harness2/scores.sh --refs [task...]   # Phase 1 gate: local H0 vs published, per task
set -euo pipefail
h2=$(cd "$(dirname "$0")" && pwd -P)
. "$h2/../tools/run2_env.sh"
mode=all; [[ ${1:-} == --refs ]] && { mode=refs; shift; }
[[ $# -gt 0 ]] || set -- $(cat "$h2/stream-tasks.txt")
python3 -I - "$mode" "$demo" "$evals" "$RUN_ROOT" "$@" <<'EOF'
import glob, json, os, re, statistics, sys
mode, demo, evals, root, tasks = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:]
raw = os.path.join(demo, "private", "raw-runs")
published = os.path.join(evals, "runs", "2026-10-06-feature-tasks-revamped", "gpt-6-luna-max")
RUN1_H0 = {  # run 1's local H0 runs: a 4th data point only, never a reference
    "ft-card-stalled-quiet-clock": os.path.join(demo, "..", "sanity", "h0-card"),
    "ft-entropy-sweep": os.path.join(raw, "h0-local", "ft-entropy-sweep"),
    "ft-mysql-fulltext-search-foundation": os.path.join(raw, "h0-local-mysql", "ft-mysql-fulltext-search-foundation"),
}

def results_in(d):
    out = []
    for r in sorted(glob.glob(os.path.join(d, "**", "result.json"), recursive=True)):
        if r.endswith("agent.result.json"): continue
        try: out.append(json.load(open(r)))
        except Exception: pass
    return out

def label(lab):
    rs = results_in(os.path.join(raw, lab))
    return rs[-1] if rs else None

def arm_results(task, prefix, n=12):
    out = []
    for i in range(1, n + 1):
        r = label(f"{prefix}-{i}")
        if r: out.append(r)
    return out

def fmt(rs):
    if not rs: return "| – | – | – | – | – |"
    rew = [r.get("reward") or 0 for r in rs]; cred = [r.get("credit") or 0 for r in rs]
    oc = {}
    for r in rs:
        o = (r.get("outcome") or {}).get("name", "?"); oc[o] = oc.get(o, 0) + 1
    steps = [(r.get("usage") or {}).get("steps") or 0 for r in rs]
    mins = [round((r.get("duration") or 0) / 60) for r in rs]
    return (f"| {sum(1 for x in rew if x >= 1)}/{len(rs)} | {statistics.mean(cred):.2f} | "
            f"{', '.join(f'{k}×{v}' for k, v in sorted(oc.items()))} | {statistics.median(steps):g} | {statistics.median(mins):g} min |")

def passes(rs): return sum(1 for r in rs if (r.get("reward") or 0) >= 1)

if mode == "refs":
    print("## Phase 1 gate: local H0 (run 2) vs published\n")
    print("| task | source | passes | mean credit | outcomes | median steps | median time |")
    print("|---|---|---|---|---|---|---|")
    vary = 0
    for t in tasks:
        pub = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(published, f"{t}__*", "result.json")))]
        loc = arm_results(t, f"r2-h0-{t}")
        print(f"| {t} | published (OpenRouter) {fmt(pub)}")
        print(f"| {t} | local H0, run 2 {fmt(loc)}")
        v = any((r.get("reward") or 0) > 0 or (r.get("credit") or 0) > 0 for r in loc)
        vary += v
        print(f"| {t} | → {'VARIES locally' if v else ('0/' + str(len(loc)) + ' locally: swap candidate' if loc else 'no local runs yet')} | | | | | |")
    print(f"\nGate (≥ 2 of the candidate tasks vary locally): {vary} vary → {'PASS' if vary >= 2 else 'NOT YET / SWAP TASKS'}")
    sys.exit(0)

def read(p):
    try: return open(p).read()
    except Exception: return ""

rows, overall = [], {}
sel_rows, sel_pass, h0_pass_rates, sel_better, credit_sel, credit_h0 = [], 0, [], 0, [], []
print("## Run 2: every rollout, per task and arm\n")
print("| task | arm | passes | mean credit | outcomes | median steps | median time |")
print("|---|---|---|---|---|---|---|")
for t in tasks:
    w = os.path.join(root, "work", t)
    arms = [("H0 local (refs)", arm_results(t, f"r2-h0-{t}"))]
    if t in RUN1_H0:
        arms.append(("H0 local, run 1 (4th data point)", results_in(RUN1_H0[t])))
    arms += [("INV probes", arm_results(t, f"r2-h2-{t}-inv")), ("DOM probes", arm_results(t, f"r2-h2-{t}-dom"))]
    src = read(os.path.join(w, "final", "SOURCE")).strip()
    # Only a composed source has its own rollouts. Otherwise raw-runs may still hold final-* records
    # from a discarded attempt under the same labels (run 2: card-stalled, mysql), which must not count.
    comp = arm_results(t, f"r2-h2-{t}-final") if src == "composed" else []
    arms.append((f"composed" + (f" (= {src}, not rerun)" if src and src != "composed" else ""), comp))
    arms.append(("Meta-Harness i4b (transfer)", arm_results(t, f"r2-mh-i4b-{t}")))
    for name, rs in arms:
        print(f"| {t} | {name} {fmt(rs)}")
        key = name.split(" (")[0].split(",")[0]
        if rs and "run 1" not in name:
            o = overall.setdefault(key, [0, 0, []]); o[0] += passes(rs); o[1] += len(rs); o[2] += [r.get("credit") or 0 for r in rs]
    sel = read(os.path.join(w, "select.selected.tsv")).strip().split("\t")
    pool = [l.split("\t") for l in read(os.path.join(w, "select.map.tsv")).splitlines() if l.strip()]
    if len(sel) >= 5:
        sid, arm, run, _, lab = sel[:5]
        r = label(lab) or {}
        rew, cred = r.get("reward") or 0, r.get("credit") or 0
        pool_rew = [(label(p[4]) or {}).get("reward") or 0 for p in pool]
        best = max(pool_rew) if pool_rew else 0
        h0 = arm_results(t, f"r2-h0-{t}")
        h0_rate = passes(h0) / len(h0) if h0 else 0
        h0_cred = statistics.mean([x.get("credit") or 0 for x in h0]) if h0 else 0
        sel_pass += rew >= 1; h0_pass_rates.append(h0_rate); credit_sel.append(cred); credit_h0.append(h0_cred)
        sel_better += rew > h0_rate
        sel_rows.append(f"| {t} | {sid} = {arm} {run} | {rew:g} | {cred:.2f} | {sum(1 for x in pool_rew if x >= 1)}/{len(pool)} | {'yes' if rew >= best else 'no'} | {h0_rate:.2f} |")
    else:
        sel_rows.append(f"| {t} | (none) | – | – | – | – | – |")
print("\n## Pass rate per arm, whole stream\n")
print("| arm | passes | mean credit |")
print("|---|---|---|")
for k, (p, n, c) in overall.items():
    print(f"| {k} | {p}/{n} ({p / n:.0%}) | {statistics.mean(c):.2f} |")
print("\n## Selector\n")
print("| task | picked | reward | credit | passing outputs in pool | picked a best one | H0 local pass rate |")
print("|---|---|---|---|---|---|---|")
print("\n".join(sel_rows))
picked_h0 = sum(1 for r in sel_rows if "= base" in r)
print(f"\nPicked an H0 output on {picked_h0} of {len(sel_rows)} tasks.")

# ---------- pre-registered success criteria ----------
lib = os.path.join(root, "library")
entries = sorted(os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(lib, "*", "EXPERIENCE.md")))
cites = []
for t in tasks:
    w = os.path.join(root, "work", t)
    for dim in ("inv", "dom"):
        notes = read(os.path.join(w, dim, "notes.md"))
        logs = read(os.path.join(w, "logs", f"{dim}.jsonl")) + read(os.path.join(w, "logs", f"{dim}.retry.jsonl"))
        for e in entries:
            if e == t: continue
            if f"context/library/{e}/" in logs and e in notes:
                cites.append(f"{t} {dim} → {e}")
verdicts = {}
for t in tasks:
    for v in re.findall(r"^verdict:\s*(.+)$", read(os.path.join(root, "work", t, "reflect", "edits.md")), re.M | re.I):
        v = v.strip().strip("`* ").lower(); verdicts[v] = verdicts.get(v, 0) + 1
nonconf = sum(n for v, n in verdicts.items() if v != "confounded")
n_sel = sum(1 for r in sel_rows if "(none)" not in r)
sel_rate = sel_pass / n_sel if n_sel else 0
h0_rate = statistics.mean(h0_pass_rates) if h0_pass_rates else 0
print("\n## Success criteria (pre-registered in rerun-plan-v1.md)\n")
print("| Level | Criterion | Run 2 | Met |")
print("|---|---|---|---|")
print(f"| Mechanism | Reflector writes ≥ 2 library entries | {len(entries)} ({', '.join(entries) or 'none'}) | {'yes' if len(entries) >= 2 else 'no'} |")
print(f"| Mechanism | ≥ 1 later editor reads and cites a library entry | {len(cites)} ({'; '.join(cites) or 'none'}) | {'yes' if cites else 'no'} |")
print(f"| Mechanism | ≥ 1 verdict helped / hurt / no observed effect | {nonconf} (all verdicts: {verdicts or 'none'}) | {'yes' if nonconf else 'no'} |")
print(f"| Outcome | Selected passes at a rate ≥ local H0 | {sel_pass}/{n_sel} = {sel_rate:.2f} vs H0 {h0_rate:.2f} | {'yes' if n_sel and sel_rate >= h0_rate else 'no'} |")
mc_s = statistics.mean(credit_sel) if credit_sel else 0; mc_h = statistics.mean(credit_h0) if credit_h0 else 0
print(f"| Outcome | Strictly better than H0 on ≥ 1 task, or better mean credit | better on {sel_better} task(s); mean credit {mc_s:.2f} vs {mc_h:.2f} | {'yes' if sel_better or mc_s > mc_h else 'no'} |")
eng = []
for t in tasks:
    for l in read(os.path.join(root, "work", t, "logs", "engagement.txt")).splitlines():
        eng.append(f"- {t}: {l}")
print("\n## Engagement misses and retries (reported, not hidden)\n")
print("\n".join(eng) if eng else "none")
EOF
