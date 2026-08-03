#!/usr/bin/env python3
"""
Mutate Core/Factions/data/factions.json and Core/Biomes/data/biomes.json
according to spec.
"""

import copy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import biome_io  # noqa: E402
from biome_io import FACTIONS_PATH, BIOMES_PATH  # noqa: E402

# ─────────────────────────────────────────────────────────────────────────────
# Load
# ─────────────────────────────────────────────────────────────────────────────
# Raw reads — mutate scripts never opt into FE0F normalization.
factions = biome_io.load_factions()
biomes   = biome_io.load_biomes()

faction_map = {f["name"]: f for f in factions}
changes = []

# ─────────────────────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────────────────────
def sym_add(h, a, b, v):
    """Add symmetric hamiltonian entry h[a][b] = h[b][a] = v."""
    h.setdefault(a, {})[b] = v
    h.setdefault(b, {})[a] = v


def update_faction(name, *, append_sig=None, new_icons=None,
                   h_new_row=None, h_sym_entries=None,
                   se_new=None):
    """Apply all mutations to a faction by name."""
    f = faction_map[name]
    if append_sig and append_sig not in f["sig"]:
        f["sig"].append(append_sig)
        changes.append(f"  sig +{append_sig}")
    if new_icons is not None:
        f["icons"] = new_icons
        changes.append(f"  icons updated ({len(new_icons)} pairs)")
    h = f.setdefault("hamiltonian", {})
    if h_new_row:
        # h_new_row: {new_atom: {other: val}}
        for new_atom, neighbors in h_new_row.items():
            h.setdefault(new_atom, {}).update(neighbors)
            changes.append(f"  H row {new_atom} added")
    if h_sym_entries:
        for a, b, v in h_sym_entries:
            sym_add(h, a, b, v)
            changes.append(f"  H {a}↔{b}={v}")
    se = f.setdefault("self_energies", {})
    if se_new:
        for atom, val in se_new.items():
            se[atom] = val
            changes.append(f"  SE {atom}={val}")


# ─────────────────────────────────────────────────────────────────────────────
# 1. Faction mutations
# ─────────────────────────────────────────────────────────────────────────────

print("=== Faction mutations ===")

# Carrion Throne — append 💰 to sig; H already has 💰; update icons
print("\nCarrion Throne")
update_faction("Carrion Throne",
    append_sig="💰",
    new_icons=[
        {"name": "Predation", "pole_0": "🦅", "pole_1": "🩸"},
        {"name": "Heritage",  "pole_0": "🏰", "pole_1": "📜"},
        {"name": "Nobility",  "pole_0": "⚜",  "pole_1": "👥"},
        {"name": "Commerce",  "pole_0": "⚖",  "pole_1": "💰"},
    ],
)

# Children of the Ember — append 🩸; add H row + sym entries; SE
print("\nChildren of the Ember")
update_faction("Children of the Ember",
    append_sig="🩸",
    new_icons=[
        {"name": "Revolt",    "pole_0": "✊",  "pole_1": "🚩"},
        {"name": "Blaze",     "pole_0": "🔥",  "pole_1": "🧨"},
        {"name": "Sacrifice", "pole_0": "⚔",   "pole_1": "🩸"},
    ],
    h_new_row={"🩸": {"⚔": 0.40, "✊": 0.25}},
    h_sym_entries=[("⚔", "🩸", 0.40), ("✊", "🩸", 0.25)],
    se_new={"🩸": 0.15},
)

# Fencebreakers — append 🌾; add H; SE
print("\nFencebreakers")
update_faction("Fencebreakers",
    append_sig="🌾",
    new_icons=[
        {"name": "Clearing",    "pole_0": "🪓", "pole_1": "🔥"},
        {"name": "Liberation",  "pole_0": "⛓",  "pole_1": "👥"},
        {"name": "Strike",      "pole_0": "⚔",  "pole_1": "🧨"},
        {"name": "Land",        "pole_0": "✊",  "pole_1": "🌾"},
    ],
    h_new_row={"🌾": {"✊": 0.35, "🪓": 0.40}},
    h_sym_entries=[("✊", "🌾", 0.35), ("🪓", "🌾", 0.40)],
    se_new={"🌾": 0.1},
)

# Hearth Witches — append 🌾; add H; SE
print("\nHearth Witches")
update_faction("Hearth Witches",
    append_sig="🌾",
    new_icons=[
        {"name": "Kitchen", "pole_0": "🫖", "pole_1": "🥣"},
        {"name": "Ward",    "pole_0": "🕯",  "pole_1": "🧿"},
        {"name": "Forage",  "pole_0": "🌿",  "pole_1": "🌾"},
    ],
    h_new_row={"🌾": {"🌿": 0.35, "🥣": 0.20}},
    h_sym_entries=[("🌿", "🌾", 0.35), ("🥣", "🌾", 0.20)],
    se_new={"🌾": 0.1},
)

