class_name QuantumKitchen_Biome
extends BiomeBase

## Quantum Kitchen Biome: Bell State Entanglement Factory
##
## The Kitchen operates on QUANTUM inputs (still in superposition!)
## and creates entangled Bell states where:
##
##   |ψ_kitchen⟩ = α|🌾🌾🌾⟩ + β|🍞⟩
##
## The bread icon Hamiltonian drives the state toward 🍞.
## Measurement collapses the state normally (no special treatment).
##
## Architecture mirrors other biomes:
## - Celestial equivalent: oven_qubit (🔥/❄️ hot/cold)
## - Icon: bread_icon (Hamiltonian that attracts toward 🍞)
## - Inputs: 3 quantum qubits that become entangled with bread output
##
## Measurement choices:
## - "Separate" basis → collapse to |🌾🌾🌾⟩ (get 3 individual resources)
## - "Bread" basis → collapse to |🍞⟩ (get 1 bread qubit)
##
## Emoji pairings:
## - 🍞 pairs with the input triple (stored as metadata)
## - Input emojis retain their original pairings from source biome

const BellStateDetector = preload("res://Core/QuantumSubstrate/BellStateDetector.gd")

# ═══════════════════════════════════════════════════════════════════════════
# CELESTIAL: Oven temperature (drives baking speed)
# ═══════════════════════════════════════════════════════════════════════════
var oven_qubit: DualEmojiQubit = null  # 🔥/❄️ Hot/Cold
var oven_period: float = 15.0  # seconds for heat cycle

# ═══════════════════════════════════════════════════════════════════════════
# ICON: Bread attractor (Hamiltonian that drives toward 🍞)
# ═══════════════════════════════════════════════════════════════════════════
var bread_icon: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# BELL STATE: Entangled kitchen state
# ═══════════════════════════════════════════════════════════════════════════
var bell_detector: BellStateDetector = null
var input_qubits: Array = []  # The 3 quantum inputs (still in superposition!)
var bread_qubit: DualEmojiQubit = null  # The entangled output: 🍞/input_triple

# ═══════════════════════════════════════════════════════════════════════════
# EMOJI PAIRINGS: Registered in _ready() via BiomeBase.register_emoji_pair()
# ═══════════════════════════════════════════════════════════════════════════

# Kitchen parameters
var bread_production_efficiency: float = 0.8  # Energy conversion ratio

# Statistics
var total_bread_produced: float = 0.0
var entanglement_count: int = 0


func _ready():
	super._ready()

	# Register emoji pairings for this biome (uses BiomeBase system)
	register_emoji_pair("🔥", "❄️")  # Hot ↔ Cold
	register_resource("🍞", true, false)  # Bread is producible

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.9, 0.7, 0.4, 0.3)  # Warm bread color
	visual_label = "🍳 Kitchen"
	visual_center_offset = Vector2(0.0, -0.8)  # Top-center (more separation)
	visual_oval_width = 220.0
	visual_oval_height = 140.0

	print("  ✅ QuantumKitchen running in bath-first mode")


func _initialize_bath() -> void:
	"""Override BiomeBase: Initialize quantum bath for Kitchen biome"""
	_initialize_bath_kitchen()


func _initialize_kitchen_qubits():
	"""Set up quantum states for kitchen"""

	# Oven qubit: 🔥 Hot (north) / ❄️ Cold (south)
	# Hot oven bakes faster, cold oven preserves inputs
	oven_qubit = BiomeUtilities.create_qubit("🔥", "❄️", PI / 2.0)
	oven_qubit.phi = 0.0
	oven_qubit.radius = 1.0
	# energy removed - derived from theta
	# Model B: Oven state is managed by QuantumComputer, not stored in plots


func _initialize_bread_icon():
	"""Set up bread icon Hamiltonian"""

	# BREAD ICON - Attracts entangled state toward 🍞 outcome
	var bread_internal = DualEmojiQubit.new()
	bread_internal.north_emoji = "🍞"
	bread_internal.south_emoji = "🌾"  # Represents inputs
	bread_internal.theta = 0.0  # Points to bread
	bread_internal.phi = 0.0
	bread_internal.radius = 1.0

	bread_icon = {
		"hamiltonian_terms": {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.0},
		"stable_theta": 0.0,  # North pole = 🍞 (bread state)
		"stable_phi": 0.0,
		"spring_constant": 0.5,  # How strongly kitchen drives toward bread
		"internal_qubit": bread_internal,
	}


