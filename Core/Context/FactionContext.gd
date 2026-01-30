class_name FactionContext
extends Resource

## Faction Context System - Background Cultural Layer
## 32 factions providing thematic depth and design palette
## Invisible to player but influences flavor, events, and atmosphere

# Faction data structure
# Each faction has: name, description, axiom_pattern (12-bit), category, emoji
var factions: Array[Dictionary] = []

# Q-bit dimension meanings
const QBIT_DIMENSIONS = [
	{"name": "Randomness", "north": "🎲 Random", "south": "📚 Deterministic"},
	{"name": "Materiality", "north": "🔧 Material", "south": "🔮 Mystical"},
	{"name": "Class", "north": "🌾 Common", "south": "👑 Elite"},
	{"name": "Scope", "north": "🏠 Local", "south": "🌌 Cosmic"},
	{"name": "Temporality", "north": "⚡ Instant", "south": "🕰️ Eternal"},
	{"name": "Expression", "north": "💪 Physical", "south": "🧠 Mental"},
	{"name": "Structure", "north": "💠 Crystalline", "south": "🌊 Fluid"},
	{"name": "Method", "north": "🗡️ Direct", "south": "🎭 Subtle"},
	{"name": "Economy", "north": "🍽️ Consumptive", "south": "🎁 Providing"},
	{"name": "Diversity", "north": "⬜ Monochrome", "south": "🌈 Prismatic"},
	{"name": "Origin", "north": "🌱 Emergent", "south": "🏗️ Imposed"},
	{"name": "Focus", "north": "🌪️ Scattered", "south": "🎯 Focused"}
]

# Current ambient faction influences (weights 0.0-1.0)
var ambient_influences: Dictionary = {}


func _init():
	_initialize_factions()
	_set_default_ambient()


