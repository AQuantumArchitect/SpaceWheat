class_name BiomeTimeTracker
extends RefCounted

## Manages time tracking and periodic events for biomes
## Composition pattern - biomes own an instance instead of duplicating code

var time_elapsed: float = 0.0
var period: float = 20.0  # Default sun/moon period (seconds)

signal period_complete(cycle_count: int)

var cycle_count: int = 0


func update(delta: float) -> void:
	# Update time tracker each frame
	time_elapsed += delta

	# Check for period completion
	if time_elapsed >= period and period > 0:
		cycle_count += 1
		period_complete.emit(cycle_count)
		time_elapsed = fmod(time_elapsed, period)


func get_cycle_progress() -> float:
	# Returns 0.0 to 1.0 progress through current cycle
	return time_elapsed / period if period > 0 else 0.0


func reset() -> void:
	# Reset time tracker to initial state
	time_elapsed = 0.0
	cycle_count = 0
