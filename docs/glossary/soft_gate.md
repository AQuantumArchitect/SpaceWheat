---
term: soft_gate
short_def: 0.5·(1+tanh((x−center)/width)) — the smooth step every quest threshold uses.
related: [width, measurement]
since: 2026-07-17
status: canonical
---

A **soft gate** replaces a hard `x >= threshold` boolean with a continuous score in
`[0, 1]`: `soft_gate(x, center, width) = 0.5·(1 + tanh((x − center) / width))`
(`QuestMath.soft_gate`, `Core/Quests/QuestMath.gd`). At `x = center` the score is
exactly `0.5` — **not** the firing point. A predicate's `value` in JSON is the soft
gate's `center`, not the value that actually completes it.

Multiple predicates on one quest/flag combine via `smooth_and` — the geometric mean of
their scores — so every thread must be high for the combined score to be high; no
single weak thread can be masked by strong ones elsewhere. A flag fires when its
combined score reaches `FLAG_FIRE_THRESHOLD = 0.85`.

Because `0.85 > 0.5`, a soft gate always needs `x` to clear `center` by roughly one
[width](width.md) (via `atanh`) before it actually fires — `QuestMath.fire_value`
computes that real target, and `QuestManager.predicate_fire_target` is the public
accessor the UI reads so displayed numbers never lie about the gap between "center" and
"fires."

Integer counts ("≥ 3 berries") use the `count_gate` variant instead — see
[width](width.md) — which shifts the center down so the stated integer is the true
firing point, not `center + width·atanh(...)`.

"At most" predicates (`_lte` suffix, `dynamics_at_most`, `biome_spectral_gap_lte`, …)
use `soft_gate_inv`, the mirror-image falling step: score rises as `x` drops *below*
center.
