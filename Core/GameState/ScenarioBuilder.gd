class_name ScenarioBuilder

# Helper class for programmatically creating scenarios (DRY pattern)

static func create_scenario(
	scenario_id: String,
	grid_width: int,
	grid_height: int,
	starting_credits: int
) -> GameState:
	"""Create a basic scenario with specified grid and credits"""
	var state = GameState.create_for_grid(grid_width, grid_height)
	state.scenario_id = scenario_id
	state.credits = starting_credits
	state.wheat_inventory = 0
	state.labor_inventory = 0
	state.flour_inventory = 0
	state.flower_inventory = 0
	state.mushroom_inventory = 0
	state.detritus_inventory = 0
	state.game_time = 0.0
	state.time_elapsed = 0.0
	return state

static func create_with_preplanted(
	scenario_id: String,
	grid_width: int,
	grid_height: int,
	starting_credits: int,
	preplanted_plots: Array[Dictionary] = []
) -> GameState:
	"""Create scenario with some plots already planted

	preplanted_plots format:
	[
		{"position": Vector2i(0, 0), "type": 0},  # type: 0=wheat, 1=mushroom
		...
	]
	"""
	var state = create_scenario(scenario_id, grid_width, grid_height, starting_credits)

	# Plant crops if specified
	for plot_def in preplanted_plots:
		var pos = plot_def["position"] as Vector2i
		if pos.x < 0 or pos.x >= grid_width or pos.y < 0 or pos.y >= grid_height:
			push_warning("ScenarioBuilder: plot position out of bounds: %s" % pos)
			continue

		var plot_idx = pos.y * grid_width + pos.x
		if plot_idx >= 0 and plot_idx < state.plots.size():
			state.plots[plot_idx]["is_planted"] = true
			state.plots[plot_idx]["type"] = plot_def.get("type", 0)

	return state

static func create_tutorial(
	scenario_id: String,
	grid_width: int,
	grid_height: int,
	starting_credits: int,
	preplanted_plots: Array[Dictionary] = []
) -> GameState:
	"""Create a tutorial scenario

	Tutorial scenarios are beginner-friendly with generous starting resources
	"""
	return create_with_preplanted(scenario_id, grid_width, grid_height, starting_credits, preplanted_plots)

static func create_challenge(
	scenario_id: String,
	grid_width: int,
	grid_height: int,
	starting_credits: int
) -> GameState:
	"""Create a challenge scenario with scarce resources

	Challenge scenarios have limited credits and time pressure
	"""
	var state = create_scenario(scenario_id, grid_width, grid_height, starting_credits)
	# Challenge-specific setup (time limits, tribute mechanics) handled elsewhere
	return state

static func create_sandbox(
	scenario_id: String,
	grid_width: int,
	grid_height: int,
	starting_credits: int
) -> GameState:
	"""Create a sandbox/freeplay scenario

	Sandbox scenarios have generous resources and no goal requirements
	"""
	var state = create_scenario(scenario_id, grid_width, grid_height, starting_credits)
	# Sandbox-specific setup handled elsewhere
	return state
