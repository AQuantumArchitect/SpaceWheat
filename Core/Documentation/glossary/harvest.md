---
term: harvest
short_def: Cashing a collapsed outcome for resources — reward = surprisal, ×4 if known.
related: [measurement, incorporation, population]
since: 2026-07-17
status: canonical
---

**Harvest** is the payout half of the measure/harvest pair: `Q = Extract` on a frozen
(already-collapsed) register converts its outcome into resources
(`ProbeActions`, `Core/Actions/ProbeActions.gd`). It is free to perform — the cost was
already paid at [measurement](measurement.md) (`R = Strike`, which costs 👥).

The payout is the surprisal of the outcome you collapsed to:
`reward = −kT · log p` (`EnergyPricing.surprisal_energy`, `Core/Markets/EnergyPricing.gd`)
— a rare outcome (low `p`) pays more than a common one, because you learned more.
`kT` is the biome's market temperature.

If the harvested icon is already in your signature (see [incorporation](incorporation.md)),
the payout is scaled by an **incorporation bonus** — up to `×4` flat in the closed
system (`ProbeActions._incorporation_reward_multiplier`). Resources you have never
incorporated pay the bare surprisal floor. **Resources come from harvest/the market;
icons come from incorporation** — the two economies never substitute for each other.

`Reap` (Ace hat, `Shift+F`) is harvest at scale: it fast-forwards the biome, then
Born-samples and collapses every live register at once for a seasonal payout, priced by
the same law.
