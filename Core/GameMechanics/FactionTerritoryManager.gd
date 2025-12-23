class_name FactionTerritoryManager
extends Node

## FactionTerritoryManager - Classical faction territory control system
## Manages which faction controls each plot and applies territorial effects
## NOTE: Icons alter quantum physics, Factions control classical territory

signal territory_changed(faction_id: String, plot_position: Vector2i, captured: bool)
signal faction_dominance_shift(dominant_faction: String, control_percentage: float)
signal territory_bonus_applied(plot_position: Vector2i, faction_id: String, bonus_type: String)

# Faction Manager reference (for faction data)
var faction_manager = null

# Territory tracking
var plot_controllers: Dictionary = {}  # Vector2i -> String (faction_id or "neutral")
var territory_scores: Dictionary = {}  # faction_id -> float

# Faction territorial strength (modified by tribute)
var faction_strength: Dictionary = {
	"granary_guilds": 0.3,    # Agricultural faction, starts moderate
	"carrion_throne": 0.4,    # Imperial faction, starts strong
	"laughing_court": 0.2,    # Chaos merchants, starts weak
	"yeast_prophets": 0.25,   # Conspiracy cultists
	"house_of_thorns": 0.15   # Defensive isolationists
}

# Territory update settings
var update_timer: float = 0.0
var update_interval: float = 2.0  # Recalculate territory every 2 seconds

# Influence calculation weights
const REPUTATION_WEIGHT = 0.3
const STRENGTH_WEIGHT = 0.7

# Territory effect multipliers (applied to controlled plots)
const TERRITORY_EFFECTS = {
	"granary_guilds": {
		"growth_rate_multiplier": 1.2,  # Agricultural efficiency
		"harvest_value_multiplier": 0.8,  # Lower market value (bulk farming)
		"entanglement_bonus": 0.15,  # Cooperative farming
		"color": Color(0.5, 0.8, 0.3),  # Olive green
		"emoji": "🌾",
		"description": "Agricultural Guild Territory"
	},
	"carrion_throne": {
		"growth_rate_multiplier": 0.7,  # Bureaucracy slows growth
		"harvest_value_multiplier": 1.4,  # Imperial premium prices
		"harvest_guarantee": true,  # Guaranteed minimum yield
		"entanglement_penalty": 0.2,  # Restricted connections
		"contract_bonus": 1.5,  # +50% contract rewards
		"color": Color(0.6, 0.4, 0.8),  # Imperial purple
		"emoji": "👑",
		"description": "Imperial Carrion Territory"
	},
	"laughing_court": {
		"growth_rate_multiplier": 1.0,  # Neutral growth
		"harvest_value_multiplier": 1.2,  # Better trade deals
		"random_bonus_chance": 0.15,  # Chaos bonuses
		"random_disaster_chance": 0.08,  # Fewer disasters than pure chaos
		"trade_bonus": 1.3,  # +30% wheat sale prices
		"color": Color(0.9, 0.5, 0.2),  # Orange/gold
		"emoji": "🎭",
		"description": "Laughing Court Territory"
	},
	"yeast_prophets": {
		"growth_rate_multiplier": 1.1,  # Ritual growth boost
		"harvest_value_multiplier": 0.9,  # Slightly lower value
		"conspiracy_boost": 1.4,  # +40% conspiracy activation
		"tomato_growth_bonus": 1.2,  # Tomatoes grow faster
		"color": Color(0.7, 0.3, 0.6),  # Purple-pink
		"emoji": "🍄",
		"description": "Yeast Prophet Territory"
	},
	"house_of_thorns": {
		"growth_rate_multiplier": 0.9,  # Defensive focus slows growth
		"harvest_value_multiplier": 1.0,  # Normal value
		"entanglement_penalty": 0.3,  # Isolationist - don't want connections
		"disaster_resistance": 0.7,  # 70% reduction in disaster chance
		"defense_bonus": 1.5,  # Protects from negative effects
		"color": Color(0.4, 0.6, 0.4),  # Dark green
		"emoji": "🛡️",
		"description": "House of Thorns Territory"
	}
}

# Faction home bases (center of influence)
const FACTION_CENTERS = {
	"granary_guilds": Vector2i(1, 1),    # Northwest
	"carrion_throne": Vector2i(2, 2),    # Center (dominant position)
	"laughing_court": Vector2i(3, 3),    # Southeast
	"yeast_prophets": Vector2i(0, 4),    # Southwest
	"house_of_thorns": Vector2i(4, 0)    # Northeast
}


