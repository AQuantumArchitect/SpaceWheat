class_name FungalNetworksBiome
extends "res://Core/Environment/BiomeBase.gd"

const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

## Fungal Networks Biome - Competing fungal colonies and mycelium dynamics
##
## Architecture: QuantumComputer with 4-qubit tensor product
##
## Axes:
##   Qubit 0 (Colony):    🦗 Locusts / 🐜 Ants
##   Qubit 1 (Growth):    🍄 Mature fungi / 🦠 Spores
##   Qubit 2 (Substrate): 🧫 Nutrients / 🍂 Detritus
##   Qubit 3 (Cycle):     🌙 Night / ☀ Day
##
## Physics:
##   - Colony competition (locusts boom-bust vs ant stability)
##   - Day-night cycling affects activity patterns
##   - Detritus → Mushroom → Spore lifecycle

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const DAY_NIGHT_PERIOD = 60.0  # 60-second day-night cycle for fungi
const SWARM_CYCLE_PERIOD = 120.0  # 2-minute locust swarm cycles
const DECAY_TO_DETRITUS_RATE = 0.02
const SPORE_DISPERSAL_RATE = 0.03
const COLONY_COMPETITION_RATE = 0.25

# ═══════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════

var locust_swarm_active: bool = false
var current_dominant_colony: String = "🦗"

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for 4-qubit system
	register_emoji_pair("🦗", "🐜")  # Colony axis
	register_emoji_pair("🍄", "🦠")  # Growth axis
	register_emoji_pair("🧫", "🍂")  # Substrate axis
	register_emoji_pair("🌙", "☀")   # Cycle axis

	# Legacy planting capabilities removed (vocabulary injection is the only expansion path)

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.6, 0.3, 0.8, 0.3)  # Purple/fungal
	visual_label = "🍄 Fungal Network"
	visual_center_offset = Vector2(0.0, -0.45)
	visual_oval_width = 450.0
	visual_oval_height = 280.0

	print("  ✅ FungalNetworksBiome initialized (QuantumComputer, 4 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer for Fungal Networks biome (4 qubits)."""
	print("🍄 Initializing Fungal Networks QuantumComputer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("FungalNetworks")

	# Allocate 4 qubits with emoji axes
	quantum_computer.allocate_axis(0, "🦗", "🐜")  # Colony: Locust/Ant
	quantum_computer.allocate_axis(1, "🍄", "🦠")  # Growth: Mature/Spore
	quantum_computer.allocate_axis(2, "🧫", "🍂")  # Substrate: Nutrient/Detritus
	quantum_computer.allocate_axis(3, "🌙", "☀")   # Cycle: Night/Day

	# Initialize to uniform superposition across all basis states
	quantum_computer.initialize_uniform_superposition()

	print("  📊 RegisterMap configured (4 qubits, 16 basis states)")

	# Get or create Icons for fungal emojis
	var fungal_emojis = ["🦗", "🐜", "🍄", "🦠", "🧫", "🍂", "🌙", "☀"]
	var icons = {}

	for emoji in fungal_emojis:
		var icon = _get_or_clone_icon(emoji)
		if icon:
			icons[emoji] = icon
	self.icons = icons

	# Configure fungal-specific dynamics
	_configure_fungal_dynamics(icons, null)

	# Build operators using cached method
	build_operators_cached("FungalNetworksBiome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  🍄 Fungal Networks QuantumComputer ready!")


func _create_fungal_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for fungal emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Fungal " + emoji

	# Set up basic couplings based on emoji role
	match emoji:
		"🦗":  # Locust - boom-bust dynamics
			icon.hamiltonian_couplings = {"🐜": COLONY_COMPETITION_RATE}
			icon.self_energy = 0.3
		"🐜":  # Ant - stable colony
			icon.hamiltonian_couplings = {"🦗": COLONY_COMPETITION_RATE}
			icon.self_energy = -0.1
		"🍄":  # Mushroom - mature fungi
			icon.hamiltonian_couplings = {"🦠": 0.15}
			icon.self_energy = 0.2
			icon.decay_rate = DECAY_TO_DETRITUS_RATE
			icon.decay_target = "🍂"
		"🦠":  # Spores - dispersing
			icon.hamiltonian_couplings = {"🍄": 0.15}
			icon.self_energy = 0.1
		"🧫":  # Nutrients - rich substrate
			icon.hamiltonian_couplings = {"🍂": 0.1}
			icon.self_energy = 0.4
		"🍂":  # Detritus - decaying matter
			icon.hamiltonian_couplings = {"🧫": 0.1}
			icon.self_energy = -0.2
		"🌙":  # Moon/Night - fungal activity peak
			icon.hamiltonian_couplings = {"☀": 0.1}
			icon.self_energy = 0.3
		"☀":  # Sun/Day - dormancy
			icon.hamiltonian_couplings = {"🌙": 0.1}
			icon.self_energy = -0.3

	return icon


func _configure_fungal_dynamics(icons: Dictionary, _icon_registry) -> void:
	"""Configure fungal-specific Icon dynamics."""
	# Colony competition (locusts ↔ ants)
	if icons.has("🦗") and icons.has("🐜"):
		icons["🦗"].hamiltonian_couplings["🐜"] = COLONY_COMPETITION_RATE
		icons["🐜"].hamiltonian_couplings["🦗"] = COLONY_COMPETITION_RATE

	# Fruiting cycle (mushroom ↔ spore)
	if icons.has("🍄") and icons.has("🦠"):
		icons["🍄"].hamiltonian_couplings["🦠"] = 0.15
		icons["🦠"].hamiltonian_couplings["🍄"] = 0.15

	# Nutrient cycling (nutrients ↔ detritus)
	if icons.has("🧫") and icons.has("🍂"):
		icons["🧫"].hamiltonian_couplings["🍂"] = 0.1
		icons["🍂"].hamiltonian_couplings["🧫"] = 0.1

	# Day-night cycling
	if icons.has("🌙") and icons.has("☀"):
		icons["🌙"].hamiltonian_couplings["☀"] = 0.1
		icons["☀"].hamiltonian_couplings["🌙"] = 0.1

	# Lindblad transfers: Detritus feeds mushrooms
	if icons.has("🍂") and icons.has("🍄"):
		icons["🍂"].lindblad_outgoing["🍄"] = 0.03

	# Mushrooms release spores
	if icons.has("🍄") and icons.has("🦠"):
		icons["🍄"].lindblad_outgoing["🦠"] = SPORE_DISPERSAL_RATE

	# Locusts produce waste (detritus)
	if icons.has("🦗") and icons.has("🍂"):
		icons["🦗"].lindblad_outgoing["🍂"] = 0.04

	# Spores decompose back to detritus (closes the fungal cycle)
	# Loop: 🍂 → 🍄 → 🦠 → 🍂
	if icons.has("🦠") and icons.has("🍂"):
		icons["🦠"].lindblad_outgoing["🍂"] = 0.02

	# Gated: Night feeding frenzy (nutrients → locusts at night)
	if icons.has("🧫"):
		icons["🧫"].gated_lindblad["🦗"] = [{
			"source": "🧫",
			"rate": 0.03,
			"gate": "🌙",
		}]
		# Day foraging (nutrients → ants during day)
		icons["🧫"].gated_lindblad["🐜"] = [{
			"source": "🧫",
			"rate": 0.03,
			"gate": "☀",
		}]

	# Decay: Mushrooms decay to detritus
	if icons.has("🍄"):
		icons["🍄"].decay_rate = DECAY_TO_DETRITUS_RATE
		icons["🍄"].decay_target = "🍂"

	# Day-night driver (60-second cycle)
	if icons.has("🌙"):
		icons["🌙"].drivers["cycle"] = {
			"type": "oscillator",
			"period": DAY_NIGHT_PERIOD,
			"amplitude": 0.5,
		}

	# Locust swarm driver (2-minute cycles)
	if icons.has("🦗"):
		icons["🦗"].drivers["swarm"] = {
			"type": "pulse",
			"period": SWARM_CYCLE_PERIOD,
			"amplitude": 0.6,
		}


func rebuild_quantum_operators() -> void:
	"""Rebuild operators after IconRegistry is ready."""
	if not quantum_computer:
		return

	print("  🔧 FungalNetworks: Rebuilding quantum operators...")

	var fungal_emojis = ["🦗", "🐜", "🍄", "🦠", "🧫", "🍂", "🌙", "☀"]
	var icons = {}

	for emoji in fungal_emojis:
		var icon = _get_or_clone_icon(emoji)
		if icon:
			icons[emoji] = icon
	self.icons = icons

	_configure_fungal_dynamics(icons, null)

	build_operators_cached("FungalNetworksBiome", icons)

	print("  ✅ FungalNetworks: Rebuilt operators")


func _create_local_icon(emoji: String) -> Icon:
	return _create_fungal_emoji_icon(emoji)


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve fungal quantum state."""
	if quantum_computer:
		quantum_computer.evolve(dt, max_evolution_dt)

		# SEMANTIC TOPOLOGY: Record phase space trajectory
		_record_attractor_snapshot()

		# Update dominant colony tracking
		_update_colony_dominance()

	# Apply semantic drift game mechanics
	super._update_quantum_substrate(dt)


func _update_colony_dominance() -> void:
	"""Track which colony is currently dominant."""
	var locust_pop = get_marginal_locusts()
	var ant_pop = 1.0 - locust_pop

	if locust_pop > 0.6:
		current_dominant_colony = "🦗"
		locust_swarm_active = true
	elif ant_pop > 0.6:
		current_dominant_colony = "🐜"
		locust_swarm_active = false
	else:
		current_dominant_colony = "⚖️"
		locust_swarm_active = false


# ═══════════════════════════════════════════════════════════════════════════
# MARGINAL PROBABILITIES (Qubit Queries)
# ═══════════════════════════════════════════════════════════════════════════

func get_marginal_locusts() -> float:
	"""P(🦗) = marginal probability of locust dominance."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(0, 0)  # Qubit 0, pole 0 (north = 🦗)


func get_marginal_mushrooms() -> float:
	"""P(🍄) = marginal probability of mature fungi."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(1, 0)  # Qubit 1, pole 0 (north = 🍄)


func get_marginal_nutrients() -> float:
	"""P(🧫) = marginal probability of rich nutrients."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(2, 0)  # Qubit 2, pole 0 (north = 🧫)


func get_marginal_night() -> float:
	"""P(🌙) = marginal probability of night phase."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(3, 0)  # Qubit 3, pole 0 (north = 🌙)


# ═══════════════════════════════════════════════════════════════════════════
# ECOSYSTEM QUERIES
# ═══════════════════════════════════════════════════════════════════════════

func get_ecosystem_health() -> float:
	"""Calculate ecosystem health from balanced populations."""
	if not quantum_computer:
		return 0.5

	var mushrooms = get_marginal_mushrooms()
	var nutrients = get_marginal_nutrients()

	# Health peaks when mushrooms and nutrients are both moderate
	var mushroom_health = 1.0 - abs(mushrooms - 0.5) * 2.0
	var nutrient_health = 1.0 - abs(nutrients - 0.5) * 2.0

	return (mushroom_health + nutrient_health) / 2.0


func get_colony_balance() -> float:
	"""Get colony balance (0.5 = equal, 0 = all ants, 1 = all locusts)."""
	return get_marginal_locusts()


func is_nighttime() -> bool:
	"""Check if it's currently night in the fungal network."""
	return get_marginal_night() > 0.5


# ═══════════════════════════════════════════════════════════════════════════
# NETWORK STATUS
# ═══════════════════════════════════════════════════════════════════════════

func get_network_status() -> Dictionary:
	"""Get full fungal network state for UI display."""
	return {
		"locusts": get_marginal_locusts(),
		"ants": 1.0 - get_marginal_locusts(),
		"dominant_colony": current_dominant_colony,
		"swarm_active": locust_swarm_active,
		"mushrooms": get_marginal_mushrooms(),
		"spores": 1.0 - get_marginal_mushrooms(),
		"nutrients": get_marginal_nutrients(),
		"detritus": 1.0 - get_marginal_nutrients(),
		"night_phase": get_marginal_night(),
		"is_night": is_nighttime(),
		"ecosystem_health": get_ecosystem_health(),
		"time_label": _get_time_label(),
	}


func _get_time_label() -> String:
	"""Convert night probability to human label."""
	var night = get_marginal_night()
	if night > 0.7:
		return "🌙 Deep Night"
	elif night > 0.5:
		return "🌙 Night"
	elif night > 0.3:
		return "☀ Day"
	else:
		return "☀ Bright Day"


func get_biome_type() -> String:
	"""Return biome type identifier."""
	return "FungalNetworks"
