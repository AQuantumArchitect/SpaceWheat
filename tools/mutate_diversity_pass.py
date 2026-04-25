#!/usr/bin/env python3
"""mutate_diversity_pass.py — Wire FungalNetworks (gradient memory) and
StarterForest (Anderson-localization-tasted transport) into biomes.json.

Surgical mutation: only `atom_components` is rewritten on these two biomes.
All other biome fields are preserved bit-for-bit.

FungalNetworks: 3 independent autocatalytic latches on 🍄, 🦠, 🐜. Each has
its own reservoir (🍂 → 🍄, 🧫 → 🦠, 🦗 → 🐜) with linear self-decay so the
latches don't compete for the global saturation budget. Should give up to 8
distinct steady states — true gradient memory.

StarterForest: source pump on 🌲 (forest interior) and far drain on 🐇
(prey), with the faction-supplied H acting as the disordered hopping
network across the 11 emojis. Steady-state shows whether a wavepacket can
traverse the chain (transport) or piles up near the source (localization).
"""
from __future__ import annotations
import json
import sys
from pathlib import Path


FUNGAL_ATOM_COMPONENTS = {
    # Three independent latches. Reservoir/carrier pairs are chosen to have
    # ZERO direct Hamiltonian coupling from native factions, so the H mixing
    # doesn't wash out the gated bistability mechanism. Each reservoir has
    # its own linear self-decay so the latches don't compete for the global
    # saturation budget — that's what makes this a gradient memory.

    # ── Latch A: 🍂 → 🍄 (litter feeds the mushroom — canonical fungal lore) ──
    "🍄": {
        "decay": {"rate": 0.3, "target": "🌱"},
    },
    "🍂": {
        "lindblad_incoming": {"🗑": 2.0},
        "decay": {"rate": 0.4, "target": "🗑"},
        "gated_lindblad_source": [
            {"target": "🍄", "gate": "🍄", "rate": 250.0, "power": 2}
        ],
    },

    # ── Latch B: ☀ → 🦠 (sunlight bath; microbial bloom self-amplifies) ──
    "🦠": {
        "decay": {"rate": 0.3, "target": "💀"},
    },
    "☀": {
        "lindblad_incoming": {"🗑": 2.0},
        "decay": {"rate": 0.4, "target": "🌙"},
        "gated_lindblad_source": [
            {"target": "🦠", "gate": "🦠", "rate": 250.0, "power": 2}
        ],
    },

    # ── Latch C: 🌙 → 🐜 (night patrol; colony self-amplifies) ──
    "🐜": {
        "decay": {"rate": 0.3, "target": "🗑"},
    },
    "🌙": {
        "lindblad_incoming": {"🗑": 2.0},
        "decay": {"rate": 0.4, "target": "☀"},
        "gated_lindblad_source": [
            {"target": "🐜", "gate": "🐜", "rate": 250.0, "power": 2}
        ],
    },

    # ── Background: rot loop (small dissipative flow, not a latch) ──
    "💀": {
        "lindblad_incoming": {"🦠": 0.04},
        "decay": {"rate": 0.02, "target": "🍂"},   # rot returns to leaf litter
    },
    # 🦗, 🧫 left unwired — the wandering insects + dish are inert sites here.
}


STARTER_FOREST_ATOM_COMPONENTS = {
    # ── Source pump: 🌲 (forest interior, far from 🐇) ──
    "🌲": {
        "lindblad_incoming": {"🗑": 0.30},
    },

    # ── Sink: 🐇 (prey at the chain's far end) drains to outside ──
    "🐇": {
        "decay": {"rate": 0.25, "target": "🗑"},
    },

    # ── Mid-chain housekeeping (light decays so no atom saturates) ──
    "🦅": {"decay": {"rate": 0.05, "target": "🐇"}},     # raptor → prey
    "🐺": {"decay": {"rate": 0.04, "target": "🦌"}},     # pack → herd
    "🦌": {"decay": {"rate": 0.03, "target": "🌿"}},     # herd grazes
    "🌿": {"decay": {"rate": 0.04, "target": "🍂"}},     # ground cover → litter
    "🍂": {"decay": {"rate": 0.05, "target": "🌱"}},     # litter → seed
    "🌱": {"decay": {"rate": 0.04, "target": "🌲"}},     # seed → tree (closes loop)

    # ── Mushroom is the disorder probe: existing autocatalytic decay kept ──
    "🍄": {
        "lindblad_incoming": {"🍂": 0.015, "💀": 0.01},
        "decay": {"rate": 0.15, "target": "🌱"},
    },

    # ── Day/night drift (slow background) ──
    "☀": {"lindblad_outgoing": {"🌙": 0.05}},
    "🌙": {"lindblad_outgoing": {"☀": 0.05}},
}


def main() -> int:
    path = Path(__file__).resolve().parent.parent / "Core/Biomes/data/biomes.json"
    biomes = json.load(path.open())

    # FungalNetworks gradient memory was attempted but its dense faction-H
    # mixing (every reservoir/carrier pair has coupling ≥ 0.5 from native
    # factions) suppresses gated bistability — best parameter-sweep score
    # hit only 0.13 for a single latch. Left at original ecology; the
    # Anderson-style transport biome is the keeper of this pass.
    targets = {
        "StarterForest": STARTER_FOREST_ATOM_COMPONENTS,
    }
    seen = set()
    for b in biomes:
        if b["name"] in targets:
            b["atom_components"] = targets[b["name"]]
            seen.add(b["name"])
    missing = set(targets) - seen
    if missing:
        print(f"WARN: not found in biomes.json: {sorted(missing)}", file=sys.stderr)

    json.dump(biomes, path.open("w"), indent=2, ensure_ascii=False)
    print(f"mutated {sorted(seen)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