# Ledger Bailiffs — append 💸; H already has 💸; add SE
print("\nLedger Bailiffs")
update_faction("Ledger Bailiffs",
    append_sig="💸",
    new_icons=[
        {"name": "Levy",   "pole_0": "💰", "pole_1": "⚖"},
        {"name": "Writ",   "pole_0": "📒", "pole_1": "🚔"},
        {"name": "Record", "pole_0": "📘", "pole_1": "💸"},
    ],
    se_new={"💸": 0.2},
)

# Memory Merchants — append 🔮; add H; SE
print("\nMemory Merchants")
update_faction("Memory Merchants",
    append_sig="🔮",
    new_icons=[
        {"name": "Memory",    "pole_0": "📼", "pole_1": "🧩"},
        {"name": "Archive",   "pole_0": "💾", "pole_1": "🗝"},
        {"name": "Foresight", "pole_0": "💰", "pole_1": "🔮"},
    ],
    h_new_row={"🔮": {"💾": 0.30, "📼": 0.45}},
    h_sym_entries=[("💾", "🔮", 0.30), ("📼", "🔮", 0.45)],
    se_new={"🔮": 0.3},
)

# Obsidian Will — append 🔩; add H; SE
print("\nObsidian Will")
update_faction("Obsidian Will",
    append_sig="🔩",
    new_icons=[
        {"name": "Discipline", "pole_0": "⛓",  "pole_1": "🪨"},
        {"name": "Foreman",    "pole_0": "🧱",  "pole_1": "🕴️"},
        {"name": "Mechanism",  "pole_0": "⚙",   "pole_1": "🔩"},
        {"name": "Doctrine",   "pole_0": "📘",  "pole_1": "⚡"},
    ],
    h_new_row={"🔩": {"⚙": 0.55, "🧱": 0.30}},
    h_sym_entries=[("⚙", "🔩", 0.55), ("🧱", "🔩", 0.30)],
    se_new={"🔩": 0.1},
)

# Rocketwright Institute — append 🌫; H already has 🌫; just sig + icons
print("\nRocketwright Institute")
update_faction("Rocketwright Institute",
    append_sig="🌫",
    new_icons=[
        {"name": "Ascent",         "pole_0": "🚀", "pole_1": "⚙"},
        {"name": "Specification",  "pole_0": "📋", "pole_1": "🔬"},
        {"name": "Exhaust",        "pole_0": "💎", "pole_1": "🌫"},
    ],
)

# Seedvault Curators — append 🌾; add H; SE
print("\nSeedvault Curators")
update_faction("Seedvault Curators",
    append_sig="🌾",
    new_icons=[
        {"name": "Research",    "pole_0": "🧪", "pole_1": "🧬"},
        {"name": "Cultivation", "pole_0": "🌱", "pole_1": "🌾"},
        {"name": "Lab",         "pole_0": "🧫", "pole_1": "🔬"},
    ],
    h_new_row={"🌾": {"🌱": 0.40, "🧫": 0.25}},
    h_sym_entries=[("🌱", "🌾", 0.40), ("🧫", "🌾", 0.25)],
    se_new={"🌾": 0.1},
)

# The Scavenged Psithurism — append 🌾; add H; SE
print("\nThe Scavenged Psithurism")
update_faction("The Scavenged Psithurism",
    append_sig="🌾",
    new_icons=[
        {"name": "Gleaning", "pole_0": "🧤", "pole_1": "🌾"},
        {"name": "Carrion",  "pole_0": "💀", "pole_1": "🗑"},
    ],
    h_new_row={"🌾": {"🧤": 0.35, "💀": 0.20}},
    h_sym_entries=[("🧤", "🌾", 0.35), ("💀", "🌾", 0.20)],
    se_new={"🌾": 0.1},
)

# Syndicate of Glass — append 🫧; add H; SE
print("\nSyndicate of Glass")
update_faction("Syndicate of Glass",
    append_sig="🫧",
    new_icons=[
        {"name": "Mirror",    "pole_0": "🪞", "pole_1": "🔍"},
        {"name": "Cold Coin", "pole_0": "💎", "pole_1": "🧊"},
        {"name": "Clarity",   "pole_0": "💰", "pole_1": "🫧"},
    ],
    h_new_row={"🫧": {"💰": 0.30, "🪞": 0.40}},
    h_sym_entries=[("💰", "🫧", 0.30), ("🪞", "🫧", 0.40)],
    se_new={"🫧": 0.05},
)

# Black Horizon — fix duplicate "Singularity" icon names
print("\nBlack Horizon")
update_faction("Black Horizon",
    new_icons=[
        {"name": "Void",        "pole_0": "🕳",  "pole_1": "🪐"},
        {"name": "Singularity", "pole_0": "🌀",  "pole_1": "⚫"},
        {"name": "Radiance",    "pole_0": "☀",   "pole_1": "⚡"},
    ],
)

