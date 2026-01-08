extends Resource

## OldFaction - Legacy faction system (replaced by Core/Factions/Faction.gd)
## Represents one of 32 galactic factions
## Each faction has unique personality, contracts, and relationships
## NOTE: This is kept for backwards compatibility with FactionManager.gd

# Faction identity
@export var faction_id: String = ""
@export var faction_name: String = ""
@export var faction_emoji: String = ""  # Visual identifier (e.g., "🌾💰⚖️")

# Faction classification (12-bit system from lore)
@export var axiom_pattern: String = ""  # e.g., "110111011101"

# Faction archetype
@export var archetype: String = ""  # "imperial", "guild", "mystic", "merchant", "militant", etc.

# Faction description
@export var description: String = ""
@export var lore_text: String = ""

# Faction relationships
@export var allied_factions: Array[String] = []
@export var rival_factions: Array[String] = []
@export var neutral_factions: Array[String] = []

# Economic values
@export var wheat_buy_price: float = 2.0  # Credits per wheat unit
@export var wheat_sell_price: float = 1.5  # Credits player pays for seeds
@export var contract_frequency: float = 1.0  # How often they offer contracts (0-1)

# Icon preferences
@export var preferred_icon: String = ""  # "biotic", "chaos", "imperium", or "none"
@export var hated_icon: String = ""

# Special traits
@export var allows_conspiracies: bool = true
@export var enforces_purity: bool = false  # Requires no tomato contamination
@export var chaos_tolerance: float = 0.5  # 0=intolerant, 1=embraces chaos


func _init(id: String = "unknown"):
	faction_id = id
	faction_name = id.capitalize()


## Faction interaction helpers

func calculate_reputation_change(action: String, value: float) -> float:
	"""Calculate how much reputation changes based on player action"""
	match action:
		"contract_success":
			return value * 1.0
		"contract_failure":
			return value * -2.0  # Failure hurts more
		"conspiracy_discovered":
			if allows_conspiracies:
				return value * 0.5
			else:
				return value * -1.5  # They hate conspiracies
		"tribute_paid":
			return value * 0.3
		"icon_aligned":
			# Check if player aligned with faction's preferred Icon
			return value
		_:
			return 0.0


func get_relationship_modifier(other_faction_id: String) -> float:
	"""Get multiplier for reputation gains/losses based on faction relationships"""
	if allied_factions.has(other_faction_id):
		return 1.5  # Helping allies is extra good
	elif rival_factions.has(other_faction_id):
		return -1.0  # Helping rivals damages reputation
	else:
		return 0.0  # Neutral factions don't care


func is_compatible_with_icon(icon_name: String) -> bool:
	"""Check if faction approves of Icon alignment"""
	if preferred_icon == icon_name:
		return true
	elif hated_icon == icon_name:
		return false
	else:
		return true  # Neutral


func generate_contract_reward(difficulty: int) -> int:
	"""Calculate contract reward based on difficulty and faction wealth"""
	var base_reward = difficulty * 50
	var faction_multiplier = 1.0

	# Wealthier factions pay more
	if archetype == "merchant" or archetype == "imperial":
		faction_multiplier = 1.5
	elif archetype == "guild":
		faction_multiplier = 1.2

	return int(base_reward * faction_multiplier)


## Factory methods for creating specific factions

static func create_granary_guilds() -> Faction:
	"""The Granary Guilds 🌾💰⚖️ - Food control networks"""
	var faction = new("granary_guilds")
	faction.faction_name = "Granary Guilds"
	faction.faction_emoji = "🌾💰⚖️"
	faction.axiom_pattern = "110111011101"
	faction.archetype = "guild"
	faction.description = "Food-control networks providing civic management"
	faction.lore_text = "The Granary Guilds control bread distribution across the empire, maintaining order through strategic food supply."

	faction.allied_factions.append_array(["carrion_throne", "station_lords"])
	faction.rival_factions.append_array(["yeast_prophets", "bone_merchants"])

	faction.wheat_buy_price = 2.5  # They pay well for wheat
	faction.wheat_sell_price = 1.2  # Cheap seeds
	faction.contract_frequency = 0.9  # Frequent contracts

	faction.preferred_icon = "imperium"
	faction.hated_icon = "chaos"

	faction.allows_conspiracies = false
	faction.enforces_purity = true  # They want PURE wheat
	faction.chaos_tolerance = 0.1  # Very low chaos tolerance

	return faction


