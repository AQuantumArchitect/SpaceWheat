---
term: standing
short_def: A six-channel reputation edge between the player and one faction.
related: [faction, soft_gate]
since: 2026-07-17
status: canonical
---

**Standing** is a per-faction reputation record with six independent channels
(`FactionStanding`, `Core/Factions/FactionStanding.gd`), each an unbounded float
defaulting to `0.0`:

- **trust** — interpersonal/transactional goodwill, raised by completed contracts.
- **debt** — what you owe; subtracts from the legacy aggregate.
- **attention** — how closely you're watched; amplifies the consequence of future acts.
- **access** — doors literally opened (biome/teaching gates read this channel).
- **legitimacy** — structural standing, distinct from trust.
- **entanglement** — a complication edge; can read as friendly or hostile.

Story predicates gate on one named channel: `standing_gte {faction, channel, value}` is
a [soft gate](soft_gate.md) — center = the authored `value`, width = the predicate's
`width` field if present, else 0.05 (`QuestManager.PREDICATE_SOFT_WIDTH`,
`_pred_width`). Firing needs the channel to clear the value by roughly one width past
center, not merely touch it once (`predicate_fire_target` reports the real number).

Nothing but completed contracts and story beats move standing — there is no panel to
spend it against; v0 tracks it only (`project_standing_tracked_only`).

The X-panel standing table (`ControlsOverlay._render_faction_standings_grid`) renders
seven columns — `trst dbt attn acc leg ent sig` — because it appends an eighth,
non-channel field after the six: **sig** is `sig_known/sig_total`, how much of that
faction's icon [signature](signature.md) you've [incorporated](incorporation.md) so
far. It is vocabulary progress, not a reputation channel — `FactionStanding` itself
still has exactly six fields. The Spotlight "standing" scalar shown beside a speaking
faction (`ControlsOverlay`, the chatter-bubble kv-row) is a *different* single number:
`FactionStanding.scalar()`, the legacy aggregate `clamp((trust − debt + access +
legitimacy) · 0.25, −1, 1)` — one float that folds four of the six channels together
for a quick read, not a seventh channel of its own.