# Debt Wardens — fix ⛓ used in both icon pairs
print("\nDebt Wardens")
update_faction("Debt Wardens",
    new_icons=[
        {"name": "Debt",       "pole_0": "💸", "pole_1": "⛓"},
        {"name": "Liberation", "pole_0": "👥", "pole_1": "💀"},
    ],
)

# Kilowatt Collective — fix ⚡ used twice
print("\nKilowatt Collective")
update_faction("Kilowatt Collective",
    new_icons=[
        {"name": "Power",   "pole_0": "🔋", "pole_1": "⚙"},
        {"name": "Circuit", "pole_0": "🔌", "pole_1": "🌞"},
        {"name": "Storm",   "pole_0": "⚡", "pole_1": "🌋"},
        {"name": "Heat",    "pole_0": "🔥", "pole_1": "🌫"},
    ],
)

# Market Spirits — expand from 1 icon pair
print("\nMarket Spirits")
update_faction("Market Spirits",
    new_icons=[
        {"name": "Sentiment", "pole_0": "🐂",  "pole_1": "🐻"},
        {"name": "Vault",     "pole_0": "🏛️", "pole_1": "💰"},
        {"name": "Exchange",  "pole_0": "📦",  "pole_1": "🏚️"},
    ],
)

# Sacred Flame Keepers — add Temple icon
print("\nSacred Flame Keepers")
update_faction("Sacred Flame Keepers",
    new_icons=[
        {"name": "Vigil",  "pole_0": "🕯",  "pole_1": "🔥"},
        {"name": "Quench", "pole_0": "🪵",  "pole_1": "🧯"},
        {"name": "Temple", "pole_0": "⛪",  "pole_1": "🍂"},
    ],
)

# Starforge Reliquary — add Accelerate icon
print("\nStarforge Reliquary")
update_faction("Starforge Reliquary",
    new_icons=[
        {"name": "Forgework",  "pole_0": "🌞", "pole_1": "⚙"},
        {"name": "Orbit",      "pole_0": "🌀", "pole_1": "🌙"},
        {"name": "Accelerate", "pole_0": "🚀", "pole_1": "⚡"},
    ],
)

# The Gilded Legacy — expand from 1 icon pair
print("\nThe Gilded Legacy")
update_faction("The Gilded Legacy",
    new_icons=[
        {"name": "Ore",   "pole_0": "💎", "pole_1": "⛏"},
        {"name": "Spark", "pole_0": "⚡", "pole_1": "🪨"},
        {"name": "Gild",  "pole_0": "💰", "pole_1": "✨"},
    ],
)

# Volcanic Foundry — expand from 1 icon pair
print("\nVolcanic Foundry")
update_faction("Volcanic Foundry",
    new_icons=[
        {"name": "Magma",   "pole_0": "🌋", "pole_1": "🔥"},
        {"name": "Crystal", "pole_0": "💎", "pole_1": "✨"},
        {"name": "Ash",     "pole_0": "🌫", "pole_1": "🪨"},
        {"name": "Charge",  "pole_0": "⚡", "pole_1": "🏜"},
    ],
)

print("\nAll faction mutations done.")

# ─────────────────────────────────────────────────────────────────────────────
# 2. Add discoverable:false to existing neighborhoods (except named exclusions)
# ─────────────────────────────────────────────────────────────────────────────
print("\n=== Biome discoverable flags ===")
DISCOVERABLE_TRUE_NAMES = {"Volcanic Foundry", "Sacred Flame Keepers"}
n_flagged = 0
for b in biomes:
    if b.get("kind") == "neighborhood" and b.get("name") not in DISCOVERABLE_TRUE_NAMES:
        if "discoverable" not in b:
            b["discoverable"] = False
            n_flagged += 1
print(f"  Added discoverable:false to {n_flagged} existing neighborhoods")

# ─────────────────────────────────────────────────────────────────────────────
# 3. Build 26 new neighborhoods
# ─────────────────────────────────────────────────────────────────────────────
print("\n=== Building new neighborhoods ===")

def make_biome(name, faction, discoverable, emojis, icons, tags, atom_components, native_factions=None):
    return {
        "name": name,
        "kind": "neighborhood",
        "faction": faction,
        "discovered": False,
        "discoverable": discoverable,
        "emojis": emojis,
        "native_factions": native_factions if native_factions else [faction],
        "tags": tags,
        "atom_components": atom_components,
        "icons": icons,
        "visual_config": {},
    }

def decay(rate, target):
    return {"decay": {"rate": rate, "target": target}}

def lindblad_out(rates_dict):
    return {"lindblad_outgoing": rates_dict}

def gated_lindblad(target, gate, rate, power, inverse=False):
    return {"gated_lindblad_source": [{"target": target, "gate": gate, "rate": rate, "power": power, "inverse": inverse}]}

new_biomes = []

