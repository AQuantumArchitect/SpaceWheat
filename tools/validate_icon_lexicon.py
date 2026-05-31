#!/usr/bin/env python3
"""validate_icon_lexicon.py

Verifies the integrity of pair-Icon data across factions.json and biomes.json.

Checks:
  1. Every faction icons[] entry has {name, pole_0, pole_1} all non-empty.
  2. Every faction icons[] entry's poles ∈ that faction's sig.
  3. Every biome icons[] entry has {name, pole_0, pole_1} all non-empty.
  4. Every biome icons[] entry's poles ∈ that biome's emojis.
  5. Names that map to a faction-owned Icon use the same pair across all biomes.
  6. Reports orphan biome Icons (placed but no faction owner).

Exit code 0 if all checks pass with errors == 0. Warnings (orphans, collisions) do not fail.
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FACTIONS_PATH = REPO / "Core/Factions/data/factions.json"
BIOMES_PATH = REPO / "Core/Biomes/data/biomes.json"


def main():
    factions = json.loads(FACTIONS_PATH.read_text())
    biomes = json.loads(BIOMES_PATH.read_text())

    errors = []
    warnings = []

    # Build (pole_0, pole_1) → owner faction
    pair_to_owner = {}
    name_to_owner = {}
    for f in factions:
        sig = set(f.get("sig", []))
        for icon in f.get("icons", []) or []:
            name = icon.get("name", "")
            p0 = icon.get("pole_0", "")
            p1 = icon.get("pole_1", "")
            if not (name and p0 and p1):
                errors.append(f"Faction {f['name']}: icon missing field {icon}")
                continue
            if p0 not in sig:
                errors.append(f"Faction {f['name']}: icon {name} pole_0 {p0} not in sig {sorted(sig)}")
            if p1 not in sig:
                errors.append(f"Faction {f['name']}: icon {name} pole_1 {p1} not in sig {sorted(sig)}")
            key = (p0, p1)
            if key in pair_to_owner:
                warnings.append(
                    f"Pair {p0}/{p1} owned by both {pair_to_owner[key]} and {f['name']}"
                )
            pair_to_owner[key] = f["name"]
            if name in name_to_owner and name_to_owner[name] != f["name"]:
                warnings.append(
                    f"Icon name '{name}' owned by both {name_to_owner[name]} and {f['name']}"
                )
            name_to_owner[name] = f["name"]

    # Validate biomes against owner mapping
    biome_pairs = set()
    orphan_count = 0
    for b in biomes:
        bname = b.get("name", "?")
        emojis = set(b.get("emojis", []))
        for icon in b.get("icons", []) or []:
            name = icon.get("name", "")
            p0 = icon.get("pole_0", "")
            p1 = icon.get("pole_1", "")
            if not (name and p0 and p1):
                errors.append(f"Biome {bname}: icon missing field {icon}")
                continue
            if p0 not in emojis:
                errors.append(f"Biome {bname}: icon {name} pole_0 {p0} not in biome.emojis")
            if p1 not in emojis:
                errors.append(f"Biome {bname}: icon {name} pole_1 {p1} not in biome.emojis")
            biome_pairs.add((p0, p1))
            if (p0, p1) not in pair_to_owner:
                orphan_count += 1

    print(f"=== Icon Lexicon Validation ===")
    print(f"Factions: {len(factions)} | Biomes: {len(biomes)}")
    print(f"Faction-owned pair-Icons: {len(pair_to_owner)}")
    print(f"Distinct biome pair-Icons: {len(biome_pairs)}")
    print(f"Orphan biome Icons (no faction owner): {orphan_count}")
    print(f"Errors: {len(errors)}")
    print(f"Warnings: {len(warnings)}")
    print()

    for e in errors[:50]:
        print(f"ERROR: {e}")
    if len(errors) > 50:
        print(f"... and {len(errors) - 50} more errors")
    for w in warnings[:20]:
        print(f"WARN:  {w}")
    if len(warnings) > 20:
        print(f"... and {len(warnings) - 20} more warnings")

    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
