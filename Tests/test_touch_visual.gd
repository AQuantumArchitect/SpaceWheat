extends Control

## Visual Touch Test — exercises full signal chain without simulation
## Run: open Tests/TouchTest.tscn in editor, press Play, tap/swipe bubbles on screen
##
## What this tests:
## - Gesture detection thresholds (tap vs swipe vs dead zone)
## - Hit-testing accuracy (bubble radius, position)
## - Signal routing (TouchInputManager → QFG → handler)
## - Tap consumption (spatial hierarchy)
## - Chain swipe accumulation
##
## Uses a real biome (BioticFlux) with a frozen single-frame evolution.
## The batcher primes frozen buffers and applies one step, populating viz_cache
## with Bloch data, purity, MI, metadata — everything the renderer expects.

const QuantumForceGraphScript = preload("res://Core/Visualization/QuantumForceGraph.gd")
const BiomeEvolutionBatcherScript = preload("res://Core/Environment/BiomeEvolutionBatcher.gd")
const BioticFlux = preload("res://Core/Environment/BioticFluxBiome.gd")

var quantum_viz: Node2D = null
var status_label: Label = null
var biomes: Dictionary = {}
var batcher = null

# Track bubble states: grid_pos → "alive" | "measured"
var bubble_states: Dictionary = {}


func _ready():
	# 1. Instantiate a real biome (creates quantum_computer + viz_cache, evolution OFF)
	var biome = BioticFlux.new()
	biome.name = "BioticFlux"
	add_child(biome)
	biomes["BioticFlux"] = biome

	# 2. Prime frozen evolution — one frame through the real pipeline
	#    This populates viz_cache with Bloch, purity, MI, metadata, couplings
	batcher = BiomeEvolutionBatcherScript.new()
	batcher.initialize([biome], null)
	batcher._prime_frozen_buffers_only()
	batcher._apply_buffered_step(biome, false)
	print("  Primed frozen frame: viz_cache populated via standard railway")

	# 3. Create QFG through the real setup() path (initializes all rendering components)
	quantum_viz = QuantumForceGraphScript.new()
	add_child(quantum_viz)
	var viewport_size = get_viewport_rect().size
	quantum_viz.center_position = Vector2(viewport_size.x / 2, viewport_size.y / 2)
	quantum_viz.setup(biomes, null, null)

	# 4. Populate bubbles from quantum registers
	quantum_viz.create_all_register_bubbles()

	# 5. Assign grid positions so click handling works
	#    (register-based nodes default to Vector2i(-1,-1) which blocks tap signals)
	for i in quantum_viz.quantum_nodes.size():
		var node = quantum_viz.quantum_nodes[i]
		node.grid_position = Vector2i(i, 0)
		quantum_viz.quantum_nodes_by_grid_pos[node.grid_position] = node
		bubble_states[node.grid_position] = "alive"

	# 6. Connect signals (same wiring as FarmView)
	quantum_viz.node_clicked.connect(_on_quantum_node_clicked)
	quantum_viz.chain_swiped.connect(_on_chain_swiped)

	# 7. Visual feedback label
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(10, 10)
	status_label.text = "Tap bubbles to measure/pop. Swipe across bubbles to entangle."
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)

	# 8. Instructions label at bottom
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.position = Vector2(10, viewport_size.y - 80)
	instructions.text = "TAP unmeasured → freeze (cyan ring)\nTAP measured → pop (remove)\nSWIPE across 2+ → chain entangle"
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(instructions)

	print("Touch test rig ready — %d bubbles" % quantum_viz.quantum_nodes.size())


func _on_quantum_node_clicked(grid_pos: Vector2i, _button_index: int) -> void:
	var state = bubble_states.get(grid_pos, "")
	if state == "":
		_set_status("Miss — no bubble at %s" % grid_pos)
		return

	if state == "alive":
		# Measure: freeze bubble visually
		_measure_bubble(grid_pos)
	elif state == "measured":
		# Pop: remove bubble
		_pop_bubble(grid_pos)


func _measure_bubble(grid_pos: Vector2i) -> void:
	var node = quantum_viz.quantum_nodes_by_grid_pos.get(grid_pos)
	if not node:
		return

	# Freeze visuals — show collapsed state
	node.emoji_north_opacity = 1.0
	node.emoji_south_opacity = 0.0
	node.color = Color(0.0, 0.8, 0.8, 0.9)  # Cyan for measured
	node.coherence = 0.0
	node.velocity = Vector2.ZERO

	bubble_states[grid_pos] = "measured"
	_set_status("Measured at %s → %s [%s]" % [grid_pos, node.emoji_north, node.biome_name])
	print("  MEASURE %s → %s" % [grid_pos, node.emoji_north])


func _pop_bubble(grid_pos: Vector2i) -> void:
	var node = quantum_viz.quantum_nodes_by_grid_pos.get(grid_pos)
	if not node:
		return

	# Remove bubble from QFG
	quantum_viz.quantum_nodes.erase(node)
	quantum_viz.quantum_nodes_by_grid_pos.erase(grid_pos)
	bubble_states.erase(grid_pos)

	quantum_viz.queue_redraw()
	_set_status("Popped at %s — +10 credits" % grid_pos)
	print("  POP %s — bubble removed" % grid_pos)


func _on_chain_swiped(positions: Array) -> void:
	var pos_strs: Array = []
	for p in positions:
		pos_strs.append(str(p))
	var chain_str = " → ".join(pos_strs)
	_set_status("Chain swipe: %s (%d bubbles)" % [chain_str, positions.size()])
	print("  CHAIN SWIPE: %s" % chain_str)


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
