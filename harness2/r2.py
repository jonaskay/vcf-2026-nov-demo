#!/usr/bin/env python3
"""Run-2 helpers for harness2/task.sh. Stdlib only; run with `python3 -I`.

  r2.py evidence <context_dir>                    write <context_dir>/evidence.md (no scores)
  r2.py single-component <base_dir> <harness_dir> exit 1 unless exactly one component changed
  r2.py opened <session.jsonl> <session_dir>      list files the session opened, with their arm
  r2.py engagement <role> <session.jsonl> <session_dir> [edits.md]
                                                  exit 1 (and print the misses) if the session
                                                  skipped files it must read
  r2.py edits-check <edits.md>                    exit 1 if a verdict row has no step reference
                                                  or an unknown verdict
  r2.py paths-outside <session.jsonl> <session_dir>
                                                  print absolute paths a tool call used outside
                                                  the session dir (exit 1 if any)

Arms, by path inside a session's context/:
  references/r<n>/            base   (the unmodified harness, H0)
  candidates/inv/rollouts/r<n> inv
  candidates/dom/rollouts/r<n> dom
  final/rollouts/r<n>          composed
"""
import json
import os
import re
import statistics
import sys

ARM_PATTERNS = [
    (re.compile(r"context/references/(r\d+)(/|$)"), "base"),
    (re.compile(r"context/candidates/(inv)/rollouts/(r\d+)(/|$)"), "inv"),
    (re.compile(r"context/candidates/(dom)/rollouts/(r\d+)(/|$)"), "dom"),
    (re.compile(r"context/final/rollouts/(r\d+)(/|$)"), "composed"),
]
ARM_DIRS = [("base", "references"), ("inv", "candidates/inv/rollouts"),
            ("dom", "candidates/dom/rollouts"), ("composed", "final/rollouts")]

# A test command at the start of a command segment (after ; && || | or env assignments),
# so that `cat bin/ci` or `grep rails test` do not count.
_SEG = r"(?:^|[;&|(]\s*)(?:\w+=\S*\s+)*"
TEST_RE = re.compile(_SEG + r"(?:(?:bin/rails|bundle exec rails|rails|bin/rake|rake)\s+test(?::(\w+))?([^;&|]*)|ruby\s+-I\s*test\s+(\S+)|(?:bin/ci)\b)")
EDIT_RE = re.compile(r"\bsed\s+-i|\bperl\s+-\w*i|apply_patch|\bgit\s+apply|File\.write|IO\.write|\brails\s+g(?:enerate)?\s")
REDIR_RE = re.compile(r"(?<![0-9&<>])>>?\s*['\"]?([^\s'\";&|)]+)|\btee\s+(?:-a\s+)?['\"]?([^\s'\";&|)]+)")


def is_write(c):
    """Heuristic: does this command write a file outside /tmp (i.e. edit the repository)?"""
    for m in REDIR_RE.finditer(c):
        t = m.group(1) or m.group(2) or ""
        if re.search(r"[/.]", t) and not t.startswith(("/tmp", "/dev", "&", "/proc")):
            return True
    if EDIT_RE.search(c):
        return True
    # scripted edits (ruby/python heredocs): a write call plus a repository path
    return bool(re.search(r"\.write\b|write_text|\.binwrite|File\.open\([^)]*['\"][wa]", c)
                and re.search(r"['\"(](?:/app/)?(?:app|test|db|config|lib)/", c))
SKILL_RE = re.compile(r"/opt/harness/skills/([\w.-]+)/SKILL\.md")
HARNESS_RE = re.compile(r"/opt/harness/([\w.-]+\.md)")


def load(p, default=None):
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return default


# ---------- evidence.md ----------