func _ready():
	print("🏰 Faction Territory Manager initialized")
	_initialize_territory_scores()


func _initialize_territory_scores():
	for faction_id in TERRITORY_EFFECTS.keys():
		territory_scores[faction_id] = 0.0


func _process(delta):
	# Update territory periodically
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_recalculate_all_territories()


func set_faction_manager(manager):
	"""Set FactionManager reference"""
	faction_manager = manager
	print("🏰 Faction Manager connected to territory system")


func register_plot(plot_position: Vector2i):
	"""Register a plot for territory control"""
	if not plot_controllers.has(plot_position):
		plot_controllers[plot_position] = "neutral"


func unregister_plot(plot_position: Vector2i):
	"""Remove a plot from territory control"""
	plot_controllers.erase(plot_position)


func get_plot_controller(plot_position: Vector2i) -> String:
	"""Get which faction controls a specific plot"""
	return plot_controllers.get(plot_position, "neutral")


func get_territory_effects(plot_position: Vector2i) -> Dictionary:
	"""Get territorial effects for a plot"""
	var controller = get_plot_controller(plot_position)
	if controller == "neutral":
		return {}
	return TERRITORY_EFFECTS.get(controller, {})


func get_territory_score(faction_id: String) -> float:
	"""Get total territory control score for a faction"""
	return territory_scores.get(faction_id, 0.0)


func get_territory_percentage(faction_id: String) -> float:
	"""Get percentage of total territory controlled by faction (0-100)"""
	var total_plots = plot_controllers.size()
	if total_plots == 0:
		return 0.0

	var controlled = 0
	for controller in plot_controllers.values():
		if controller == faction_id:
			controlled += 1

	return (float(controlled) / float(total_plots)) * 100.0


func get_dominant_faction() -> String:
	"""Get faction with most territory control"""
	var max_score = 0.0
	var dominant = "neutral"

	for faction_id in territory_scores.keys():
		if territory_scores[faction_id] > max_score:
			max_score = territory_scores[faction_id]
			dominant = faction_id

	return dominant


## Territory calculation

func _recalculate_all_territories():
	"""Recalculate faction control for all plots"""
	var territory_changed_count = 0

	# Reset scores
	_initialize_territory_scores()

	# Calculate influence for each plot
	for plot_position in plot_controllers.keys():
		var new_controller = _calculate_plot_controller(plot_position)
		var old_controller = plot_controllers[plot_position]

		# Update controller if changed
		if new_controller != old_controller:
			plot_controllers[plot_position] = new_controller
			territory_changed.emit(new_controller, plot_position, true)
			territory_changed_count += 1

		# Update scores
		if new_controller != "neutral":
			territory_scores[new_controller] += 1.0

	# Check for dominance shifts
	if territory_changed_count > 0:
		_check_dominance_shift()


func _calculate_plot_controller(plot_position: Vector2i) -> String:
	"""Calculate which faction should control a specific plot"""

	var granary_influence = _calculate_faction_influence("granary_guilds", plot_position)
	var throne_influence = _calculate_faction_influence("carrion_throne", plot_position)
	var court_influence = _calculate_faction_influence("laughing_court", plot_position)
	var prophets_influence = _calculate_faction_influence("yeast_prophets", plot_position)
	var thorns_influence = _calculate_faction_influence("house_of_thorns", plot_position)

	# Threshold for control (must have significant influence)
	const CONTROL_THRESHOLD = 0.25

	# Find strongest faction
	var max_influence = 0.0
	var controller = "neutral"

	var influences = {
		"granary_guilds": granary_influence,
		"carrion_throne": throne_influence,
		"laughing_court": court_influence,
		"yeast_prophets": prophets_influence,
		"house_of_thorns": thorns_influence
	}

	for faction_id in influences:
		if influences[faction_id] > max_influence:
			max_influence = influences[faction_id]
			controller = faction_id

	if max_influence < CONTROL_THRESHOLD:
		return "neutral"

	return controller


func _calculate_faction_influence(faction_id: String, plot_position: Vector2i) -> float:
	"""Calculate a faction's influence on a specific plot"""

	# Base influence from faction strength
	var base_strength = faction_strength.get(faction_id, 0.0)

	# TODO: Add reputation bonus when FactionManager tracks reputation per faction
	# For now, reputation system is not implemented
	var reputation_bonus = 0.0

	# Spatial influence (distance from faction home base)
	var faction_center = FACTION_CENTERS.get(faction_id, Vector2i(2, 2))
	var distance = plot_position.distance_to(faction_center)
	var distance_factor = 1.0 / (1.0 + distance * 0.15)  # Closer plots = stronger influence

	# Combine factors (for now, just use base_strength since reputation not implemented)
	var total_influence = base_strength * STRENGTH_WEIGHT * distance_factor

	return clamp(total_influence, 0.0, 1.0)


