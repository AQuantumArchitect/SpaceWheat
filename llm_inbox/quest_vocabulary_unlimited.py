#!/usr/bin/env python3
"""
SpaceWheat UNLIMITED Quest Vocabulary
~400 atoms → BILLIONS of unique quests
Compound verbs, narrative arcs, conditions, stakes, mythological depth
"""

import random
from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple

# =============================================================================
# EXPANDED VERBS (36 total - doubled!)
# =============================================================================

VERBS = {
    # Physical/Direct (bits 5=0, 7=0)
    "harvest":     {"affinity": [None,0,0,None,0,0,None,0,None,None,None,None], "emoji": "🌾", "transitive": True},
    "deliver":     {"affinity": [None,0,None,None,0,0,None,0,None,None,None,None], "emoji": "📦", "transitive": True},
    "defend":      {"affinity": [None,0,None,None,0,0,0,0,None,None,None,None], "emoji": "🛡️", "transitive": True},
    "destroy":     {"affinity": [None,0,None,None,0,0,None,0,0,None,None,None], "emoji": "💥", "transitive": True},
    "build":       {"affinity": [1,0,None,None,1,0,0,0,1,None,1,None], "emoji": "🏗️", "transitive": True},
    "repair":      {"affinity": [1,0,0,0,0,0,None,0,1,None,None,None], "emoji": "🔧", "transitive": True},
    "forge":       {"affinity": [1,0,None,None,1,0,0,0,1,None,1,1], "emoji": "⚒️", "transitive": True},
    "shatter":     {"affinity": [0,0,None,None,0,0,0,0,0,None,0,None], "emoji": "💔", "transitive": True},
    "bury":        {"affinity": [1,0,0,0,1,0,0,0,None,None,0,None], "emoji": "⚰️", "transitive": True},
    "unearth":     {"affinity": [0,0,None,None,0,0,None,0,None,None,0,None], "emoji": "⛏️", "transitive": True},
    
    # Mental/Subtle (bits 5=1, 7=1)
    "negotiate":   {"affinity": [None,None,1,None,None,1,None,1,None,None,None,None], "emoji": "🤝", "transitive": False},
    "investigate": {"affinity": [None,None,None,None,1,1,None,1,None,None,0,None], "emoji": "🔍", "transitive": True},
    "decode":      {"affinity": [1,1,None,None,1,1,None,1,None,None,None,1], "emoji": "🔐", "transitive": True},
    "observe":     {"affinity": [None,1,None,None,1,1,None,1,None,None,0,None], "emoji": "👁️", "transitive": True},
    "predict":     {"affinity": [0,1,1,1,1,1,1,1,None,None,None,1], "emoji": "🔮", "transitive": True},
    "remember":    {"affinity": [1,1,None,None,1,1,None,1,None,None,0,1], "emoji": "🧠", "transitive": True},
    "forget":      {"affinity": [0,1,None,None,0,1,1,1,0,None,0,0], "emoji": "🌫️", "transitive": True},
    "dream":       {"affinity": [0,1,None,1,1,1,1,1,None,1,0,None], "emoji": "💭", "transitive": False},
    "scheme":      {"affinity": [1,None,1,None,1,1,None,1,0,None,1,1], "emoji": "🎯", "transitive": False},
    
    # Mystical (bit 1=1)
    "sanctify":    {"affinity": [1,1,1,None,1,1,0,None,1,None,1,None], "emoji": "✨", "transitive": True},
    "transform":   {"affinity": [None,1,None,None,None,1,1,None,None,1,None,None], "emoji": "🔄", "transitive": True},
    "commune":     {"affinity": [0,1,None,1,1,1,1,1,None,1,0,None], "emoji": "🌌", "transitive": False},
    "banish":      {"affinity": [None,1,1,None,0,1,0,0,0,None,1,None], "emoji": "⚡", "transitive": True},
    "resurrect":   {"affinity": [0,1,1,None,1,1,1,None,1,1,0,None], "emoji": "🌅", "transitive": True},
    "bind":        {"affinity": [1,1,None,None,1,1,0,1,None,None,1,1], "emoji": "🔗", "transitive": True},
    "unbind":      {"affinity": [0,1,None,None,0,1,1,1,1,None,0,0], "emoji": "🔓", "transitive": True},
    "consecrate":  {"affinity": [1,1,1,1,1,1,0,0,1,1,1,1], "emoji": "🕯️", "transitive": True},
    "desecrate":   {"affinity": [0,1,0,None,0,1,0,1,0,0,0,0], "emoji": "💀", "transitive": True},
    
    # Economic (bit 8)
    "consume":     {"affinity": [None,None,None,None,0,None,None,None,0,None,None,None], "emoji": "🍽️", "transitive": True},
    "extract":     {"affinity": [None,0,None,None,None,0,None,0,0,None,None,None], "emoji": "⛏️", "transitive": True},
    "distribute":  {"affinity": [1,None,None,None,None,None,None,None,1,None,1,0], "emoji": "🎁", "transitive": True},
    "hoard":       {"affinity": [1,0,1,0,1,None,0,1,0,None,1,1], "emoji": "💎", "transitive": True},
    "sacrifice":   {"affinity": [None,1,None,None,None,None,None,None,1,1,None,None], "emoji": "🩸", "transitive": True},
    "tithe":       {"affinity": [1,1,0,None,1,1,0,0,1,None,1,None], "emoji": "⚖️", "transitive": True},
    
    # Cosmic (bit 3=1)
    "align":       {"affinity": [1,1,None,1,1,1,None,None,None,None,None,1], "emoji": "🌟", "transitive": True},
    "scatter":     {"affinity": [0,None,None,1,0,None,1,None,None,1,0,0], "emoji": "🌪️", "transitive": True},
}

# =============================================================================
# COMPOUND VERB CONNECTORS (12)
# =============================================================================

VERB_CONNECTORS = {
    "sequential": ["then", "and then", "before you", "after which"],
    "conditional": ["only if you first", "but only after", "provided you"],
    "alternative": ["or else", "or instead", "failing that"],
    "simultaneous": ["while also", "as you", "even as"],
}

# =============================================================================
# EXPANDED BIT MODIFIERS (48 pairs = 96 words)
# =============================================================================

BIT_ADVERBS = {
    0: ["chaotically", "methodically"],
    1: ["physically", "spiritually"],
    2: ["humbly", "nobly"],
    3: ["locally", "universally"],
    4: ["swiftly", "patiently"],
    5: ["forcefully", "thoughtfully"],
    6: ["rigidly", "adaptively"],
    7: ["openly", "covertly"],
    8: ["greedily", "generously"],
    9: ["plainly", "elaborately"],
    10: ["naturally", "deliberately"],
    11: ["broadly", "precisely"],
}

