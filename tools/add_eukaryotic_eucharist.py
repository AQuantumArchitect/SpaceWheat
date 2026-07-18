#!/usr/bin/env python3
"""Add the EukaryoticEucharist biome — a cluster of caste-icons from the sibling
Eukaryotic Eucharist ecology (a depth-stratified microbial water column), whose
castes breathe at GOLDEN-RATIO periods (drivers at φ-ladder frequencies: a KAM /
maximally non-resonant set that never phase-locks).

Idempotent: re-running removes any prior copies of these entries first. Emojis are
written with explicit \\U escapes so no FE0F variation selector can slip in.

Adds:
  factions.json : 3 factions (Sunlit Canopy / Twilight Recyclers / Toxic Abyss)
  icons.json    : 7 caste pair-icons, each with a φ-ladder self-energy driver
  biomes.json   : 1 biome (closed Lindbladian matter loop + 7-site plot layout)
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAC = os.path.join(ROOT, "Core/Factions/data/factions.json")
ICO = os.path.join(ROOT, "Core/Factions/data/icons.json")
BIO = os.path.join(ROOT, "Core/Biomes/data/biomes.json")

# ── bare atoms (explicit codepoints; no FE0F) ────────────────────────────────
HERB="\U0001F33F"; LEAF="\U0001F342"; YELLOW="\U0001F7E1"; DOWN="\U0001F53B"
MICROBE="\U0001F9A0"; SKULL="\U0001F480"; BRICK="\U0001F9F1"; WAVE="\U0001F30A"
SKULLX="☠"; TUBE="\U0001F9EA"; SHARK="\U0001F988"; NEWMOON="\U0001F311"
JELLY="\U0001FABC"; BLACKCIRC="⚫"; SINK="\U0001F5D1"

PHI = (1 + 5 ** 0.5) / 2
T0 = 40.0  # fundamental breathing period (game seconds); driver freq = 1/period

FACTIONS = [
    {
        "name": "Sunlit Canopy",
        "description": "The lit surface shelf: photosynthetic blooms that fatten in the light and the grazers "
                       "that graze them. The providing base of the whole column, a green prismatic canopy over "
                       "an eternal day/night sway.",
        "domain": "Nature", "ring": "second", "motto": "Bask, fatten, be eaten.",
        "tags": ["ecosystem", "surface", "photosynthesis", "producer"],
        "bits": [0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0],
        "cloud": [HERB, LEAF, YELLOW, DOWN],
        "icons": [
            {"name": "EuPhotobloom", "pole_0": HERB, "pole_1": LEAF},
            {"name": "EuGrazer", "pole_0": YELLOW, "pole_1": DOWN},
        ],
    },
    {
        "name": "Twilight Recyclers",
        "description": "The mid-column recyclers: anaerobic scavenger swarms and aerobic walls that turn the "
                       "sinking rain of detritus back into biomass. Common, fluid, quick to bloom and quick to starve.",
        "domain": "Decay", "ring": "second", "motto": "Nothing falls for free.",
        "tags": ["ecosystem", "twilight", "scavenger", "recycler"],
        "bits": [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
        "cloud": [MICROBE, SKULL, BRICK, WAVE],
        "icons": [
            {"name": "EuAnaerobe", "pole_0": MICROBE, "pole_1": SKULL},
            {"name": "EuAerobicWall", "pole_0": BRICK, "pole_1": WAVE},
        ],
    },
    {
        "name": "Toxic Abyss",
        "description": "The deep floor: a toxic bloom that hoards venom, an apex hunter that lurks the dark, and "
                       "the abyssal drifter that carries the last of the matter back to the sink. Elite, cosmic, "
                       "subtle, focused — the eternal deep.",
        "domain": "Boundary", "ring": "third", "motto": "The deep keeps what it takes.",
        "tags": ["ecosystem", "abyss", "predator", "toxic"],
        "bits": [1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 1],
        "cloud": [SKULLX, TUBE, SHARK, NEWMOON, JELLY, BLACKCIRC],
        "icons": [
            {"name": "EuToxicBloom", "pole_0": SKULLX, "pole_1": TUBE},
            {"name": "EuAbyssHunter", "pole_0": SHARK, "pole_1": NEWMOON},
            {"name": "EuAbyssDrifter", "pole_0": JELLY, "pole_1": BLACKCIRC},
        ],
    },
]

# φ-ladder drivers: freq = 1/period, periods = [T0/φ, T0, T0·φ, T0·φ², T0·φ³] (the KAM breathing set).
def drv(period, typ, phase=0.0, amp=1.0):
    return {"amp": amp, "freq": round(1.0 / period, 5), "phase": phase, "type": typ}

ICONS = [
    # name           pole_0    pole_1     se0  se1  rabi  h_couplings                driver
    ("EuGrazer",      YELLOW,   DOWN,      1.0, 0.8, 0.35, {HERB: 0.25},              drv(T0, "cosine")),                 # rung 0
    ("EuAnaerobe",    MICROBE,  SKULL,     1.0, 0.8, 0.35, {LEAF: 0.2, SKULL: 0.15},  drv(T0 / PHI, "sine")),             # -1 (fastest)
    ("EuAerobicWall", BRICK,    WAVE,      1.0, 0.8, 0.35, {MICROBE: 0.15},           drv(T0 * PHI, "cosine")),           # +1
    ("EuAbyssHunter", SHARK,    NEWMOON,   1.0, 0.8, 0.35, {BRICK: 0.2, YELLOW: 0.1}, drv(T0 * PHI ** 2, "sine")),        # +2
    ("EuAbyssDrifter", JELLY,   BLACKCIRC, 1.0, 0.8, 0.35, {SKULLX: 0.15},            drv(T0 * PHI ** 3, "cosine")),      # +3
    ("EuPhotobloom",  HERB,     LEAF,      1.0, 0.8, 0.35, {},                        drv(T0, "cosine", phase=3.14159, amp=0.6)),  # canopy day-cycle, antiphase (steady base)
    ("EuToxicBloom",  SKULLX,   TUBE,      1.0, 0.8, 0.35, {SHARK: 0.1},              drv(T0 * PHI ** 3, "sine", amp=0.4)),        # slow deep (steady base)
]

def icon_obj(name, p0, p1, se0, se1, rabi, hcoup, driver):
    return {"name": name, "pole_0": p0, "pole_1": p1, "self_energy_0": se0, "self_energy_1": se1,
            "rabi_coupling": rabi, "hamiltonian_couplings": hcoup, "energy_couplings": {}, "driver": driver}

BIOME = {
    "name": "EukaryoticEucharist",
    "description": "A depth-stratified microbial water column ported from the Eukaryotic Eucharist ecology: a calm "
                   "photosynthetic canopy and a toxic deep floor, with grazers, scavengers and predators breathing "
                   "between them at golden-ratio periods (a KAM set that never phase-locks). Matter closes — the "
                   "abyssal drifter returns it to the sink and photosynthesis pumps it back up.",
    "image_path": "res://Assets/Biomes/Eukaryotic_Eucharist.png",
    "discovered": False,
    "plot_layout": [
        {"x": 0.20, "y": 0.12}, {"x": 0.50, "y": 0.26}, {"x": 0.35, "y": 0.42}, {"x": 0.65, "y": 0.52},
        {"x": 0.50, "y": 0.66}, {"x": 0.36, "y": 0.80}, {"x": 0.62, "y": 0.90},
    ],
    "emojis": [HERB, LEAF, YELLOW, DOWN, MICROBE, SKULL, BRICK, WAVE, SKULLX, TUBE, SHARK, NEWMOON, JELLY, BLACKCIRC],
    "native_factions": ["Sunlit Canopy", "Twilight Recyclers", "Toxic Abyss"],
    "tags": ["ecosystem", "microbial", "depth", "eukaryotic-eucharist"],
    "atom_components": {
        HERB:    {"lindblad_incoming": {SINK: 0.20}, "decay": {"rate": 0.04, "target": LEAF}},   # photosynthesis pump + senescence
        LEAF:    {"decay": {"rate": 0.05, "target": MICROBE}},                                    # detritus feeds microbes
        YELLOW:  {"decay": {"rate": 0.06, "target": LEAF}},                                       # grazers shed to detritus
        MICROBE: {"decay": {"rate": 0.04, "target": HERB}, "lindblad_incoming": {SKULL: 0.01}},   # remineralize to biomass
        BRICK:   {"decay": {"rate": 0.03, "target": WAVE}},
        WAVE:    {"decay": {"rate": 0.05, "target": MICROBE}},
        SHARK:   {"decay": {"rate": 0.02, "target": SKULL}},                                      # predator death -> carcass
        SKULL:   {"decay": {"rate": 0.05, "target": MICROBE}},                                    # carcasses -> microbes
        SKULLX:  {"lindblad_incoming": {SINK: 0.05}, "decay": {"rate": 0.04, "target": TUBE}},
        TUBE:    {"decay": {"rate": 0.05, "target": SINK}},
        JELLY:   {"decay": {"rate": 0.03, "target": SINK}},                                       # abyssal drifter returns matter to the sink
    },
    "regime": "closed",
}


def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

def dump(p, data):
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

def main():
    facs = load(FAC)
    fac_names = {f["name"] for f in FACTIONS}
    facs = [f for f in facs if f.get("name") not in fac_names]
    facs.extend(FACTIONS)
    dump(FAC, facs)

    icos = load(ICO)
    ico_names = {i[0] for i in ICONS}
    icos = [i for i in icos if i.get("name") not in ico_names]
    icos.extend(icon_obj(*spec) for spec in ICONS)
    dump(ICO, icos)

    bios = load(BIO)
    bios = [b for b in bios if b.get("name") != BIOME["name"]]
    bios.append(BIOME)
    dump(BIO, bios)

    print(f"factions: +{len(FACTIONS)}  icons: +{len(ICONS)}  biome: +1 ({BIOME['name']})")
    print("emojis:", " ".join(BIOME["emojis"]))

if __name__ == "__main__":
    main()
