# Marked for Death — slop misaligned with current vision

Generated 2026-04-28 after Village ⊗ HearthKeepers tensor market experiment.
Last updated 2026-04-28 after Phase VII cleanup pass.

## Current vision (locked)

- **Factions** only state Hamiltonians (icons + couplings).
- **Biomes** only state Lindbladians (atom_components: decay, incoming, outgoing, gated_lindblad_source).
- **Faction-biomes** are normal biomes named after a faction, using its full signature emojis and hand-crafted Lindbladian rates on the heavy side of `0.1–0.2`.
- **Affinity** is a relationship map only (Phase V kernel).
- **Markets** are tensor products `Biome_A ⊗ Biome_B` priced via paired marginals + cross-axis tension.
- **Currency** is commodity-to-commodity. No hub.

---

## Done

### ✅ §1 — Outlier gated_lindblad_source rates
Verified clean in `biomes.json`. The 100× typo rates (SporeLibrary, MagneticAnomaly, ColdLab,
MothGarden, ShrineOfAshes, MnemonicHive, OrbitalStrike, GildedRot, TwofacedTide, BrittleDawn)
no longer appear. Village 25.0 rates are intentional gated power-2 drains.

### ✅ §2 — Faction-side Lindbladian dead code
Removed from Faction.gd (var declarations, validation, get_icon_contribution keys, to_dict,
load_from_dict), IconBuilder.gd (both build-path accumulators, gated_lindblad set_meta, debug
prints), QuestRewards.gd (production_bias — was always 1.0).

### ✅ §3 — Currency hub `💰` placeholder
Already resolved before this pass: Contract.gd has cost_emoji + cost_amount; MarketLattice never
had price_currency. Commodity-to-commodity is live.

### ✅ §4 — complete_quest resource rewards → MarketLattice.exercise
complete_quest now calls MarketLattice.synthesize_and_exercise() for the resource reward
(substrate-derived 1/p × QC_RATIO). Falls back to QuestRewards fixed path if no live biome
qubit. Vocabulary and standing deltas still go through their own paths.

### ✅ §5 — Deprecated Hamiltonian affinity constants
PLAYER_AFFINITY_LEARN_THETA and PLAYER_AFFINITY_SETTLEMENT_RATE deleted.
_pump_for_icon affinity rotation and _apply_settlement_rotation now call
MarketLattice.synthesize_and_exercise — substrate-derived θ via distribute_settlement_theta.
ICON_PUMP_OWNER_RATE and ICON_PUMP_SHARED_RATE kept (FDM mass injection, not affinity).

### ✅ §6 — Deleted biome wrappers
FibonacciAdversary, BiomeFactory, BioticFluxBiome, DataDrivenBiome, FungalNetworksBiome,
QuantumOrganism, StarterForestBiome, StellarForgesBiome, VillageBiome, VolcanicWorldsBiome
(+ .uid files) committed out of the tree.

---

## Still live

### 1. ToolConfig GROUP→FRAME shims — 90% migrated

Legacy int-keyed API shims exist in ToolConfig.gd (select_group, get_current_group, etc.).
One remaining caller chain:

```
UI/Core/QuantumInstrumentInput.gd  get_current_tool_group() → ToolConfig.get_current_group()
UI/Core/FarmSurface.gd             _sync_from_tool_group() reads int group
```

All other shim methods (select_group, get_group, does_group_pause_sim, get_group_name) are
unused. Safe to delete the dead shims; migrate FarmSurface to frame API; then retire
get_current_group and the FRAME_TO_GROUP / GROUP_TO_FRAME dicts.

### 2. test_submenu_integration.gd — broken preload

```
tests/test_submenu_integration.gd:7   preload("res://UI/Core/Submenus/VocabInjectionSubmenu.gd")
```

VocabInjectionSubmenu.gd was deleted; IconInjectionSubmenu.gd replaced it. Test will fail at
preload time. Fix: update the preload + call sites to IconInjectionSubmenu.

### 3. Orphan .uid files in Tests/

173 .uid files remain for deleted .gd test files. No functional impact (engine ignores orphan
UIDs for missing scripts), but they're noise. Safe batch-delete.

---

## Not slop (stable — do not touch)

- `BiomeRegistry` two-file load (biomes.json + faction_biomes.json) — clean, used.
- `BiomeBuilder.build_from_spec` accepts both Biome objects and Dictionaries — used by tensor lab.
- Lindbladian rate ceiling for faction-biomes: `0.1–0.2` (heavy side of biome range).
- HearthKeepers as Flavor-2 reference faction-biome — passes; rates: `0.20 / 0.18 / 0.20 / 0.15`.
- ContractMarket.gd — bid generation via native QuantumContractEngine; MarketLattice handles
  exercise/reward. Different jobs, both live.
- ICON_PUMP_OWNER_RATE / ICON_PUMP_SHARED_RATE — FDM mass injection, not affinity. Keep.