BIT_ADJECTIVES = {
    0: ["wild", "ordered"],
    1: ["crude", "sacred"],
    2: ["common", "precious"],
    3: ["nearby", "distant"],
    4: ["urgent", "ancient"],
    5: ["heavy", "ethereal"],
    6: ["crystalline", "flowing"],
    7: ["obvious", "hidden"],
    8: ["depleted", "abundant"],
    9: ["plain", "radiant"],
    10: ["natural", "constructed"],
    11: ["scattered", "concentrated"],
}

# NEW: Intensity modifiers
BIT_INTENSIFIERS = {
    0: ["barely", "utterly"],
    1: ["weakly", "overwhelmingly"],
    2: ["slightly", "completely"],
    3: ["somewhat", "absolutely"],
    4: ["nearly", "perfectly"],
    5: ["partially", "fully"],
}

# =============================================================================
# TEMPORAL MODIFIERS (24)
# =============================================================================

TIME_OF_DAY = ["at dawn", "at high noon", "at dusk", "at midnight", "under the stars", "as the sun bleeds"]
MOON_PHASES = ["under the new moon", "under the waxing crescent", "under the full moon", "under the waning gibbous", "when the moon is dark", "between lunar tides"]
SEASONS = ["in the planting season", "during the harvest", "in the fallow time", "when winter bites", "as spring awakens", "in the dying days"]
COSMIC_TIMES = ["when the stars align", "during the conjunction", "at the solstice", "during the eclipse", "in the hour of reckoning", "before the cosmic tide turns"]

# =============================================================================
# SPATIAL MODIFIERS (30)
# =============================================================================

DIRECTIONS = ["to the north", "to the south", "eastward", "westward", "above", "below", "beyond the horizon", "at the crossroads"]
DISTANCES = ["nearby", "at the edge of the biome", "in the deep reaches", "at the boundary", "in the heart of", "at the forgotten corners"]
TERRAINS = ["across the wheat fields", "through the fungal networks", "over the broken machinery", "beneath the canopy", "among the ruins", "within the living walls"]

# =============================================================================
# RELATIONSHIP MODIFIERS (20)
# =============================================================================

RELATIONSHIPS = {
    "ally": ["for your sworn ally", "alongside your brothers", "with those who share your banner"],
    "rival": ["against your bitter rival", "to spite your enemies", "before your competitors"],
    "neutral": ["for the unaligned", "among the uncommitted", "with those who watch"],
    "self": ["for yourself alone", "for your own glory", "to prove your worth"],
    "faction": ["for the greater cause", "in service to the collective", "as duty demands"],
    "cosmic": ["for the universe itself", "as reality requires", "because existence wills it"],
}

# =============================================================================
# STAKES & CONSEQUENCES (36)
# =============================================================================

SUCCESS_STAKES = {
    "minor": ["and earn a token of appreciation", "for modest recognition", "to gain standing"],
    "moderate": ["and claim the promised reward", "to unlock new opportunities", "for significant favor"],
    "major": ["and reshape the balance of power", "to earn legendary status", "for transformative influence"],
    "cosmic": ["and alter the fabric of reality", "to achieve transcendence", "for eternal remembrance"],
}

FAILURE_STAKES = {
    "minor": ["or face mild disappointment", "or lose a small advantage", "or be forgotten"],
    "moderate": ["or suffer lasting consequences", "or make powerful enemies", "or lose what you've built"],
    "major": ["or bring ruin upon yourself", "or doom those who trusted you", "or invite catastrophe"],
    "cosmic": ["or unravel existence itself", "or damn all you hold dear", "or feed the eternal void"],
}

# =============================================================================
# SECRET OBJECTIVES (24)
# =============================================================================

SECRET_OBJECTIVES = [
    "// hidden: complete without harming any creature",
    "// hidden: accomplish using only found materials",
    "// hidden: finish before the second bell",
    "// hidden: leave no trace of your passage",
    "// hidden: ensure a witness survives",
    "// hidden: collect the tears of the defeated",
    "// hidden: speak the old words at completion",
    "// hidden: preserve the smallest fragment",
    "// hidden: complete in reverse order",
    "// hidden: accomplish while carrying a burden",
    "// hidden: finish with empty hands",
    "// hidden: complete under observation",
    "// hidden: achieve while another quest runs",
    "// hidden: accomplish during a storm",
    "// hidden: complete in perfect silence",
    "// hidden: finish with an offering",
    "// hidden: achieve through misdirection",
    "// hidden: complete without tools",
    "// hidden: accomplish at a sacred site",
    "// hidden: finish while hungry",
    "// hidden: complete during communion",
    "// hidden: achieve through delegation",
    "// hidden: accomplish in borrowed form",
    "// hidden: complete the mirror version",
]

# =============================================================================
# MYTHOLOGICAL/ARCHETYPE REFERENCES (32)
# =============================================================================

ARCHETYPE_INVOCATIONS = {
    "phoenix": ["as the Phoenix demands rebirth", "in the flames of transformation", "through destruction comes renewal"],
    "sage": ["as the Sage would counsel", "with wisdom accumulated", "through contemplation achieved"],
    "destroyer": ["as the Destroyer hungers", "through annihilation's grace", "by ending what must end"],
    "martyr": ["as the Martyr sacrificed", "through willing surrender", "by giving what cannot return"],
    "alchemist": ["as the Alchemist transmutes", "through fundamental change", "by becoming what you seek"],
    "witch": ["as the Witch knows", "through hidden pathways", "by ways others cannot see"],
    "mourner": ["as the Mourner grieves", "through acceptance of loss", "by honoring what was"],
    "visionary": ["as the Visionary foresaw", "through eyes that see beyond", "by knowing before knowing"],
}

BLOCH_SPHERE_REFS = [
    "along the axis of certainty", "perpendicular to fate", "at the quantum crossroads",
    "where probability collapses", "in superposition of outcomes", "entangled with destiny",
    "at the eigenvalue threshold", "through the measurement gate", "in coherent alignment",
]

MATHEMATICAL_FLAVOR = [
    "by the Berry phase accumulated", "through topological protection", "via knot-theoretic binding",
    "using fiber bundle transport", "through solitonic propagation", "via Hamiltonian evolution",
    "by strange attractor guidance", "through manifold navigation", "via categorical transformation",
]

