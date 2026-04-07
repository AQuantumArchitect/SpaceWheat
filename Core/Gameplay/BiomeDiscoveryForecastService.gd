class_name BiomeDiscoveryForecastService
extends RefCounted

const BiomeAffinityCalculator = preload("res://Core/Quantum/BiomeAffinityCalculator.gd")
const BiomeRegistryClass = preload("res://Core/Biomes/BiomeRegistry.gd")
const PolicyStateProjector = preload("res://Core/AI/PolicyStateProjector.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

const FLOOR = 0.1
const QUEST_SCALE = 5.0
const VOCAB_SCALE = 2.0
const MILK_SCALE = 3.0

# Mutable weight overrides — set via configure() from rig configure_discovery action.
# Defaults to the consts above when empty.
static var _weights: Dictionary = {}


static func configure(weights: Dictionary) -> void:
	_weights = weights.duplicate()


static func _w(key: String, default: float) -> float:
	if _weights.has(key):
		return float(_weights[key])
	return default


static func compute_weights(farm, unexplored: Array) -> Array[float]:
	var weights: Array[float] = []
	if not farm:
		return weights

	var quest_pairs: Array = []
	var quest_manager = InstrumentLocator.resolve_quest_manager(farm, farm)
	if quest_manager:
		for quest in quest_manager.get_active_quests():
			var north = quest.get("reward_vocab_north", "")
			if not north.is_empty():
				quest_pairs.append({"north": north, "south": quest.get("reward_vocab_south", "")})
		if quest_manager.has_method("get_locked_offers"):
			for quest in quest_manager.get_locked_offers():
				var north = quest.get("reward_vocab_north", "")
				if not north.is_empty():
					quest_pairs.append({"north": north, "south": quest.get("reward_vocab_south", "")})

	var learned_pairs: Array = []
	var player_vocab = InstrumentLocator.resolve_player_vocabulary(farm)
	if player_vocab and player_vocab.has_method("get_all_learned_pairs"):
		learned_pairs = player_vocab.get_all_learned_pairs()

	var emoji_to_factions = PolicyStateProjector.get_emoji_to_factions()
	var biome_registry = BiomeRegistryClass.new()

	var w_floor = _w("floor", FLOOR)
	var w_quest = _w("quest_scale", QUEST_SCALE)
	var w_vocab = _w("vocab_scale", VOCAB_SCALE)
	var w_milk  = _w("milk_scale", MILK_SCALE)

	for biome_name in unexplored:
		var weight = w_floor

		for pair in quest_pairs:
			weight += w_quest * BiomeAffinityCalculator.calculate_affinity_by_name(pair, biome_name)

		if not learned_pairs.is_empty():
			var vocab_sum = 0.0
			for pair in learned_pairs:
				vocab_sum += BiomeAffinityCalculator.calculate_affinity_by_name(pair, biome_name)
			weight += w_vocab * vocab_sum / learned_pairs.size()

		var biome_data = biome_registry.get_by_name(biome_name)
		if biome_data:
			var best_fmv = PolicyStateProjector._MILK_MAX_DISTANCE
			for emoji in biome_data.emojis:
				for faction_name in emoji_to_factions.get(emoji, []):
					var faction_milk_value = PolicyStateProjector.faction_milk_value(faction_name)
					if faction_milk_value < best_fmv:
						best_fmv = faction_milk_value
			if best_fmv < PolicyStateProjector._MILK_MAX_DISTANCE:
				weight += w_milk * (float(PolicyStateProjector._MILK_MAX_DISTANCE) / max(1.0, float(best_fmv)))

		weights.append(weight)

	return weights


static func weighted_random_pick(items: Array, weights: Array[float]) -> Variant:
	var total = 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return items[randi() % items.size()]
	var roll = randf() * total
	var cumulative = 0.0
	for i in range(items.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return items[i]
	return items[items.size() - 1]


static func compute_forecast(farm) -> Dictionary:
	if not farm:
		return {}
	var observation_frame = InstrumentLocator.resolve_root_node(farm, "/root/ObservationFrame")
	if not observation_frame:
		return {}
	var unexplored = observation_frame.get_unexplored_biomes()
	if unexplored.is_empty():
		return {}
	var weights = compute_weights(farm, unexplored)
	var total = 0.0
	for weight in weights:
		total += weight
	var forecast: Dictionary = {}
	for i in range(unexplored.size()):
		forecast[unexplored[i]] = {
			"weight": weights[i],
			"probability": weights[i] / total if total > 0.0 else 0.0
		}
	return forecast
