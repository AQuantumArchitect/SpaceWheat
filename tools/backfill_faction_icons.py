#!/usr/bin/env python3
"""Backfill `icons[]` arrays on factions that don't have them.

A pair-icon names a two-state axis a faction lives on (e.g., Combat = ⚔↔🛡).
This script preserves JSON key ordering and only adds the icons[] field
where it's currently empty/missing.
"""
import json
import sys
from pathlib import Path

# Hand-curated pair-icons keyed by faction name.
# Each entry: list of {"name", "pole_0", "pole_1"}.
ICONS = {
    "Bone Merchants": [
        {"name": "Salvage", "pole_0": "🦴", "pole_1": "💰"},
        {"name": "Repair", "pole_0": "🔧", "pole_1": "💉"},
    ],
    "Brotherhood of Ash": [
        {"name": "Cleansing", "pole_0": "⚔", "pole_1": "🧯"},
        {"name": "Aftermath", "pole_0": "⚱", "pole_1": "🌫"},
    ],
    "Cartographers of the Impossible": [
        {"name": "Charting", "pole_0": "🗺", "pole_1": "🧭"},
        {"name": "Sighting", "pole_0": "🔭", "pole_1": "📍"},
    ],
    "Chop Docs": [
        {"name": "Mend", "pole_0": "💉", "pole_1": "🦴"},
        {"name": "Fitting", "pole_0": "⚙️", "pole_1": "🔧"},
    ],
    "Clan of the Hidden Root": [
        {"name": "Underground", "pole_0": "🌱", "pole_1": "⛏"},
        {"name": "Snare", "pole_0": "🪨", "pole_1": "🪤"},
    ],
    "Cult of the Drowned Star": [
        {"name": "Pressure", "pole_0": "⭐", "pole_1": "🕳"},
        {"name": "Drowning", "pole_0": "🫧", "pole_1": "⚱"},
    ],
    "Flesh Architects": [
        {"name": "Tissue", "pole_0": "🫀", "pole_1": "🧬"},
        {"name": "Suture", "pole_0": "🩸", "pole_1": "🧵"},
    ],
    "Gearwright Circle": [
        {"name": "Mechanism", "pole_0": "⚙", "pole_1": "🔩"},
        {"name": "Toolset", "pole_0": "🛠", "pole_1": "🧰"},
        {"name": "Spark", "pole_0": "💎", "pole_1": "⚡"},
    ],
    "Hearth Witches": [
        {"name": "Kitchen", "pole_0": "🫖", "pole_1": "🥣"},
        {"name": "Ward", "pole_0": "🕯", "pole_1": "🧿"},
    ],
    "Helix Conservatory": [
        {"name": "Inheritance", "pole_0": "🧬", "pole_1": "🧫"},
        {"name": "Probe", "pole_0": "🔬", "pole_1": "🕳"},
    ],
    "Iron Shepherds": [
        {"name": "Guard", "pole_0": "⚔", "pole_1": "🛡"},
        {"name": "Patrol", "pole_0": "🐑", "pole_1": "🛸"},
    ],
    "Irrigation Jury": [
        {"name": "Allotment", "pole_0": "💧", "pole_1": "⚖"},
        {"name": "Furrow", "pole_0": "🌱", "pole_1": "🪣"},
    ],
    "Keepers of Silence": [
        {"name": "Hush", "pole_0": "🔇", "pole_1": "🤫"},
        {"name": "Embargo", "pole_0": "🛑", "pole_1": "📵"},
    ],
    "Ledger Bailiffs": [
        {"name": "Levy", "pole_0": "💰", "pole_1": "⚖"},
        {"name": "Writ", "pole_0": "📒", "pole_1": "🚔"},
    ],
    "Monolith Masons": [
        {"name": "Course", "pole_0": "🧱", "pole_1": "🏛"},
        {"name": "Plumb", "pole_0": "📐", "pole_1": "🏺"},
    ],
    "Mossline Brokers": [
        {"name": "Translation", "pole_0": "🌿", "pole_1": "🦠"},
        {"name": "Witness", "pole_0": "🧫", "pole_1": "🧿"},
    ],
    "Nexus Wardens": [
        {"name": "Crossing", "pole_0": "🚪", "pole_1": "🗝"},
        {"name": "Manifest", "pole_0": "🛂", "pole_1": "📋"},
    ],
    "Obsidian Will": [
        {"name": "Discipline", "pole_0": "⛓", "pole_1": "🪨"},
        {"name": "Foreman", "pole_0": "🧱", "pole_1": "🕴️"},
    ],
    "Order of the Crimson Scale": [
        {"name": "Arbitration", "pole_0": "⚔", "pole_1": "💱"},
        {"name": "Wyrm", "pole_0": "🐉", "pole_1": "🩸"},
    ],
    "Plague Vectors": [
        {"name": "Contagion", "pole_0": "🦠", "pole_1": "💀"},
        {"name": "Density", "pole_0": "🐝", "pole_1": "🐇"},
    ],
    "Reality Midwives": [
        {"name": "Birth", "pole_0": "🍼", "pole_1": "✨"},
        {"name": "Reception", "pole_0": "🤲", "pole_1": "💫"},
    ],
    "Relay Lattice": [
        {"name": "Uplink", "pole_0": "📡", "pole_1": "📶"},
        {"name": "Mesh", "pole_0": "🧩", "pole_1": "🗺"},
    ],
    "Rocketwright Institute": [
        {"name": "Ascent", "pole_0": "🚀", "pole_1": "⚙"},
        {"name": "Specification", "pole_0": "📋", "pole_1": "🔬"},
    ],
    "Rose Wardens": [
        {"name": "Bloom", "pole_0": "🌹", "pole_1": "🥀"},
        {"name": "Thorn", "pole_0": "🌺", "pole_1": "⚔"},
    ],
    "Sacred Flame Keepers": [
        {"name": "Vigil", "pole_0": "🕯", "pole_1": "🔥"},
        {"name": "Quench", "pole_0": "🪵", "pole_1": "🧯"},
    ],
    "Salt-Runners": [
        {"name": "Channel", "pole_0": "🛶", "pole_1": "💧"},
        {"name": "Contraband", "pole_0": "🧂", "pole_1": "🔓"},
    ],
    "Starforge Reliquary": [
        {"name": "Forgework", "pole_0": "🌞", "pole_1": "⚙"},
        {"name": "Orbit", "pole_0": "🌀", "pole_1": "🌙"},
    ],
    "Station Lords": [
        {"name": "Toll", "pole_0": "🚀", "pole_1": "💰"},
        {"name": "Berth", "pole_0": "🏢", "pole_1": "🛂"},
    ],
    "Swift Herd": [
        {"name": "Graze", "pole_0": "🦌", "pole_1": "🌿"},
        {"name": "Flight", "pole_0": "🐇", "pole_1": "🌿"},
    ],
    "Symphony Smiths": [
        {"name": "Tone", "pole_0": "🎵", "pole_1": "🔊"},
        {"name": "Forge", "pole_0": "🔨", "pole_1": "⚙"},
        {"name": "Silence", "pole_0": "🔇", "pole_1": "❄"},
    ],
    "Syndicate of Glass": [
        {"name": "Mirror", "pole_0": "🪞", "pole_1": "🔍"},
        {"name": "Cold Coin", "pole_0": "💎", "pole_1": "🧊"},
    ],
    "Terrarium Collective": [
        {"name": "Closed Loop", "pole_0": "🫙", "pole_1": "♻️"},
        {"name": "Sustain", "pole_0": "🌿", "pole_1": "💧"},
    ],
    "The Indelible Precept": [
        {"name": "Decree", "pole_0": "📜", "pole_1": "⚖"},
        {"name": "Filing", "pole_0": "📋", "pole_1": "💳"},
    ],
    "The Liminal Osmosis": [
        {"name": "Slip-Frequency", "pole_0": "📻", "pole_1": "📶"},
        {"name": "Casting", "pole_0": "📡", "pole_1": "🗣"},
    ],
    "The Opalescent Hegemon": [
        {"name": "Distant Eye", "pole_0": "🔭", "pole_1": "⚫"},
        {"name": "Imposed Order", "pole_0": "🌠", "pole_1": "⚖"},
    ],
    "The Scavenged Psithurism": [
        {"name": "Gleaning", "pole_0": "🧤", "pole_1": "🗑"},
        {"name": "Wheat-Dust", "pole_0": "💀", "pole_1": "🗑"},
    ],
    "The Sovereign Ukase": [
        {"name": "Decree", "pole_0": "💊", "pole_1": "📦"},
        {"name": "Distribution", "pole_0": "🧪", "pole_1": "🚛"},
    ],
    "The Submersed": [
        {"name": "Reef", "pole_0": "🪸", "pole_1": "🦀"},
        {"name": "Tide", "pole_0": "🌊", "pole_1": "🐠"},
    ],
    "The Vitreous Scrutiny": [
        {"name": "Curvature", "pole_0": "📐", "pole_1": "🧮"},
        {"name": "Far Sight", "pole_0": "🔭", "pole_1": "🔬"},
    ],
    "Umbra Exchange": [
        {"name": "Leverage", "pole_0": "🗝", "pole_1": "💰"},
        {"name": "Shadow", "pole_0": "🕵️", "pole_1": "💀"},
    ],
    "Void Emperors": [
        {"name": "Abandoned Crown", "pole_0": "⚫", "pole_1": "⚜"},
        {"name": "Slow Reign", "pole_0": "♟", "pole_1": "🕰"},
    ],
    "Void Serfs": [
        {"name": "Processing", "pole_0": "👥", "pole_1": "⛓"},
        {"name": "Discount", "pole_0": "💸", "pole_1": "💀"},
    ],
    "Void Troubadours": [
        {"name": "Lyric", "pole_0": "🎸", "pole_1": "🎼"},
        {"name": "Lantern", "pole_0": "💫", "pole_1": "🏮"},
    ],
    "Vortex Readers": [
        {"name": "Spiral", "pole_0": "🌀", "pole_1": "🐙"},
        {"name": "Sight", "pole_0": "👁", "pole_1": "✨"},
    ],
    "Wildfire": [
        {"name": "Burn", "pole_0": "🔥", "pole_1": "🍂"},
        {"name": "Renewal", "pole_0": "🌿", "pole_1": "🌱"},
    ],
    "Yeast Prophets": [
        {"name": "Rising", "pole_0": "🍞", "pole_1": "💨"},
        {"name": "Ferment", "pole_0": "🧪", "pole_1": "🫙"},
    ],
    "Archivists": [
        {"name": "Red Book", "pole_0": "📕", "pole_1": "🔑"},
        {"name": "Green Book", "pole_0": "📗", "pole_1": "📓"},
    ],
    "CycleKeepers": [
        {"name": "Above", "pole_0": "🦋", "pole_1": "🕷"},
        {"name": "Below", "pole_0": "🐛", "pole_1": "🕷"},
    ],
}


