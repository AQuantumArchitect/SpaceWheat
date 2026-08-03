#!/usr/bin/env python3
"""mutate_biome_repair.py — fix odd-emoji-count biomes by adding one register
each, and re-order pairings so each qubit becomes a sharp named axis.

The "no duplicate emoji per biome" register-map rule (RegisterMap.gd:57) tripped
on every biome with an odd `emojis` count, because the pair-grouper falls back
to self-pairing the trailing emoji. Rather than pad with arbitrary glyphs, each
new emoji is chosen to extend the biome's existing physics:

  PastoralCommons  + 🐺   wires the predator the description names but lacks
  FreshwaterSpring + 🔥   completes the H₂O phase triangle (already external)
  Woodlot          + 🌱   closes the timber regrowth loop (already external)
  MothGarden       + 🌸   adds a Tilman shared-resource node beside the L-V cycle
  Lanternfall      + 🧂   salt = drug-runner contraband (lore axis at the docks)
  LaserGlint       + ✨   metastable upper level → 4-level laser

Pair order is also rebuilt so each qubit forms a meaningful named axis (the
biome's `icons[]` array). Earlier orderings had self-paired pairs like
{🏁,🏁} and {💥,💥} which would themselves trip the new assertion.
"""
from __future__ import annotations
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import biome_io  # noqa: E402


PATCHES = {
    "PastoralCommons": {
        "emojis": ["🐑","🐺","🐝","🌿","🥣","🫙","🤲","🌾"],
        "icons": [
            {"name": "Predation",   "pole_0": "🐑", "pole_1": "🐺"},
            {"name": "Pollination", "pole_0": "🐝", "pole_1": "🌿"},
            {"name": "Harvest",     "pole_0": "🥣", "pole_1": "🫙"},
            {"name": "Commons",     "pole_0": "🤲", "pole_1": "🌾"},
        ],
        "atom_additions": {
            "🐺": {
                "lindblad_incoming": {"🗑": 0.03, "🐑": 0.04},
                "decay": {"rate": 0.05, "target": "🗑"},
            },
        },
    },

    "FreshwaterSpring": {
        "emojis": ["🧊","🔥","💧","🌊","🫧","🌿"],
        "icons": [
            {"name": "Phase", "pole_0": "🧊", "pole_1": "🔥"},
            {"name": "Scale", "pole_0": "💧", "pole_1": "🌊"},
            {"name": "Cycle", "pole_0": "🫧", "pole_1": "🌿"},
        ],
        "atom_additions": {
            "🔥": {
                "lindblad_outgoing": {"💧": 0.04},
                "decay": {"rate": 0.06, "target": "🗑"},
            },
        },
    },

    "Woodlot": {
        "emojis": ["🌲","🌱","🪓","🪵","🔥","🍂"],
        "icons": [
            {"name": "Lifestage",   "pole_0": "🌲", "pole_1": "🌱"},
            {"name": "Labor",       "pole_0": "🪓", "pole_1": "🪵"},
            {"name": "Decompose",   "pole_0": "🔥", "pole_1": "🍂"},
        ],
        "atom_additions": {
            "🌱": {
                "lindblad_outgoing": {"🌲": 0.03},
                "decay": {"rate": 0.01, "target": "🗑"},
            },
        },
    },

    "MothGarden": {
        "emojis": ["🦋","🌸","🕷","🐛"],
        "icons": [
            {"name": "Mutualism", "pole_0": "🦋", "pole_1": "🌸"},
            {"name": "Predation", "pole_0": "🕷", "pole_1": "🐛"},
        ],
        "atom_additions": {
            "🌸": {
                "lindblad_incoming": {"🗑": 0.4},
                "lindblad_outgoing": {"🦋": 0.05, "🐛": 0.05},
            },
        },
    },

    "Lanternfall": {
        "emojis": ["🌉","🪔","📯","🗼","🏁","🧂"],
        "icons": [
            {"name": "Crossing",   "pole_0": "🌉", "pole_1": "🪔"},
            {"name": "Relay",      "pole_0": "📯", "pole_1": "🗼"},
            {"name": "Contraband", "pole_0": "🏁", "pole_1": "🧂"},
        ],
        # Lamplighters faction H is unchanged → SSH chain physics preserved.
        # 🧂 is dynamically isolated; it lives in the register so the lore
        # (salt-runners working the docks) has a real population to read.
        "atom_additions": {
            "🧂": {
                "lindblad_incoming": {"🗑": 0.02},
                "decay": {"rate": 0.04, "target": "🗑"},
            },
        },
    },

    "LaserGlint": {
        "emojis": ["💥","🌟","✨","🌈"],
        "icons": [
            {"name": "Inversion", "pole_0": "💥", "pole_1": "🌟"},
            {"name": "Lasing",    "pole_0": "✨", "pole_1": "🌈"},
        ],
        # ✨ as the metastable upper laser level: slow drain to 🌈.
        # The existing 💥→🌈 fast cascade is left intact so the 3-level demo
        # still passes; ✨ adds a parallel slow channel that builds population
        # — the textbook 4-level architecture, additively layered.
        "atom_additions": {
            "✨": {
                "lindblad_incoming": {"💥": 0.3},
                "lindblad_outgoing": {"🌈": 0.15},
            },
        },
    },
}


def main() -> int:
    biomes = biome_io.load_biomes()  # raw read — mutate scripts never normalize

    seen = set()
    for b in biomes:
        name = b.get("name")
        if name not in PATCHES:
            continue
        patch = PATCHES[name]

        b["emojis"] = patch["emojis"]
        b["icons"] = patch["icons"]

        ac = b.setdefault("atom_components", {})
        for atom, spec in patch["atom_additions"].items():
            ac[atom] = spec

        # sanity: pair-grouper invariant
        ems = patch["emojis"]
        assert len(ems) % 2 == 0, f"{name}: even-count violated"
        assert len(ems) == len(set(ems)), f"{name}: dupes in emojis"
        for i in range(0, len(ems), 2):
            assert ems[i] != ems[i+1], f"{name}: pair {i//2} self-collides"

        seen.add(name)

    missing = set(PATCHES) - seen
    if missing:
        print(f"WARN: not found: {sorted(missing)}")
        return 1

    biome_io.save_biomes(biomes)
    print(f"patched {sorted(seen)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