# ── Volcanic Foundry (discoverable: true) ──────────────────────────────────
new_biomes.append(make_biome(
    "Volcanic Foundry", "Volcanic Foundry", True,
    ["🌋","🔥","🪨","💎","🌫","✨","⚡","🏜"],
    [{"name":"Magma","pole_0":"🌋","pole_1":"🔥"},
     {"name":"Crystal","pole_0":"💎","pole_1":"✨"},
     {"name":"Ash","pole_0":"🌫","pole_1":"🪨"},
     {"name":"Charge","pole_0":"⚡","pole_1":"🏜"}],
    ["volcanic","mining","geothermal","fire"],
    {
        "🌋": decay(0.15, "🔥"),
        "🔥": gated_lindblad("💎", "🌋", 0.18, 2),
        "💎": decay(0.10, "✨"),
        "✨": decay(0.08, "🌫"),
        "🌫": decay(0.12, "🪨"),
        "🪨": decay(0.06, "🌋"),
        "🏜": lindblad_out({"🌋": 0.10}),
        "⚡": lindblad_out({"🏜": 0.08}),
    }
))

# ── Sacred Flame Keepers (discoverable: true) ──────────────────────────────
new_biomes.append(make_biome(
    "Sacred Flame Keepers", "Sacred Flame Keepers", True,
    ["🔥","🕯","⛪","🪵","🧯","🍂"],
    [{"name":"Vigil","pole_0":"🕯","pole_1":"🔥"},
     {"name":"Quench","pole_0":"🪵","pole_1":"🧯"},
     {"name":"Temple","pole_0":"⛪","pole_1":"🍂"}],
    ["sacred","fire","ritual","forest"],
    {
        "🪵": lindblad_out({"🔥": 0.15}),
        "🔥": gated_lindblad("🕯", "⛪", 0.18, 1),
        "⛪": decay(0.04, "🔥"),
        "🕯": decay(0.12, "🧯"),
        "🧯": lindblad_out({"🍂": 0.10}),
        "🍂": lindblad_out({"🪵": 0.08}),
    }
))

# ── Black Horizon (discoverable: false) ────────────────────────────────────
new_biomes.append(make_biome(
    "Black Horizon", "Black Horizon", False,
    ["⚫","🕳","🪐","🌀","☀","⚡"],
    [{"name":"Void","pole_0":"🕳","pole_1":"🪐"},
     {"name":"Singularity","pole_0":"🌀","pole_1":"⚫"},
     {"name":"Radiance","pole_0":"☀","pole_1":"⚡"}],
    ["void","cosmic","entropy"],
    {
        "☀":  gated_lindblad("⚫", "🕳", 0.20, 2),
        "⚫": decay(0.12, "🌀"),
        "🌀": decay(0.10, "🪐"),
        "🪐": decay(0.08, "🕳"),
        "🕳": decay(0.06, "⚡"),
        "⚡": decay(0.04, "☀"),
    }
))

# ── Bone Merchants (discoverable: false) ───────────────────────────────────
new_biomes.append(make_biome(
    "Bone Merchants", "Bone Merchants", False,
    ["🦴","💉","🔧","💰"],
    [{"name":"Salvage","pole_0":"🦴","pole_1":"💰"},
     {"name":"Repair","pole_0":"🔧","pole_1":"💉"}],
    ["salvage","medicine","trade"],
    {
        "🦴": lindblad_out({"💰": 0.15}),
        "💰": gated_lindblad("🔧", "🦴", 0.18, 1),
        "🔧": lindblad_out({"💉": 0.12}),
        "💉": decay(0.08, "🦴"),
    }
))

# ── Carrion Throne (discoverable: false) ───────────────────────────────────
new_biomes.append(make_biome(
    "Carrion Throne", "Carrion Throne", False,
    ["👥","⚖","🦅","⚜","🩸","🏰","📜","💰"],
    [{"name":"Predation","pole_0":"🦅","pole_1":"🩸"},
     {"name":"Heritage","pole_0":"🏰","pole_1":"📜"},
     {"name":"Nobility","pole_0":"⚜","pole_1":"👥"},
     {"name":"Commerce","pole_0":"⚖","pole_1":"💰"}],
    ["empire","authority","predation","tribute"],
    {
        "🦅": decay(0.15, "🩸"),
        "🩸": gated_lindblad("⚜", "🦅", 0.18, 2),
        "⚜": decay(0.10, "👥"),
        "👥": lindblad_out({"💰": 0.12}),
        "💰": lindblad_out({"⚖": 0.08}),
        "⚖": lindblad_out({"🏰": 0.06}),
        "🏰": decay(0.05, "📜"),
        "📜": decay(0.04, "🦅"),
    }
))

