class_name SimulationFixture
extends Control

## SimulationFixture - Manages multiple independent FarmView simulations
## Each simulation runs with a different debug scenario
## User can cycle between them for testing and inspection

const FarmView = preload("res://UI/FarmView.gd")

# Simulation instances
var simulations: Array = []
var current_simulation_index: int = 0

# Slideshow mode
var slideshow_enabled: bool = false
var slideshow_timer: float = 0.0
var slideshow_duration: float = 3.0  # seconds per scenario

# UI for displaying which scenario is shown
var scenario_label: Label = null


func _ready():
	print("🎬 SimulationFixture initializing...")
	set_process_input(true)
	set_process(true)

	# Create label for displaying current scenario
	scenario_label = Label.new()
	scenario_label.text = "Scenario: minimal | Press SPACE to cycle | S for slideshow"
	scenario_label.add_theme_font_size_override("font_size", 16)
	add_child(scenario_label)

	# Create simulation for each scenario
	var scenarios = ["minimal", "planted", "wealthy"]
	for scenario in scenarios:
		_create_simulation(scenario)

	# Show first simulation
	_show_simulation(0)

	print("🎬 SimulationFixture ready - Created %d simulations" % simulations.size())


func _create_simulation(scenario: String) -> void:
	"""Create a new FarmView simulation with given scenario"""
	var farm_view = FarmView.new()
	add_child(farm_view)

	# Store scenario name on the farm_view for later reference
	farm_view.set_meta("scenario_name", scenario)

	# Will load the scenario in its _ready()
	farm_view.call_deferred("_load_debug_scenario", scenario)

	simulations.append(farm_view)
	print("   Created simulation: %s" % scenario)


func _show_simulation(index: int) -> void:
	"""Show simulation at given index, hide others"""
	if index < 0 or index >= simulations.size():
		print("⚠️ Invalid simulation index: %d" % index)
		return

	# Hide all simulations
	for i in range(simulations.size()):
		simulations[i].visible = false

	# Show the selected one
	current_simulation_index = index
	simulations[index].visible = true

	var scenario_name = simulations[index].get_meta("scenario_name", "unknown")
	scenario_label.text = "🎬 Scenario: %s (%d/%d) | SPACE=cycle | S=slideshow | Arrow keys=nav" % [
		scenario_name,
		index + 1,
		simulations.size()
	]

	print("📺 Showing simulation: %s [%d/%d]" % [scenario_name, index + 1, simulations.size()])


func _process(delta):
	"""Handle slideshow mode"""
	if not slideshow_enabled:
		return

	slideshow_timer += delta
	if slideshow_timer >= slideshow_duration:
		slideshow_timer = 0.0
		_next_simulation()


func _input(event: InputEvent):
	"""Handle keyboard controls"""
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_SPACE:
			# Cycle to next simulation
			_next_simulation()
			get_tree().root.set_input_as_handled()

		KEY_LEFT:
			# Previous simulation
			_prev_simulation()
			get_tree().root.set_input_as_handled()

		KEY_RIGHT:
			# Next simulation
			_next_simulation()
			get_tree().root.set_input_as_handled()

		KEY_S:
			# Toggle slideshow
			slideshow_enabled = !slideshow_enabled
			slideshow_timer = 0.0
			if slideshow_enabled:
				print("▶️ Slideshow ENABLED")
				scenario_label.text += " [▶️ SLIDESHOW ON]"
			else:
				print("⏸️ Slideshow DISABLED")
				scenario_label.text = scenario_label.text.replace(" [▶️ SLIDESHOW ON]", "")
			get_tree().root.set_input_as_handled()


func _next_simulation() -> void:
	"""Show next simulation in order"""
	var next_index = (current_simulation_index + 1) % simulations.size()
	_show_simulation(next_index)


func _prev_simulation() -> void:
	"""Show previous simulation"""
	var prev_index = current_simulation_index - 1
	if prev_index < 0:
		prev_index = simulations.size() - 1
	_show_simulation(prev_index)