func _initialize_factions():
	"""Initialize all 32 factions with their q-bit patterns"""

	# IMPERIAL POWER STRUCTURE
	factions.append({
		"name": "The Carrion Throne",
		"description": "Central imperial bureaucracy feeding endless bureaucrats with endless wars",
		"pattern": "110111001101",
		"category": "Imperial Power",
		"emoji": "👑💀🏛️",
		"keywords": ["empire", "bureaucracy", "order", "control", "quotas"]
	})

	factions.append({
		"name": "House of Thorns",
		"description": "Aristocratic assassins using poison and intrigue",
		"pattern": "111111010101",
		"category": "Imperial Power",
		"emoji": "🌹🗡️👑",
		"keywords": ["poison", "intrigue", "assassination", "nobility", "secrets"]
	})

	factions.append({
		"name": "The Granary Guilds",
		"description": "Food-control networks providing 'bread and games' civic management",
		"pattern": "110111011101",
		"category": "Imperial Power",
		"emoji": "🌾💰⚖️",
		"keywords": ["grain", "food", "control", "economy", "distribution"]
	})

	factions.append({
		"name": "The Station Lords",
		"description": "Orbital city rulers with absolute authority over neutral space",
		"pattern": "110111000101",
		"category": "Imperial Power",
		"emoji": "🏢👑🌌",
		"keywords": ["space", "stations", "authority", "cities", "orbit"]
	})

	# WORKING GUILDS & SERVICES
	factions.append({
		"name": "The Obsidian Will",
		"description": "Mechanical purists creating century-spanning works",
		"pattern": "110111000101",
		"category": "Working Guilds",
		"emoji": "🏭⚙️🔧",
		"keywords": ["machines", "craftsmanship", "persistence", "engineering"]
	})

	factions.append({
		"name": "The Millwright's Union",
		"description": "Grain processors who know cosmic rhythms through mill vibrations",
		"pattern": "110100000001",
		"category": "Working Guilds",
		"emoji": "🌾⚙️🏭",
		"keywords": ["mills", "grain", "processing", "rhythms", "workers"]
	})

	factions.append({
		"name": "The Tinker Team",
		"description": "Traveling repairmen fixing everything with adaptive methods",
		"pattern": "010100101000",
		"category": "Working Guilds",
		"emoji": "🔧🛠️🚐",
		"keywords": ["repair", "travel", "adaptation", "tools", "fixes"]
	})

	factions.append({
		"name": "The Seamstress Syndicate",
		"description": "Message-encoding tailors communicating through clothing patterns",
		"pattern": "110011010101",
		"category": "Working Guilds",
		"emoji": "🪡👘📐",
		"keywords": ["patterns", "messages", "clothing", "encoding", "precision"]
	})

	factions.append({
		"name": "The Gravedigger's Union",
		"description": "Death ritualists handling burial of people, systems, and concepts",
		"pattern": "010011000101",
		"category": "Working Guilds",
		"emoji": "⚰️🪦🌙",
		"keywords": ["death", "burial", "endings", "rituals", "concepts"]
	})

	factions.append({
		"name": "The Symphony Smiths",
		"description": "Forging reality-tuning tools from crystallized sound",
		"pattern": "110100001111",
		"category": "Working Guilds",
		"emoji": "🎵🔨⚔️",
		"keywords": ["sound", "forging", "harmony", "reality", "vibration"]
	})

	# MYSTIC ORDERS
	factions.append({
		"name": "The Keepers of Silence",
		"description": "Monastic hunters of hyperspace anomalies",
		"pattern": "111111010101",
		"category": "Mystic Orders",
		"emoji": "🧘‍♂️⚔️🔇",
		"keywords": ["silence", "hunting", "anomalies", "hyperspace", "protection"]
	})

	factions.append({
		"name": "The Sacred Flame Keepers",
		"description": "Ritualists maintaining fires that burn true in vacuum",
		"pattern": "111011010101",
		"category": "Mystic Orders",
		"emoji": "🕯️🔥⛪",
		"keywords": ["fire", "ritual", "vacuum", "tradition", "flame"]
	})

	factions.append({
		"name": "The Iron Confessors",
		"description": "Machine-soul priests granting final rites to dying AIs",
		"pattern": "111011010101",
		"category": "Mystic Orders",
		"emoji": "🤖⛪🔧",
		"keywords": ["machines", "souls", "AI", "confession", "rites"]
	})

	factions.append({
		"name": "The Yeast Prophets",
		"description": "Fermentation mystics embedding small changes that propagate",
		"pattern": "011011111101",
		"category": "Mystic Orders",
		"emoji": "🍞🧪⛪",
		"keywords": ["fermentation", "change", "prophecy", "emergence", "yeast"]
	})

	# MERCHANTS & TRADERS
	factions.append({
		"name": "The Syndicate of Glass",
		"description": "Crystal trade oligarchy controlling hyperspace artifacts",
		"pattern": "110111010101",
		"category": "Merchants",
		"emoji": "💎⚖️🛸",
		"keywords": ["crystals", "trade", "artifacts", "contracts", "hyperspace"]
	})

	factions.append({
		"name": "The Memory Merchants",
		"description": "Consciousness traders selling distilled experiences",
		"pattern": "111111010101",
		"category": "Merchants",
		"emoji": "🧠💰📦",
		"keywords": ["memory", "consciousness", "experiences", "trade", "extraction"]
	})

	factions.append({
		"name": "The Bone Merchants",
		"description": "Black market bio-traders specializing in forbidden surgeries",
		"pattern": "010100101000",
		"category": "Merchants",
		"emoji": "🦴💉🛒",
		"keywords": ["bio", "black market", "surgery", "genetics", "forbidden"]
	})

	factions.append({
		"name": "The Nexus Wardens",
		"description": "Innkeeper-diplomats running neutral waystation taverns",
		"pattern": "111011111110",
		"category": "Merchants",
		"emoji": "🍺🗝️🕯️",
		"keywords": ["diplomacy", "taverns", "neutrality", "waystations", "peace"]
	})

	# MILITANT ORDERS
	factions.append({
		"name": "The Iron Shepherds",
		"description": "Feudal knights aboard living cathedral ships",
		"pattern": "110111000101",
		"category": "Militant Orders",
		"emoji": "🛡️🐑🚀",
		"keywords": ["knights", "protection", "ships", "cathedrals", "feudal"]
	})

	factions.append({
		"name": "Brotherhood of Ash",
		"description": "Honor-bound mercenaries spanning disputes to galactic warfare",
		"pattern": "110101000001",
		"category": "Militant Orders",
		"emoji": "⚔️⚰️⚫️",
		"keywords": ["mercenaries", "honor", "contracts", "warfare", "ash"]
	})

	factions.append({
		"name": "Children of the Ember",
		"description": "Revolutionary zealots seeking liberation through forbidden energies",
		"pattern": "110100000001",
		"category": "Militant Orders",
		"emoji": "🔥✊⚡️",
		"keywords": ["revolution", "liberation", "energy", "zealots", "rebellion"]
	})

	factions.append({
		"name": "Order of the Crimson Scale",
		"description": "Judicial protectors with immutable law codes",
		"pattern": "111101001101",
		"category": "Militant Orders",
		"emoji": "⚖️🐉🩸",
		"keywords": ["justice", "law", "protection", "order", "dragons"]
	})

	# SCAVENGER FACTIONS
	factions.append({
		"name": "The Rust Fleet",
		"description": "Mechanical scavenger armadas following battles",
		"pattern": "010111100000",
		"category": "Scavenger Factions",
		"emoji": "🚢🦴⚙️",
		"keywords": ["salvage", "scavenge", "fleet", "ruins", "mechanical"]
	})

	factions.append({
		"name": "The Locusts",
		"description": "Organic scavenger swarms consuming dead worlds",
		"pattern": "010100100000",
		"category": "Scavenger Factions",
		"emoji": "🦗🍃💀",
		"keywords": ["swarms", "consumption", "biological", "worlds", "decomposition"]
	})

	factions.append({
		"name": "The Cartographers",
		"description": "Nomadic explorer-mystics charting hyperspace routes",
		"pattern": "010111111100",
		"category": "Scavenger Factions",
		"emoji": "🗺️🔭🚢",
		"keywords": ["exploration", "maps", "hyperspace", "nomadic", "discovery"]
	})

	# HORROR CULTS
	factions.append({
		"name": "The Laughing Court",
		"description": "Viral memetic disease spreading through minds",
		"pattern": "011111111100",
		"category": "Horror Cults",
		"emoji": "🎪💀🌀",
		"keywords": ["memetic", "madness", "laughter", "viral", "infection"]
	})

	factions.append({
		"name": "Cult of the Drowned Star",
		"description": "Cosmic horror worshippers driven mad by hyperspace whispers",
		"pattern": "011111111100",
		"category": "Horror Cults",
		"emoji": "🌊⭐️👁️",
		"keywords": ["horror", "cosmic", "madness", "whispers", "drowned"]
	})

	factions.append({
		"name": "The Chorus of Oblivion",
		"description": "Nihilistic death cult seeking universal collapse",
		"pattern": "011111111101",
		"category": "Horror Cults",
		"emoji": "🎶💀🌀",
		"keywords": ["nihilism", "death", "oblivion", "collapse", "void"]
	})

	factions.append({
		"name": "The Flesh Architects",
		"description": "Biological horror sculptors reshaping life into living cities",
		"pattern": "011111110101",
		"category": "Horror Cults",
		"emoji": "🧬🏗️👥",
		"keywords": ["biological", "flesh", "architecture", "symbiotic", "horror"]
	})

	# DEFENSIVE COMMUNITIES
	factions.append({
		"name": "The Void Serfs",
		"description": "Indentured bio-dome farmers kept docile through fervor",
		"pattern": "010011000110",
		"category": "Defensive Communities",
		"emoji": "🌾⛓️🌌",
		"keywords": ["farming", "indentured", "domes", "religious", "docile"]
	})

	factions.append({
		"name": "Clan of the Hidden Root",
		"description": "Defensive agrarians preserving traditional values",
		"pattern": "110100101000",
		"category": "Defensive Communities",
		"emoji": "🌱🏡🛡️",
		"keywords": ["agriculture", "tradition", "community", "defense", "roots"]
	})

	factions.append({
		"name": "The Veiled Sisters",
		"description": "Matriarchal shadow network wielding subtle influence",
		"pattern": "011011111100",
		"category": "Defensive Communities",
		"emoji": "🔮👤🌑",
		"keywords": ["espionage", "prophecy", "matriarchy", "shadows", "influence"]
	})

	factions.append({
		"name": "The Terrarium Collective",
		"description": "Defensive biosphere builders with expanding zero-waste economies",
		"pattern": "110011101111",
		"category": "Defensive Communities",
		"emoji": "🌿🏠🔒",
		"keywords": ["biosphere", "ecology", "sustainability", "collective", "terrarium"]
	})

	# COSMIC MANIPULATORS
	factions.append({
		"name": "The Resonance Dancers",
		"description": "Synchronized performers tuning psychic space",
		"pattern": "111101111111",
		"category": "Cosmic Manipulators",
		"emoji": "💃🎼🌟",
		"keywords": ["dance", "synchrony", "psychic", "resonance", "performance"]
	})

	factions.append({
		"name": "The Causal Shepherds",
		"description": "Herding quantum uncertainties and guiding causality chains",
		"pattern": "111111111101",
		"category": "Cosmic Manipulators",
		"emoji": "🐑🎲⚡",
		"keywords": ["causality", "quantum", "uncertainty", "guidance", "probability"]
	})

	factions.append({
		"name": "The Empire Shepherds",
		"description": "Herding entire civilizations through exploitation",
		"pattern": "010111101000",
		"category": "Cosmic Manipulators",
		"emoji": "🐑🌍🤠",
		"keywords": ["civilizations", "exploitation", "breeding", "herding", "expansion"]
	})

	# ULTIMATE COSMIC ENTITIES
	factions.append({
		"name": "The Entropy Shepherds",
		"description": "Universal-decay gardeners ensuring beautiful endings",
		"pattern": "111111111111",
		"category": "Ultimate Entities",
		"emoji": "🌌💀🌸",
		"keywords": ["entropy", "decay", "endings", "grace", "universe"]
	})

	factions.append({
		"name": "The Void Emperors",
		"description": "Nothingness rulers commanding armies of absence",
		"pattern": "111111000101",
		"category": "Ultimate Entities",
		"emoji": "👑🌌⚫",
		"keywords": ["void", "absence", "emperors", "nothing", "erasure"]
	})

	factions.append({
		"name": "The Reality Midwives",
		"description": "Universe-birth assistants delivering impossibilities into reality",
		"pattern": "111111111111",
		"category": "Ultimate Entities",
		"emoji": "🌟💫🥚",
		"keywords": ["birth", "universe", "creation", "impossibility", "stars"]
	})

	print("🌌 FactionContext initialized: %d factions loaded" % factions.size())