# ── Children of the Ember (discoverable: false) ────────────────────────────
new_biomes.append(make_biome(
    "Children of the Ember", "Children of the Ember", False,
    ["⚔","🔥","✊","🚩","🧨","🩸"],
    [{"name":"Revolt","pole_0":"✊","pole_1":"🚩"},
     {"name":"Blaze","pole_0":"🔥","pole_1":"🧨"},
     {"name":"Sacrifice","pole_0":"⚔","pole_1":"🩸"}],
    ["revolution","fire","resistance"],
    {
        "✊": gated_lindblad("🚩", "🔥", 0.18, 1),
        "🚩": decay(0.12, "🧨"),
        "🧨": decay(0.15, "🔥"),
        "🔥": lindblad_out({"⚔": 0.10}),
        "⚔": decay(0.12, "🩸"),
        "🩸": decay(0.08, "✊"),
    }
))

# ── Clan of the Hidden Root (discoverable: false) ──────────────────────────
new_biomes.append(make_biome(
    "Clan of the Hidden Root", "Clan of the Hidden Root", False,
    ["🌱","⛏","🪨","🪤"],
    [{"name":"Underground","pole_0":"🌱","pole_1":"⛏"},
     {"name":"Snare","pole_0":"🪨","pole_1":"🪤"}],
    ["underground","survival","hidden"],
    {
        "🌱": gated_lindblad("⛏", "🪨", 0.18, 1),
        "⛏": decay(0.12, "🪨"),
        "🪨": decay(0.10, "🪤"),
        "🪤": lindblad_out({"🌱": 0.08}),
    }
))

# ── Debt Wardens (discoverable: false) ─────────────────────────────────────
new_biomes.append(make_biome(
    "Debt Wardens", "Debt Wardens", False,
    ["⛓","💸","👥","💀"],
    [{"name":"Debt","pole_0":"💸","pole_1":"⛓"},
     {"name":"Liberation","pole_0":"👥","pole_1":"💀"}],
    ["debt","chains","dispossession"],
    {
        "👥": gated_lindblad("💸", "⛓", 0.18, 2),
        "💸": decay(0.12, "⛓"),
        "⛓": decay(0.10, "💀"),
        "💀": decay(0.06, "👥"),
    }
))

# ── Fencebreakers (discoverable: false) ────────────────────────────────────
new_biomes.append(make_biome(
    "Fencebreakers", "Fencebreakers", False,
    ["⚔","🧨","🔥","🪓","✊","⛓","👥","🌾"],
    [{"name":"Clearing","pole_0":"🪓","pole_1":"🔥"},
     {"name":"Liberation","pole_0":"⛓","pole_1":"👥"},
     {"name":"Strike","pole_0":"⚔","pole_1":"🧨"},
     {"name":"Land","pole_0":"✊","pole_1":"🌾"}],
    ["revolution","land","enclosure","liberation"],
    {
        "🌾": gated_lindblad("✊", "⛓", 0.15, 1),
        "✊": decay(0.12, "🪓"),
        "🪓": lindblad_out({"🔥": 0.12, "⚔": 0.06}),
        "🔥": decay(0.10, "🧨"),
        "⚔": lindblad_out({"🧨": 0.08}),
        "🧨": decay(0.12, "⛓"),
        "⛓": decay(0.10, "👥"),
        "👥": lindblad_out({"🌾": 0.08}),
    }
))

# ── Gearwright Circle (discoverable: true) ─────────────────────────────────
new_biomes.append(make_biome(
    "Gearwright Circle", "Gearwright Circle", True,
    ["⚙","🛠","🔩","🧰","🏷️","💎","🪨","⚡"],
    [{"name":"Mechanism","pole_0":"⚙","pole_1":"🔩"},
     {"name":"Toolset","pole_0":"🛠","pole_1":"🧰"},
     {"name":"Spark","pole_0":"💎","pole_1":"⚡"},
     {"name":"Label","pole_0":"🏷️","pole_1":"🪨"}],
    ["engineering","mechanisms","craft"],
    {
        "🪨": decay(0.12, "💎"),
        "💎": gated_lindblad("⚡", "⚙", 0.18, 2),
        "⚡": decay(0.10, "🔩"),
        "🔩": lindblad_out({"⚙": 0.12}),
        "⚙": lindblad_out({"🛠": 0.08}),
        "🛠": lindblad_out({"🧰": 0.08}),
        "🧰": decay(0.06, "🏷️"),
        "🏷️": decay(0.04, "🪨"),
    }
))

# ── Hearth Witches (discoverable: false) ───────────────────────────────────
new_biomes.append(make_biome(
    "Hearth Witches", "Hearth Witches", False,
    ["🌿","🕯","🫖","🥣","🧿","🌾"],
    [{"name":"Kitchen","pole_0":"🫖","pole_1":"🥣"},
     {"name":"Ward","pole_0":"🕯","pole_1":"🧿"},
     {"name":"Forage","pole_0":"🌿","pole_1":"🌾"}],
    ["folk magic","herbs","kitchen","protection"],
    {
        "🌾": lindblad_out({"🌿": 0.10}),
        "🌿": gated_lindblad("🫖", "🕯", 0.18, 1),
        "🫖": decay(0.12, "🥣"),
        "🥣": decay(0.10, "🧿"),
        "🧿": decay(0.08, "🕯"),
        "🕯": lindblad_out({"🌾": 0.06}),
    }
))