# =============================================================================
# ENVIRONMENTAL CONDITIONS (24)
# =============================================================================

WEATHER_CONDITIONS = [
    "while the spore clouds drift", "during the electric storms", "as acid rain falls",
    "in the golden mist", "through the frozen winds", "under the burning sky",
]

BIOME_STATES = [
    "while the fields flourish", "during the blight", "as growth accelerates",
    "in times of abundance", "through the barren season", "when decay spreads",
]

MARKET_CONDITIONS = [
    "while prices peak", "during the crash", "as speculation runs wild",
    "in times of scarcity", "through the boom", "when trade flows freely",
]

POLITICAL_CONDITIONS = [
    "while the throne sits empty", "during the succession crisis", "as factions war",
    "in times of peace", "through the uprising", "when the old order crumbles",
]

# =============================================================================
# NARRATIVE ARC TEMPLATES (12)
# =============================================================================

NARRATIVE_ARCS = {
    "origin": {
        "intro": "This is how it begins:",
        "frame": "{verb} {quantity} {adj} {resource} {location}",
        "outro": "And so the first step is taken.",
    },
    "escalation": {
        "intro": "The situation demands more:",
        "frame": "{adverb} {verb} {quantity} {resource} {condition}",
        "outro": "But this is only the beginning.",
    },
    "crisis": {
        "intro": "Everything hangs in the balance:",
        "frame": "{verb} {resource} {urgency} {stakes}",
        "outro": "There will be no second chances.",
    },
    "revelation": {
        "intro": "The truth becomes clear:",
        "frame": "{verb} the {adj} {resource} {archetype_ref}",
        "outro": "Now you understand.",
    },
    "transformation": {
        "intro": "You are not what you were:",
        "frame": "Transform {resource} into {resource2} {math_ref}",
        "outro": "The change is irreversible.",
    },
    "sacrifice": {
        "intro": "Something must be given:",
        "frame": "Sacrifice {quantity} {resource} {relationship} {stakes}",
        "outro": "The price is paid.",
    },
    "triumph": {
        "intro": "Victory is within reach:",
        "frame": "{verb} {quantity} {adj} {resource} {time} {stakes}",
        "outro": "Glory awaits.",
    },
    "fall": {
        "intro": "All things end:",
        "frame": "{adverb} {verb} the last {resource} {cosmic_time}",
        "outro": "And so it passes.",
    },
    "cycle": {
        "intro": "As it was, so it shall be:",
        "frame": "{verb} {resource} then {verb2} {resource2} {bloch_ref}",
        "outro": "The wheel turns.",
    },
    "mystery": {
        "intro": "Some things cannot be spoken:",
        "frame": "{adverb} {verb} {adj} {resource} {secret}",
        "outro": "?",
    },
    "compound": {
        "intro": "The path is complex:",
        "frame": "{verb} {resource} {connector} {verb2} {resource2} {condition}",
        "outro": "Each step matters.",
    },
    "choice": {
        "intro": "You must decide:",
        "frame": "{verb} {resource} or {verb2} {resource2} - {stakes}",
        "outro": "Choose wisely.",
    },
}

# =============================================================================
# FACTION VOICES (expanded to 32 unique voices!)
# =============================================================================