func _check_dominance_shift():
	"""Check if dominant faction has changed"""
	var dominant = get_dominant_faction()
	if dominant != "neutral":
		var control_pct = get_territory_percentage(dominant)
		if control_pct > 50.0:  # Faction has majority control
			faction_dominance_shift.emit(dominant, control_pct)


## Player Actions (Classical Diplomacy)

func offer_tribute(faction_id: String, wheat_amount: int) -> bool:
	"""Offer wheat tribute to faction to boost their territorial strength"""
	if not TERRITORY_EFFECTS.has(faction_id):
		return false

	# Boost faction's territorial strength (reduced from 5% to 2% per wheat)
	var boost = wheat_amount * 0.02
	faction_strength[faction_id] = clamp(faction_strength[faction_id] + boost, 0.0, 1.0)

	print("🌾 Offered %d wheat to %s (+%.2f strength)" % [wheat_amount, faction_id, boost])
	return true


func suppress_faction(faction_id: String, credit_amount: int) -> bool:
	"""Pay credits to suppress a faction's territorial expansion"""
	if not TERRITORY_EFFECTS.has(faction_id):
		return false

	# Reduce faction strength (1 credit = -0.001 strength, so 100 credits = -0.1)
	var reduction = credit_amount * 0.001
	faction_strength[faction_id] = clamp(faction_strength[faction_id] - reduction, 0.0, 1.0)

	print("💰 Paid %d credits to suppress %s (-%.2f strength)" % [credit_amount, faction_id, reduction])
	return true


## Territory Statistics

func get_territory_stats() -> Dictionary:
	"""Get comprehensive territory statistics"""
	var total = plot_controllers.size()
	var neutral_count = _count_controlled_plots("neutral")
	var neutral_pct = (neutral_count / float(total)) * 100.0 if total > 0 else 0.0

	return {
		"granary_guilds_plots": _count_controlled_plots("granary_guilds"),
		"carrion_throne_plots": _count_controlled_plots("carrion_throne"),
		"laughing_court_plots": _count_controlled_plots("laughing_court"),
		"yeast_prophets_plots": _count_controlled_plots("yeast_prophets"),
		"house_of_thorns_plots": _count_controlled_plots("house_of_thorns"),
		"neutral_plots": neutral_count,
		"total_plots": total,
		"granary_guilds_percentage": get_territory_percentage("granary_guilds"),
		"carrion_throne_percentage": get_territory_percentage("carrion_throne"),
		"laughing_court_percentage": get_territory_percentage("laughing_court"),
		"yeast_prophets_percentage": get_territory_percentage("yeast_prophets"),
		"house_of_thorns_percentage": get_territory_percentage("house_of_thorns"),
		"neutral_percentage": neutral_pct,
		"dominant_faction": get_dominant_faction()
	}


func _count_controlled_plots(faction_id: String) -> int:
	"""Count number of plots controlled by a faction"""
	var count = 0
	for controller in plot_controllers.values():
		if controller == faction_id:
			count += 1
	return count


func print_territory_map():
	"""Debug: Print current territory control"""
	var stats = get_territory_stats()
	print("\n==========================")
	print("FACTION TERRITORY MAP")
	print("==========================")
	print("🌾 Granary Guilds: %d plots (%.1f%%)" % [stats.granary_guilds_plots, stats.granary_guilds_percentage])
	print("👑 Carrion Throne: %d plots (%.1f%%)" % [stats.carrion_throne_plots, stats.carrion_throne_percentage])
	print("🎭 Laughing Court: %d plots (%.1f%%)" % [stats.laughing_court_plots, stats.laughing_court_percentage])
	print("🍄 Yeast Prophets: %d plots (%.1f%%)" % [stats.yeast_prophets_plots, stats.yeast_prophets_percentage])
	print("🛡️  House of Thorns: %d plots (%.1f%%)" % [stats.house_of_thorns_plots, stats.house_of_thorns_percentage])
	print("⚪ Neutral: %d plots" % stats.neutral_plots)
	print("🏆 Dominant: %s" % stats.dominant_faction)
	print("==========================\n")
