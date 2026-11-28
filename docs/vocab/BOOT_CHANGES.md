# Boot Hamiltonians before and after, 2026-11-16

Dumped with `tests/vocab_boot_probe.gd` (every biome in `biomes.json`, its boot loadout built the way
`BiomeBuilder` builds it, H's lowest eigenvalues, the spectral gap the ending reads, and the boot
state's P(south) per qubit) on origin/main 13788d61 and on this branch. `||ΔH||` is the Frobenius
norm of H minus H with the 19 new words' physics stripped; with them stripped the probe reproduces
the before spectrum exactly in every biome.

**164 biomes. Loadouts (pairs and order) identical in all 164. Display names differ in 39 loadouts.**
**H changes in 7 biomes, every one of them because it booted a word that had no physics.** None of them
is a campaign biome.

| Biome | Loadout (after) | Gap before | Gap after | ‖ΔH‖ | ‖H‖ after | Lowest E before | Lowest E after | P(south) before | P(south) after |
|---|---|---:|---:|---:|---:|---|---|---|---|
| Flesh Architects | Tissue 🫀/🧬 · Suture 🩸/🧵 | 0.230 | 0.050 | 0.794 | 1.371 | -0.050, 0.180, 0.400, 0.630 | 0.014, 0.065, 0.446, 1.295 | 0.315, 0.671 | 0.321, 0.704 |
| Harbor | Channel 🛶/💧 · Irrigation 🪣/🌾 · Mooring ⚓/🪝 | 0.000 | 0.183 | 1.418 | 2.563 | -0.108, -0.108, 0.510, 0.510 | -0.079, 0.103, 0.351, 0.464 | 0.446, 0.970, 0.462 | 0.382, 0.606, 0.461 |
| QuayRooks | Mooring ⚓/🪝 · Cargo 🚢/💰 · Tally 🛶/📋 | 0.002 | 0.446 | 1.334 | 4.443 | -0.208, -0.206, -0.107, -0.105 | -0.631, -0.184, 0.219, 0.667 | 0.738, 0.352, 0.671 | 0.368, 0.691, 0.347 |
| ScrapYard | Leavings 🧤/🗑 · Ruin 🚧/🧱 | 0.000 | 0.310 | 0.510 | 1.170 | 0.220, 0.220, 0.530, 0.530 | 0.164, 0.474, 0.576, 0.886 | 0.030, 0.030 | 0.220, 0.030 |
| The Gilded Legacy | Ore 💎/⛏ | 0.000 | 0.427 | 0.439 | 0.439 | 0.000, 0.000 | 0.011, 0.439 | 0.970 | 0.504 |
| Volcanic Foundry | Kiln 🌫/✨ | 0.000 | 0.403 | 0.377 | 0.377 | 0.000, 0.000 | -0.027, 0.377 | 0.970 | 0.272 |
| VolcanicWorlds | Ash 🌫/🪨 · Ore 💎/⛏ | 0.000 | 0.397 | 0.797 | 1.017 | -0.262, -0.262, 0.162, 0.162 | -0.458, -0.061, 0.411, 0.808 | 0.832, 0.832 | 0.829, 0.401 |

A physics-less qubit adds nothing to H, so every level is doubled: the before gap is exactly 0
(or 2e-16) in VolcanicWorlds, ScrapYard, Harbor, The Gilded Legacy and Volcanic Foundry. Those
biomes would have satisfied any `biome_spectral_gap_lte` predicate for free; none is read by one.

## The campaign's biomes

Campaign biomes are the ones `Core/Campaign/campaign.json` names. Their loadouts and spectra are unchanged;
`tests/test_vocab_names_and_physics.py` pins the first six.

**TheDemos** (gap 1.5852 before and after). The player's home boots Subsistence 👥/🌾 alone. Unchanged.

**Village** (gap 0.2108 before and after). Boots Labor 👥/🍞, Hearth 🔥/❄, Capital 💰/⚙. Unchanged: none of the three was renamed or physics-less. The new Woodcutting 👥/🪓 (Hearth Keepers, a Village native) would couple to 🪵, 🔥 and 🍞 if a player planted it here, but the campaign never teaches it, so it cannot be planted in a campaign run.

**StarterForest** (gap 0.2064 before and after). Boots Pack, Raptor, Cycle, Solar, Humus. Unchanged. Swift Herd is native here and its Graze 🦌/🌿 and Flight 🐇/🌿 now have physics, but their atoms are claimed at boot by Pack, Raptor and Humus, so neither boots; they only matter if planted, and the campaign does not teach them.

**BloodLedger** (gap 0.9564 before and after). Boots Predation, Heritage, Nobility, Commerce. Unchanged.

**FreshwaterSpring** (gap 0.4573 before and after). Boots Elemental 🔥/💧 and the word now called Sprout 🫧/🌿 (was listed as Cycle). Physics unchanged.

**Woodlot** (gap 0.3041 before and after). Boots Burn and Succession. Unchanged.

Also named by the campaign, unchanged in H: GildedRot (gap 0.120), Lamplighters (gap 0.005), Lanternfall (gap 0.001), NullingChamber (gap 0.420), ShrineOfAshes (gap 1.120), ZenoLatch (gap 0.806). Name-only changes there: Lamplighters: Relay→Tower; Lanternfall: Signal→Fanfare; ShrineOfAshes: Aftermath→Vestige; ZenoLatch: Relay→Lamppost.
