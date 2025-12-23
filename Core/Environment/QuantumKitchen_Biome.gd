class_name QuantumKitchen_Biome
extends BiomeBase

## Quantum Kitchen Biome: Triplet Bell State to Bread Converter
##
## The Kitchen measures a triple Bell state (wheat + water + flour)
## and produces a bread qubit entangled with the input resources.
##
## Input: Three separate qubits in Bell state configuration
## (defined by spatial plot arrangement via gate action)
##
## Output: (🍞 bread, (🌾 wheat + 💧 water + 🌾 flour))
## A weird qubit where the bread is entangled with the consumed resources
##
## Mechanics:
## 1. Player arranges plots: wheat, water, flour in spatial pattern
## 2. Pattern defines Bell state type (GHZ, W, Cluster)
## 3. Kitchen measures triplet → collapses to bread production
## 4. Bread qubit stores entanglement (what resources created it)
## 5. Bread can be consumed by guilds (drains it away)

const BellStateDetector = preload("res://Core/QuantumSubstrate/BellStateDetector.gd")

## Bell state detector for triplet analysis
var bell_detector: BellStateDetector

## Input qubits (must be in Bell state)
var wheat_qubit: DualEmojiQubit   # 🌾 input
var water_qubit: DualEmojiQubit   # 💧 input
var flour_qubit: DualEmojiQubit   # 🌾 input (flour is wheat product)

## Output qubit
var bread_qubit: DualEmojiQubit   # (🍞, combined inputs)

## Kitchen parameters
var bread_production_efficiency: float = 0.8  # How much energy converts to bread
var bell_state_strength_required: float = 0.5  # Minimum state quality for measurement

## Statistics
var total_bread_produced: float = 0.0
var measurement_count: int = 0
var last_measurement_time: float = 0.0


