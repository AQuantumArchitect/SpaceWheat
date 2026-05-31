#!/usr/bin/env python3
"""validate_faction_bits.py

Soft audit of the 12-bit axial encoding in factions.json.

Reads:
  - Core/Factions/data/axes.json (12 axes: name, key, pole_0, pole_1, label_0, label_1, description)
  - Core/Factions/data/factions.json (faction list with bits and description)

Checks (warnings only, exit 0 if no hard errors):
  1. Every faction has exactly 12 bits.
  2. Bits are 0/1 (not other values).
  3. If faction.description contains a left-pole keyword (label_0, lowercased)
     for axis i, the corresponding bit should be 0; if it contains a right-pole
     keyword, bit should be 1. Logged as WARN; does not fail.
  4. If sig contains a pole emoji of an axis, that's flagged informationally
     (overlap with axis substrate; expected, just shown).

Hard errors (exit 1):
  - Cannot read either JSON file
  - Bits malformed (size != 12 or non-0/1 values)
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
AXES_PATH = REPO / "Core/Factions/data/axes.json"
FACTIONS_PATH = REPO / "Core/Factions/data/factions.json"


def main() -> int:
    if not AXES_PATH.exists():
        print(f"ERROR: axes.json not found at {AXES_PATH}")
        return 1
    if not FACTIONS_PATH.exists():
        print(f"ERROR: factions.json not found at {FACTIONS_PATH}")
        return 1

    axes = json.loads(AXES_PATH.read_text())
    factions = json.loads(FACTIONS_PATH.read_text())

    print(f"=== Faction Bit Audit ===")
    print(f"Axes: {len(axes)} | Factions: {len(factions)}")

    if len(axes) != 12:
        print(f"ERROR: expected 12 axes, got {len(axes)}")
        return 1

    errors = 0
    soft_warnings = 0
    informational = 0

    # Precompute axis pole emoji set
    axis_pole_emojis = {}
    for i, ax in enumerate(axes):
        axis_pole_emojis[ax["pole_0"]] = (i, 0, ax["label_0"])
        axis_pole_emojis[ax["pole_1"]] = (i, 1, ax["label_1"])

    for f in factions:
        name = f.get("name", "?")
        bits = f.get("bits", [])

        # Check 1: bit count
        if len(bits) != 12:
            print(f"ERROR: {name}: expected 12 bits, got {len(bits)}")
            errors += 1
            continue

        # Check 2: bit values
        bad = [b for b in bits if b not in (0, 1)]
        if bad:
            print(f"ERROR: {name}: non-binary bits: {bad}")
            errors += 1
            continue

        description = (f.get("description") or "").lower()
        sig = f.get("sig", [])

        # Check 3: description vs bit consistency
        for i, ax in enumerate(axes):
            label_0 = ax["label_0"].lower()
            label_1 = ax["label_1"].lower()
            mentions_0 = label_0 in description
            mentions_1 = label_1 in description
            if mentions_0 and mentions_1:
                # Both mentioned (e.g. "balances common and elite") — skip
                continue
            if mentions_0 and bits[i] != 0:
                print(
                    f"WARN: {name}: description mentions '{ax['label_0']}' but bit[{i}]={bits[i]} (expected 0 = {ax['label_0']})"
                )
                soft_warnings += 1
            elif mentions_1 and bits[i] != 1:
                print(
                    f"WARN: {name}: description mentions '{ax['label_1']}' but bit[{i}]={bits[i]} (expected 1 = {ax['label_1']})"
                )
                soft_warnings += 1

        # Check 4: sig overlap with axis poles (informational)
        for emoji in sig:
            if emoji in axis_pole_emojis:
                ax_i, bit_pos, label = axis_pole_emojis[emoji]
                # Just count; don't print every overlap (would spam)
                informational += 1

    print()
    print(f"Errors: {errors}")
    print(f"Soft warnings (description vs bits): {soft_warnings}")
    print(f"Informational (sig contains axial pole emoji): {informational}")
    print()
    if errors == 0:
        print("✓ Bit structure clean; soft warnings indicate description/bit drift only.")
    return 1 if errors > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
