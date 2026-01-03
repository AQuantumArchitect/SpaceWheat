extends Control

## Minimal test scene for quantum bubble touch controls
## Tests tap-to-measure and swipe-to-entangle gestures

const BathQuantumViz = preload("res://Core/Visualization/BathQuantumVisualizationController.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")

var quantum_viz: BathQuantumViz = null
var biotic_flux_biome = null
var market_biome = null

# Track test state - minimal plot wrappers
var test_plots: Dictionary = {}  # Vector2i → FarmPlot (wraps qubit)


func _ready() -> void:
	print("🎮 ═══════════════════════════════════════════════════════════")
	print("🎮 BUBBLE TOUCH CONTROL TEST")
	print("🎮 Testing: tap-to-measure, swipe-to-entangle")
	print("🎮 ═══════════════════════════════════════════════════════════")

	# Create biomes
	biotic_flux_biome = BioticFluxBiome.new()
	market_biome = MarketBiome.new()

	# Initialize biomes (they create their baths internally)
	add_child(biotic_flux_biome)
	add_child(market_biome)

	# Wait for async bath initialization
	await get_tree().process_frame
	await get_tree().process_frame

	# Create visualization controller
	quantum_viz = BathQuantumViz.new()

	# Add to a CanvasLayer so Node2D renders on top
	var viz_layer = CanvasLayer.new()
	viz_layer.layer = 1  # Render above UI layer (layer 0)
	add_child(viz_layer)
	viz_layer.add_child(quantum_viz)

	# Add biomes to visualization
	quantum_viz.add_biome("BioticFlux", biotic_flux_biome)
	quantum_viz.add_biome("Market", market_biome)

	# Initialize visualization (creates QuantumForceGraph)
	await quantum_viz.initialize()

	print("   ✅ Visualization initialized")

	# Connect touch gesture signals
	if quantum_viz.graph:
		# Tap gesture
		var tap_result = quantum_viz.graph.node_clicked.connect(_on_bubble_tapped)
		if tap_result == OK:
			print("   ✅ Tap gesture connected")
		else:
			print("   ❌ Failed to connect tap gesture")

		# Swipe gesture
		var swipe_result = quantum_viz.graph.node_swiped_to.connect(_on_bubble_swiped)
		if swipe_result == OK:
			print("   ✅ Swipe gesture connected")
		else:
			print("   ❌ Failed to connect swipe gesture")
	else:
		print("   ❌ No graph available!")

	# Plant some test plots
	_plant_test_plots()

	print("🎮 ═══════════════════════════════════════════════════════════")
	print("🎮 READY TO TEST!")
	print("🎮 - TAP a bubble to measure it (should turn cyan)")
	print("🎮 - SWIPE between bubbles to entangle them")
	print("🎮 - TAP a measured bubble to harvest (should disappear)")
	print("🎮 ═══════════════════════════════════════════════════════════")


func _plant_test_plots() -> void:
	"""Plant some test qubits in the biomes for touch testing"""
	print("\n🌱 Planting test plots...")

	# Plant 4 plots in BioticFlux biome
	var biotic_plots = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0)
	]

	for plot_pos in biotic_plots:
		# Create qubit in superposition (theta = PI/2 by default)
		# BioticFlux bath has: ☀ 🌙 🌾 🍄 💀 🍂
		var qubit = DualEmojiQubit.new("🌾", "🍄", PI / 2.0)  # wheat/mushroom

		# Create minimal plot wrapper (use FarmPlot for QuantumNode compatibility)
		var plot = FarmPlot.new()
		plot.grid_position = plot_pos
		plot.quantum_state = qubit
		plot.is_planted = true

		# Store plot for touch handler lookup
		test_plots[plot_pos] = plot

		# Request plot-driven bubbles (PROPER METHOD - bubbles know their grid_pos!)
		quantum_viz.request_plot_bubble("BioticFlux", plot_pos, plot)

		print("   🌾 Planted plot %s (BioticFlux)" % plot_pos)

	# Plant 2 plots in Market biome
	var market_plots = [
		Vector2i(4, 0),
		Vector2i(5, 0)
	]

	for plot_pos in market_plots:
		# Create qubit in superposition
		# Market bath has: 🐂 🐻 💰 📦 🏛️ 🏚️
		var qubit = DualEmojiQubit.new("💰", "🐂", PI / 2.0)  # money/bull

		# Create minimal plot wrapper (use FarmPlot for QuantumNode compatibility)
		var plot = FarmPlot.new()
		plot.grid_position = plot_pos
		plot.quantum_state = qubit
		plot.is_planted = true

		# Store plot for touch handler lookup
		test_plots[plot_pos] = plot

		# Request plot-driven bubbles (PROPER METHOD - bubbles know their grid_pos!)
		quantum_viz.request_plot_bubble("Market", plot_pos, plot)

		print("   💰 Planted plot %s (Market)" % plot_pos)

	print("   ✅ Planted %d test plots" % test_plots.size())

	# Debug: Verify bubbles are in graph's render list
	if quantum_viz.graph:
		print("   📊 Graph has %d quantum_nodes ready to render" % quantum_viz.graph.quantum_nodes.size())
		print("   📊 Graph indexed positions: %s" % quantum_viz.graph.quantum_nodes_by_grid_pos.keys())