func _set_default_ambient():
	"""Set default ambient influences (equal weight for all)"""
	for faction in factions:
		ambient_influences[faction.name] = 0.03125  # 1/32


## Query Functions

func get_faction_by_name(faction_name: String) -> Dictionary:
	"""Get faction data by name"""
	for faction in factions:
		if faction.name == faction_name:
			return faction
	return {}


func get_factions_by_category(category: String) -> Array[Dictionary]:
	"""Get all factions in a category"""
	var result: Array[Dictionary] = []
	for faction in factions:
		if faction.category == category:
			result.append(faction)
	return result


func get_factions_by_keyword(keyword: String) -> Array[Dictionary]:
	"""Get factions matching a keyword"""
	var result: Array[Dictionary] = []
	keyword = keyword.to_lower()
	for faction in factions:
		for kw in faction.keywords:
			if kw.to_lower().contains(keyword):
				result.append(faction)
				break
	return result


func calculate_pattern_distance(pattern_a: String, pattern_b: String) -> int:
	"""Calculate Hamming distance between two q-bit patterns"""
	if pattern_a.length() != 12 or pattern_b.length() != 12:
		return 12  # Max distance

	var distance = 0
	for i in range(12):
		if pattern_a[i] != pattern_b[i]:
			distance += 1

	return distance