# ── Kilowatt Collective (discoverable: false) ──────────────────────────────
new_biomes.append(make_biome(
    "Kilowatt Collective", "Kilowatt Collective", False,
    ["🔋","🔌","⚙","⚡","🔥","🌫","🌋","🌞"],
    [{"name":"Power","pole_0":"🔋","pole_1":"⚙"},
     {"name":"Circuit","pole_0":"🔌","pole_1":"🌞"},
     {"name":"Storm","pole_0":"⚡","pole_1":"🌋"},
     {"name":"Heat","pole_0":"🔥","pole_1":"🌫"}],
    ["energy","geothermal","electrification"],
    {
        "🌋": gated_lindblad("🔥", "🌞", 0.18, 2),
        "🔥": decay(0.12, "🌫"),
        "🌫": decay(0.15, "⚡"),
        "⚡": gated_lindblad("🔋", "🔌", 0.18, 1),
        "🔋": lindblad_out({"⚙": 0.10}),
        "⚙": decay(0.08, "🔌"),
        "🔌": decay(0.06, "🌞"),
        "🌞": decay(0.04, "🌋"),
    }
))

# ── Ledger Bailiffs (discoverable: false) ──────────────────────────────────
new_biomes.append(make_biome(
    "Ledger Bailiffs", "Ledger Bailiffs", False,
    ["⚖","💰","📒","📘","🚔","💸"],
    [{"name":"Levy","pole_0":"💰","pole_1":"⚖"},
     {"name":"Writ","pole_0":"📒","pole_1":"🚔"},
     {"name":"Record","pole_0":"📘","pole_1":"💸"}],
    ["debt","law","enforcement","finance"],
    {
        "💰": gated_lindblad("⚖", "📒", 0.18, 2),
        "⚖": decay(0.12, "🚔"),
        "🚔": decay(0.15, "💸"),
        "💸": decay(0.10, "📘"),
        "📘": decay(0.08, "📒"),
        "📒": lindblad_out({"💰": 0.06}),
    }
))

# ── Market Spirits (discoverable: false) ───────────────────────────────────
new_biomes.append(make_biome(
    "Market Spirits", "Market Spirits", False,
    ["🐂","🐻","💰","📦","🏛️","🏚️"],
    [{"name":"Sentiment","pole_0":"🐂","pole_1":"🐻"},
     {"name":"Vault","pole_0":"🏛️","pole_1":"💰"},
     {"name":"Exchange","pole_0":"📦","pole_1":"🏚️"}],
    ["markets","sentiment","trade","speculation"],
    {
        "🐂": gated_lindblad("💰", "🏛️", 0.18, 2),
        "💰": decay(0.12, "📦"),
        "📦": decay(0.10, "🏚️"),
        "🏚️": decay(0.12, "🐻"),
        "🐻": decay(0.08, "🏛️"),
        "🏛️": decay(0.06, "🐂"),
    }
))

# ── Memory Merchants (discoverable: false) ─────────────────────────────────
new_biomes.append(make_biome(
    "Memory Merchants", "Memory Merchants", False,
    ["💰","💾","📼","🧩","🗝","🔮"],
    [{"name":"Memory","pole_0":"📼","pole_1":"🧩"},
     {"name":"Archive","pole_0":"💾","pole_1":"🗝"},
     {"name":"Foresight","pole_0":"💰","pole_1":"🔮"}],
    ["memory","information","trade","prophecy"],
    {
        "🔮": gated_lindblad("💰", "📼", 0.18, 2),
        "💰": decay(0.12, "💾"),
        "💾": decay(0.10, "🗝"),
        "🗝": decay(0.10, "🧩"),
        "🧩": decay(0.08, "📼"),
        "📼": decay(0.06, "🔮"),
    }
))

# ── Obsidian Will (discoverable: false) ────────────────────────────────────
new_biomes.append(make_biome(
    "Obsidian Will", "Obsidian Will", False,
    ["🪨","⛓","🧱","📘","🕴️","⚙","⚡","🔩"],
    [{"name":"Discipline","pole_0":"⛓","pole_1":"🪨"},
     {"name":"Foreman","pole_0":"🧱","pole_1":"🕴️"},
     {"name":"Mechanism","pole_0":"⚙","pole_1":"🔩"},
     {"name":"Doctrine","pole_0":"📘","pole_1":"⚡"}],
    ["order","discipline","industrial","doctrine"],
    {
        "📘": gated_lindblad("🕴️", "⛓", 0.18, 2),
        "🕴️": decay(0.12, "🧱"),
        "🧱": decay(0.10, "🪨"),
        "🪨": decay(0.12, "⛓"),
        "⛓": decay(0.10, "⚙"),
        "⚙": gated_lindblad("🔩", "⚡", 0.15, 1),
        "🔩": decay(0.08, "⚡"),
        "⚡": decay(0.04, "📘"),
    }
))

