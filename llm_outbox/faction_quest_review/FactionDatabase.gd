class_name FactionDatabase
extends Resource

## Complete database of 32 factions with 12-bit classification patterns
## Each faction has: name, emoji, 12-bit pattern, category

# =============================================================================
# FACTION DATA STRUCTURE
# =============================================================================

## Faction format:
## {
##   "name": String,
##   "emoji": String (3 emojis),
##   "bits": Array[int] (12 bits: 0 or 1),
##   "category": String,
##   "description": String (short)
## }

# =============================================================================
# IMPERIAL POWERS (4 factions)
# =============================================================================

const CARRION_THRONE = {
	"name": "Carrion Throne",
	"emoji": "👑💀🏛️",
	"bits": [1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "Central imperial bureaucracy feeding endless bureaucrats with endless wars."
}

const HOUSE_OF_THORNS = {
	"name": "House of Thorns",
	"emoji": "🌹🗡️👑",
	"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "Aristocratic assassins using poison and intrigue."
}

const GRANARY_GUILDS = {
	"name": "Granary Guilds",
	"emoji": "🌾💰⚖️",
	"bits": [1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "Food-control networks providing bread and games."
}

const STATION_LORDS = {
	"name": "Station Lords",
	"emoji": "🏢👑🌌",
	"bits": [1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "Orbital city rulers with absolute authority over neutral space."
}

# =============================================================================
# WORKING GUILDS & SERVICES (6 factions)
# =============================================================================

const OBSIDIAN_WILL = {
	"name": "Obsidian Will",
	"emoji": "🏭⚙️🔧",
	"bits": [1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1],
	"category": "Working Guilds",
	"description": "Mechanical purists creating century-spanning works."
}

const MILLWRIGHTS_UNION = {
	"name": "Millwright's Union",
	"emoji": "🌾⚙️🏭",
	"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
	"category": "Working Guilds",
	"description": "Grain processors who know cosmic rhythms through mill vibrations."
}

const TINKER_TEAM = {
	"name": "Tinker Team",
	"emoji": "🔧🛠️🚐",
	"bits": [0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
	"category": "Working Guilds",
	"description": "Traveling repairmen fixing everything with adaptive methods."
}

const SEAMSTRESS_SYNDICATE = {
	"name": "Seamstress Syndicate",
	"emoji": "🪡👘📐",
	"bits": [1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Working Guilds",
	"description": "Message-encoding tailors whose precise work communicates through clothing patterns."
}

const GRAVEDIGGERS_UNION = {
	"name": "Gravedigger's Union",
	"emoji": "⚰️🪦🌙",
	"bits": [0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1],
	"category": "Working Guilds",
	"description": "Death ritualists handling the burial of people, failed systems, and dead concepts."
}

const SYMPHONY_SMITHS = {
	"name": "Symphony Smiths",
	"emoji": "🎵🔨⚔️",
	"bits": [1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1],
	"category": "Working Guilds",
	"description": "Forging reality-tuning tools from crystallized sound."
}

# =============================================================================
# MYSTIC ORDERS (4 factions)
# =============================================================================

const KEEPERS_OF_SILENCE = {
	"name": "Keepers of Silence",
	"emoji": "🧘‍♂️⚔️🔇",
	"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Mystic Orders",
	"description": "Monastic hunters of hyperspace anomalies, enforcing silence."
}

const SACRED_FLAME_KEEPERS = {
	"name": "Sacred Flame Keepers",
	"emoji": "🕯️🔥⛪",
	"bits": [1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Mystic Orders",
	"description": "Ritualists maintaining fires that burn true in vacuum."
}

const IRON_CONFESSORS = {
	"name": "Iron Confessors",
	"emoji": "🤖⛪🔧",
	"bits": [1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Mystic Orders",
	"description": "Machine-soul priests bridging flesh and steel."
}

const YEAST_PROPHETS = {
	"name": "Yeast Prophets",
	"emoji": "🍞🧪⛪",
	"bits": [0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1],
	"category": "Mystic Orders",
	"description": "Fermentation mystics embedding small changes that propagate."
}

# =============================================================================
# MERCHANTS & TRADERS (4 factions)
# =============================================================================

const SYNDICATE_OF_GLASS = {
	"name": "Syndicate of Glass",
	"emoji": "💎⚖️🛸",
	"bits": [1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Merchants & Traders",
	"description": "Crystal trade oligarchy controlling hyperspace artifacts."
}

const MEMORY_MERCHANTS = {
	"name": "Memory Merchants",
	"emoji": "🧠💰📦",
	"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Merchants & Traders",
	"description": "Consciousness traders extracting and selling distilled experiences."
}

const BONE_MERCHANTS = {
	"name": "Bone Merchants",
	"emoji": "🦴💉🛒",
	"bits": [0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
	"category": "Merchants & Traders",
	"description": "Black market bio-traders specializing in forbidden surgeries."
}

const NEXUS_WARDENS = {
	"name": "Nexus Wardens",
	"emoji": "🍺🗝️🕯️",
	"bits": [1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0],
	"category": "Merchants & Traders",
	"description": "Innkeeper-diplomats running neutral waystation taverns."
}

# =============================================================================
# MILITANT ORDERS (4 factions)
# =============================================================================

const IRON_SHEPHERDS = {
	"name": "Iron Shepherds",
	"emoji": "🛡️🐑🚀",
	"bits": [1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1],
	"category": "Militant Orders",
	"description": "Feudal knights aboard living cathedral ships."
}

const BROTHERHOOD_OF_ASH = {
	"name": "Brotherhood of Ash",
	"emoji": "⚔️⚰️⚫️",
	"bits": [1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1],
	"category": "Militant Orders",
	"description": "Honor-bound mercenaries whose contracts span personal disputes to galactic warfare."
}

const CHILDREN_OF_THE_EMBER = {
	"name": "Children of the Ember",
	"emoji": "🔥✊⚡️",
	"bits": [1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
	"category": "Militant Orders",
	"description": "Revolutionary zealots seeking liberation through forbidden energies."
}

const ORDER_OF_CRIMSON_SCALE = {
	"name": "Order of the Crimson Scale",
	"emoji": "⚖️🐉🩸",
	"bits": [1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1],
	"category": "Militant Orders",
	"description": "Judicial protectors with immutable law codes."
}

# =============================================================================
# SCAVENGER FACTIONS (3 factions)
# =============================================================================

const RUST_FLEET = {
	"name": "Rust Fleet",
	"emoji": "🚢🦴⚙️",
	"bits": [0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0],
	"category": "Scavenger Factions",
	"description": "Mechanical scavenger armadas following battles."
}

const LOCUSTS = {
	"name": "Locusts",
	"emoji": "🦗🍃💀",
	"bits": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0],
	"category": "Scavenger Factions",
	"description": "Organic scavenger swarms consuming dead worlds."
}

const CARTOGRAPHERS = {
	"name": "Cartographers",
	"emoji": "🗺️🔭🚢",
	"bits": [0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0],
	"category": "Scavenger Factions",
	"description": "Nomadic explorer-mystics charting hyperspace routes."
}

# =============================================================================
# HORROR CULTS (4 factions)
# =============================================================================

const LAUGHING_COURT = {
	"name": "Laughing Court",
	"emoji": "🎪💀🌀",
	"bits": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
	"category": "Horror Cults",
	"description": "Viral memetic disease spreading through minds."
}

const CULT_OF_DROWNED_STAR = {
	"name": "Cult of the Drowned Star",
	"emoji": "🌊⭐️👁️",
	"bits": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
	"category": "Horror Cults",
	"description": "Cosmic horror worshippers driven mad by whispers from hyperspace."
}

const CHORUS_OF_OBLIVION = {
	"name": "Chorus of Oblivion",
	"emoji": "🎶💀🌀",
	"bits": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],
	"category": "Horror Cults",
	"description": "Nihilistic death cult seeking universal collapse."
}

const FLESH_ARCHITECTS = {
	"name": "Flesh Architects",
	"emoji": "🧬🏗️👥",
	"bits": [0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1],
	"category": "Horror Cults",
	"description": "Biological horror sculptors reshaping life into living cities."
}

# =============================================================================
# DEFENSIVE COMMUNITIES (4 factions)
# =============================================================================

const VOID_SERFS = {
	"name": "Void Serfs",
	"emoji": "🌾⛓️🌌",
	"bits": [0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0],
	"category": "Defensive Communities",
	"description": "Indentured bio-dome farmers kept docile through religious fervor."
}

const CLAN_OF_HIDDEN_ROOT = {
	"name": "Clan of the Hidden Root",
	"emoji": "🌱🏡🛡️",
	"bits": [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
	"category": "Defensive Communities",
	"description": "Defensive agrarians preserving traditional values through communal cooperation."
}

const VEILED_SISTERS = {
	"name": "Veiled Sisters",
	"emoji": "🔮👤🌑",
	"bits": [0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0],
	"category": "Defensive Communities",
	"description": "Matriarchal shadow network wielding subtle influence."
}

const TERRARIUM_COLLECTIVE = {
	"name": "Terrarium Collective",
	"emoji": "🌿🏠🔒",
	"bits": [1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1],
	"category": "Defensive Communities",
	"description": "Defensive biosphere builders constructing expanding zero-waste economies."
}

# =============================================================================
# COSMIC MANIPULATORS (3 factions)
# =============================================================================

const RESONANCE_DANCERS = {
	"name": "Resonance Dancers",
	"emoji": "💃🎼🌟",
	"bits": [1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	"category": "Cosmic Manipulators",
	"description": "Synchronized performers across space stations tuning psychic space."
}

const CAUSAL_SHEPHERDS = {
	"name": "Causal Shepherds",
	"emoji": "🐑🎲⚡",
	"bits": [1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1],
	"category": "Cosmic Manipulators",
	"description": "Herding quantum uncertainties and guiding causality chains."
}

const EMPIRE_SHEPHERDS = {
	"name": "Empire Shepherds",
	"emoji": "🐑🌍🤠",
	"bits": [0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0],
	"category": "Cosmic Manipulators",
	"description": "Herd entire civilizations that graze continents down."
}

# =============================================================================
# ULTIMATE COSMIC ENTITIES (3 factions)
# =============================================================================

const ENTROPY_SHEPHERDS = {
	"name": "Entropy Shepherds",
	"emoji": "🌌💀🌸",
	"bits": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	"category": "Ultimate Cosmic Entities",
	"description": "Universal-decay gardeners ensuring beautiful endings."
}

const VOID_EMPERORS = {
	"name": "Void Emperors",
	"emoji": "👑🌌⚫",
	"bits": [1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1],
	"category": "Ultimate Cosmic Entities",
	"description": "Nothingness rulers commanding armies of absence."
}

const REALITY_MIDWIVES = {
	"name": "Reality Midwives",
	"emoji": "🌟💫🥚",
	"bits": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	"category": "Ultimate Cosmic Entities",
	"description": "Universe-birth assistants helping cosmic eggs hatch."
}

# =============================================================================
# DATABASE COLLECTIONS
# =============================================================================

const ALL_FACTIONS = [
	# Imperial Powers (4)
	CARRION_THRONE,
	HOUSE_OF_THORNS,
	GRANARY_GUILDS,
	STATION_LORDS,

	# Working Guilds (6)
	OBSIDIAN_WILL,
	MILLWRIGHTS_UNION,
	TINKER_TEAM,
	SEAMSTRESS_SYNDICATE,
	GRAVEDIGGERS_UNION,
	SYMPHONY_SMITHS,

	# Mystic Orders (4)
	KEEPERS_OF_SILENCE,
	SACRED_FLAME_KEEPERS,
	IRON_CONFESSORS,
	YEAST_PROPHETS,

	# Merchants & Traders (4)
	SYNDICATE_OF_GLASS,
	MEMORY_MERCHANTS,
	BONE_MERCHANTS,
	NEXUS_WARDENS,

	# Militant Orders (4)
	IRON_SHEPHERDS,
	BROTHERHOOD_OF_ASH,
	CHILDREN_OF_THE_EMBER,
	ORDER_OF_CRIMSON_SCALE,

	# Scavenger Factions (3)
	RUST_FLEET,
	LOCUSTS,
	CARTOGRAPHERS,

	# Horror Cults (4)
	LAUGHING_COURT,
	CULT_OF_DROWNED_STAR,
	CHORUS_OF_OBLIVION,
	FLESH_ARCHITECTS,

	# Defensive Communities (4)
	VOID_SERFS,
	CLAN_OF_HIDDEN_ROOT,
	VEILED_SISTERS,
	TERRARIUM_COLLECTIVE,

	# Cosmic Manipulators (3)
	RESONANCE_DANCERS,
	CAUSAL_SHEPHERDS,
	EMPIRE_SHEPHERDS,

	# Ultimate Cosmic Entities (3)
	ENTROPY_SHEPHERDS,
	VOID_EMPERORS,
	REALITY_MIDWIVES,
]

const FACTIONS_BY_CATEGORY = {
	"Imperial Powers": [CARRION_THRONE, HOUSE_OF_THORNS, GRANARY_GUILDS, STATION_LORDS],
	"Working Guilds": [OBSIDIAN_WILL, MILLWRIGHTS_UNION, TINKER_TEAM, SEAMSTRESS_SYNDICATE, GRAVEDIGGERS_UNION, SYMPHONY_SMITHS],
	"Mystic Orders": [KEEPERS_OF_SILENCE, SACRED_FLAME_KEEPERS, IRON_CONFESSORS, YEAST_PROPHETS],
	"Merchants & Traders": [SYNDICATE_OF_GLASS, MEMORY_MERCHANTS, BONE_MERCHANTS, NEXUS_WARDENS],
	"Militant Orders": [IRON_SHEPHERDS, BROTHERHOOD_OF_ASH, CHILDREN_OF_THE_EMBER, ORDER_OF_CRIMSON_SCALE],
	"Scavenger Factions": [RUST_FLEET, LOCUSTS, CARTOGRAPHERS],
	"Horror Cults": [LAUGHING_COURT, CULT_OF_DROWNED_STAR, CHORUS_OF_OBLIVION, FLESH_ARCHITECTS],
	"Defensive Communities": [VOID_SERFS, CLAN_OF_HIDDEN_ROOT, VEILED_SISTERS, TERRARIUM_COLLECTIVE],
	"Cosmic Manipulators": [RESONANCE_DANCERS, CAUSAL_SHEPHERDS, EMPIRE_SHEPHERDS],
	"Ultimate Cosmic Entities": [ENTROPY_SHEPHERDS, VOID_EMPERORS, REALITY_MIDWIVES],
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_faction_by_name(faction_name: String) -> Dictionary:
	"""Get faction data by exact name match"""
	for faction in ALL_FACTIONS:
		if faction["name"] == faction_name:
			return faction
	return {}

static func get_random_faction() -> Dictionary:
	"""Get random faction from all 32"""
	return ALL_FACTIONS[randi() % ALL_FACTIONS.size()]

static func get_random_faction_from_category(category: String) -> Dictionary:
	"""Get random faction from specific category"""
	var factions = FACTIONS_BY_CATEGORY.get(category, [])
	if factions.is_empty():
		push_warning("Unknown category: %s" % category)
		return {}
	return factions[randi() % factions.size()]

static func get_all_faction_names() -> Array:
	"""Get array of all faction names"""
	var names = []
	for faction in ALL_FACTIONS:
		names.append(faction["name"])
	return names

static func get_faction_count() -> int:
	"""Get total faction count (should be 32)"""
	return ALL_FACTIONS.size()

static func validate_database() -> bool:
	"""Validate that all factions have correct structure"""
	for faction in ALL_FACTIONS:
		if not faction.has("name") or not faction.has("emoji") or not faction.has("bits"):
			push_error("Invalid faction structure: %s" % faction)
			return false
		if faction["bits"].size() != 12:
			push_error("Faction %s has %d bits (expected 12)" % [faction["name"], faction["bits"].size()])
			return false
	return true

# =============================================================================
# BIT PATTERN ANALYSIS
# =============================================================================

static func get_bit_affinity_score(faction_bits: Array, target_bits: Array) -> int:
	"""Calculate affinity score between two bit patterns

	Returns:
		Count of matching bits (0-12)
	"""
	if faction_bits.size() != 12 or target_bits.size() != 12:
		push_error("Invalid bit array size")
		return 0

	var matches = 0
	for i in range(12):
		if faction_bits[i] == target_bits[i]:
			matches += 1
	return matches

static func find_similar_factions(faction: Dictionary, min_similarity: int = 8) -> Array:
	"""Find factions with similar bit patterns

	Args:
		faction: Reference faction
		min_similarity: Minimum matching bits (0-12)

	Returns:
		Array of similar factions
	"""
	var similar = []
	var ref_bits = faction["bits"]

	for other in ALL_FACTIONS:
		if other["name"] == faction["name"]:
			continue
		var score = get_bit_affinity_score(ref_bits, other["bits"])
		if score >= min_similarity:
			similar.append({"faction": other, "similarity": score})

	return similar

# =============================================================================
# DEBUG / TESTING
# =============================================================================

static func print_database_stats() -> void:
	"""Print database statistics"""
	print("📚 Faction Database Statistics:")
	print("  Total Factions: %d" % get_faction_count())
	print("\n  By Category:")
	for category in FACTIONS_BY_CATEGORY.keys():
		var count = FACTIONS_BY_CATEGORY[category].size()
		print("    %s: %d" % [category, count])

	print("\n  Validation: %s" % ("✅ PASS" if validate_database() else "❌ FAIL"))

static func test_faction_database() -> void:
	"""Test faction database"""
	print("🧪 Testing FactionDatabase...")

	print_database_stats()

	# Test random selection
	var random_faction = get_random_faction()
	print("\n  Random Faction: %s %s" % [random_faction["emoji"], random_faction["name"]])

	# Test category selection
	var guild = get_random_faction_from_category("Working Guilds")
	print("  Random Guild: %s %s" % [guild["emoji"], guild["name"]])

	# Test similarity
	var similar = find_similar_factions(MILLWRIGHTS_UNION, 6)
	print("\n  Factions similar to Millwright's Union:")
	for entry in similar:
		print("    %s (similarity: %d/12)" % [entry["faction"]["name"], entry["similarity"]])

	print("\n✅ FactionDatabase test complete")