static func create_yeast_prophets() -> Faction:
	"""The Yeast Prophets 🍞🧪⛪ - Fermentation mystics"""
	var faction = new("yeast_prophets")
	faction.faction_name = "Yeast Prophets"
	faction.faction_emoji = "🍞🧪⛪"
	faction.axiom_pattern = "011011111101"
	faction.archetype = "mystic"
	faction.description = "Fermentation mystics embedding small changes that propagate"
	faction.lore_text = "The Yeast Prophets believe in patient, organic transformation through micro-adjustments to living systems."

	faction.allied_factions.append_array(["nexus_wardens", "dreaming_hive"])
	faction.rival_factions.append_array(["granary_guilds", "carrion_throne"])

	faction.wheat_buy_price = 1.8  # They pay less
	faction.wheat_sell_price = 1.5  # Seeds cost more
	faction.contract_frequency = 0.6  # Less frequent

	faction.preferred_icon = "biotic"
	faction.hated_icon = "imperium"

	faction.allows_conspiracies = true
	faction.enforces_purity = false
	faction.chaos_tolerance = 0.8  # High tolerance for chaos

	return faction


static func create_carrion_throne() -> Faction:
	"""The Carrion Throne 👑💀🏛️ - Central imperial bureaucracy"""
	var faction = new("carrion_throne")
	faction.faction_name = "Carrion Throne"
	faction.faction_emoji = "👑💀🏛️"
	faction.axiom_pattern = "110111001101"
	faction.archetype = "imperial"
	faction.description = "Central imperial bureaucracy feeding endless wars"
	faction.lore_text = "The eternal empire, sustained by wheat quotas extracted from millions of farming colonies across the galaxy."

	faction.allied_factions.append_array(["granary_guilds", "iron_shepherds", "station_lords"])
	faction.rival_factions.append_array(["house_of_thorns", "children_of_ember", "laughing_court"])

	faction.wheat_buy_price = 3.0  # Imperial demand = high prices
	faction.wheat_sell_price = 1.0  # Subsidized seeds
	faction.contract_frequency = 1.0  # Always demanding quotas

	faction.preferred_icon = "imperium"
	faction.hated_icon = "chaos"

	faction.allows_conspiracies = false
	faction.enforces_purity = true
	faction.chaos_tolerance = 0.0  # Zero tolerance

	return faction


static func create_house_of_thorns() -> Faction:
	"""House of Thorns 🌹🗡️👑 - Aristocratic assassins"""
	var faction = new("house_of_thorns")
	faction.faction_name = "House of Thorns"
	faction.faction_emoji = "🌹🗡️👑"
	faction.axiom_pattern = "111111010101"
	faction.archetype = "militant"
	faction.description = "Aristocratic assassins using poison and intrigue"
	faction.lore_text = "Subtle, deadly, and eternally patient. The House of Thorns plays the long game of galactic politics."

	faction.allied_factions.append_array(["memory_merchants", "bone_merchants"])
	faction.rival_factions.append_array(["carrion_throne", "iron_shepherds"])

	faction.wheat_buy_price = 1.5  # They don't care about wheat
	faction.wheat_sell_price = 2.0  # Expensive seeds
	faction.contract_frequency = 0.4  # Rare contracts

	faction.preferred_icon = "chaos"
	faction.hated_icon = "imperium"

	faction.allows_conspiracies = true
	faction.enforces_purity = false
	faction.chaos_tolerance = 0.9  # They thrive on chaos

	return faction


static func create_laughing_court() -> Faction:
	"""The Laughing Court 🎪💀🌀 - Viral memetic disease"""
	var faction = new("laughing_court")
	faction.faction_name = "Laughing Court"
	faction.faction_emoji = "🎪💀🌀"
	faction.axiom_pattern = "011111111100"
	faction.archetype = "horror"
	faction.description = "Viral memetic disease spreading through minds"
	faction.lore_text = "Their laughter echoes across dimensions. Once you hear it, you cannot unhear it. The joke is on all of us."

	faction.allied_factions.append_array(["cult_of_drowned_star", "flesh_architects"])
	faction.rival_factions.append_array(["carrion_throne", "keepers_of_silence", "granary_guilds"])

	faction.wheat_buy_price = 4.0  # They pay absurd prices (it's a joke)
	faction.wheat_sell_price = 0.1  # Seeds are almost free (trap!)
	faction.contract_frequency = 0.3  # Unpredictable

	faction.preferred_icon = "chaos"
	faction.hated_icon = "imperium"

	faction.allows_conspiracies = true
	faction.enforces_purity = false
	faction.chaos_tolerance = 1.0  # They ARE chaos

	return faction