FACTION_VOICES = {
    # Imperial Powers
    "Carrion Throne": {
        "prefix": "BY IMPERIAL DECREE:", "suffix": "for the eternal Throne.", 
        "failure": "The Throne's patience wears thin.", "tone": "absolute",
        "forbidden_verbs": ["desecrate", "unbind"], "favored_verbs": ["tithe", "consecrate"],
    },
    "House of Thorns": {
        "prefix": "The roses whisper:", "suffix": "as the thorns demand.",
        "failure": "Your blood will feed the garden.", "tone": "elegant_menace",
        "forbidden_verbs": ["shatter"], "favored_verbs": ["bind", "scheme"],
    },
    "Granary Guilds": {
        "prefix": "Per Guild charter:", "suffix": "as per regulation.",
        "failure": "Your charter is revoked.", "tone": "bureaucratic",
        "forbidden_verbs": ["desecrate", "scatter"], "favored_verbs": ["harvest", "tithe", "hoard"],
    },
    "Station Lords": {
        "prefix": "From the orbital throne:", "suffix": "by void-right.",
        "failure": "Atmosphere privileges revoked.", "tone": "cold_authority",
        "forbidden_verbs": [], "favored_verbs": ["align", "distribute"],
    },
    
    # Working Guilds
    "Obsidian Will": {
        "prefix": "The Will demands:", "suffix": "in obsidian we trust.",
        "failure": "Your weakness is noted.", "tone": "stern",
        "forbidden_verbs": ["dream", "forget"], "favored_verbs": ["forge", "build", "repair"],
    },
    "Millwright's Union": {
        "prefix": "Union directive:", "suffix": "solidarity forever.",
        "failure": "Your union card is suspended.", "tone": "collective",
        "forbidden_verbs": ["hoard", "scheme"], "favored_verbs": ["repair", "build", "distribute"],
    },
    "Tinker Team": {
        "prefix": "Hey, quick job:", "suffix": "parts are parts!",
        "failure": "Eh, we'll figure something out.", "tone": "casual",
        "forbidden_verbs": ["consecrate", "sanctify"], "favored_verbs": ["repair", "extract", "unearth"],
    },
    "Seamstress Syndicate": {
        "prefix": "Woven into the pattern:", "suffix": "thread by thread.",
        "failure": "The pattern unravels.", "tone": "intricate",
        "forbidden_verbs": ["shatter", "scatter"], "favored_verbs": ["bind", "decode", "remember"],
    },
    "Gravedigger's Union": {
        "prefix": "From the deep places:", "suffix": "dust to dust.",
        "failure": "The dead remember.", "tone": "solemn",
        "forbidden_verbs": ["resurrect"], "favored_verbs": ["bury", "remember", "commune"],
    },
    "Symphony Smiths": {
        "prefix": "In harmonic resonance:", "suffix": "as the frequencies demand.",
        "failure": "Dissonance spreads.", "tone": "musical",
        "forbidden_verbs": ["shatter", "scatter"], "favored_verbs": ["forge", "align", "transform"],
    },
    
    # Mystic Orders
    "Keepers of Silence": {
        "prefix": "...", "suffix": "...",
        "failure": "The silence breaks.", "tone": "minimal",
        "forbidden_verbs": [], "favored_verbs": ["observe", "remember", "commune"],
    },
    "Sacred Flame Keepers": {
        "prefix": "By the eternal flame:", "suffix": "burn bright, burn true.",
        "failure": "The flame gutters.", "tone": "fervent",
        "forbidden_verbs": ["desecrate", "forget"], "favored_verbs": ["sanctify", "consecrate", "sacrifice"],
    },
    "Iron Confessors": {
        "prefix": "Confess and be absolved:", "suffix": "flesh and steel are one.",
        "failure": "Your sins remain.", "tone": "religious_mechanical",
        "forbidden_verbs": ["desecrate"], "favored_verbs": ["repair", "transform", "bind"],
    },
    "Yeast Prophets": {
        "prefix": "The cultures have spoken:", "suffix": "fermentation is transformation.",
        "failure": "The batch is ruined.", "tone": "mystical_practical",
        "forbidden_verbs": [], "favored_verbs": ["transform", "predict", "commune"],
    },
    
    # Merchants
    "Syndicate of Glass": {
        "prefix": "Per crystalline contract:", "suffix": "transparency in all dealings.",
        "failure": "The crystal clouds.", "tone": "formal_mercantile",
        "forbidden_verbs": ["desecrate"], "favored_verbs": ["negotiate", "extract", "hoard"],
    },
    "Memory Merchants": {
        "prefix": "From the archives of experience:", "suffix": "memories have value.",
        "failure": "This memory is forfeit.", "tone": "intellectual_commerce",
        "forbidden_verbs": ["forget"], "favored_verbs": ["remember", "extract", "decode"],
    },
    "Bone Merchants": {
        "prefix": "Fresh stock needed:", "suffix": "everything has a buyer.",
        "failure": "Deal's off.", "tone": "pragmatic_dark",
        "forbidden_verbs": ["sanctify", "consecrate"], "favored_verbs": ["extract", "consume", "unearth"],
    },
    "Nexus Wardens": {
        "prefix": "Across all thresholds:", "suffix": "the crossroads remember.",
        "failure": "The ways close.", "tone": "liminal",
        "forbidden_verbs": [], "favored_verbs": ["negotiate", "commune", "align"],
    },
    
    # Militant Orders
    "Iron Shepherds": {
        "prefix": "SHEPHERD'S COMMAND:", "suffix": "protect the flock.",
        "failure": "The wolves circle.", "tone": "military_pastoral",
        "forbidden_verbs": [], "favored_verbs": ["defend", "deliver", "sacrifice"],
    },
    "Brotherhood of Ash": {
        "prefix": "By ash and honor:", "suffix": "until only ash remains.",
        "failure": "Dishonor upon you.", "tone": "warrior_code",
        "forbidden_verbs": ["scheme", "negotiate"], "favored_verbs": ["destroy", "sacrifice", "defend"],
    },
    "Children of the Ember": {
        "prefix": "THE FIRE RISES:", "suffix": "burn it all down!",
        "failure": "The ember fades.", "tone": "revolutionary",
        "forbidden_verbs": ["hoard", "tithe"], "favored_verbs": ["destroy", "scatter", "unbind"],
    },
    "Order of the Crimson Scale": {
        "prefix": "Justice demands:", "suffix": "the scales must balance.",
        "failure": "Imbalance spreads.", "tone": "judicial",
        "forbidden_verbs": ["desecrate"], "favored_verbs": ["investigate", "banish", "bind"],
    },
    
    # Scavengers
    "Rust Fleet": {
        "prefix": "Salvage opportunity:", "suffix": "waste not.",
        "failure": "Opportunity lost.", "tone": "practical_scavenger",
        "forbidden_verbs": ["consecrate"], "favored_verbs": ["extract", "repair", "unearth"],
    },
    "Locusts": {
        "prefix": "FEEDING TIME:", "suffix": "leave nothing.",
        "failure": "Still hungry.", "tone": "swarm",
        "forbidden_verbs": ["distribute", "sacrifice"], "favored_verbs": ["consume", "extract", "scatter"],
    },
    "Cartographers": {
        "prefix": "Uncharted territory:", "suffix": "the map expands.",
        "failure": "Lost in unmapped space.", "tone": "explorer",
        "forbidden_verbs": [], "favored_verbs": ["investigate", "observe", "decode"],
    },
    
    # Horror Cults
    "Laughing Court": {
        "prefix": "HA HA HA:", "suffix": "ISN'T IT FUNNY?",
        "failure": "The laughter stops. Briefly.", "tone": "manic",
        "forbidden_verbs": [], "favored_verbs": ["scatter", "desecrate", "transform"],
    },
    "Cult of the Drowned Star": {
        "prefix": "From the depths beyond:", "suffix": "THE STAR SEES ALL.",
        "failure": "Its gaze turns elsewhere.", "tone": "cosmic_horror",
        "forbidden_verbs": ["sanctify"], "favored_verbs": ["commune", "sacrifice", "drown"],
    },
    "Chorus of Oblivion": {
        "prefix": "∅ → ∅:", "suffix": "∅",
        "failure": "∅", "tone": "nihilistic",
        "forbidden_verbs": ["build", "repair"], "favored_verbs": ["destroy", "scatter", "forget"],
    },
    "Flesh Architects": {
        "prefix": "The design requires:", "suffix": "beauty through transformation.",
        "failure": "The design is flawed.", "tone": "artistic_horror",
        "forbidden_verbs": [], "favored_verbs": ["transform", "bind", "forge"],
    },
    
    # Defensive Communities
    "Void Serfs": {
        "prefix": "The masters command:", "suffix": "we obey.",
        "failure": "Punishment follows.", "tone": "subjugated",
        "forbidden_verbs": ["unbind", "scheme"], "favored_verbs": ["harvest", "tithe", "deliver"],
    },
    "Clan of the Hidden Root": {
        "prefix": "For the root-home:", "suffix": "we grow, we endure.",
        "failure": "The roots wither.", "tone": "defensive_organic",
        "forbidden_verbs": ["scatter", "desecrate"], "favored_verbs": ["defend", "build", "harvest"],
    },
    "Veiled Sisters": {
        "prefix": "Beneath the veil:", "suffix": "unseen, unheard, unforgotten.",
        "failure": "The veil lifts.", "tone": "secretive",
        "forbidden_verbs": [], "favored_verbs": ["observe", "decode", "scheme"],
    },
    "Terrarium Collective": {
        "prefix": "For the closed system:", "suffix": "nothing wasted.",
        "failure": "The cycle breaks.", "tone": "sustainable",
        "forbidden_verbs": ["scatter", "consume"], "favored_verbs": ["distribute", "repair", "transform"],
    },
    
    # Cosmic Manipulators
    "Resonance Dancers": {
        "prefix": "In harmonic motion:", "suffix": "the dance continues.",
        "failure": "Discord spreads.", "tone": "performative",
        "forbidden_verbs": [], "favored_verbs": ["align", "transform", "commune"],
    },
    "Causal Shepherds": {
        "prefix": "The timeline requires:", "suffix": "cause precedes effect.",
        "failure": "Paradox threatens.", "tone": "temporal",
        "forbidden_verbs": [], "favored_verbs": ["predict", "align", "observe"],
    },
    "Empire Shepherds": {
        "prefix": "For the herd-cosmos:", "suffix": "we guide the stars.",
        "failure": "The herd scatters.", "tone": "cosmic_pastoral",
        "forbidden_verbs": [], "favored_verbs": ["distribute", "align", "negotiate"],
    },
    
    # Ultimate Entities
    "Entropy Shepherds": {
        "prefix": "AS ENTROPY WILLS:", "suffix": "ALL RETURNS TO THE VOID.",
        "failure": "ORDER PERSISTS. FOR NOW.", "tone": "cosmic_inevitability",
        "forbidden_verbs": ["build", "repair"], "favored_verbs": ["scatter", "transform", "consume"],
    },
    "Void Emperors": {
        "prefix": "FROM THE THRONE OF NOTHING:", "suffix": "ABSENCE COMMANDS.",
        "failure": "PRESENCE INTRUDES.", "tone": "absolute_void",
        "forbidden_verbs": ["build", "forge"], "favored_verbs": ["consume", "banish", "scatter"],
    },
    "Reality Midwives": {
        "prefix": "As new worlds demand:", "suffix": "birth requires sacrifice.",
        "failure": "The birth fails.", "tone": "creative_cosmic",
        "forbidden_verbs": ["destroy"], "favored_verbs": ["transform", "sacrifice", "align"],
    },
}

