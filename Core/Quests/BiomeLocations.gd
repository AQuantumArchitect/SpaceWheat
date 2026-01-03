class_name BiomeLocations
extends Resource

## Location names for each biome
## 5 locations per biome = 25 total

# =============================================================================
# BIOME LOCATION NAMES
# =============================================================================

const LOCATIONS = {
	"BioticFlux": [
		"the wheat fields",
		"the mushroom groves",
		"the sun altar",
		"the moon shrine",
		"the detritus pits"
	],
	"Kitchen": [
		"the eternal flame",
		"the ice stores",
		"the bread ovens",
		"the fermentation vats",
		"the grinding stones"
	],
	"Forest": [
		"the wolf den",
		"the eagle's nest",
		"the rabbit warrens",
		"the ancient grove",
		"the bare clearing"
	],
	"Market": [
		"the trading floor",
		"the bull pen",
		"the bear cave",
		"the vault",
		"the auction block"
	],
	"GranaryGuilds": [
		"the grain silos",
		"the flour mills",
		"the bread halls",
		"the water cisterns",
		"the Guild chambers"
	],
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_random_location(biome_name: String) -> String:
	"""Get random location for biome"""
	var locations = LOCATIONS.get(biome_name, LOCATIONS["BioticFlux"])
	return locations[randi() % locations.size()]

static func get_all_locations(biome_name: String) -> Array:
	"""Get all locations for biome"""
	return LOCATIONS.get(biome_name, LOCATIONS["BioticFlux"]).duplicate()

static func has_biome(biome_name: String) -> bool:
	"""Check if biome has locations defined"""
	return LOCATIONS.has(biome_name)
