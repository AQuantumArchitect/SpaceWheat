#!/usr/bin/env python3
"""set_starter_island.py — set the 6-biome starter island as the active lab.

Marks exactly the starter-island set as discovered=True; all others False.
Re-run to reset to the canonical lab state.

Starter island:
  StarterForest   — forest ecosystem, transport/localization demo
  Woodlot         — managed timber, forest edge
  PastoralCommons — meadow, stable polyculture
  WeaversLoft     — textile craft, binding cycle
  Village         — hearth + commerce (hearth currently broken — todo)
  BioticFlux      — ecological margin, pure-H (L todo)
"""
from __future__ import annotations
import json
from pathlib import Path

ISLAND = {
    "StarterForest",
    "Woodlot",
    "PastoralCommons",
    "WeaversLoft",
    "Village",
    "BioticFlux",
}


def main() -> int:
    path = Path(__file__).resolve().parent.parent / "Core/Biomes/data/biomes.json"
    biomes = json.load(path.open())
    turned_on, turned_off = [], []
    for b in biomes:
        want = b["name"] in ISLAND
        was  = b.get("discovered", False)
        b["discovered"] = want
        if want and not was:
            turned_on.append(b["name"])
        elif not want and was:
            turned_off.append(b["name"])
    json.dump(biomes, path.open("w"), indent=2, ensure_ascii=False)
    if turned_on:
        print(f"  discovered ON :  {sorted(turned_on)}")
    if turned_off:
        print(f"  discovered OFF:  {sorted(turned_off)}")
    if not turned_on and not turned_off:
        print("  (no change — already set)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
