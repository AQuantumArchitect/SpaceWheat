#!/usr/bin/env python3
"""mutate_fungalnetworks_and_gate.py — wire the wet×night AND gate.

Adds a gated_lindblad_source on 🌧 targeting 🦠, gated by 🌙:
  extra flow into 🦠 = 1.5 · ρ(🌙) · ρ(🌧)

With 🌙 ≈ 0.17 and 🌧 ≈ 0.07 (baseline steady state), this gate contributes
~0.018 per unit time vs the unconditional 0.06·ρ(🌧) ≈ 0.004 — roughly 4× the
baseline, so the gated channel is the dominant bacteria pump at night.

Physically: rain soaks the substrate and the moon activates the hyphal
signalling network, together triggering a microbial bloom. Neither alone is
nearly as effective.

Wild/calm toggle semantics:
  Wild  (🌧 ↑) — AND gate active, bloom driven by weather + lunar cycle;
                  nonlinear, sensitive to sky state, history-dependent.
  Calm  (🧫 ↑) — rain atom depleted; only the existing linear H-coupling
                  between 🦠↔🧫 (Mossline/Locusts) drives bacteria; smooth,
                  predictable, substrate-controlled.

The toggle is a kick, not a latch — player mission territory to make it hold.
"""
from __future__ import annotations
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import biome_io  # noqa: E402


AND_GATE = {"target": "🦠", "gate": "🌙", "rate": 1.5, "power": 1}


def main() -> int:
    biomes = biome_io.load_biomes()  # raw read — mutate scripts never normalize
    for b in biomes:
        if b["name"] != "FungalNetworks":
            continue
        rain = b["atom_components"]["🌧"]
        rain.setdefault("gated_lindblad_source", [])
        if AND_GATE not in rain["gated_lindblad_source"]:
            rain["gated_lindblad_source"].append(AND_GATE)
        break
    else:
        print("FungalNetworks not found")
        return 1

    biome_io.save_biomes(biomes)
    print("patched: 🌧×🌙 → 🦠 AND gate wired")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