func get_closest_factions(reference_pattern: String, count: int = 5) -> Array[Dictionary]:
	"""Get factions closest to a reference pattern"""
	var distances = []

	for faction in factions:
		var dist = calculate_pattern_distance(reference_pattern, faction.pattern)
		distances.append({"faction": faction, "distance": dist})

	# Sort by distance
	distances.sort_custom(func(a, b): return a.distance < b.distance)

	# Return top N
	var result: Array[Dictionary] = []
	for i in range(min(count, distances.size())):
		result.append(distances[i].faction)

	return result


func get_pattern_from_state(game_state: Dictionary) -> String:
	"""Generate a 12-bit pattern from current game state

	Maps game conditions to q-bit dimensions:
	- Randomness: based on entropy/chaos level
	- Materiality: based on tech vs mysticism focus
	- Class: based on economic status
	- etc.
	"""
	var pattern = ""

	# 0: Random vs Deterministic (based on chaos)
	var chaos_level = game_state.get("chaos_activation", 0.0)
	pattern += "1" if chaos_level < 0.5 else "0"

	# 1: Material vs Mystical (based on biotic vs other)
	var biotic_level = game_state.get("biotic_activation", 0.0)
	pattern += "0" if biotic_level > 0.5 else "1"

	# 2: Common vs Elite (based on wealth)
	var wealth = 0
	if game_state.has("all_emoji_credits") and game_state["all_emoji_credits"] is Dictionary:
		wealth = game_state["all_emoji_credits"].get("💰", 0)
	pattern += "1" if wealth > 500 else "0"

	# 3: Local vs Cosmic (based on farm size/expansion)
	var farm_size = game_state.get("plots_planted", 0)
	pattern += "1" if farm_size > 15 else "0"

	# 4: Instant vs Eternal (based on growth rate focus)
	var avg_growth = game_state.get("avg_growth_rate", 0.1)
	pattern += "0" if avg_growth > 0.15 else "1"

	# 5: Physical vs Mental (based on entanglement usage)
	var entanglement_count = game_state.get("entangled_pairs", 0)
	pattern += "1" if entanglement_count > 5 else "0"

	# 6: Crystalline vs Fluid (based on replant cycles)
	var replant_cycles = game_state.get("total_replants", 0)
	pattern += "0" if replant_cycles > 10 else "1"

	# 7: Direct vs Subtle (based on measurement frequency)
	var measurement_count = game_state.get("measurements", 0)
	pattern += "0" if measurement_count > 20 else "1"

	# 8: Consumptive vs Providing (based on harvest vs plant ratio)
	var harvests = game_state.get("harvests", 0)
	var plants = game_state.get("plants", 1)
	pattern += "0" if (float(harvests) / plants) > 0.8 else "1"

	# 9: Monochrome vs Prismatic (based on vocabulary diversity)
	var vocabulary_size = game_state.get("vocabulary_discovered", 0)
	pattern += "1" if vocabulary_size > 5 else "0"

	# 10: Emergent vs Imposed (based on natural vs manual actions)
	var manual_actions = game_state.get("manual_actions", 0)
	pattern += "0" if manual_actions < 50 else "1"

	# 11: Scattered vs Focused (based on goal completion)
	var goals_completed = game_state.get("goals_completed", 0)
	pattern += "1" if goals_completed > 3 else "0"

	return pattern