func _on_bubble_tapped(grid_pos: Vector2i, button_index: int) -> void:
	"""Handle tap gesture on quantum bubble

	If unmeasured: MEASURE (collapse quantum state)
	If measured: HARVEST (remove bubble)
	"""
	print("\n🎯 BUBBLE TAPPED: %s (button: %d)" % [grid_pos, button_index])
	print("   Available plots: ", test_plots.keys())

	if not test_plots.has(grid_pos):
		print("   ⚠️  No plot at %s - grid_pos mismatch!" % grid_pos)
		return

	var plot = test_plots[grid_pos]

	# Check if already measured
	if plot.has_been_measured:
		print("   → HARVESTING measured plot")
		_harvest_plot(grid_pos)
	else:
		print("   → MEASURING quantum state")
		_measure_plot(grid_pos)


func _on_bubble_swiped(from_grid_pos: Vector2i, to_grid_pos: Vector2i) -> void:
	"""Handle swipe gesture between quantum bubbles - CREATE ENTANGLEMENT"""
	print("\n✨ BUBBLE SWIPE: %s → %s" % [from_grid_pos, to_grid_pos])

	if not test_plots.has(from_grid_pos):
		print("   ❌ Source plot %s doesn't exist" % from_grid_pos)
		return

	if not test_plots.has(to_grid_pos):
		print("   ❌ Target plot %s doesn't exist" % to_grid_pos)
		return

	var plot_a = test_plots[from_grid_pos]
	var plot_b = test_plots[to_grid_pos]

	if plot_a.has_been_measured or plot_b.has_been_measured:
		print("   ❌ Cannot entangle measured plots (classical states)")
		return

	# Create entanglement by setting same Bell state
	var qubit_a = plot_a.quantum_state
	var qubit_b = plot_b.quantum_state

	# Simple entanglement: both qubits in Bell state Φ+ (theta=π/2, phi=0)
	qubit_a.theta = PI / 2.0
	qubit_a.phi = 0.0
	qubit_b.theta = PI / 2.0
	qubit_b.phi = 0.0

	print("   ✅ Entangled %s ↔ %s (Φ+ state)" % [from_grid_pos, to_grid_pos])


func _measure_plot(grid_pos: Vector2i) -> void:
	"""Measure quantum state (collapse wavefunction) - uses Plot.measure() to test full pipeline"""
	var plot = test_plots[grid_pos]

	# Call plot.measure() like the real game does
	var outcome = plot.measure()

	print("   🔬 Measured: %s → %s" % [grid_pos, outcome])
	print("   📊 State: theta=%.3f, phi=%.3f, radius=%.3f" % [plot.quantum_state.theta, plot.quantum_state.phi, plot.quantum_state.radius])
	print("   📊 Plot.has_been_measured = %s" % plot.has_been_measured)
	print("   💡 Bubble should now have CYAN GLOW!")


func _harvest_plot(grid_pos: Vector2i) -> void:
	"""Harvest measured plot - uses Plot.harvest() to test full pipeline"""
	var plot = test_plots[grid_pos]

	# Call plot.harvest() like the real game does
	var harvest_data = plot.harvest()

	if harvest_data.get("success", false):
		var outcome = harvest_data.get("outcome", "?")
		var energy = harvest_data.get("energy", 0.0)

		print("   🌾 Harvested: %s → %s (energy: %.2f)" % [grid_pos, outcome, energy])
		print("   💡 Bubble should DISAPPEAR!")

		# Remove plot from tracking (it's now empty)
		test_plots.erase(grid_pos)
	else:
		print("   ❌ Harvest failed!")


func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts for testing"""
	# Debug: Show ALL input events
	if event is InputEventMouseButton and event.pressed:
		print("🖱️  MOUSE CLICK at: ", event.position)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			print("\n👋 Exiting test...")
			get_tree().quit()
		elif event.keycode == KEY_R:
			print("\n🔄 Reloading test scene...")
			get_tree().reload_current_scene()
		elif event.keycode == KEY_SPACE:
			print("\n📊 === TEST STATE ===")
			print("   Total plots: %d" % test_plots.size())
			var measured_count = 0
			for plot in test_plots.values():
				if plot.has_been_measured:
					measured_count += 1
			print("   Measured: %d plots" % measured_count)
			print("   Unmeasured: %d plots" % (test_plots.size() - measured_count))