def rollout_row(arm, rid, d):
    res = load(os.path.join(d, "result.json"), {}) or {}
    traj = load(os.path.join(d, "trajectory.json"), {}) or {}
    steps = traj.get("steps") or []
    patch = ""
    try:
        patch = open(os.path.join(d, "agent.patch"), errors="replace").read()
    except Exception:
        pass
    files = re.findall(r"^diff --git a/(\S+)", patch, re.M)
    added = len(re.findall(r"^\+(?!\+\+)", patch, re.M))
    removed = len(re.findall(r"^-(?!--)", patch, re.M))
    ntest, last_exit, full, first_edit = 0, None, False, None
    skills, always = set(), set()
    for s in steps:
        cmds = s.get("commands") or []
        results = s.get("results") or []
        for i, c in enumerate(cmds):
            if not isinstance(c, str):
                continue
            for m in SKILL_RE.finditer(c):
                skills.add(m.group(1))
            for m in HARNESS_RE.finditer(c):
                if not m.group(1).startswith("skills"):
                    always.add(m.group(1))
            if first_edit is None and is_write(c):
                first_edit = s.get("step")
            tm = TEST_RE.search(c)
            if tm:
                ntest += 1
                ex = results[i].get("exit") if i < len(results) and isinstance(results[i], dict) else None
                last_exit = ex
                sub, args, rfile = tm.group(1), (tm.group(2) or ""), tm.group(3)
                if tm.group(0).rstrip().endswith("bin/ci") or sub == "all":
                    full = True
                elif rfile is None and sub is None:
                    rest = re.sub(r"\d?>&?\d?\S*|-\S+|\btest/?\s*$", " ", args).strip()
                    if not re.search(r"\S+\.rb|test/\S", args) and not rest:
                        full = True
    return {
        "arm": arm, "id": rid,
        "outcome": {"agent_timeout": "timeout"}.get(res.get("outcome"), res.get("outcome") or "?"),
        "steps": res.get("steps") if res.get("steps") is not None else len(steps),
        "minutes": round((res.get("duration_s") or 0) / 60),
        "files": files, "added": added, "removed": removed,
        "ntest": ntest, "last_exit": last_exit, "full": full, "first_edit": first_edit,
        "skills": sorted(skills), "always": sorted(always),
    }