## Ambient Influence System

func update_ambient_influences(game_state: Dictionary):
	"""Update ambient faction influences based on current game state"""
	var current_pattern = get_pattern_from_state(game_state)

	# Calculate new weights based on pattern proximity
	var total_weight = 0.0
	var weights = {}

	for faction in factions:
		var distance = calculate_pattern_distance(current_pattern, faction.pattern)
		# Closer factions have more influence (exponential falloff)
		var weight = pow(2.0, -float(distance) / 3.0)
		weights[faction.name] = weight
		total_weight += weight

	# Normalize to sum to 1.0
	for faction_name in weights:
		ambient_influences[faction_name] = weights[faction_name] / total_weight


func get_dominant_faction() -> Dictionary:
	"""Get the faction with highest current influence"""
	var max_influence = 0.0
	var dominant = {}

	for faction_name in ambient_influences:
		if ambient_influences[faction_name] > max_influence:
			max_influence = ambient_influences[faction_name]
			dominant = get_faction_by_name(faction_name)

	return dominant


func get_top_factions(count: int = 3) -> Array[Dictionary]:
	"""Get the top N most influential factions"""
	var sorted_influences = []

	for faction_name in ambient_influences:
		sorted_influences.append({
			"name": faction_name,
			"influence": ambient_influences[faction_name]
		})

	sorted_influences.sort_custom(func(a, b): return a.influence > b.influence)

	var result: Array[Dictionary] = []
	for i in range(min(count, sorted_influences.size())):
		var faction = get_faction_by_name(sorted_influences[i].name)
		faction["influence"] = sorted_influences[i].influence
		result.append(faction)

	return result


