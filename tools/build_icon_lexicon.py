#!/usr/bin/env python3
"""build_icon_lexicon.py

Cross-references biomes.json icons[] against factions.json sig[] to propose
faction ownership of each pair-Icon.

Rules:
  - An Icon is *owned* by a faction iff BOTH poles ∈ faction.sig.
  - If multiple factions could own it, prefer the smallest sig (most specific).
    Tie-break by name.
  - Icons with no eligible owner are "orphans" — listed for manual decision.

Outputs:
  - Pretty report to stdout
  - JSON proposals to tools/icon_lexicon_proposals.json
  - With --apply, mutates Core/Factions/data/factions.json in place (backup written)
"""
import argparse
import json
import shutil
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FACTIONS_PATH = REPO / "Core/Factions/data/factions.json"
BIOMES_PATH = REPO / "Core/Biomes/data/biomes.json"
PROPOSALS_PATH = REPO / "tools/icon_lexicon_proposals.json"


def load_biomes():
    return json.loads(BIOMES_PATH.read_text())


def load_factions():
    return json.loads(FACTIONS_PATH.read_text())


def collect_pair_icons(biomes):
    """Return {(pole_0,pole_1): {name, biomes:[...]}} keyed by ordered pair.

    If the same pair appears under two different names, both names are recorded.
    """
    icons = {}
    for biome in biomes:
        bname = biome.get("name", "?")
        for icon in biome.get("icons", []) or []:
            name = icon.get("name", "")
            p0 = icon.get("pole_0", "")
            p1 = icon.get("pole_1", "")
            if not (name and p0 and p1):
                continue
            key = (p0, p1)
            entry = icons.setdefault(key, {"names": set(), "biomes": []})
            entry["names"].add(name)
            entry["biomes"].append(bname)
    return icons


def find_owners(pair, factions):
    """Return list of faction dicts whose sig contains both poles."""
    p0, p1 = pair
    owners = []
    for f in factions:
        sig = f.get("sig", [])
        if p0 in sig and p1 in sig:
            owners.append(f)
    return owners


def pick_owner(owners):
    """Smallest sig wins; tie-break by name."""
    if not owners:
        return None
    return sorted(owners, key=lambda f: (len(f.get("sig", [])), f.get("name", "")))[0]


def build_proposals(biomes, factions):
    pair_icons = collect_pair_icons(biomes)
    proposals = {f["name"]: [] for f in factions}
    orphans = []
    contested = []
    seen_names = defaultdict(list)  # name -> [factions]

    for pair, info in pair_icons.items():
        names = sorted(info["names"])
        canonical_name = names[0]  # if multiple names for same pair, pick alphabetically first
        owners = find_owners(pair, factions)
        if not owners:
            orphans.append(
                {
                    "name": canonical_name,
                    "alt_names": names[1:],
                    "pole_0": pair[0],
                    "pole_1": pair[1],
                    "biomes": sorted(set(info["biomes"])),
                }
            )
            continue
        chosen = pick_owner(owners)
        if len(owners) > 1:
            contested.append(
                {
                    "name": canonical_name,
                    "pole_0": pair[0],
                    "pole_1": pair[1],
                    "chose": chosen["name"],
                    "candidates": [o["name"] for o in owners],
                }
            )
        proposals[chosen["name"]].append(
            {"name": canonical_name, "pole_0": pair[0], "pole_1": pair[1]}
        )
        seen_names[canonical_name].append(chosen["name"])

    name_collisions = {n: fs for n, fs in seen_names.items() if len(set(fs)) > 1}

    return proposals, orphans, contested, name_collisions


def report(proposals, orphans, contested, name_collisions, factions):
    n_owned = sum(len(v) for v in proposals.values())
    n_factions_with = sum(1 for v in proposals.values() if v)
    print(f"=== Icon Lexicon Proposal Report ===")
    print(f"Total factions: {len(factions)}")
    print(f"Factions with ≥1 owned Icon: {n_factions_with}")
    print(f"Factions with 0 owned Icons: {len(factions) - n_factions_with}")
    print(f"Total Icon assignments: {n_owned}")
    print(f"Orphan Icons (no faction sig contains both poles): {len(orphans)}")
    print(f"Contested Icons (>1 faction eligible, picked smallest sig): {len(contested)}")
    print(f"Name collisions (same name → different factions): {len(name_collisions)}")
    print()

    if orphans:
        print(f"--- Orphans ({len(orphans)}) — need manual fix or accept as biome-only ---")
        for o in orphans[:30]:
            print(
                f"  {o['name']:>20s}  {o['pole_0']}/{o['pole_1']}  in biomes: {', '.join(o['biomes'])}"
            )
        if len(orphans) > 30:
            print(f"  ... and {len(orphans) - 30} more")
        print()

    if contested:
        print(f"--- Contested (auto-resolved by smallest sig) ---")
        for c in contested[:20]:
            print(
                f"  {c['name']:>20s}  {c['pole_0']}/{c['pole_1']}  → {c['chose']}  (candidates: {', '.join(c['candidates'])})"
            )
        if len(contested) > 20:
            print(f"  ... and {len(contested) - 20} more")
        print()

    if name_collisions:
        print(f"--- Name collisions ---")
        for n, fs in name_collisions.items():
            print(f"  {n}: {fs}")
        print()

    print(f"--- Per-faction summary (top 15 by icon count) ---")
    sorted_props = sorted(proposals.items(), key=lambda x: -len(x[1]))
    for fname, icons in sorted_props[:15]:
        if icons:
            print(f"  {fname:>30s}: {len(icons):2d}  e.g. {icons[0]['name']}")


def write_proposals_json(proposals, orphans, contested, name_collisions):
    PROPOSALS_PATH.write_text(
        json.dumps(
            {
                "proposals": proposals,
                "orphans": orphans,
                "contested": contested,
                "name_collisions": name_collisions,
            },
            indent=2,
            ensure_ascii=False,
        )
    )
    print(f"\nWrote proposals → {PROPOSALS_PATH.relative_to(REPO)}")


def apply(proposals):
    backup = FACTIONS_PATH.with_suffix(".json.bak")
    shutil.copy(FACTIONS_PATH, backup)
    print(f"Backup → {backup.relative_to(REPO)}")
    factions = load_factions()
    for f in factions:
        f["icons"] = proposals.get(f["name"], [])
    FACTIONS_PATH.write_text(json.dumps(factions, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {FACTIONS_PATH.relative_to(REPO)} with icons[] on {len(factions)} factions")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="Mutate factions.json in place")
    args = ap.parse_args()
    biomes = load_biomes()
    factions = load_factions()
    proposals, orphans, contested, collisions = build_proposals(biomes, factions)
    report(proposals, orphans, contested, collisions, factions)
    write_proposals_json(proposals, orphans, contested, collisions)
    if args.apply:
        apply(proposals)


if __name__ == "__main__":
    main()
