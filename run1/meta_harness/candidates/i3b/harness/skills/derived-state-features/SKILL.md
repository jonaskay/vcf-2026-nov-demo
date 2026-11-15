# Derived-state features (activity/time based states)

Work order (keeps the run short): 1) write the SQL scope + Ruby predicate on the model concern; 2) check with one runner experiment which existing hook touches `last_active_at`; 3) add the state to views/JSON/filters; 4) tests; 5) full suite.

- Define the state as a pure function of timestamps/events: a SQL scope and a Ruby predicate that give the same answer (test that they agree on every fixture case). A state that "begins after N days of quiet" appears by the clock passing, with no job and no stored flag, if the needed timestamps already exist.
- Look for existing machinery first (activity spikes, `last_active_at`, events, entropy periods, statuses). Reuse its thresholds and helpers rather than recomputing differently.
- "X, then Y": the state is on only if there is an X and nothing has happened since the LATEST X (or since the latest activity of any kind) for N. Evaluate against the most recent X, not "any X in history". Test: X, quiet N -> on; X, activity at N-1, quiet N-1 more -> off; new X, quiet N -> on.
- A trigger defined as "K or more of something from at least M people within a window" is a sliding window: check every window, anchored at each qualifying item, not only the window ending now. Window length that is a fraction of a configurable period reads that period from the record's board/account setting. Count distinct users; ignore system users.
- "Any activity" = everything that touches `last_active_at` (comments, events, reactions, assignments, reopen, publish). Test at least two different kinds. Don't add hooks to many models; reuse the existing touch path.
- Thresholds are literal: "three or more" is `>= 3`; test just inside and just outside the window edge.
- "Wherever cards are shown": `grep -rln "card" app/views`, list every card partial (previews, public previews, perma/container, columns, notifications, JSON/jbuilder) and add the indicator to each with the same markup/key; add the state to fragment cache keys. Prove it with a request test asserting page and JSON.
- New list filter value: add it to the filter's allowed list, map it in `indexed_by`, check any `include_*` helpers that hide closed/postponed cards, and make params round-trip. Prove it with a controller test using `?indexed_by=<value>`.
