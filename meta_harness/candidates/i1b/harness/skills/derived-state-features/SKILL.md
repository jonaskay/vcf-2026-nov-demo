# Derived-state features (activity/time based states)

- Define the state as a pure function of timestamps/events: a SQL scope and a Ruby predicate that give the same answer. A state that "begins after N days of quiet" should appear by the clock passing, with no job and no stored flag, if the needed timestamps already exist.
- Look for existing machinery first (activity spikes, `last_active_at`, events, entropy periods, statuses). Reuse its thresholds and helpers rather than recomputing differently.
- "Any activity resets it": decide which events count as activity (what already touches `last_active_at`) and test that each one clears the state.
- Thresholds are literal: "three or more" is `>= 3`, "within X" is inclusive of the window edge; test just inside and just outside. "From at least two people" means distinct users.
- Windows may be relative to a configurable value (e.g. a board or account period); read it from the record, not a constant.
- "Wherever cards are shown": grep `app/views` for every card partial (previews, public previews, perma, notifications, JSON) and add the indicator to each; update fragment cache keys.
- New list filter: add the value to the filter's allowed list, map it to the scope, and make sure params round-trip (filter summary/labels/JSON if they enumerate values).
