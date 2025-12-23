## Audit and repair all save files and scenarios
## Run with: godot -s audit_and_repair_saves.gd

extends SceneTree

func _init():
	print("\n" + "=".repeat(70))
	print("🔍 SPACEWHEAT SAVE FILE AUDIT & REPAIR TOOL")
	print("=".repeat(70) + "\n")

func _initialize():
	# Phase 1: Audit scenarios
	print("▶ PHASE 1: AUDIT SCENARIO FILES")
	print("-".repeat(70))
	await audit_scenarios()

	# Phase 2: Audit and repair save files
	print("\n▶ PHASE 2: AUDIT SAVE FILES")
	print("-".repeat(70))
	await audit_save_files()

	# Phase 3: Create repaired files
	print("\n▶ PHASE 3: CREATE FRESH SCENARIO")
	print("-".repeat(70))
	await create_fresh_scenario()

	print("\n" + "=".repeat(70))
	print("✅ AUDIT & REPAIR COMPLETE")
	print("=".repeat(70) + "\n")

	quit(0)

func audit_scenarios() -> void:
	"""Audit all scenario files"""

	var scenarios_dir = "res://Scenarios/"
	var dir = DirAccess.open(scenarios_dir)

	if not dir:
		print("❌ Could not open Scenarios directory")
		return

	var scenario_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			scenario_files.append(file_name)
		file_name = dir.get_next()

	print("Found %d scenario file(s)" % scenario_files.size())

	if scenario_files.is_empty():
		print("❌ No scenario files found!")
		return

	for scenario_file in scenario_files:
		var path = scenarios_dir + scenario_file
		_audit_game_state_file(path, "SCENARIO")

func audit_save_files() -> void:
	"""Audit all save files in user directory"""

	var saves_dir = "user://saves/"
	var dir = DirAccess.open(saves_dir)

	if not dir:
		print("No save directory exists yet (normal for fresh install)")
		return

	var save_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			save_files.append(file_name)
		file_name = dir.get_next()

	print("Found %d save file(s)" % save_files.size())

	if save_files.is_empty():
		print("No save files found (normal)")
		return

	for save_file in save_files:
		var path = saves_dir + save_file
		_audit_game_state_file(path, "SAVE")

func _audit_game_state_file(path: String, file_type: String) -> void:
	"""Audit a single GameState file"""

	print("\n📄 %s: %s" % [file_type, path.get_file()])

	var state = _try_load_resource(path)
	if not state:
		print("  ❌ Could not load file")
		return

	# Check if it's a GameState
	if state.get_script() != load("res://Core/GameState/GameState.gd"):
		print("  ❌ Not a GameState resource (type: %s)" % state.get_class())
		return

	print("  ✓ Valid GameState resource")

	# Audit properties
	var issues = []

	# Check grid dimensions
	var expected_width = 6
	var expected_height = 1
	if state.grid_width != expected_width or state.grid_height != expected_height:
		issues.append("Grid size: %dx%d (expected %dx%d)" % [
			state.grid_width, state.grid_height,
			expected_width, expected_height
		])

	# Check plot format
	for plot_idx in range(state.plots.size()):
		var plot = state.plots[plot_idx]

		# Check required fields
		if not plot.has("position"):
			issues.append("Plot %d: missing 'position'" % plot_idx)
		if not plot.has("type"):
			issues.append("Plot %d: missing 'type'" % plot_idx)
		if not plot.has("is_planted"):
			issues.append("Plot %d: missing 'is_planted'" % plot_idx)
		if not plot.has("has_been_measured"):
			issues.append("Plot %d: missing 'has_been_measured'" % plot_idx)
		if not plot.has("entangled_with"):
			issues.append("Plot %d: missing 'entangled_with'" % plot_idx)

		# Check for obsolete fields
		if plot.has("theta"):
			issues.append("Plot %d: has obsolete 'theta' (should regenerate from biome)" % plot_idx)
		if plot.has("phi"):
			issues.append("Plot %d: has obsolete 'phi' (should regenerate from biome)" % plot_idx)
		if plot.has("growth_progress"):
			issues.append("Plot %d: has obsolete 'growth_progress'" % plot_idx)
		if plot.has("is_mature"):
			issues.append("Plot %d: has obsolete 'is_mature'" % plot_idx)

	# Check economy
	if not state.has_meta("credits"):
		if state.credits < 0:
			issues.append("Economy: negative credits (%d)" % state.credits)

	# Report
	if issues.is_empty():
		print("  ✅ All checks passed")
	else:
		print("  ⚠️  %d issue(s) found:" % issues.size())
		for issue in issues:
			print("     - %s" % issue)

func create_fresh_scenario() -> void:
	"""Create a fresh, properly formatted default scenario"""

	print("Creating fresh default scenario...")

	var GameStateClass = load("res://Core/GameState/GameState.gd")
	var state = GameStateClass.new()
	state.scenario_id = "default"
	state.save_timestamp = Time.get_unix_time_from_system()
	state.game_time = 0.0
	state.grid_width = 6
	state.grid_height = 1
	state.credits = 20
	state.wheat_inventory = 0
	state.flour_inventory = 0
	state.labor_inventory = 0
	state.flower_inventory = 0
	state.mushroom_inventory = 0
	state.detritus_inventory = 0
	state.imperium_resource = 0
	state.tributes_paid = 0
	state.tributes_failed = 0

	# Create fresh plot array (6x1 grid)
	state.plots.clear()
	for y in range(state.grid_height):
		for x in range(state.grid_width):
			state.plots.append({
				"position": Vector2i(x, y),
				"type": 0,  # WHEAT
				"is_planted": false,
				"has_been_measured": false,
				"theta_frozen": false,
				"entangled_with": []
			})

	state.current_goal_index = 0
	state.completed_goals = []
	state.biotic_activation = 0.0
	state.chaos_activation = 0.0
	state.imperium_activation = 0.0
	state.active_contracts = []
	state.sun_moon_phase = 0.0

	# Save the file
	var path = "res://Scenarios/default.tres"
	var result = ResourceSaver.save(state, path)

	if result == OK:
		print("  ✅ Fresh scenario saved to: %s" % path)
		print("  Grid: %dx%d (%d plots)" % [
			state.grid_width, state.grid_height,
			state.grid_width * state.grid_height
		])
		print("  Economy: %d credits" % state.credits)
	else:
		print("  ❌ Failed to save scenario (error: %d)" % result)

func _try_load_resource(path: String) -> Resource:
	"""Try to load a resource, handling errors gracefully"""

	if not ResourceLoader.exists(path):
		return null

	var result = ResourceLoader.load(path)
	return result

func _print_plot_dict(plot: Dictionary) -> String:
	"""Print plot dictionary for debugging"""
	var parts = []
	for key in plot.keys():
		parts.append("%s=%s" % [key, plot[key]])
	return "{%s}" % ", ".join(parts)
