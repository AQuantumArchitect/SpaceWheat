---
term: width
short_def: The transition-zone size of a soft gate — how far past center it takes to fire.
related: [soft_gate]
since: 2026-07-17
status: canonical
---

**Width** is the second parameter of every [soft gate](soft_gate.md): it sets how wide
the `0 → 1` transition zone is around `center`. A narrow width makes the gate feel
almost like a hard threshold (score swings from near-0 to near-1 over a small range of
`x`); a wide width spreads partial credit over a broad range, so the progress bar moves
visibly long before the gate fires.

Defaults are per predicate-type (`QuestManager.PREDICATE_SOFT_WIDTH`), chosen by the
scale of what's being measured — the design rule
(`Core/Quests/QuestMath.gd` header comment):

- physics observables in `[0, 1]` (coherence, purity) → width ≈ **0.05**
- integer counts (berries, atoms, signature size) → width ≈ **1.5–2.0**
- accumulated phase/time → width ≈ **0.1**
- spectral gap (range `0–0.3`) → width ≈ **0.02–0.03**

Any predicate instance may override the type default with its own `"width"` field in
JSON — a single beat can fire crisply (small width, e.g. `first_breath`'s `0.4` on a
`[0,1]`-scale growth signal) without moving the shared default other flags of the same
type rely on (`QuestManager._pred_width`).

Width directly sets the gap between a soft gate's authored `value` and its real firing
point: `fire_value = center + width · atanh(2·0.85 − 1)`. A wider width means a bigger
gap — the quoted threshold undersells what the player actually has to reach.