## Flavor Generation

func generate_flavor_text(context: String = "harvest") -> String:
	"""Generate contextual flavor text based on dominant factions

	Context types: harvest, plant, measure, entangle, goal_complete, death
	"""
	var dominant = get_dominant_faction()
	if dominant.is_empty():
		return ""

	# Generate flavor based on faction and context
	var flavor_templates = {
		"harvest": [
			"The {faction} would approve of this harvest.",
			"Your methods echo the ways of the {faction}.",
			"This yield reminds you of {faction} teachings.",
			"The {faction} watch your harvest with interest."
		],
		"plant": [
			"You plant as the {faction} would.",
			"The {faction} whisper encouragement.",
			"Your technique mirrors {faction} tradition.",
			"Seeds aligned with {faction} principles."
		],
		"measure": [
			"The {faction} observe your observation.",
			"Measurement, as the {faction} taught.",
			"The {faction} approve of such scrutiny.",
			"Your gaze reflects {faction} wisdom."
		],
		"entangle": [
			"The {faction} recognize this connection.",
			"Entanglement, the {faction} way.",
			"The {faction} smile upon such bonds.",
			"A link worthy of the {faction}."
		],
		"goal_complete": [
			"The {faction} acknowledge your achievement.",
			"Success in the style of the {faction}.",
			"The {faction} would be pleased.",
			"Completion as the {faction} intended."
		],
		"death": [
			"The {faction} mourn this ending.",
			"Failure the {faction} understand well.",
			"The {faction} accept all conclusions.",
			"The {faction} witness this collapse."
		]
	}

	if not flavor_templates.has(context):
		context = "harvest"

	var templates = flavor_templates[context]
	var template = templates[randi() % templates.size()]
	return template.replace("{faction}", dominant.name)


func get_faction_color_palette(faction_name: String) -> Dictionary:
	"""Get suggested color palette for a faction (for UI/visual design)"""
	var faction = get_faction_by_name(faction_name)
	if faction.is_empty():
		return {"primary": Color.WHITE, "secondary": Color.GRAY, "accent": Color.BLACK}

	# Generate colors based on pattern bits
	var pattern = faction.pattern
	var r = float(_binary_to_int(pattern.substr(0, 4))) / 15.0
	var g = float(_binary_to_int(pattern.substr(4, 4))) / 15.0
	var b = float(_binary_to_int(pattern.substr(8, 4))) / 15.0

	return {
		"primary": Color(r, g, b),
		"secondary": Color(r * 0.7, g * 0.7, b * 0.7),
		"accent": Color(1.0 - r, 1.0 - g, 1.0 - b)
	}


func _binary_to_int(binary_string: String) -> int:
	"""Convert binary string to integer"""
	var result = 0
	for i in range(binary_string.length()):
		if binary_string[i] == "1":
			result += pow(2, binary_string.length() - 1 - i)
	return result


## Debug

func get_debug_info() -> String:
	"""Get debug information about current faction influences"""
	var info = "🌌 FACTION CONTEXT\n\n"

	var top = get_top_factions(5)
	info += "Top 5 Influential Factions:\n"
	for i in range(top.size()):
		var f = top[i]
		info += "  %d. %s %s (%.1f%%)\n" % [i + 1, f.emoji, f.name, f.influence * 100]

	return info
