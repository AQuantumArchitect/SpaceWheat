class_name VillageBiome
extends "res://Core/Environment/BiomeBase.gd"

const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

## Village Biome - Starter civilization hub (reduced emoji set)
## Fire/ice, labor/bread, mill power, commerce
##
## Themes: Hearth, baker, millwright, labor, trade

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const USE_REDUCED_EMOJI_SET = true

const REDUCED_VILLAGE_EMOJI_AXES = [
	{"north": "🔥", "south": "❄️"},
	{"north": "👥", "south": "🍞"},
	{"north": "⚙️", "south": "💨"},
	{"north": "💰", "south": "🧺"}
]

const FULL_VILLAGE_EMOJI_AXES = [
	{"north": "🔥", "south": "❄️"},
	{"north": "🌾", "south": "🍞"},
	{"north": "⚙️", "south": "💨"},
	{"north": "🦠", "south": "👥"},
	{"north": "💰", "south": "🧺"}
]

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for the starter Village (reduced axis set by default)
	for axis in _get_active_village_axes():
		register_emoji_pair(axis["north"], axis["south"])

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

	# Allocate qubits using the active emoji axis set (reduced for starter Village by default)
	var axes = _get_active_village_axes()
	for idx in range(axes.size()):
		var axis = axes[idx]
		quantum_computer.allocate_axis(idx, axis["north"], axis["south"])

	# Initialize to uniform superposition across all basis states
	quantum_computer.initialize_uniform_superposition()

	print("  📊 RegisterMap configured (5 qubits, 32 basis states)")

	# Get or create Icons for village emojis
	var village_emojis: Array = []
	var icons = {}

	for axis in axes:
		for emoji in [axis["north"], axis["south"]]:
			if emoji != "" and not village_emojis.has(emoji):
				village_emojis.append(emoji)

	for emoji in village_emojis:
		var icon = _get_or_clone_icon(emoji)
		if icon:
			icons[emoji] = icon
	self.icons = icons

	# Configure village-specific dynamics
	_configure_village_dynamics(icons, null)

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
			icon.hamiltonian_couplings = {"❄️": 0.7, "🍞": 0.08}
			icon.self_energy = 0.5
		"❄️":  # Ice - cold hearth
			icon.hamiltonian_couplings = {"🔥": 0.7}
			icon.self_energy = -0.5
		"👥":  # Labor - people/bread axis
			icon.hamiltonian_couplings = {"🍞": 0.15, "💰": 0.05}
			icon.self_energy = 0.2
		"🍞":  # Bread - labor product
			icon.hamiltonian_couplings = {"👥": 0.15, "🧺": 0.07, "⚙️": 0.05}
			icon.self_energy = 0.3
		"⚙️":  # Gears - mechanical power
			icon.hamiltonian_couplings = {"💨": 0.1}
			icon.self_energy = 0.3
		"💨":  # Wind - drives mill
			icon.hamiltonian_couplings = {"⚙️": 0.1}
			icon.self_energy = 0.1
		"💰":  # Money - commerce
			icon.hamiltonian_couplings = {"🧺": 0.05, "👥": 0.05}
			icon.self_energy = 0.3
		"🧺":  # Baskets - hold goods
			icon.hamiltonian_couplings = {"💰": 0.05, "🍞": 0.07}
			icon.self_energy = 0.1

	return icon


func _configure_village_dynamics(icons: Dictionary, icon_registry) -> void:
	"""Configure village-specific Icon dynamics."""
	# Fire bakes bread
	if icons.has("🔥") and icons.has("🍞"):
		icons["🔥"].lindblad_incoming["🍞"] = 0.03

	# Labor (👥) boosts bread production in the starter village
	if icons.has("👥") and icons.has("🍞"):
		icons["👥"].lindblad_incoming["🍞"] = 0.02

	# Trade creates bread from money
	if icons.has("💰") and icons.has("🍞"):
		icons["💰"].lindblad_incoming["🍞"] = 0.01

	# Wind driver (trade winds, 45-second cycle)
	if icons.has("💨"):
		icons["💨"].drivers["wind"] = {
			"type": "oscillator",
			"period": 45.0,
			"amplitude": 0.3,
		}

	# Market driver (commerce cycle, 60-second rhythm)
	if icons.has("💰"):
		icons["💰"].drivers["market"] = {
			"type": "oscillator",
			"period": 60.0,
			"amplitude": 0.25,
		}

	# Bread feeds labor (closes the production cycle)
	if icons.has("🍞") and icons.has("👥"):
		icons["🍞"].lindblad_outgoing["👥"] = 0.015

	# Commerce cycle: baskets return to money (closes trade loop)
	if icons.has("🧺") and icons.has("💰"):
		icons["🧺"].lindblad_outgoing["💰"] = 0.01


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve quantum substrate under Lindblad dynamics."""
	if quantum_computer:
		quantum_computer.evolve(dt, max_evolution_dt)

	# Apply semantic drift game mechanics (🌀 chaos vs ✨ stability)
	super._update_quantum_substrate(dt)


func _get_active_village_axes() -> Array:
	"""Return the emoji axis set the village currently uses."""
	return REDUCED_VILLAGE_EMOJI_AXES if USE_REDUCED_EMOJI_SET else FULL_VILLAGE_EMOJI_AXES


func get_biome_type() -> String:
	return "Village"


func get_paired_emoji(emoji: String) -> String:
	"""Get the paired emoji for this biome's quantum axis"""
	return emoji_pairings.get(emoji, "?")


func _rebuild_quantum_operators_impl() -> void:
	"""Rebuild operators when IconRegistry changes."""
	if not quantum_computer:
		return

	var axes = _get_active_village_axes()
	var icons: Dictionary = {}

	for axis in axes:
		for emoji in [axis["north"], axis["south"]]:
			if emoji == "":
				continue
			var icon = _get_or_clone_icon(emoji)
			if icon:
				icons[emoji] = icon
	self.icons = icons

	if icons.size() > 0:
		_configure_village_dynamics(icons, null)
		build_operators_cached("VillageBiome", icons)


func _create_local_icon(emoji: String):
	return _create_village_emoji_icon(emoji)