# ── Rocketwright Institute (discoverable: false) ───────────────────────────
new_biomes.append(make_biome(
    "Rocketwright Institute", "Rocketwright Institute", False,
    ["🚀","🔬","⚙","📋","💎","🌫"],
    [{"name":"Ascent","pole_0":"🚀","pole_1":"⚙"},
     {"name":"Specification","pole_0":"📋","pole_1":"🔬"},
     {"name":"Exhaust","pole_0":"💎","pole_1":"🌫"}],
    ["engineering","research","propulsion"],
    {
        "📋": gated_lindblad("🔬", "⚙", 0.18, 1),
        "🔬": decay(0.12, "💎"),
        "💎": gated_lindblad("🚀", "📋", 0.18, 2),
        "🚀": decay(0.15, "🌫"),
        "🌫": decay(0.10, "⚙"),
        "⚙": decay(0.08, "📋"),
    }
))

# ── Seedvault Curators (discoverable: false) ───────────────────────────────
new_biomes.append(make_biome(
    "Seedvault Curators", "Seedvault Curators", False,
    ["🌱","🔬","🧪","🧫","🧬","🌾"],
    [{"name":"Research","pole_0":"🧪","pole_1":"🧬"},
     {"name":"Cultivation","pole_0":"🌱","pole_1":"🌾"},
     {"name":"Lab","pole_0":"🧫","pole_1":"🔬"}],
    ["seeds","genetics","preservation","agriculture"],
    {
        "🌾": decay(0.12, "🌱"),
        "🌱": gated_lindblad("🧪", "🔬", 0.18, 2),
        "🧪": decay(0.12, "🧫"),
        "🧫": decay(0.10, "🧬"),
        "🧬": decay(0.08, "🔬"),
        "🔬": decay(0.06, "🌾"),
    }
))

# ── Starforge Reliquary (discoverable: false) ──────────────────────────────
new_biomes.append(make_biome(
    "Starforge Reliquary", "Starforge Reliquary", False,
    ["🌞","🌀","⚙","🚀","🌙","⚡"],
    [{"name":"Forgework","pole_0":"🌞","pole_1":"⚙"},
     {"name":"Orbit","pole_0":"🌀","pole_1":"🌙"},
     {"name":"Accelerate","pole_0":"🚀","pole_1":"⚡"}],
    ["stellar","forging","orbit","relic"],
    {
        "🌞": gated_lindblad("⚡", "🌙", 0.18, 2),
        "⚡": decay(0.12, "🚀"),
        "🚀": decay(0.10, "🌀"),
        "🌀": decay(0.12, "🌙"),
        "🌙": decay(0.10, "⚙"),
        "⚙": decay(0.06, "🌞"),
    }
))

# ── Station Lords (discoverable: false) ────────────────────────────────────
new_biomes.append(make_biome(
    "Station Lords", "Station Lords", False,
    ["🚀","🏢","💰","🛂"],
    [{"name":"Toll","pole_0":"🚀","pole_1":"💰"},
     {"name":"Berth","pole_0":"🏢","pole_1":"🛂"}],
    ["transit","toll","infrastructure","control"],
    {
        "🚀": gated_lindblad("💰", "🏢", 0.18, 2),
        "💰": decay(0.12, "🛂"),
        "🛂": decay(0.10, "🏢"),
        "🏢": decay(0.06, "🚀"),
    }
))

# ── Symphony Smiths (discoverable: false) ──────────────────────────────────
new_biomes.append(make_biome(
    "Symphony Smiths", "Symphony Smiths", False,
    ["🎵","🔊","🔨","⚙","📡","❄","🔇","💎"],
    [{"name":"Tone","pole_0":"🎵","pole_1":"🔊"},
     {"name":"Forge","pole_0":"🔨","pole_1":"⚙"},
     {"name":"Silence","pole_0":"🔇","pole_1":"❄"},
     {"name":"Signal","pole_0":"📡","pole_1":"💎"}],
    ["sound","forge","resonance","craft"],
    {
        "🎵": gated_lindblad("🔊", "📡", 0.18, 2),
        "🔊": decay(0.12, "🔨"),
        "🔨": gated_lindblad("⚙", "💎", 0.18, 1),
        "⚙": decay(0.10, "📡"),
        "📡": decay(0.08, "❄"),
        "❄":  decay(0.10, "🔇"),
        "🔇": decay(0.06, "💎"),
        "💎": decay(0.04, "🎵"),
    }
))

# ── Syndicate of Glass (discoverable: false) ───────────────────────────────
new_biomes.append(make_biome(
    "Syndicate of Glass", "Syndicate of Glass", False,
    ["💰","💎","🪞","🔍","🧊","🫧"],
    [{"name":"Mirror","pole_0":"🪞","pole_1":"🔍"},
     {"name":"Cold Coin","pole_0":"💎","pole_1":"🧊"},
     {"name":"Clarity","pole_0":"💰","pole_1":"🫧"}],
    ["glass","transparency","cold markets","speculation"],
    {
        "🫧": gated_lindblad("🪞", "💰", 0.18, 2),
        "🪞": decay(0.12, "🔍"),
        "🔍": decay(0.10, "💎"),
        "💎": decay(0.12, "🧊"),
        "🧊": decay(0.08, "💰"),
        "💰": decay(0.06, "🫧"),
    }
))

