#!/usr/bin/env python3
"""
gen_biome_icon_stubs.py
Generates icons.json entries for every biome-declared icon pair that has no
existing physics record.

Physics extraction: same math as the icon-physics conversion path, but sourcing from ALL
factions (not just the owning faction), since biome-local icons have no owner.
Each pole's self_energy, hamiltonian couplings, alignment couplings, and driver
are accumulated additively across every faction that mentions that emoji.

Also adds an "orphaned_icons" catalog faction to factions.json so the new icons
are queryable via IconLexicon.get_icons_for_faction("orphaned_icons").

Run without --write for a dry run (prints what would be added).
Run with --write to commit changes to icons.json and factions.json.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FACTIONS_PATH = ROOT / "Core/Factions/data/factions.json"
BIOMES_PATH   = ROOT / "Core/Biomes/data/biomes.json"
ICONS_PATH    = ROOT / "Core/Factions/data/icons.json"


# ── Helpers ────────────────────────────────────────────────────────────────

def _coupling_value(val):
    if isinstance(val, list) and len(val) == 2:
        return [float(val[0]), float(val[1])]
    return float(val)


def _merge_couplings(a: dict, b: dict, exclude: set) -> dict:
    out = {}
    for src in (a, b):
        for k, v in src.items():
            if k in exclude:
                continue
            val = _coupling_value(v)
            if k in out:
                prev = out[k]
                if isinstance(prev, list) and isinstance(val, list):
                    out[k] = [prev[0] + val[0], prev[1] + val[1]]
                elif isinstance(prev, list):
                    out[k] = [prev[0] + float(val), prev[1]]
                elif isinstance(val, list):
                    out[k] = [float(prev) + val[0], val[1]]
                else:
                    out[k] = float(prev) + float(val)
            else:
                out[k] = val
    return out


def _merge_dicts(a: dict, b: dict) -> dict:
    out = dict(a)
    out.update(b)
    return out


def _norm(s: str) -> str:
    """Strip variation selectors so 🕵️ and 🕵 compare equal."""
    return s.replace('️', '').replace('︎', '')


# ── Build pair index from existing icons.json ────────────────────────────────

def build_pair_index(icons: list) -> dict:
    """Returns {norm(p0)|norm(p1): icon_record} for both orderings."""
    idx = {}
    for ic in icons:
        k1 = _norm(ic['pole_0']) + '|' + _norm(ic['pole_1'])
        k2 = _norm(ic['pole_1']) + '|' + _norm(ic['pole_0'])
        idx[k1] = ic
        idx[k2] = ic
    return idx


# ── Extract physics for a pair from all factions ─────────────────────────────

def extract_from_all_factions(p0: str, p1: str, factions: list) -> dict:
    """Accumulate physics for (p0, p1) across all factions."""
    intra = {p0, p1}
    se0 = 0.0
    se1 = 0.0
    rabi = 0.0
    h_couplings: dict = {}
    e_couplings: dict = {}
    driver: dict = {}
    mb: dict = {}

    for f in factions:
        se = f.get('self_energies', {})
        se0 += float(se.get(p0, 0.0))
        se1 += float(se.get(p1, 0.0))

        ham = f.get('hamiltonian', {})
        h_p0 = ham.get(p0, {})
        h_p1 = ham.get(p1, {})

        # Rabi: intra-icon coupling between p0 and p1
        rabi_raw = h_p0.get(p1, h_p1.get(p0, 0.0))
        if isinstance(rabi_raw, list):
            rabi += (rabi_raw[0] ** 2 + rabi_raw[1] ** 2) ** 0.5
        else:
            rabi += abs(float(rabi_raw))

        # Cross-icon Hamiltonian couplings (excluding intra pair)
        cross = _merge_couplings(h_p0, h_p1, intra)
        h_couplings = _merge_couplings(h_couplings, cross, set())

        # Energy (bath) couplings
        ac = f.get('alignment_couplings', {})
        e_part = _merge_dicts(ac.get(p0, {}), ac.get(p1, {}))
        e_part = {k: float(v) for k, v in e_part.items()}
        e_couplings = _merge_dicts(e_couplings, e_part)

        # Driver (first found)
        if not driver:
            drivers = f.get('drivers', {})
            driver = drivers.get(p0, drivers.get(p1, {}))

        # Measurement behavior (merge)
        mbb = f.get('measurement_behavior', {})
        mb_part = _merge_dicts(mbb.get(p0, {}), mbb.get(p1, {}))
        if mb_part:
            mb.update(mb_part)

    entry = {
        "pole_0": p0,
        "pole_1": p1,
        "owner_faction": "",
        "self_energy_0": round(se0, 6),
        "self_energy_1": round(se1, 6),
        "rabi_coupling":  round(rabi, 6),
        "hamiltonian_couplings": h_couplings,
        "energy_couplings": {k: round(v, 6) for k, v in e_couplings.items()},
    }
    if driver:
        entry["driver"] = driver
    if mb:
        entry["measurement_behavior"] = mb
    return entry


# ── Main ─────────────────────────────────────────────────────────────────────

def main(argv: list) -> int:
    write = "--write" in argv

    factions = json.loads(FACTIONS_PATH.read_text(encoding="utf-8"))
    biomes   = json.loads(BIOMES_PATH.read_text(encoding="utf-8"))
    icons    = json.loads(ICONS_PATH.read_text(encoding="utf-8"))

    pair_index = build_pair_index(icons)

    # Collect every biome icon pair not yet in icons.json.
    # De-duplicate by normalized pair key; track first name found.
    new_pairs: dict = {}  # norm_key → {name, p0, p1, biome_name}
    for b in biomes:
        bn = b.get('name', '?')
        for ic in b.get('icons', []):
            p0 = ic.get('pole_0', '')
            p1 = ic.get('pole_1', '')
            if not p0 or not p1:
                continue
            nk = _norm(p0) + '|' + _norm(p1)
            rk = _norm(p1) + '|' + _norm(p0)
            if nk in pair_index or rk in pair_index:
                continue  # already covered
            if nk in new_pairs or rk in new_pairs:
                continue  # already queued (another biome uses same pair)
            new_pairs[nk] = {
                'name': ic.get('name', f"{p0}/{p1}"),
                'p0': p0,
                'p1': p1,
                'biome': bn,
            }

    print(f"Biome icon pairs without icons.json record: {len(new_pairs)}")

    # Generate entries
    new_entries = []
    zero_physics = []
    for nk, meta in sorted(new_pairs.items(), key=lambda x: x[1]['biome']):
        p0, p1, iname = meta['p0'], meta['p1'], meta['name']
        entry = extract_from_all_factions(p0, p1, factions)
        entry['name'] = iname
        # Reorder fields for readability
        ordered = {
            'name': entry['name'],
            'pole_0': entry['pole_0'],
            'pole_1': entry['pole_1'],
            'owner_faction': entry['owner_faction'],
            'self_energy_0': entry['self_energy_0'],
            'self_energy_1': entry['self_energy_1'],
            'rabi_coupling':  entry['rabi_coupling'],
            'hamiltonian_couplings': entry['hamiltonian_couplings'],
            'energy_couplings': entry['energy_couplings'],
        }
        if 'driver' in entry:
            ordered['driver'] = entry['driver']
        if 'measurement_behavior' in entry:
            ordered['measurement_behavior'] = entry['measurement_behavior']
        new_entries.append(ordered)
        if entry['self_energy_0'] == 0.0 and entry['self_energy_1'] == 0.0 and entry['rabi_coupling'] == 0.0:
            zero_physics.append(f"  {iname} ({p0}/{p1})  ← {meta['biome']}")
        else:
            print(f"  {iname} ({p0}/{p1}): SE={entry['self_energy_0']:.3f}/{entry['self_energy_1']:.3f} rabi={entry['rabi_coupling']:.3f}")

    if zero_physics:
        print(f"\nIcons with zero physics (no faction data for either pole): {len(zero_physics)}")
        for z in zero_physics:
            print(z)

    # Build orphaned_icons catalog faction entry
    orphan_faction = {
        "name": "orphaned_icons",
        "description": "Catalog of biome-local icons awaiting faction assignment or icon-cloud integration.",
        "ring": "outer",
        "bits": [],
        "tags": ["internal", "catalog"],
        "icons": [
            {"name": e['name'], "pole_0": e['pole_0'], "pole_1": e['pole_1']}
            for e in new_entries
        ],
    }

    print(f"\norphaned_icons faction: {len(orphan_faction['icons'])} icons")

    if not write:
        print("\nDry run — pass --write to commit changes.")
        return 0

    # Write icons.json
    icons.extend(new_entries)
    ICONS_PATH.write_text(
        json.dumps(icons, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )
    print(f"\nWritten: {ICONS_PATH}  (+{len(new_entries)} entries, total {len(icons)})")

    # Write factions.json — append orphaned_icons if not already present
    if any(f.get('name') == 'orphaned_icons' for f in factions):
        print("orphaned_icons faction already exists in factions.json — skipping")
    else:
        factions.append(orphan_faction)
        FACTIONS_PATH.write_text(
            json.dumps(factions, indent=2, ensure_ascii=False),
            encoding="utf-8"
        )
        print(f"Written: {FACTIONS_PATH}  (+orphaned_icons faction)")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
