#!/usr/bin/env python3
"""mutate_fungalnetworks.py — fix odd-emoji-count + plant rain as a pump.

Adds 🌧 (10th emoji) and re-pairs into 5 named axes that read as physics:
  Insect     🦗|🐜    (Locusts H couples them, ~0.6)
  Kingdom    🍄|🦠    (no direct H — pure observable: fungus vs microbe)
  Decompose  🍂|💀    (Mycelial Web's chiral edges live here)
  Sky        🌙|☀    (basis labels; faction H drives 🌙→🍄 strongly)
  Bath       🌧|🧫    (two pumps for 🦠: chaotic rain vs controlled dish)

🌧 wires as a moisture pump targeting 🦠 (strong) and 🍄 (weak), with its own
🗑 source so it has a population to drive things with. The Bath axis becomes
the natural "wild vs calm" toggle qubit (see follow-up: applying X here swaps
which pump is dominant).
"""
from __future__ import annotations
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import biome_io  # noqa: E402


NEW_EMOJIS = ["🦗", "🐜", "🍄", "🦠", "🍂", "💀", "🌙", "☀", "🌧", "🧫"]
NEW_ICONS = [
    {"name": "Insect",    "pole_0": "🦗", "pole_1": "🐜"},
    {"name": "Kingdom",   "pole_0": "🍄", "pole_1": "🦠"},
    {"name": "Decompose", "pole_0": "🍂", "pole_1": "💀"},
    {"name": "Sky",       "pole_0": "🌙", "pole_1": "☀"},
    {"name": "Bath",      "pole_0": "🌧", "pole_1": "🧫"},
]

RAIN_ATOM = {
    "lindblad_incoming": {"🗑": 0.4},
    "lindblad_outgoing": {"🦠": 0.06, "🍄": 0.02},
}


def main() -> int:
    biomes = biome_io.load_biomes()  # raw read — mutate scripts never normalize
    for b in biomes:
        if b["name"] != "FungalNetworks":
            continue
        b["emojis"] = NEW_EMOJIS
        b["icons"] = NEW_ICONS
        b["atom_components"]["🌧"] = RAIN_ATOM

        ems = b["emojis"]
        assert len(ems) % 2 == 0, "even-count violated"
        assert len(ems) == len(set(ems)), "dupes in emojis"
        for i in range(0, len(ems), 2):
            assert ems[i] != ems[i+1], f"pair {i//2} self-collides"
        break
    else:
        print("FungalNetworks not found")
        return 1

    biome_io.save_biomes(biomes)
    print("patched FungalNetworks (9 → 10 emojis, +🌧)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