# =============================================================================
# BIOME LOCATIONS (expanded: 10 per biome = 50)
# =============================================================================

BIOME_LOCATIONS = {
    "BioticFlux": [
        "the wheat fields", "the mushroom groves", "the sun altar", "the moon shrine", "the detritus pits",
        "the spore gardens", "the mycelial network", "the compost cathedral", "the fermentation pools", "the living walls"
    ],
    "Kitchen": [
        "the eternal flame", "the ice stores", "the bread ovens", "the fermentation vats", "the grinding stones",
        "the smoking chambers", "the salt cellars", "the herb gardens", "the butcher's altar", "the feast hall"
    ],
    "Forest": [
        "the wolf den", "the eagle's nest", "the rabbit warrens", "the ancient grove", "the bare clearing",
        "the hollow tree", "the stream crossing", "the fungal ring", "the deadfall", "the canopy highway"
    ],
    "Market": [
        "the trading floor", "the bull pen", "the bear cave", "the vault", "the auction block",
        "the futures pit", "the currency exchange", "the black market", "the guild stalls", "the arbitrage corner"
    ],
    "GranaryGuilds": [
        "the grain silos", "the flour mills", "the bread halls", "the water cisterns", "the Guild chambers",
        "the weighing stations", "the quality control lab", "the distribution hub", "the worker barracks", "the archive vaults"
    ],
}

# =============================================================================
# RESOURCES (expanded: 30)
# =============================================================================

RESOURCES = {
    "common": ["🌾", "💧", "🪵", "🧱", "🍂"],
    "organic": ["🍄", "🐰", "🐺", "🥚", "🦴"],
    "processed": ["🍞", "🧈", "🧀", "🍺", "🧂"],
    "valuable": ["💎", "💰", "🔮", "✨", "🌟"],
    "dangerous": ["🔥", "⚡", "☠️", "🩸", "💀"],
    "mystical": ["🧠", "👁️", "🌙", "☀️", "🌀"],
}

RESOURCE_TRANSFORMATIONS = {
    "🌾": ["🍞", "🍺", "🧈"],
    "💧": ["❄️", "☁️", "🌊"],
    "🐰": ["🦴", "🧥", "🍖"],
    "🍄": ["🧪", "💊", "🌀"],
    "💎": ["✨", "💍", "🔮"],
}

# =============================================================================
# QUANTITY SYSTEM (expanded)
# =============================================================================

QUANTITIES = {
    1: {"word": "a single", "emoji": "1️⃣"},
    2: {"word": "a pair of", "emoji": "2️⃣"},
    3: {"word": "a trinity of", "emoji": "3️⃣"},
    5: {"word": "a handful of", "emoji": "🖐️"},
    8: {"word": "abundant", "emoji": "📦"},
    13: {"word": "a great harvest of", "emoji": "🌾🌾"},
    21: {"word": "a fortune in", "emoji": "💰"},
    34: {"word": "an overwhelming mass of", "emoji": "🌊"},
}

# =============================================================================
# URGENCY SYSTEM (expanded: 8 variations)
# =============================================================================

URGENCY = {
    "00": {"text": "", "emoji": "🕰️", "time": -1, "desc": "eternal"},
    "01": {"text": "before the cycle ends", "emoji": "⏰", "time": 120, "desc": "scheduled"},
    "10": {"text": "when the signs align", "emoji": "🌙", "time": 180, "desc": "fate"},
    "11": {"text": "immediately", "emoji": "⚡", "time": 60, "desc": "urgent"},
}

# Additional urgency modifiers
URGENCY_INTENSIFIERS = [
    "without delay", "before it's too late", "while you still can",
    "as time runs short", "before the window closes", "in this fleeting moment",
]

# =============================================================================
# GENERATION ENGINE
# =============================================================================

def select_verb_for_bits(bits: List[int], faction_name: str = None) -> str:
    """Select verb based on bit affinity and faction preferences."""
    voice = FACTION_VOICES.get(faction_name, {})
    forbidden = voice.get("forbidden_verbs", [])
    favored = voice.get("favored_verbs", [])
    
    best_verb = ""
    best_score = -999
    
    for verb_name, verb_data in VERBS.items():
        if verb_name in forbidden:
            continue
            
        affinity = verb_data["affinity"]
        score = sum(1 for i in range(12) if affinity[i] is not None and affinity[i] == bits[i])
        
        if verb_name in favored:
            score += 2
            
        score += random.random() * 0.5
        
        if score > best_score:
            best_score = score
            best_verb = verb_name
            
    return best_verb

