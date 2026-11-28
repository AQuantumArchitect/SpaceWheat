---
term: harvest
short_def: Gathering a banked strike yield, scaled by the vocabulary tier.
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

The vocabulary tier (`ProbeActions.vocabulary_tier`) scales the payout in every
biome. A known word pays **×6**. A plot that only shares an emoji pays **×2**.
Other plots pay **×1**. Your payout vocabulary includes your home biome's words
and the words you've taken through [incorporation](incorporation.md).

`Reap` (Ace hat, `Shift+F`) is harvest at scale: it fast-forwards the biome, then
Born-samples and collapses every live register at once for a seasonal payout, priced by
the same law.
