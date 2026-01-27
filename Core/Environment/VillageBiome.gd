class_name VillageBiome
extends "res://Core/Environment/BiomeBase.gd"

const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

## Village Biome - Civilization and transformation ecosystem
## Fire/ice, grain/bread, mill power, microbiome to civilization, commerce
##
## Themes: Hearth, baker, millwright, microbiome, granary

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const TRANSFORMATION_RATE = 0.2   # Grain → Bread
const FERMENTATION_RATE = 0.15    # Microbes → People
const MILL_RATE = 0.12            # Gears process grain
const TRADE_RATE = 0.06           # Commerce coupling

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for 5-qubit system
	register_emoji_pair("🔥", "❄️")  # Hearth temperature axis
	register_emoji_pair("🌾", "🍞")  # Transformation axis
	register_emoji_pair("⚙️", "💨")  # Mill power axis
	register_emoji_pair("🦠", "👥")  # Microbiome/Society axis
	register_emoji_pair("💰", "🧺")  # Commerce axis

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.8, 0.6, 0.3, 0.3)  # Warm village brown/orange
	visual_label = "🏘️ Village"
	visual_center_offset = Vector2(0.45, -0.45)  # Top-right (Y position)
	visual_oval_width = 640.0
	visual_oval_height = 400.0

	print("  ✅ VillageBiome initialized (QuantumComputer, 5 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer for Village biome (5 qubits)."""
	print("🏘️ Initializing Village QuantumComputer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("Village")

	# Allocate 5 qubits with emoji axes
	quantum_computer.allocate_axis(0, "🔥", "❄️")  # Hearth: Fire/Ice
	quantum_computer.allocate_axis(1, "🌾", "🍞")  # Transformation: Grain/Bread
	quantum_computer.allocate_axis(2, "⚙️", "💨")  # Mill Power: Gears/Wind
	quantum_computer.allocate_axis(3, "🦠", "👥")  # Microbiome: Bacteria/People
	quantum_computer.allocate_axis(4, "💰", "🧺")  # Commerce: Money/Baskets

	# Initialize to warm village with grain |00000⟩ = 🔥🌾⚙️🦠💰
	quantum_computer.initialize_basis(0)

	print("  📊 RegisterMap configured (5 qubits, 32 basis states)")

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🏘️ IconRegistry not available!")
		return

	# Get or create Icons for village emojis
	var village_emojis = ["🔥", "❄️", "🌾", "🍞", "⚙️", "💨", "🦠", "👥", "💰", "🧺"]
	var icons = {}

	for emoji in village_emojis:
		var icon = icon_registry.get_icon(emoji)
		if not icon:
			# Create basic village icon if not found
			icon = _create_village_emoji_icon(emoji)
			icon_registry.register_icon(icon)
		icons[emoji] = icon

	# Configure village-specific dynamics
	_configure_village_dynamics(icons, icon_registry)

	# Build operators using cached method
	build_operators_cached("VillageBiome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  🏘️ Village QuantumComputer ready!")


func _create_village_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for village emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Village " + emoji

	# Set up basic couplings based on emoji role
	match emoji:
		"🔥":  # Fire - hearth oscillation
			icon.hamiltonian_couplings = {"❄️": 0.7, "🌾": 0.08}
			icon.self_energy = 0.5
		"❄️":  # Ice - cold hearth
			icon.hamiltonian_couplings = {"🔥": 0.7}
			icon.self_energy = -0.5
		"🌾":  # Grain - transforms to bread
			icon.hamiltonian_couplings = {"🍞": TRANSFORMATION_RATE, "⚙️": MILL_RATE, "💰": TRADE_RATE}
			icon.self_energy = 0.2
		"🍞":  # Bread - product of transformation
			icon.hamiltonian_couplings = {"🌾": TRANSFORMATION_RATE, "🧺": 0.07, "🦠": 0.08}
			icon.self_energy = 0.3
		"⚙️":  # Gears - mechanical power
			icon.hamiltonian_couplings = {"💨": 0.1, "🌾": MILL_RATE}
			icon.self_energy = 0.3
		"💨":  # Wind - drives mill
			icon.hamiltonian_couplings = {"⚙️": 0.1}
			icon.self_energy = 0.1
		"🦠":  # Bacteria - fermentation, microbiome
			icon.hamiltonian_couplings = {"👥": FERMENTATION_RATE, "🍞": 0.08}
			icon.self_energy = 0.4
		"👥":  # People - civilization
			icon.hamiltonian_couplings = {"🦠": FERMENTATION_RATE, "💰": 0.05}
			icon.self_energy = 0.2
		"💰":  # Money - commerce
			icon.hamiltonian_couplings = {"🧺": 0.05, "🌾": TRADE_RATE, "👥": 0.05}
			icon.self_energy = 0.3
		"🧺":  # Baskets - hold goods
			icon.hamiltonian_couplings = {"💰": 0.05, "🍞": 0.07}
			icon.self_energy = 0.1

	return icon


func _configure_village_dynamics(icons: Dictionary, icon_registry) -> void:
	"""Configure village-specific Icon dynamics."""
	# Fire bakes grain into bread
	if icons.has("🔥") and icons.has("🍞"):
		icons["🔥"].lindblad_incoming["🍞"] = 0.03

	# Yeast (microbes) help bread rise
	if icons.has("🦠") and icons.has("🍞"):
		icons["🦠"].lindblad_incoming["🍞"] = 0.02

	# Trade creates bread from money
	if icons.has("💰") and icons.has("🍞"):
		icons["💰"].lindblad_incoming["🍞"] = 0.01


func get_biome_type() -> String:
	return "Village"


func get_paired_emoji(emoji: String) -> String:
	"""Get the paired emoji for this biome's quantum axis"""
	return emoji_pairings.get(emoji, "?")


func _rebuild_quantum_operators_impl() -> void:
	"""Rebuild operators when IconRegistry changes."""
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry or not quantum_computer:
		return

	var village_emojis = ["🔥", "❄️", "🌾", "🍞", "⚙️", "💨", "🦠", "👥", "💰", "🧺"]
	var icons = {}

	for emoji in village_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon

	if icons.size() > 0:
		_configure_village_dynamics(icons, icon_registry)
		build_operators_cached("VillageBiome", icons)