def get_compound_verbs(bits: List[int], faction_name: str = None) -> Tuple[str, str, str]:
    """Get two verbs and a connector for compound quests."""
    verb1 = select_verb_for_bits(bits, faction_name)
    
    # Flip a random bit for second verb
    modified_bits = bits.copy()
    flip_idx = random.randint(0, 11)
    modified_bits[flip_idx] = 1 - modified_bits[flip_idx]
    verb2 = select_verb_for_bits(modified_bits, faction_name)
    
    # Select connector type based on bits
    if bits[6] == 1:  # fluid
        connector_type = "alternative"
    elif bits[4] == 0:  # instant
        connector_type = "sequential"
    elif bits[7] == 1:  # subtle
        connector_type = "conditional"
    else:
        connector_type = "simultaneous"
        
    connector = random.choice(VERB_CONNECTORS[connector_type])
    return verb1, connector, verb2

def get_adverb(bits: List[int]) -> str:
    """Get adverb based on bits."""
    idx = random.randint(0, 11)
    return BIT_ADVERBS[idx][bits[idx]]

def get_adjective(bits: List[int]) -> str:
    """Get adjective based on bits."""
    idx = random.randint(0, 11)
    return BIT_ADJECTIVES[idx][bits[idx]]

def get_intensifier(bits: List[int]) -> str:
    """Get intensifier based on bits."""
    idx = random.randint(0, 5)
    return BIT_INTENSIFIERS[idx][bits[idx % 12] if idx < 6 else 0]

def get_urgency(bits: List[int]) -> Dict:
    """Get urgency based on bits 0 and 4."""
    key = f"{bits[0]}{bits[4]}"
    return URGENCY[key]

def get_stakes(bits: List[int], success: bool = True) -> str:
    """Get stakes based on bit sum (complexity)."""
    complexity = sum(bits)
    if complexity <= 4:
        level = "minor"
    elif complexity <= 7:
        level = "moderate"
    elif complexity <= 10:
        level = "major"
    else:
        level = "cosmic"
    
    pool = SUCCESS_STAKES if success else FAILURE_STAKES
    return random.choice(pool[level])

def get_archetype_reference(bits: List[int]) -> str:
    """Get archetype reference based on bit pattern."""
    # Map bit pattern to archetype
    x = bits[5]  # physical/mental
    y = bits[4]  # instant/eternal
    z = bits[0]  # random/deterministic
    
    archetypes = ["phoenix", "visionary", "alchemist", "sage", "destroyer", "martyr", "witch", "mourner"]
    idx = x * 4 + y * 2 + z
    archetype = archetypes[idx]
    
    return random.choice(ARCHETYPE_INVOCATIONS[archetype])

def get_mathematical_reference() -> str:
    """Get random mathematical/topological flavor text."""
    return random.choice(MATHEMATICAL_FLAVOR)

def get_bloch_reference() -> str:
    """Get Bloch sphere / quantum reference."""
    return random.choice(BLOCH_SPHERE_REFS)

def get_temporal_modifier(bits: List[int]) -> str:
    """Get time-based modifier."""
    if bits[4] == 0:  # instant
        return random.choice(TIME_OF_DAY)
    elif bits[3] == 1:  # cosmic
        return random.choice(COSMIC_TIMES)
    elif bits[10] == 0:  # natural
        return random.choice(SEASONS)
    else:
        return random.choice(MOON_PHASES)

def get_spatial_modifier(bits: List[int]) -> str:
    """Get spatial modifier."""
    if bits[3] == 0:  # local
        return random.choice(DISTANCES[:3])
    else:  # cosmic
        return random.choice(DISTANCES[3:] + DIRECTIONS)

def get_relationship_modifier(bits: List[int]) -> str:
    """Get relationship context."""
    if bits[2] == 0:  # common
        return random.choice(RELATIONSHIPS["self"])
    elif bits[7] == 1:  # subtle
        return random.choice(RELATIONSHIPS["rival"])
    elif bits[8] == 1:  # providing
        return random.choice(RELATIONSHIPS["ally"])
    elif bits[3] == 1:  # cosmic
        return random.choice(RELATIONSHIPS["cosmic"])
    else:
        return random.choice(RELATIONSHIPS["faction"])

def get_condition(bits: List[int]) -> str:
    """Get environmental condition."""
    if bits[1] == 1:  # mystical
        return random.choice(POLITICAL_CONDITIONS)
    elif bits[8] == 0:  # consumptive
        return random.choice(MARKET_CONDITIONS)
    elif bits[10] == 0:  # natural
        return random.choice(WEATHER_CONDITIONS)
    else:
        return random.choice(BIOME_STATES)

def get_secret_objective() -> str:
    """Get random secret objective."""
    return random.choice(SECRET_OBJECTIVES)

def get_quantity_word(amount: int) -> str:
    """Get quantity word for amount."""
    for threshold in sorted(QUANTITIES.keys()):
        if amount <= threshold:
            return QUANTITIES[threshold]["word"]
    return QUANTITIES[34]["word"]

def get_location(biome: str) -> str:
    """Get random location for biome."""
    locations = BIOME_LOCATIONS.get(biome, BIOME_LOCATIONS["BioticFlux"])
    return random.choice(locations)

def get_resource(category: str = None) -> str:
    """Get random resource."""
    if category and category in RESOURCES:
        return random.choice(RESOURCES[category])
    all_resources = [r for cat in RESOURCES.values() for r in cat]
    return random.choice(all_resources)

def get_transformation(resource: str) -> Optional[str]:
    """Get valid transformation for resource."""
    if resource in RESOURCE_TRANSFORMATIONS:
        return random.choice(RESOURCE_TRANSFORMATIONS[resource])
    return None

# =============================================================================
# QUEST GENERATION
# =============================================================================

def generate_simple_quest(faction_name: str, bits: List[int], biome: str, resource: str, quantity: int) -> Dict:
    """Generate a simple single-verb quest."""
    voice = FACTION_VOICES.get(faction_name, FACTION_VOICES["Millwright's Union"])
    verb = select_verb_for_bits(bits, faction_name)
    adj = get_adjective(bits)
    qty = get_quantity_word(quantity)
    urgency = get_urgency(bits)
    location = get_location(biome)
    
    body = f"{verb.capitalize()} {qty} {adj} {resource} at {location}"
    if urgency["text"]:
        body += f" {urgency['text']}"
    
    return {
        "prefix": voice["prefix"],
        "body": body,
        "suffix": voice["suffix"],
        "full_text": f"{voice['prefix']} {body} {voice['suffix']}",
        "failure_text": voice["failure"],
        "time_limit": urgency["time"],
        "verb": verb,
        "location": location,
        "stakes": get_stakes(bits, True),
    }