def main() -> int:
    path = Path(__file__).resolve().parent.parent / "Core/Factions/data/factions.json"
    factions = json.load(path.open())
    by_name = {f["name"]: f for f in factions}

    missing_in_data = [n for f in factions if not f.get("icons") for n in [f["name"]]]
    have_design = set(ICONS.keys())
    not_designed = [n for n in missing_in_data if n not in have_design]
    extra_design = [n for n in have_design if n not in by_name or by_name[n].get("icons")]

    if not_designed:
        print("FACTIONS MISSING DESIGN:", not_designed)
    if extra_design:
        print("DESIGN FOR FACTION ALREADY ICONED OR ABSENT:", extra_design)

    # Validate: every pole_0/pole_1 must be in faction sig
    errors = []
    for fname, icons in ICONS.items():
        if fname not in by_name:
            continue
        sig = set(by_name[fname].get("sig", []))
        for ic in icons:
            for pole in ("pole_0", "pole_1"):
                if ic[pole] not in sig:
                    errors.append(f"  {fname}: pair-icon '{ic['name']}' pole {ic[pole]} not in sig {sorted(sig)}")
    if errors:
        print("POLE/SIG MISMATCHES:")
        for e in errors:
            print(e)
        return 1

    # Apply
    n_applied = 0
    for f in factions:
        name = f["name"]
        if name in ICONS and not f.get("icons"):
            f["icons"] = ICONS[name]
            n_applied += 1

    json.dump(factions, path.open("w"), indent=2, ensure_ascii=False)
    print(f"applied pair-icons to {n_applied} factions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
