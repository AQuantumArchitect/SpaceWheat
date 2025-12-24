extends Control

## Test scene for QuantumForceGraph visualization
## Displays colorful qubits with force-directed layout and entanglement

const QuantumForceGraphScript = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumNodeScript = preload("res://Core/Visualization/QuantumNode.gd")
const FarmPlotScript = preload("res://Core/GameMechanics/FarmPlot.gd")
const DualEmojiQubitScript = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

@onready var graph_node = $QuantumForceGraph
@onready var qubit_count_label = $UI/InfoPanel/MarginContainer/VBoxContainer/QubitCountLabel
@onready var entanglement_label = $UI/InfoPanel/MarginContainer/VBoxContainer/EntanglementLabel
@onready var coherence_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CoherenceLabel

var graph: Node2D = null
var qubits = []
var update_timer = 0.0


func _ready():
	"""Initialize the test scene with sample qubits"""
	print("⚛️  QuantumForceGraph Test Scene initializing...")

	# Create and add the QuantumForceGraph to the scene
	graph = QuantumForceGraphScript.new()
	graph_node.add_child(graph)

	# Create sample qubits directly (without full farm grid)
	_create_sample_qubits()

	# Don't assign quantum_nodes directly - instead, manually add them one by one
	# This respects the Array[QuantumNode] type constraint
	for quantum_node in qubits:
		graph.quantum_nodes.append(quantum_node)
		if quantum_node.plot_id:
			graph.node_by_plot_id[quantum_node.plot_id] = quantum_node

	# Manually initialize the graph's visual properties
	graph.center_position = Vector2(640, 360)
	graph.graph_radius = 250.0

	# Tell graph to set up for rendering
	graph.set_process(true)

	print("✅ QuantumForceGraph test scene ready")
	print("   🔵 15 colorful qubits with force-directed layout")
	print("   🌀 Entanglement lines between coupled qubits")
	print("   ✨ Real-time dynamics and coherence visualization")


func _create_sample_qubits():
	"""Create sample qubits directly"""
	var emojis = ["🌿", "🐰", "🐦", "🐺", "💫", "🌟", "⭐", "✨", "🔮", "💎", "🌻", "🦋", "🐝", "🐛", "🦗"]
	var center = Vector2(640, 360)
	var radius = 250.0

	for i in range(emojis.size()):
		# Create a plot with quantum state
		var plot = FarmPlotScript.new()
		plot.plot_id = "test_plot_%d" % i
		plot.grid_position = Vector2i(i % 5, i / 5)

		# Create a qubit
		var qubit = DualEmojiQubitScript.new(emojis[i], emojis[(i + 1) % emojis.size()])
		qubit.theta = randf_range(0.0, PI)
		qubit.phi = randf_range(0.0, TAU)
		qubit.radius = randf_range(0.4, 1.0)

		plot.quantum_state = qubit

		# Calculate positions
		var grid_pos = Vector2i(i % 5, i / 5)
		var anchor_pos = center + Vector2(cos(i * TAU / emojis.size()) * radius, sin(i * TAU / emojis.size()) * radius)

		# Create a QuantumNode object (requires FarmPlot, anchor_pos, grid_pos, center_pos)
		var quantum_node = QuantumNodeScript.new(plot, anchor_pos, grid_pos, center)
		quantum_node.color = Color.from_hsv(float(i) / emojis.size(), 0.8, 0.9)
		quantum_node.emoji_north = emojis[i]
		quantum_node.emoji_south = emojis[(i + 1) % emojis.size()]

		qubits.append(quantum_node)


func _process(delta):
	"""Update metrics display"""
	update_timer += delta
	if update_timer > 0.5:
		_update_metrics()
		update_timer = 0.0

	# Close on Q
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()


func _update_metrics():
	"""Update the displayed metrics"""
	if qubits.is_empty():
		return

	# Count qubits
	var qubit_count = qubits.size()
	var entangled_count = 0
	var total_coherence = 0.0

	for quantum_node in qubits:
		# Count entanglements if plot exists
		if quantum_node.plot and "entangled_plots" in quantum_node.plot:
			entangled_count += quantum_node.plot.entangled_plots.size()

		# Get coherence from the actual qubit
		if quantum_node.plot and "quantum_state" in quantum_node.plot and quantum_node.plot.quantum_state:
			total_coherence += quantum_node.plot.quantum_state.radius

	# Update labels
	qubit_count_label.text = "Qubits: %d" % qubit_count
	entanglement_label.text = "Entangled: %d" % entangled_count

	if qubit_count > 0:
		var avg_coherence = total_coherence / qubit_count
		coherence_label.text = "Avg Coherence: %.2f" % avg_coherence
	else:
		coherence_label.text = "Avg Coherence: ────"
