class_name ScenarioMetadata
extends Resource

## ScenarioMetadata - Describes a game scenario without loading full GameState
## Allows browsing available scenarios, difficulty levels, prerequisites
## Can be displayed in UI without instantiating full farm simulation

@export var scenario_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var difficulty: String = "normal"  # "tutorial", "easy", "normal", "hard", "expert", "sandbox"
@export var grid_size: String = "6x1"  # Display string like "6x1" or "4x2"
@export var starting_credits: int = 20
@export var estimated_time_minutes: int = 10  # Rough gameplay time estimate
@export var tags: Array[String] = []  # ["quantum", "entanglement", "economy", "challenge"]
@export var prerequisites: Array[String] = []  # scenario_ids that must be completed first
@export var unlocked_by_default: bool = true  # If false, requires prerequisites


func get_preview_string() -> String:
	"""Generate human-readable preview for UI"""
	return "%s (%s) - %s" % [display_name, difficulty, description]