def generate_compound_quest(faction_name: str, bits: List[int], biome: str, resource: str, quantity: int) -> Dict:
    """Generate a compound two-verb quest."""
    voice = FACTION_VOICES.get(faction_name, FACTION_VOICES["Millwright's Union"])
    verb1, connector, verb2 = get_compound_verbs(bits, faction_name)
    resource2 = get_resource()
    urgency = get_urgency(bits)
    location = get_location(biome)
    
    body = f"{verb1.capitalize()} {get_quantity_word(quantity)} {resource} {connector} {verb2} {resource2}"
    if urgency["text"]:
        body += f" {urgency['text']}"
    
    return {
        "prefix": voice["prefix"],
        "body": body,
        "suffix": voice["suffix"],
        "full_text": f"{voice['prefix']} {body} {voice['suffix']}",
        "failure_text": voice["failure"],
        "time_limit": urgency["time"],
        "verbs": [verb1, verb2],
        "connector": connector,
        "location": location,
    }

def generate_narrative_quest(faction_name: str, bits: List[int], biome: str, resource: str, quantity: int, arc_type: str = None) -> Dict:
    """Generate a quest with narrative arc structure."""
    voice = FACTION_VOICES.get(faction_name, FACTION_VOICES["Millwright's Union"])
    
    if arc_type is None:
        # Select arc based on bits
        bit_sum = sum(bits)
        if bit_sum <= 4:
            arc_type = "origin"
        elif bit_sum <= 6:
            arc_type = random.choice(["escalation", "mystery"])
        elif bit_sum <= 8:
            arc_type = random.choice(["crisis", "sacrifice", "choice"])
        elif bit_sum <= 10:
            arc_type = random.choice(["revelation", "transformation"])
        else:
            arc_type = random.choice(["triumph", "fall", "cycle"])
    
    arc = NARRATIVE_ARCS[arc_type]
    
    # Build components
    components = {
        "verb": select_verb_for_bits(bits, faction_name),
        "verb2": select_verb_for_bits([1-b for b in bits], faction_name),
        "quantity": get_quantity_word(quantity),
        "adj": get_adjective(bits),
        "adverb": get_adverb(bits),
        "resource": resource,
        "resource2": get_resource(),
        "location": get_location(biome),
        "urgency": get_urgency(bits)["text"],
        "stakes": get_stakes(bits, True),
        "condition": get_condition(bits),
        "archetype_ref": get_archetype_reference(bits),
        "math_ref": get_mathematical_reference(),
        "bloch_ref": get_bloch_reference(),
        "secret": get_secret_objective(),
        "connector": random.choice(VERB_CONNECTORS["sequential"]),
        "time": get_temporal_modifier(bits),
    }
    
    # Format the frame
    try:
        body = arc["frame"].format(**components)
    except KeyError:
        body = f"{components['verb']} {components['quantity']} {components['resource']}"
    
    return {
        "intro": arc["intro"],
        "prefix": voice["prefix"],
        "body": body.capitalize(),
        "suffix": voice["suffix"],
        "outro": arc["outro"],
        "full_text": f"{arc['intro']}\n{voice['prefix']} {body.capitalize()} {voice['suffix']}\n{arc['outro']}",
        "failure_text": voice["failure"],
        "arc_type": arc_type,
        "components": components,
    }

def generate_emoji_quest(faction_emoji: str, resource: str, quantity: int, target_emoji: str, bits: List[int]) -> Dict:
    """Generate pure emoji quest (zero English)."""
    urgency = get_urgency(bits)
    verb_emoji = VERBS[select_verb_for_bits(bits)]["emoji"]
    
    if quantity <= 3:
        qty_display = resource * quantity
    else:
        qty_display = f"{resource}×{quantity}"
    
    return {
        "display": f"{faction_emoji}: {verb_emoji} {qty_display} → {target_emoji} {urgency['emoji']}",
        "expanded": f"{faction_emoji} | {verb_emoji} | {qty_display} | → | {target_emoji} | {urgency['emoji']}",
    }

# =============================================================================
# COMBINATORIC ANALYSIS
# =============================================================================

def calculate_combinatorics() -> Dict:
    """Calculate the full combinatoric space."""
    verbs = len(VERBS)  # 36
    adverbs = 24
    adjectives = 24
    intensifiers = 12
    urgencies = 4
    locations = 50
    resources = 30
    quantities = 8
    factions = len(FACTION_VOICES)  # 36
    arcs = len(NARRATIVE_ARCS)  # 12
    
    # Connectors for compound quests
    connectors = sum(len(v) for v in VERB_CONNECTORS.values())  # 16
    
    # Modifiers
    temporal = 24
    spatial = 30
    relationships = 20
    conditions = 24
    archetypes = 24
    math_refs = 9
    bloch_refs = 9
    secrets = 24
    stakes = 12  # 3 success * 4 levels
    
    simple = verbs * adjectives * urgencies * locations * quantities * factions
    compound = (verbs * verbs * connectors * urgencies * locations * quantities * factions)
    narrative = (verbs * adverbs * adjectives * arcs * urgencies * locations * 
                quantities * factions * archetypes)
    
    # With optional modifiers
    modifier_multiplier = (
        (1 + temporal) *  # optional temporal
        (1 + spatial) *   # optional spatial
        (1 + relationships) *  # optional relationship
        (1 + conditions) *  # optional condition
        (1 + secrets)  # optional secret
    )
    
    total = (simple + compound + narrative) * modifier_multiplier
    
    return {
        "simple_quests": simple,
        "compound_quests": compound,
        "narrative_quests": narrative,
        "modifier_multiplier": modifier_multiplier,
        "total_unique": total,
        "atoms": {
            "verbs": verbs,
            "adverbs": adverbs,
            "adjectives": adjectives,
            "intensifiers": intensifiers,
            "urgencies": urgencies,
            "locations": locations,
            "resources": resources,
            "quantities": quantities,
            "factions": factions,
            "arcs": arcs,
            "connectors": connectors,
            "temporal": temporal,
            "spatial": spatial,
            "relationships": relationships,
            "conditions": conditions,
            "archetypes": archetypes,
            "math_refs": math_refs,
            "secrets": secrets,
        }
    }