func _ready():
	super._ready()
	bell_detector = BellStateDetector.new()
	add_child(bell_detector)

	print("🍳 Quantum Kitchen initialized")


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Kitchen has no continuous evolution"""
	pass  # Measurement-based system, not continuous evolution


func set_input_qubits(wheat: DualEmojiQubit, water: DualEmojiQubit, flour: DualEmojiQubit):
	"""
	Set the three input qubits that will be measured

	The qubits must be in a spatial Bell state configuration.
	The kitchen doesn't track positions - that's defined externally.
	"""
	wheat_qubit = wheat
	water_qubit = water
	flour_qubit = flour

	print("🍳 Kitchen inputs set: wheat (🌾), water (💧), flour (🌾)")


func configure_bell_state(plot_positions):
	"""
	Configure the Bell state from plot positions

	The plots themselves act as a "quantum gate" that defines
	how the three qubits are entangled.

	positions: [pos_wheat, pos_water, pos_flour] in physical layout
	"""
	if plot_positions.size() != 3:
		push_error("Kitchen requires exactly 3 plot positions")
		return false

	var types = ["wheat", "water", "flour"]
	bell_detector.set_plots(plot_positions, types)

	var state_type = bell_detector.get_state_type()
	var is_valid = bell_detector.is_valid_triplet()

	if is_valid:
		print("🍳 Bell state detected: %s (strength: %.1f)" % [
			bell_detector.get_state_name(),
			bell_detector.get_state_strength()
		])
	else:
		print("⚠️  Invalid Bell state configuration. Required arrangement:")
		print("   • GHZ: Three plots in line (horizontal/vertical/diagonal)")
		print("   • W State: L-shape arrangement")
		print("   • Cluster: T-shape arrangement")

	return is_valid


func can_produce_bread() -> bool:
	"""Check if kitchen is ready to produce bread"""
	# Need valid Bell state
	if not bell_detector.is_valid_triplet():
		return false

	# Need input qubits
	if not wheat_qubit or not water_qubit or not flour_qubit:
		return false

	# Need energy in inputs
	if wheat_qubit.radius < 0.1 or water_qubit.radius < 0.1 or flour_qubit.radius < 0.1:
		return false

	return true


func produce_bread() -> DualEmojiQubit:
	"""
	MEASUREMENT: Measure the triplet Bell state and produce bread

	Process:
	1. Verify Bell state is valid
	2. Measure each input qubit
	3. Collapse triplet to classical outcome
	4. Produce bread qubit entangled with inputs
	5. Consume input energy proportional to bread produced
	6. Return bread qubit

	Returns: New bread qubit (🍞, inputs) or null if failed
	"""
	if not can_produce_bread():
		print("⚠️  Cannot produce bread: missing valid Bell state or inputs")
		return null

	print("\n🍳 KITCHEN MEASUREMENT SEQUENCE")
	print(_make_line("═", 60))

	# Step 1: Get Bell state info
	var state_type = bell_detector.get_state_type()
	var state_name = bell_detector.get_state_name()
	var state_strength = bell_detector.get_state_strength()

	print("\n1️⃣  BELL STATE VERIFICATION:")
	print("   Type: %s" % state_name)
	print("   Strength: %.1f%%" % [state_strength * 100])
	print("   Description: %s" % bell_detector.get_state_description())
	print()

	# Step 2: Measure each input qubit
	print("2️⃣  MEASURING INPUT TRIPLET:")
	print()

	var wheat_outcome = _measure_qubit(wheat_qubit, "🌾 Wheat")
	var water_outcome = _measure_qubit(water_qubit, "💧 Water")
	var flour_outcome = _measure_qubit(flour_qubit, "🌾 Flour")

	# Step 3: Calculate bread energy from inputs
	print("\n3️⃣  CALCULATING BREAD ENERGY:")
	print()

	var wheat_energy = wheat_qubit.radius * wheat_outcome
	var water_energy = water_qubit.radius * water_outcome
	var flour_energy = flour_qubit.radius * flour_outcome

	var total_input_energy = wheat_energy + water_energy + flour_energy
	var bread_energy = total_input_energy * bread_production_efficiency

	print("   Wheat energy: %.2f" % wheat_energy)
	print("   Water energy: %.2f" % water_energy)
	print("   Flour energy: %.2f" % flour_energy)
	print("   Total input: %.2f" % total_input_energy)
	print("   Efficiency: %.0f%%" % [bread_production_efficiency * 100])
	print("   Bread produced: %.2f" % bread_energy)
	print()

	# Step 4: Collapse - consume inputs
	print("4️⃣  COLLAPSING TRIPLET (Consuming Inputs):")
	print()

	wheat_qubit.radius *= (1.0 - bread_production_efficiency * 0.5)
	water_qubit.radius *= (1.0 - bread_production_efficiency * 0.3)
	flour_qubit.radius *= (1.0 - bread_production_efficiency * 0.5)

	print("   Wheat remaining: %.2f" % wheat_qubit.radius)
	print("   Water remaining: %.2f" % water_qubit.radius)
	print("   Flour remaining: %.2f" % flour_qubit.radius)
	print()

	# Step 5: Create bread qubit
	# The bread is entangled with the inputs that created it
	# State 1: 🍞 (bread)
	# State 2: (🌾 🌾 💧) - the combined inputs
	print("5️⃣  CREATING BREAD QUBIT:")
	print()

	bread_qubit = BiomeUtilities.create_qubit("🍞", "(🌾🌾💧)", PI / 2.0)  # Start in superposition
	bread_qubit.radius = max(0.1, bread_energy)  # Store energy as radius

	# Theta influenced by Bell state type
	var theta_from_state = _get_theta_from_bell_state(state_type)
	bread_qubit.theta = theta_from_state

	print("   Bread qubit created:")
	print("   • Energy (radius): %.2f" % bread_qubit.radius)
	print("   • State (theta): %.2f rad (%.0f°)" % [
		bread_qubit.theta,
		bread_qubit.theta * 180.0 / PI
	])
	print("   • Entangled with: (wheat + water + flour)")
	print()

	# Step 6: Record measurement
	measurement_count += 1
	total_bread_produced += bread_energy
	last_measurement_time = Time.get_ticks_msec()

	print("6️⃣  MEASUREMENT COMPLETE")
	print("   Total bread ever produced: %.2f" % total_bread_produced)
	print("   Measurement count: %d" % measurement_count)
	print()
	print(_make_line("═", 60))
	print()

	return bread_qubit


func _make_line(char: String, count: int) -> String:
	"""Helper to create repeated character string"""
	var line = ""
	for i in range(count):
		line += char
	return line


func _measure_qubit(qubit: DualEmojiQubit, label: String) -> float:
	"""
	Measure a single qubit in the triplet

	Returns: Measurement outcome as probability (0.0-1.0)
	"""
	if not qubit:
		return 0.0

	var prob = sin(qubit.theta / 2.0) ** 2
	var outcome = "state 1" if randf() < prob else "state 2"
	var outcome_value = prob if outcome == "state 1" else (1.0 - prob)

	print("   %s: P(state1)=%.1f%% → measured %s (value: %.2f)" % [
		label,
		prob * 100,
		outcome,
		outcome_value
	])

	return outcome_value


func _get_theta_from_bell_state(state_type: BellStateDetector.BellStateType) -> float:
	"""
	Determine bread qubit theta based on Bell state type

	Different Bell state configurations create bread with different properties
	"""
	match state_type:
		BellStateDetector.BellStateType.GHZ_HORIZONTAL:
			return 0.0  # Pure bread state (coins equivalent in market analogy)
		BellStateDetector.BellStateType.GHZ_VERTICAL:
			return PI / 4.0  # Lean toward bread
		BellStateDetector.BellStateType.GHZ_DIAGONAL:
			return PI / 2.0  # Balanced bread/inputs
		BellStateDetector.BellStateType.W_STATE:
			return 3.0 * PI / 4.0  # Lean toward inputs
		BellStateDetector.BellStateType.CLUSTER_STATE:
			return PI  # Pure inputs state (maximizes resource linkage)
		_:
			return PI / 2.0  # Default balanced


func get_bread_qubit() -> DualEmojiQubit:
	"""Get the currently produced bread qubit"""
	return bread_qubit


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "QuantumKitchen"


func get_kitchen_status() -> Dictionary:
	"""Get current kitchen state for display"""
	var wheat_available = wheat_qubit.radius if wheat_qubit else 0.0
	var water_available = water_qubit.radius if water_qubit else 0.0
	var flour_available = flour_qubit.radius if flour_qubit else 0.0
	var bread_available = bread_qubit.radius if bread_qubit else 0.0

	var bell_state = "None"
	var bell_strength = 0.0
	if bell_detector:
		bell_state = bell_detector.get_state_name()
		bell_strength = bell_detector.get_state_strength()

	return {
		"wheat_energy": wheat_available,
		"water_energy": water_available,
		"flour_energy": flour_available,
		"bread_energy": bread_available,
		"bell_state": bell_state,
		"bell_strength": bell_strength,
		"can_produce": can_produce_bread(),
		"total_produced": total_bread_produced,
		"measurement_count": measurement_count,
		"last_measurement": last_measurement_time
	}


func _reset_custom() -> void:
	"""Override parent: Reset kitchen to initial state"""
	bread_qubit = null
	measurement_count = 0
	total_bread_produced = 0.0
	print("🍳 Quantum Kitchen reset")