func _initialize_bath_kitchen() -> void:
	"""Initialize quantum bath for Kitchen biome (Bath-First)

	Kitchen emojis: 🔥 ❄️ 🍞 🌾
	Dynamics:
	  - Fire/Cold oscillate with time-dependent self-energy (oven cycle)
	  - Bread is produced from Wheat via Lindblad transfer
	  - Heat accelerates bread production
	"""
	print("🛁 Initializing Kitchen quantum bath...")

	# Create bath with Kitchen emoji basis
	bath = QuantumBath.new()
	var emojis = ["🔥", "❄️", "🍞", "🌾"]
	bath.initialize_with_emojis(emojis)

	# Initialize weighted distribution
	# Fire/Cold start balanced (moderate oven)
	# Wheat is input material, Bread starts low
	bath.initialize_weighted({
		"🔥": 0.25,  # Fire - oven heat
		"❄️": 0.25,  # Cold - oven rest
		"🌾": 0.40,  # Wheat - raw input
		"🍞": 0.10   # Bread - product (starts low)
	})

	# Collect Icons from registry
	# Get IconRegistry (now guaranteed to be first autoload)
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🛁 IconRegistry not available!")
		return

	var icons: Array[Icon] = []
	for emoji in emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons.append(icon)
		else:
			push_warning("🛁 Icon not found for emoji: " + emoji)

	# Build Hamiltonian and Lindblad operators from Icons
	if not icons.is_empty():
		bath.active_icons = icons
		bath.build_hamiltonian_from_icons(icons)
		bath.build_lindblad_from_icons(icons)

		print("  ✅ Bath initialized with %d emojis, %d icons" % [emojis.size(), icons.size()])
		print("  ✅ Hamiltonian: %d non-zero terms" % bath.hamiltonian_sparse.size())
		print("  ✅ Lindblad: %d transfer terms" % bath.lindblad_terms.size())
	else:
		push_warning("🛁 No icons found for Kitchen bath")

	print("  🍳 Kitchen ready for bread production!")


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Evolve kitchen quantum state"""
	# Bath mode: bread production dynamics handled by BiomeBase
	# Oven temperature and bread transformation come from bath Lindblad operators
	pass


func _apply_oven_oscillation(delta: float):
	"""Oven qubit oscillates between hot and cold"""
	if not oven_qubit:
		return

	var omega = TAU / oven_period
	var t = time_tracker.time_elapsed

	# Temperature oscillates (like sun in BioticFlux)
	var amplitude = PI / 4.0  # ±45° swing
	var base_theta = PI / 4.0  # Biased hot
	oven_qubit.theta = base_theta + amplitude * sin(omega * t)

	oven_qubit.theta = clamp(oven_qubit.theta, 0.0, PI)


func _apply_bread_hamiltonian(delta: float):
	"""Apply bread icon to drive entangled states toward 🍞"""
	if not bread_qubit:
		return

	# Get oven heat level (hot = faster baking)
	var heat = pow(cos(oven_qubit.theta / 2.0), 2) if oven_qubit else 0.5

	# Spring force toward bread state (theta=0)
	var target_theta = bread_icon["stable_theta"]
	var spring_k = bread_icon["spring_constant"] * heat  # Heat accelerates baking

	var theta_diff = target_theta - bread_qubit.theta
	bread_qubit.theta += theta_diff * spring_k * delta

	# Clamp theta
	bread_qubit.theta = clamp(bread_qubit.theta, 0.0, PI)


# ═══════════════════════════════════════════════════════════════════════════
# PUBLIC API: Kitchen operations
# ═══════════════════════════════════════════════════════════════════════════

func set_quantum_inputs(qubit1: DualEmojiQubit, qubit2: DualEmojiQubit, qubit3: DualEmojiQubit):
	"""
	Set the three QUANTUM input qubits (still in superposition!)

	These qubits will be entangled with the bread output.
	They are NOT measured yet - that happens when player uses measure tool.
	"""
	input_qubits = [qubit1, qubit2, qubit3]

	# Build input description from the qubits' emojis
	var input_desc = "%s%s%s" % [
		qubit1.north_emoji if qubit1 else "?",
		qubit2.north_emoji if qubit2 else "?",
		qubit3.north_emoji if qubit3 else "?",
	]

	print("🍳 Kitchen received quantum inputs: %s (still in superposition)" % input_desc)


func set_quantum_inputs_with_units(qubit1: DualEmojiQubit, qubit2: DualEmojiQubit, qubit3: DualEmojiQubit,
	units1: float, units2: float, units3: float):
	"""
	Set the three QUANTUM input qubits WITH resource amounts

	Resource units are stored in qubit metadata since radius is a computed property.
	"""
	input_qubits = [qubit1, qubit2, qubit3]

	# Build input description from the qubits' emojis
	var input_desc = "%s%s%s" % [
		qubit1.north_emoji if qubit1 else "?",
		qubit2.north_emoji if qubit2 else "?",
		qubit3.north_emoji if qubit3 else "?",
	]

	# Store resource amounts in qubit metadata
	if qubit1:
		qubit1.set_meta("resource_units", units1)
	if qubit2:
		qubit2.set_meta("resource_units", units2)
	if qubit3:
		qubit3.set_meta("resource_units", units3)

	print("🍳 Kitchen received quantum inputs: %s (still in superposition)" % input_desc)


func configure_bell_state(plot_positions: Array) -> bool:
	"""
	Configure Bell state from plot positions

	The spatial arrangement determines the entanglement type:
	- GHZ (line): Maximally entangled, all-or-nothing collapse
	- W (L-shape): Robust entanglement, one-survives collapse
	- Cluster (T-shape): Graph state, sequential measurement
	"""
	if plot_positions.size() != 3:
		push_error("Kitchen requires exactly 3 plot positions")
		return false

	bell_detector.set_plots(plot_positions, ["input1", "input2", "input3"])

	var is_valid = bell_detector.is_valid_triplet()
	if is_valid:
		print("🍳 Bell state configured: %s" % bell_detector.get_state_name())
	else:
		print("⚠️  Invalid Bell state configuration")

	return is_valid


func create_bread_entanglement() -> DualEmojiQubit:
	"""
	Create the entangled bread state from quantum inputs

	This creates the Bell state: α|inputs⟩ + β|🍞⟩
	The bread_icon Hamiltonian will drive it toward 🍞 over time.

	Returns: The bread qubit (entangled with inputs)
	"""
	if input_qubits.size() < 3:
		print("⚠️  Cannot create bread: need 3 quantum inputs")
		return null

	if not input_qubits[0] or not input_qubits[1] or not input_qubits[2]:
		print("⚠️  Cannot create bread: null input qubits")
		return null

	print("\n🍳 CREATING BREAD ENTANGLEMENT")
	print("═".repeat(60))

	# Calculate combined input resources
	# Resource units are stored in qubit metadata (can't use radius - it's computed from quantum computer)
	var total_resources = 0.0
	var input_desc = ""
	for i in range(3):
		var q = input_qubits[i]
		var units = q.get_meta("resource_units", 0.0) if q else 0.0
		total_resources += units
		input_desc += q.north_emoji if q else "?"
		print("  Input %d: %s/%s (θ=%.2f, units=%.1f)" % [
			i + 1,
			q.north_emoji if q else "?",
			q.south_emoji if q else "?",
			q.theta if q else 0.0,
			units,
		])

	# Create bread qubit: 🍞 / (inputs)
	# Starts at θ=π/2 (equal superposition of bread and inputs)
	bread_qubit = DualEmojiQubit.new("🍞", "(%s)" % input_desc)
	bread_qubit.theta = PI / 2.0  # Equal superposition
	bread_qubit.phi = 0.0

	# Store resource amount in metadata (can't directly set radius - it's computed)
	var bread_produced = total_resources * bread_production_efficiency
	bread_qubit.set_meta("resource_units", bread_produced)
	bread_qubit.set_meta("bread_radius", bread_produced)  # For measurement

	# Store input references for entanglement correlation
	bread_qubit.set_meta("entangled_inputs", input_qubits)
	bread_qubit.set_meta("input_description", input_desc)

	# Model B: Bread state is managed by QuantumComputer, not stored in plots
	entanglement_count += 1

	print("\n  Created: 🍞/(%s)" % input_desc)
	print("  θ = π/2 (equal superposition)")
	print("  Resource units = %.2f (%.0f%% of inputs)" % [bread_produced, bread_production_efficiency * 100])
	print("  Bread icon will drive toward 🍞 state...")
	print("═".repeat(60) + "\n")

	return bread_qubit


func measure_as_bread() -> DualEmojiQubit:
	"""
	Measure in the BREAD basis → collapse to |🍞⟩

	Returns the bread qubit collapsed to bread state.
	The input qubits are consumed (their information is now in the bread).
	"""
	if not bread_qubit:
		print("⚠️  No bread qubit to measure")
		return null

	print("🍞 MEASURING AS BREAD")

	# Collapse to bread state (theta → 0)
	bread_qubit.theta = 0.0

	# Clear input qubits (consumed) - mark them as used
	for q in input_qubits:
		if q:
			q.set_meta("resource_units", 0.0)  # Mark as consumed

	# Get bread production amount from metadata (can't use radius - it's computed)
	var bread_amount = bread_qubit.get_meta("bread_radius", 0.0)
	total_bread_produced += bread_amount

	print("  → Collapsed to 🍞 (resources: %.2f)" % bread_amount)

	return bread_qubit


func measure_as_separate() -> Array:
	"""
	Measure in the SEPARATE basis → collapse to |input₁⟩|input₂⟩|input₃⟩

	Returns the 3 individual input qubits (collapsed to their own states).
	The bread qubit is destroyed (the entanglement chose inputs over bread).
	"""
	if not bread_qubit or input_qubits.size() < 3:
		print("⚠️  No entanglement to measure")
		return []

	print("🌾 MEASURING AS SEPARATE INPUTS")

	var results = []
	for i in range(3):
		var q = input_qubits[i]
		if q:
			# Each input collapses based on its own theta
			var prob_north = pow(cos(q.theta / 2.0), 2)
			var collapsed_to_north = randf() < prob_north
			q.theta = 0.0 if collapsed_to_north else PI
			results.append(q)
			print("  → Input %d collapsed to %s" % [i + 1, q.north_emoji if collapsed_to_north else q.south_emoji])

	# Destroy bread qubit (chose inputs instead)
	bread_qubit.radius = 0.0
	bread_qubit = null

	return results


func get_bread_probability() -> float:
	"""Get probability of measuring bread (vs separate inputs)"""
	if not bread_qubit:
		return 0.0

	# P(bread) = cos²(θ/2) since bread is north pole
	return pow(cos(bread_qubit.theta / 2.0), 2)


func get_kitchen_status() -> Dictionary:
	"""Get current kitchen state for display"""
	var heat = pow(cos(oven_qubit.theta / 2.0), 2) if oven_qubit else 0.0

	return {
		"has_inputs": input_qubits.size() >= 3,
		"has_bread_entanglement": bread_qubit != null,
		"bread_probability": get_bread_probability(),
		"oven_heat": heat,
		"oven_theta": oven_qubit.theta if oven_qubit else 0.0,
		"bread_resources": bread_qubit.radius if bread_qubit else 0.0,
		"total_produced": total_bread_produced,
		"entanglement_count": entanglement_count,
	}


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "QuantumKitchen"


func get_paired_emoji(emoji: String) -> String:
	"""Get the paired emoji for this biome's axis"""
	return emoji_pairings.get(emoji, "?")


# ═══════════════════════════════════════════════════════════════════════════
# LEGACY API: Compatibility with old tests
# ═══════════════════════════════════════════════════════════════════════════

func set_input_qubits(wheat: DualEmojiQubit, water: DualEmojiQubit, flour: DualEmojiQubit):
	"""Legacy: Set inputs (redirects to new API)"""
	set_quantum_inputs(wheat, water, flour)


func can_produce_bread() -> bool:
	"""Legacy: Check if kitchen can produce bread"""
	return input_qubits.size() >= 3 and input_qubits[0] != null


func produce_bread() -> DualEmojiQubit:
	"""Legacy: Create bread (redirects to new API)"""
	if not bread_qubit:
		create_bread_entanglement()
	return measure_as_bread()