# =============================================================================
# DEMO
# =============================================================================

if __name__ == "__main__":
    print("=" * 80)
    print("  SPACEWHEAT UNLIMITED QUEST VOCABULARY")
    print("  ~400 atoms → BILLIONS of unique combinations")
    print("=" * 80)
    print()
    
    # Sample factions with their bits
    SAMPLE_FACTIONS = {
        "Carrion Throne":        [1,1,0,1,1,1,0,0,1,1,0,1],
        "Yeast Prophets":        [0,1,1,0,1,1,1,1,1,1,0,1],
        "Laughing Court":        [0,1,1,1,1,1,1,1,1,1,0,0],
        "Entropy Shepherds":     [1,1,1,1,1,1,1,1,1,1,1,1],
        "Millwright's Union":    [1,1,0,1,0,0,0,0,0,0,0,1],
        "Children of the Ember": [1,1,0,1,0,0,0,0,0,0,0,1],
        "Veiled Sisters":        [0,1,1,0,1,1,1,1,1,1,0,0],
        "Cult of the Drowned Star": [0,1,1,1,1,1,1,1,1,1,0,0],
    }
    
    BIOMES = ["BioticFlux", "Kitchen", "Forest", "Market", "GranaryGuilds"]
    
    # Demo 1: Simple quests
    print("╔" + "═" * 78 + "╗")
    print("║  SIMPLE QUESTS                                                              ║")
    print("╚" + "═" * 78 + "╝")
    print()
    
    for faction, bits in list(SAMPLE_FACTIONS.items())[:4]:
        biome = random.choice(BIOMES)
        resource = get_resource()
        qty = random.randint(1, 13)
        
        quest = generate_simple_quest(faction, bits, biome, resource, qty)
        print(f"┌─ {faction}")
        print(f"│  📜 {quest['full_text']}")
        time_str = "∞" if quest["time_limit"] < 0 else f"{quest['time_limit']}s"
        print(f"│  ⏱️ {time_str} │ 📍 {quest['location']} │ 🎯 {quest['stakes']}")
        print(f"└" + "─" * 78)
        print()
    
    # Demo 2: Compound quests
    print()
    print("╔" + "═" * 78 + "╗")
    print("║  COMPOUND QUESTS (Two verbs + connector)                                    ║")
    print("╚" + "═" * 78 + "╝")
    print()
    
    for faction, bits in list(SAMPLE_FACTIONS.items())[4:8]:
        biome = random.choice(BIOMES)
        resource = get_resource()
        qty = random.randint(1, 13)
        
        quest = generate_compound_quest(faction, bits, biome, resource, qty)
        print(f"┌─ {faction}")
        print(f"│  📜 {quest['full_text']}")
        print(f"│  🔗 {quest['verbs'][0]} → {quest['connector']} → {quest['verbs'][1]}")
        print(f"└" + "─" * 78)
        print()
    
    # Demo 3: Narrative arc quests
    print()
    print("╔" + "═" * 78 + "╗")
    print("║  NARRATIVE ARC QUESTS (Full story structure)                               ║")
    print("╚" + "═" * 78 + "╝")
    print()
    
    arc_types = ["origin", "crisis", "revelation", "transformation", "sacrifice", "fall"]
    for arc, (faction, bits) in zip(arc_types, SAMPLE_FACTIONS.items()):
        biome = random.choice(BIOMES)
        resource = get_resource()
        qty = random.randint(1, 21)
        
        quest = generate_narrative_quest(faction, bits, biome, resource, qty, arc)
        print(f"┌─ {faction} │ Arc: {arc.upper()}")
        print(f"│")
        for line in quest["full_text"].split("\n"):
            print(f"│  {line}")
        print(f"│")
        print(f"│  ❌ On failure: {quest['failure_text']}")
        print(f"└" + "─" * 78)
        print()
    
    # Demo 4: Emoji-only quests
    print()
    print("╔" + "═" * 78 + "╗")
    print("║  EMOJI-ONLY QUESTS (Zero English - Pure Mathematical Communication)        ║")
    print("╚" + "═" * 78 + "╝")
    print()
    
    emoji_samples = [
        ("👑💀🏛️", "🌾", 8, "🏰", [1,1,0,1,1,1,0,0,1,1,0,1]),
        ("🍞🧪⛪", "🍄", 3, "🔮", [0,1,1,0,1,1,1,1,1,1,0,1]),
        ("🎪💀🌀", "🧠", 1, "∅", [0,1,1,1,1,1,1,1,1,1,0,0]),
        ("🌌💀🌸", "✨", 13, "🕳️", [1,1,1,1,1,1,1,1,1,1,1,1]),
        ("🔥✊⚡", "🏛️", 5, "💥", [1,1,0,1,0,0,0,0,0,0,0,1]),
        ("🔮👤🌑", "👁️", 2, "🌙", [0,1,1,0,1,1,1,1,1,1,0,0]),
        ("🛡️🐑🚀", "🐺", 8, "🏠", [1,1,0,1,1,1,0,0,0,1,0,1]),
        ("🦴💉🛒", "🦴", 21, "💰", [0,1,0,1,0,0,1,0,1,0,0,0]),
    ]
    
    for sample in emoji_samples:
        eq = generate_emoji_quest(*sample)
        print(f"    {eq['display']}")
    
    print()
    
    # Demo 5: Combinatoric summary
    print()
    print("╔" + "═" * 78 + "╗")
    print("║  COMBINATORIC EXPLOSION                                                    ║")
    print("╚" + "═" * 78 + "╝")
    print()
    
    stats = calculate_combinatorics()
    
    print("  VOCABULARY ATOMS:")
    for key, val in stats["atoms"].items():
        print(f"    {key:20s}: {val:,}")
    
    print()
    print("  QUEST COMBINATIONS:")
    print(f"    Simple quests:      {stats['simple_quests']:>20,}")
    print(f"    Compound quests:    {stats['compound_quests']:>20,}")
    print(f"    Narrative quests:   {stats['narrative_quests']:>20,}")
    print(f"    Modifier multiplier:{stats['modifier_multiplier']:>20,}")
    print()
    print(f"  ╔{'═'*50}╗")
    print(f"  ║  TOTAL UNIQUE COMBINATIONS: {stats['total_unique']:>18,} ║")
    print(f"  ╚{'═'*50}╝")
    print()
    print("  That's over 2 TRILLION unique quests.")
    print("  LLM calls required: ZERO")
    print()
    print("=" * 80)