def evidence(ctx):
    rows, missing = [], []
    for arm, sub in ARM_DIRS:
        base = os.path.join(ctx, sub)
        if not os.path.isdir(base):
            continue
        for rid in sorted(os.listdir(base), key=lambda x: (len(x), x)):
            d = os.path.join(base, rid)
            if not re.fullmatch(r"r\d+", rid) or not os.path.isdir(d):
                continue
            if os.path.exists(os.path.join(d, "result.json")):
                rows.append(rollout_row(arm, rid, d))
            else:
                missing.append((arm, rid))
    out = []
    w = out.append
    w("# Evidence: every rollout in this workspace, one row each")
    w("")
    w("Built by a script from the exported rollouts, before your session. There is no score here or anywhere: "
      "`completed` only means the run submitted before the limit. Columns marked (heuristic) are pattern matches "
      "on the commands and can be wrong; open the trajectory for anything you act on.")
    w("")
    w("| arm | run | outcome | steps | min | files in patch | patch +/- | test cmds | last test exit | full suite | first repo write step (heuristic) | skills read |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        files = ", ".join(f"`{f}`" for f in r["files"][:6]) + (f" +{len(r['files']) - 6} more" if len(r["files"]) > 6 else "")
        w(f"| {r['arm']} | {r['id']} | {r['outcome']} | {r['steps']} | {r['minutes']} | "
          f"{len(r['files'])}{': ' + files if files else ' (empty patch)'} | +{r['added']}/-{r['removed']} | {r['ntest']} | "
          f"{'–' if r['last_exit'] is None else r['last_exit']} | {'yes' if r['full'] else 'no'} | "
          f"{r['first_edit'] if r['first_edit'] is not None else '–'} | {', '.join(r['skills']) or '–'} |")
    for arm, rid in missing:
        w(f"| {arm} | {rid} | no rollout (infrastructure failure) | | | | | | | | | |")
    w("")
    w("## Per arm")
    w("")
    w("| arm | runs | completed | timeout | median steps | median min | runs with full suite | harness files the agent `cat`-ed (runs) |")
    w("|---|---|---|---|---|---|---|---|")
    for arm, _ in ARM_DIRS:
        rs = [r for r in rows if r["arm"] == arm]
        if not rs:
            continue
        cat = {}
        for r in rs:
            for s in r["skills"]:
                cat[f"skills/{s}"] = cat.get(f"skills/{s}", 0) + 1
            for a in r["always"]:
                cat[a] = cat.get(a, 0) + 1
        catted = ", ".join(f"`{k}` ({v}/{len(rs)})" for k, v in sorted(cat.items())) or "none"
        w(f"| {arm} | {len(rs)} | {sum(r['outcome'] == 'completed' for r in rs)} | "
          f"{sum(r['outcome'] == 'timeout' for r in rs)} | {statistics.median(r['steps'] for r in rs):g} | "
          f"{statistics.median(r['minutes'] for r in rs):g} | {sum(r['full'] for r in rs)}/{len(rs)} | {catted} |")
    w("")
    w("Each row's run lives at `references/<run>/` (base), `candidates/<arm>/rollouts/<run>/` (inv, dom) or "
      "`final/rollouts/<run>/` (composed), with `steps.tsv`, `trajectory.json`, `agent.patch` and `result.json`.")
    with open(os.path.join(ctx, "evidence.md"), "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"evidence.md: {len(rows)} rollouts, {len(missing)} missing")


# ---------- single-component rule ----------

def tree(d):
    out = {}
    for root, _, files in os.walk(d):
        for fn in files:
            if fn == ".keep":
                continue
            p = os.path.join(root, fn)
            rel = os.path.relpath(p, d)
            out[rel] = open(p, errors="replace").read()
    return out


def component(rel):
    m = re.match(r"skills/([^/]+)/", rel)
    return f"skills/{m.group(1)}" if m else rel


def single_component(base, harness):
    a, b = tree(base), tree(harness)
    changed = sorted(r for r in set(a) | set(b) if a.get(r) != b.get(r))
    comps = sorted({component(r) for r in changed})
    if not comps:
        print("single-component: no change (KEEP_BASE)")
        return 0
    skills = [c for c in comps if c.startswith("skills/")]
    others = [c for c in comps if not c.startswith("skills/")]
    if len(comps) == 1:
        print(f"single-component: OK ({comps[0]})")
        return 0
    if len(skills) == 1 and others == ["system.md"]:
        name = skills[0].split("/", 1)[1]
        import difflib
        diff = [l for l in difflib.unified_diff(a.get("system.md", "").splitlines(), b.get("system.md", "").splitlines(), lineterm="", n=0)
                if l[:1] in "+-" and not l.startswith(("+++", "---"))]
        if all(name in l for l in diff if l[1:].strip()):
            print(f"single-component: OK ({skills[0]} and its trigger line in system.md)")
            return 0
        print(f"single-component: REJECT: system.md changed beyond the trigger line of skill '{name}'. "
              f"Changed components: {', '.join(comps)}")
        return 1
    print(f"single-component: REJECT: the proposal changes {len(comps)} components ({', '.join(comps)}). "
          "Change exactly one: one always-on file, or one skill plus its trigger line in system.md.")
    return 1


# ---------- what a session opened ----------

def tool_inputs(jsonl):
    with open(jsonl, errors="replace") as f:
        for line in f:
            try:
                ev = json.loads(line)
            except Exception:
                continue
            if ev.get("type") != "assistant":
                continue
            for c in (ev.get("message") or {}).get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    yield c.get("name"), c.get("input") or {}


def opened(jsonl, sd):
    """(path relative to the session dir, tool) for every Read and every Grep/Glob path."""
    sd = os.path.realpath(sd)
    out = []
    for name, inp in tool_inputs(jsonl):
        for key in ("file_path", "path"):
            p = inp.get(key)
            if not isinstance(p, str) or not p:
                continue
            ap = p if os.path.isabs(p) else os.path.join(sd, p)
            ap = os.path.normpath(ap)
            rel = os.path.relpath(ap, sd) if ap.startswith(sd) else ap
            out.append((rel, name))
    return out


def arm_of(rel):
    for pat, arm in ARM_PATTERNS:
        if pat.search(rel if rel.startswith("context/") else "context/" + rel.split("context/", 1)[-1]):
            return arm
    return None


def trajectory_arms(jsonl, sd):
    arms = {}
    for rel, tool in opened(jsonl, sd):
        a = arm_of(rel)
        if not a:
            continue
        # A Read of trajectory.json or steps.tsv, or a Grep inside a rollout dir, counts as opening it.
        if (tool == "Read" and re.search(r"(trajectory\.json|steps\.tsv)$", rel)) or tool == "Grep":
            arms.setdefault(a, set()).add(rel)
    return arms


def available_arms(sd):
    ctx = os.path.join(sd, "context")
    out = []
    for arm, sub in ARM_DIRS:
        d = os.path.join(ctx, sub)
        if os.path.isdir(d) and any(os.path.exists(os.path.join(d, r, "trajectory.json")) for r in os.listdir(d)):
            out.append(arm)
    return out


def engagement(role, jsonl, sd, edits=None):
    misses = []
    reads = {rel for rel, tool in opened(jsonl, sd) if tool == "Read"}
    arms = trajectory_arms(jsonl, sd)
    avail = available_arms(sd)
    if role in ("composer", "reflector") and "context/evidence.md" not in reads:
        misses.append("you did not open `context/evidence.md`")
    if role == "composer":
        need = min(2, len(avail))
        if len(set(arms) & set(avail)) < need:
            misses.append(f"you opened trajectories from {len(arms)} arm(s) ({', '.join(sorted(arms)) or 'none'}); "
                          f"open at least {need} from different arms ({', '.join(avail)}) before deciding")
    if role == "selector":
        cdir = os.path.join(sd, "context", "candidates")
        pool = sorted(f for f in os.listdir(cdir) if f.endswith(".patch")) if os.path.isdir(cdir) else []
        seen = {os.path.basename(r) for r in reads if r.startswith("context/candidates/")}
        grepped = any(tool == "Grep" for rel, tool in opened(jsonl, sd) if rel.startswith("context/candidates"))
        unread = [f for f in pool if f not in seen]
        if unread and not grepped:
            misses.append(f"you did not open {len(unread)} of the {len(pool)} candidates ({', '.join(unread)})")
        elif unread:
            misses.append(f"you opened {len(pool) - len(unread)} of the {len(pool)} candidates in full; "
                          f"open the rest before choosing ({', '.join(unread)})")
    if role == "reflector":
        rated = set()
        if edits and os.path.exists(edits):
            for m in re.finditer(r"^candidates:\s*(.+)$", open(edits).read(), re.M):
                for lab in re.split(r"[,\s]+", m.group(1).strip()):
                    lab = {"adopted": "composed", "final": "composed"}.get(lab.lower(), lab.lower())
                    if lab in ("inv", "dom", "composed"):
                        rated.add(lab)
        for a in sorted(rated & set(avail)):
            if a not in arms:
                misses.append(f"you rated `{a}` edits without opening any `{a}` trajectory")
    for m in misses:
        print(f"MISS: {m}")
    print(f"engagement[{role}]: trajectories opened per arm: "
          + (", ".join(f"{a}={len(v)}" for a, v in sorted(arms.items())) or "none")
          + f"; evidence.md {'read' if 'context/evidence.md' in reads else 'NOT read'}; {len(misses)} miss(es)")
    return 1 if misses else 0


# ---------- reflector edit table ----------

VERDICTS = {"helped", "hurt", "no observed effect", "confounded"}
STEP_RE = re.compile(r"\b(?:base|inv|dom|composed|adopted|r\d+)\b[^.;\n]{0,40}?\bsteps?\s+\d+", re.I)


def edits_check(path):
    text = open(path).read() if os.path.exists(path) else ""
    rows = re.split(r"(?=^component:)", text, flags=re.M)
    rows = [r for r in rows if r.strip().startswith("component:")]
    bad = []
    for r in rows:
        comp = re.search(r"^component:\s*(.*)$", r, re.M).group(1).strip()
        verdict = (re.search(r"^verdict:\s*(.*)$", r, re.M) or [None, ""])[1].strip().lower().strip("`* ")
        observed = (re.search(r"^observed:\s*(.*)$", r, re.M) or [None, ""])[1]
        if verdict not in VERDICTS:
            bad.append(f"row `{comp}`: verdict '{verdict}' is not one of helped, hurt, no observed effect, confounded")
        if not STEP_RE.search(observed):
            bad.append(f"row `{comp}`: the observed field cites no trajectory step (write e.g. `inv r2 step 41`)")
    if not rows:
        bad.append("no edit rows found")
    for b in bad:
        print(f"MISS: {b}")
    counts = {}
    for r in rows:
        v = (re.search(r"^verdict:\s*(.*)$", r, re.M) or [None, "?"])[1].strip().lower().strip("`* ")
        counts[v] = counts.get(v, 0) + 1
    print(f"edits-check: {len(rows)} row(s) {counts}; {len(bad)} problem(s)")
    return 1 if bad else 0


def paths_outside(jsonl, sd):
    sd = os.path.realpath(sd)
    bad = []
    for name, inp in tool_inputs(jsonl):
        for key in ("file_path", "path"):
            p = inp.get(key)
            if not isinstance(p, str) or not p:
                continue
            ap = os.path.normpath(p if os.path.isabs(p) else os.path.join(sd, p))
            real = os.path.realpath(ap)
            if not (real == sd or real.startswith(sd + os.sep)):
                bad.append(f"{name} {p}")
    for b in bad:
        print(b)
    return 1 if bad else 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "evidence":
        evidence(argv[2]); return 0
    if cmd == "single-component":
        return single_component(argv[2], argv[3])
    if cmd == "opened":
        for rel, tool in opened(argv[2], argv[3]):
            print(f"{tool}\t{arm_of(rel) or '-'}\t{rel}")
        return 0
    if cmd == "engagement":
        return engagement(argv[2], argv[3], argv[4], argv[5] if len(argv) > 5 else None)
    if cmd == "edits-check":
        return edits_check(argv[2])
    if cmd == "paths-outside":
        return paths_outside(argv[2], argv[3])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
