class_name FactionVoices
extends Resource

## Faction-specific voice templates and personality
## 10 voice categories for 32 factions

# =============================================================================
# VOICE TEMPLATES
# =============================================================================

const FACTION_VOICE = {
	"imperial": {
		"prefix": "By imperial decree:",
		"suffix": "for the Throne.",
		"failure": "The Throne is displeased.",
		"tone": "absolute"
	},
	"guild": {
		"prefix": "The Guild requires:",
		"suffix": "as per contract.",
		"failure": "Contract violated.",
		"tone": "collective"
	},
	"mystic": {
		"prefix": "The mysteries demand:",
		"suffix": "so it is written.",
		"failure": "The prophecy dims.",
		"tone": "mystical"
	},
	"merchant": {
		"prefix": "A profitable venture:",
		"suffix": "payment upon delivery.",
		"failure": "Deal cancelled.",
		"tone": "mercantile"
	},
	"militant": {
		"prefix": "Orders:",
		"suffix": "for honor.",
		"failure": "Dishonored.",
		"tone": "military"
	},
	"scavenger": {
		"prefix": "Opportunity:",
		"suffix": "finders keepers.",
		"failure": "Nothing gained.",
		"tone": "opportunistic"
	},
	"horror": {
		"prefix": "IT WHISPERS:",
		"suffix": "or be consumed.",
		"failure": "IT HUNGERS STILL.",
		"tone": "eldritch"
	},
	"defensive": {
		"prefix": "For our protection:",
		"suffix": "for the community.",
		"failure": "We remain vulnerable.",
		"tone": "protective"
	},
	"cosmic": {
		"prefix": "The cosmos requires:",
		"suffix": "across all dimensions.",
		"failure": "Reality destabilizes.",
		"tone": "transcendent"
	},
	"entity": {
		"prefix": "EXISTENCE DEMANDS:",
		"suffix": "THUS IT SHALL BE.",
		"failure": "ENTROPY ACCELERATES.",
		"tone": "absolute_cosmic"
	},
}

# =============================================================================
# FACTION TO VOICE MAPPING
# =============================================================================

const FACTION_TO_VOICE = {
	# Imperial Powers
	"Carrion Throne": "imperial",
	"House of Thorns": "imperial",
	"Granary Guilds": "imperial",
	"Station Lords": "imperial",

	# Working Guilds
	"Obsidian Will": "guild",
	"Millwright's Union": "guild",
	"Tinker Team": "guild",
	"Seamstress Syndicate": "guild",
	"Gravedigger's Union": "guild",
	"Symphony Smiths": "guild",

	# Mystic Orders
	"Keepers of Silence": "mystic",
	"Sacred Flame Keepers": "mystic",
	"Iron Confessors": "mystic",
	"Yeast Prophets": "mystic",

	# Merchants & Traders
	"Syndicate of Glass": "merchant",
	"Memory Merchants": "merchant",
	"Bone Merchants": "merchant",
	"Nexus Wardens": "merchant",

	# Militant Orders
	"Iron Shepherds": "militant",
	"Brotherhood of Ash": "militant",
	"Children of the Ember": "militant",
	"Order of the Crimson Scale": "militant",

	# Scavenger Factions
	"Rust Fleet": "scavenger",
	"Locusts": "scavenger",
	"Cartographers": "scavenger",

	# Horror Cults
	"Laughing Court": "horror",
	"Cult of the Drowned Star": "horror",
	"Chorus of Oblivion": "horror",
	"Flesh Architects": "horror",

	# Defensive Communities
	"Void Serfs": "defensive",
	"Clan of the Hidden Root": "defensive",
	"Veiled Sisters": "defensive",
	"Terrarium Collective": "defensive",

	# Cosmic Manipulators
	"Resonance Dancers": "cosmic",
	"Causal Shepherds": "cosmic",
	"Empire Shepherds": "cosmic",

	# Ultimate Cosmic Entities
	"Entropy Shepherds": "entity",
	"Void Emperors": "entity",
	"Reality Midwives": "entity",
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_voice(faction_name: String) -> Dictionary:
	"""Get voice template for faction"""
	var voice_key = FACTION_TO_VOICE.get(faction_name, "guild")
	return FACTION_VOICE[voice_key]

static func get_all_voices() -> Dictionary:
	"""Get all voice templates"""
	return FACTION_VOICE.duplicate()
