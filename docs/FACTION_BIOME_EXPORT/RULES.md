# Schema + Numeric Rules

## Faction-biome JSON schema

Every entry in `Core/Biomes/data/faction_biomes.json` must have:

```json
{
  "name": "FactionNameNoSpaces",      // also the display name; no spaces, PascalCase
  "kind": "faction_biome",            // tag — distinguishes from regular biomes
  "faction": "Faction Display Name",  // exact match to FactionDatabaseV2.gd "name"
  "description": "1-2 sentence description of the embodied territory.",
  "image_path": "res://Assets/Biomes/<existing>.png",  // reuse a regular biome image OR add new
  "music_path": "res://Assets/Audio/Music/<existing>.mp3",
  "discovered": false,                 // factions discovered through gameplay; experiment biomes use true
  "plot_layout": [{"x": 0.4, "y": 0.4}, ...],   // 2-5 plot positions; mirror sig count rough
  "emojis": ["🔥", "❄", ...],         // exactly the faction's sig array, normalized (no VS16)
  "native_factions": ["Faction Display Name"],  // single-element list
  "tags": ["faction_biome", "<domain_lower>", "<ring>"],
  "atom_components": { ... },          // see Lindblad rules below
  "icons": [                          // pairings, ordered to match emojis array
    {"name": "AxisName1", "pole_0": "🔥", "pole_1": "❄"},
    ...
  ],
  "visual_config": {
    "color": [r, g, b, a],            // 0..1 floats
    "label": "Faction Display Name"
  }
}
```

## Hamiltonian profile (`<f>.jsonl`) format

One JSON object per line. Two operations: `set` writes a value, `add` increments. Always use `set` for authored profiles.

```jsonl
# Comments lines start with #
# Self-energies (diagonal Hamiltonian — bias toward one pole)
{"op":"set","path":"self_energies.🔥","value":0.80}
{"op":"set","path":"self_energies.❄","value":-0.60}

# Drivers (oscillating self-energy modulation — gives the biome rhythm)
{"op":"set","path":"drivers.🔥.type","value":"cosine"}
{"op":"set","path":"drivers.🔥.frequency","value":0.0667}    # Hz; 0.0667 = 15s sim period
{"op":"set","path":"drivers.🔥.phase","value":0.0}
{"op":"set","path":"drivers.🔥.amplitude","value":1.0}

# Rabi couplings (off-diagonal Hamiltonian — pairs swap population)
{"op":"set","path":"couplings.🔥.❄","value":0.800}
{"op":"set","path":"couplings.❄.🔥","value":0.800}            # always specify both directions

# Cross-axis couplings (production chain Hamiltonian)
{"op":"set","path":"couplings.🔥.🍞","value":0.400}            # fire → bread (one-way is fine)
```

## Numeric ceilings

| Quantity | Range | Notes |
|---|---|---|
| Self-energy | ±0.05 to ±0.80 | Asymmetric pairs (e.g. 0.80/−0.60) are common — gives the biome a "preferred pole" |
| Rabi coupling (within axis) | 0.300 to 0.800 | The intrinsic dynamics of the qubit |
| Cross-axis coupling | 0.100 to 0.400 | Ties qubits together — production chain |
| Driver frequency | 0.020 to 0.10 Hz | Sim-time Hz; 0.0667 = 15s, 0.05 = 20s, 0.025 = 40s |
| Driver amplitude | 0.4 to 1.0 | Multiplied onto self-energy |
| **Lindblad decay rate** | **0.01 to 0.20** | Slow timescale; 0.20 is heavy side |
| **Lindblad incoming/outgoing rate** | **0.01 to 0.20** | Same regime |
| **Lindblad gated_lindblad_source rate** | **0.10 to 0.20** | Faction-biomes use the heavy side; regular biomes can sit lower |
| Gated power | 1 or 2 | 1 = linear gate, 2 = quadratic threshold |

**Lindblad ceiling enforcement**: any rate ≥ 1.0 will be flagged as a balancing bug. Stay safely below.

## Lindbladian (atom_components) shape

```json
"atom_components": {
  "🔥": {
    "decay": {"rate": 0.18, "target": "❄"},               // 🔥 leaks → ❄ at rate 0.18
    "lindblad_outgoing": {"💨": 0.05},                    // 🔥 also leaks → 💨 at rate 0.05
    "lindblad_incoming": {"🗑": 0.03}                     // 🔥 receives mass from 🗑 at 0.03 (rare)
  },
  "🍞": {
    "gated_lindblad_source": [
      {"target": "🔥", "gate": "🔥", "rate": 0.20, "power": 2, "inverse": false},
      {"target": "💨", "gate": "💨", "rate": 0.15, "power": 1, "inverse": false}
    ]
  }
}
```

- `decay`: single target, single rate. Source emoji loses to target.
- `lindblad_outgoing`: dict of `target: rate` pairs.
- `lindblad_incoming`: dict of `source: rate` pairs (this emoji *gains* from those sources).
- `gated_lindblad_source`: array of objects. Each adds a manufacturing pump on the source emoji conditioned on the gate.

Most faction-biomes will only need 2–4 entries. Don't author more than ~6 Lindblad sites — sparsity is good.

## Authoring checklist

Before submitting a faction-biome:

- [ ] `name` matches the JSONL filename (PascalCase JSON ↔ lowercase JSONL).
- [ ] `faction` field exactly matches `FactionDatabaseV2.gd` faction name.
- [ ] `emojis` array is the faction's complete `sig` (no extras, no missing).
- [ ] All `couplings.A.B` have a matching `couplings.B.A` for Rabi pairs (within-axis).
- [ ] All emojis used in atom_components / icons / couplings appear in the faction's `sig`.
- [ ] Every Lindblad rate is in `[0.01, 0.20]`.
- [ ] Every Hamiltonian self-energy is in `[-0.80, 0.80]`.
- [ ] Lindblad-effect strength is ≥10× weaker than the dominant Hamiltonian coupling on each axis.
- [ ] Pairing reflects the natural oppositions in the faction's character (look at the motto and description).
- [ ] At least one cross-axis coupling exists if the faction is a "producer" (has a clear input → output chain).
