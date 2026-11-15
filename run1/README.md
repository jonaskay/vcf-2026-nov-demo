# Run 1 (Sat Nov 14, 2026), sealed

A frozen copy of run 1's material, made on Nov 15 before any run-2 work (rerun plan, Phase 0).
The originals stay where they were, so paths in the report still resolve; this copy is the
reference for the talk. Every file is listed in `MANIFEST.sha256` and the tree is read-only.

    cd demo/run1 && shasum -a 256 -c MANIFEST.sha256 --quiet && echo "run 1 intact"

- `scripts/` holds the run-1 code: Harness² `task.sh`, `stream.sh`, `scores.sh`; Meta-Harness
  `loop.sh`, `scoreboard.sh`, `seed_h0.sh`; `tools/`, `agents/` and H0 as they were.
- `demo/private/` (hidden check names, raw lemans output with scores) is deliberately NOT copied.
