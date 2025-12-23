class_name QuantumMill
extends Node2D

const FlowRateCalculator = preload("res://Core/GameMechanics/FlowRateCalculator.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")

## Quantum Mill - Non-destructive measurement infrastructure
## Couples to wheat qubits via ancilla, measures periodically
## Produces flour (resource) based on measurement outcomes

# Configuration
var grid_position: Vector2i = Vector2i.ZERO
var coupling_strength: float = 0.5  # Hamiltonian coupling coefficient
var measurement_interval: float = 1.0  # Seconds between measurements
var last_measurement_time: float = 0.0

# Statistics
var total_measurements: int = 0
var flour_outcomes: int = 0
var measurement_history: Array = []

# References
var entangled_wheat: Array = []
var farm_grid: FarmGrid = null


func _ready():
	set_process(true)
	print("🏭 QuantumMill initialized at %s" % grid_position)


func _process(delta: float):
	"""Update mill - perform measurements at interval"""
	last_measurement_time += delta

	if last_measurement_time >= measurement_interval:
		perform_quantum_measurement()
		last_measurement_time = 0.0


func set_entangled_wheat(plots: Array) -> void:
	"""Link wheat plots to this mill

	Args:
		plots: Array of WheatPlot references to couple to ancilla
	"""
	entangled_wheat = plots
	print("  Linked %d wheat plots to mill" % entangled_wheat.size())


func perform_quantum_measurement() -> void:
	"""Measure ancilla of all entangled wheat plots

	Process:
	1. Couple each wheat qubit to ancilla (H = g * Z_wheat ⊗ X_mill)
	2. Measure ancilla in computational basis (|0⟩ or |1⟩)
	3. Record outcome (nothing or flour)
	4. Add to economy
	"""
	if entangled_wheat.is_empty():
		return

	var total_flour = 0

	for plot in entangled_wheat:
		if not plot or not plot.quantum_state:
			continue

		# Step 1: Couple wheat to ancilla
		plot.quantum_state.couple_to_ancilla(coupling_strength, measurement_interval)

		# Step 2: Measure ancilla
		var outcome = plot.quantum_state.measure_ancilla()

		# Step 3: For gameplay/visuals, collapse wheat to one pole based on outcome
		# Flour (|1⟩) → South pole (theta=π, detritus)
		# Nothing (|0⟩) → North pole (theta=0, healthy)
		if outcome == "flour":
			plot.quantum_state.theta = PI  # Collapse to south (detritus state)
		else:
			plot.quantum_state.theta = 0.0  # Collapse to north (healthy state)
		plot.quantum_state.phi = 0.0  # Reset phase for clarity
		plot.has_been_measured = true

		# Step 4: Record outcome
		if outcome == "flour":
			total_flour += 1

	# Step 4: Update statistics
	total_measurements += 1
	flour_outcomes += total_flour

	measurement_history.append({
		"time": Time.get_ticks_msec(),
		"flour_produced": total_flour,
		"wheat_count": entangled_wheat.size()
	})

	# Step 5: Add to economy if available
	if total_flour > 0:
		if farm_grid and farm_grid.has_method("add_resource"):
			farm_grid.add_resource("flour", total_flour)


func get_flow_rate() -> Dictionary:
	"""Compute flour production flow rate from measurement history

	Returns:
		Dictionary with keys: mean, variance, std_error, confidence
	"""
	return FlowRateCalculator.compute_flow_rate(measurement_history, 60.0)


func get_debug_info() -> Dictionary:
	"""Return mill state for debugging"""
	var flow_rate = get_flow_rate()
	return {
		"position": grid_position,
		"total_measurements": total_measurements,
		"flour_produced": flour_outcomes,
		"wheat_count": entangled_wheat.size(),
		"flow_rate_mean": flow_rate.get("mean", 0.0),
		"coupling_strength": coupling_strength,
		"measurement_interval": measurement_interval,
	}