# ── The Gilded Legacy (discoverable: false) ────────────────────────────────
new_biomes.append(make_biome(
    "The Gilded Legacy", "The Gilded Legacy", False,
    ["⛏","💎","💰","✨","⚡","🪨"],
    [{"name":"Ore","pole_0":"💎","pole_1":"⛏"},
     {"name":"Spark","pole_0":"⚡","pole_1":"🪨"},
     {"name":"Gild","pole_0":"💰","pole_1":"✨"}],
    ["mining","heritage","wealth","dynasty"],
    {
        "🪨": gated_lindblad("💎", "⛏", 0.18, 2),
        "💎": decay(0.12, "✨"),
        "✨": decay(0.10, "⚡"),
        "⚡": decay(0.12, "💰"),
        "💰": decay(0.08, "⛏"),
        "⛏": decay(0.06, "🪨"),
    }
))

# ── The Scavenged Psithurism (discoverable: false) ─────────────────────────
new_biomes.append(make_biome(
    "The Scavenged Psithurism", "The Scavenged Psithurism", False,
    ["🧤","🗑","💀","🌾"],
    [{"name":"Gleaning","pole_0":"🧤","pole_1":"🌾"},
     {"name":"Carrion","pole_0":"💀","pole_1":"🗑"}],
    ["scavenging","decay","marginal","harvest"],
    {
        "🌾": decay(0.12, "🧤"),
        "🧤": gated_lindblad("🗑", "💀", 0.18, 1),
        "🗑": decay(0.10, "💀"),
        "💀": decay(0.08, "🌾"),
    }
))

# ── Umbra Exchange (discoverable: false) ───────────────────────────────────
new_biomes.append(make_biome(
    "Umbra Exchange", "Umbra Exchange", False,
    ["🗝","🕵️","💀","💰"],
    [{"name":"Leverage","pole_0":"🗝","pole_1":"💰"},
     {"name":"Shadow","pole_0":"🕵️","pole_1":"💀"}],
    ["shadow market","espionage","death","leverage"],
    {
        "💰": gated_lindblad("🗝", "🕵️", 0.18, 2),
        "🗝": decay(0.12, "🕵️"),
        "🕵️": decay(0.10, "💀"),
        "💀": decay(0.08, "💰"),
    }
))

# ── Forgewright Union (discoverable: false) ────────────────────────────────
new_biomes.append(make_biome(
    "Forgewright Union", "Forgewright Union", False,
    ["🔧","🔨","🔥","🪨","🔩","⚙"],
    [{"name":"Machinery","pole_0":"⚙","pole_1":"🔩"},
     {"name":"Magma","pole_0":"🔥","pole_1":"🪨"},
     {"name":"Tools","pole_0":"🔧","pole_1":"🔨"}],
    ["forge","labor","metalwork","industry"],
    {
        "🪨": decay(0.12, "🔥"),
        "🔥": gated_lindblad("🔨", "⚙", 0.18, 2),
        "🔨": decay(0.12, "🔧"),
        "🔧": gated_lindblad("🔩", "🔨", 0.15, 1),
        "🔩": decay(0.10, "⚙"),
        "⚙": decay(0.06, "🪨"),
    }
))

print(f"  Built {len(new_biomes)} new realized biomes")
biomes.extend(new_biomes)

# ─────────────────────────────────────────────────────────────────────────────
# 4. Add native factions to starter biomes
# ─────────────────────────────────────────────────────────────────────────────
print("\n=== Starter biome native_factions ===")
biome_map = {b["name"]: b for b in biomes}

patches = [
    ("Woodlot",      "Sacred Flame Keepers"),
    ("StarterForest","Sacred Flame Keepers"),
    ("Village",      "Gearwright Circle"),
]
for biome_name, faction_name in patches:
    b = biome_map.get(biome_name)
    if b is None:
        print(f"  WARNING: biome '{biome_name}' not found")
        continue
    nf = b.setdefault("native_factions", [])
    if faction_name not in nf:
        nf.append(faction_name)
        print(f"  {biome_name} += {faction_name}")
    else:
        print(f"  {biome_name}: {faction_name} already present")

# ─────────────────────────────────────────────────────────────────────────────
# Write back
# ─────────────────────────────────────────────────────────────────────────────
print("\n=== Writing files ===")
biome_io.save_factions(factions, trailing_newline=True)
print(f"  Wrote {FACTIONS_PATH}")
biome_io.save_biomes(biomes, trailing_newline=True)
print(f"  Wrote {BIOMES_PATH} ({len(biomes)} biomes total)")

print("\nDone.")
