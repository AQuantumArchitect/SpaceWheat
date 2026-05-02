# Faction-Biome Export Package — for the 90-faction bot pass

You are authoring **per-faction biomes** (Flavor 2 architecture) for SpaceWheat. Each faction in `factions.json` becomes a biome with its complete signature emojis as quantum axes plus hand-crafted Lindbladian dissipation that represents how the faction interacts with the market.

## What you're producing

For each faction `<F>`, two artifacts:

1. **One JSON entry** appended to `Core/Biomes/data/faction_biomes.json` (sibling of the main `biomes.json`). Schema matches the reference at `reference/HearthKeepers.biome.json`.
2. **One JSONL profile** at `Core/Config/Hamiltonians/<f>.jsonl` (lowercase, no spaces). Schema matches `reference/hearthkeepers.jsonl`.

That's it. The existing `BiomeBuilder` machinery picks them up automatically.

## Hard rules

- **Separation**: factions only state Hamiltonians (icons + couplings, in `FactionDatabaseV2.gd`); biomes only state Lindbladians (atom_components in JSON). Faction-biomes are biomes, not factions, even though they're named for one.
- **Lindblad rate ceiling**: `0.10–0.20` heavy side. Rates above ~0.5 saturate gated terms; rates above ~1.0 break Euler integration (catastrophic-state warnings). Lean toward 0.15–0.20 for production-chain gated terms, 0.10–0.15 for slow decays.
- **Hamiltonian couplings**: typical range `0.3–0.8` for Rabi (off-diagonal), `±0.1–0.8` for self-energies. Rule of thumb: Hamiltonian effects must be ≥10× stronger than Lindblad effects on the same axis.
- **Pairings**: group the faction's signature emojis into north/south pairs sequentially `[s0,s1], [s2,s3], …`. Six emojis → 3 qubits. Use the natural opposition (cold/hot, void/full, decay/growth) when ordering.
- **Cross-axis bridges are the trade signal**. When a faction's emoji also appears in a regular biome but on a *different* qubit pairing, that mismatch is what the tensor market reads. See `tensor_experiment_results.md`.

## Files in this package

| File | Purpose |
|---|---|
| `README.md` | This file |
| `RULES.md` | Detailed schema + numeric rules + checklist |
| `factions.json` | All 88 faction definitions (name, domain, ring, bits, sig, motto, description) |
| `gated_lindblad_corpus.json` | 53 inspiration entries from existing biomes — patterns to draw from |
| `tensor_experiment_results.md` | What the V⊗HK lab learned about tensor markets |
| `reference/HearthKeepers.biome.json` | Reference faction-biome JSON entry |
| `reference/hearthkeepers.jsonl` | Reference Hamiltonian profile |

## Workflow

1. Read `RULES.md` — schema and numeric ceilings.
2. Read `tensor_experiment_results.md` — understand why cross-axis bridges matter.
3. For each faction in `factions.json`:
   - Inspect its `sig` emojis and `motto`/`description` for character cues.
   - Browse `gated_lindblad_corpus.json` for relevant production-chain patterns (e.g. a faction working with rot/decay → look at GildedRot's 🌹←🥀; a metalworking faction → see ScrapYard, AntimatterFoundry).
   - Author atom_components on the heavy 0.10–0.20 side.
   - Author the JSONL profile with self-energies, drivers (only if rhythm-bearing), Rabi couplings, and 1–3 cross-couplings tying the faction's production chain.
4. Skip factions that already exist in `biomes.json` as a regular biome — they don't need a faction-biome twin.

## What "gated_lindblad_source" means

A gated Lindblad source on emoji `S` at rate `r` with gate `G` and power `p` adds dissipation:
```
dρ_S/dt += r × (P_G^p) × (project_S - ρ_S)
```
i.e. emoji S is being *manufactured* whenever gate emoji G is populated. Use this for production chains: bread-from-fire, ash-from-burn, rot-from-rose. Power 1 is linear, power 2 is quadratic (sharper threshold).

`inverse: true` flips: dissipation strengthens when gate is *absent*. Used for "decay when X is missing".
