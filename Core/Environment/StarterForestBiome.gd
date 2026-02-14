class_name StarterForestBiome
extends "res://Core/Environment/BiomeBase.gd"

const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

## Starter Forest Biome - Classic ecosystem with predator/prey dynamics
## Celestial cycle (sun/moon), wolves/rabbits, eagles/deer, forest lifecycle, plant growth
##
## Faction themes: Pack Lords + Swift Herd + Verdant Pulse + Celestial Archons

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const PREDATION_RATE = 0.15  # Wolves hunt rabbits
const APEX_HUNT_RATE = 0.12  # Eagles hunt deer
const DECAY_RATE = 0.1      # Trees decay
const GROWTH_RATE = 0.1     # Seedlings grow

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for 5-qubit system
	register_emoji_pair("☀", "🌙")   # Celestial axis
	register_emoji_pair("🐺", "🐇")  # Predator/Prey axis
	register_emoji_pair("🦅", "🦌")  # Apex/Herbivore axis
	register_emoji_pair("🌲", "🍂")  # Forest Lifecycle axis
	register_emoji_pair("🌱", "🌿")  # Growth axis

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.2, 0.7, 0.3, 0.3)  # Forest green
	visual_label = "🌲 Starter Forest"
	visual_center_offset = Vector2(-0.45, -0.45)  # Top-left (T position)
	visual_oval_width = 640.0
	visual_oval_height = 400.0

	print("  ✅ StarterForestBiome initialized (QuantumComputer, 5 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer using new BiomeBuilder architecture.
	
	NEW ARCHITECTURE:
	- Factions → Hamiltonian (coherent, universal laws)
	- Biome → Lindblad (dissipative, environmental context)
	- Icons = Hamiltonian only (no Lindblad terms)
	"""
	print("🌲 Initializing Starter Forest QuantumComputer (NEW ARCHITECTURE)...")
	
	# Define quantum axes (emoji pairs)
	var emoji_pairs = [
		{"north": "☀", "south": "🌙"},   # Celestial: Sun/Moon
		{"north": "🐺", "south": "🐇"},  # Predator/Prey: Wolf/Rabbit
		{"north": "🦅", "south": "🦌"},  # Apex/Herbivore: Eagle/Deer
		{"north": "🌲", "south": "🍂"},  # Forest Lifecycle: Tree/Decay
		{"north": "🌱", "south": "🌿"},  # Growth: Seedling/Vegetation
	]
	
	# Define biome-specific Lindblad (environmental dissipation)
	var lindblad_spec = _create_forest_lindblad_spec()
	
	# Get faction standings (empty = all factions at full strength)
	# TODO: In future, get this from ObservationFrame or faction reputation system
	var faction_standings = {}
	
	# Build quantum system using unified builder
	var BiomeBuilder = load("res://Core/Biomes/BiomeBuilder.gd")
	var result = BiomeBuilder.build_biome_quantum_system(
		"StarterForest",
		emoji_pairs,
		faction_standings,
		lindblad_spec
	)
	
	if not result.success:
		push_error("🌲 Failed to build StarterForest quantum system: %s" % result.error)
		return
	
	# Install the built quantum computer
	quantum_computer = result.quantum_computer
	icons = result.icons
	icon_overrides = result.icons.duplicate(true)
	
	print("  ✅ Hamiltonian: %dx%d matrix (from factions)" % [
		quantum_computer.hamiltonian.n,
		quantum_computer.hamiltonian.n
	])
	print("  ✅ Lindblad: %d operators + %d gated (from biome)" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()
	])
	print("  🌲 Starter Forest QuantumComputer ready! (H=factions, L=biome)")
	
	# Initialize phasic shadow: liquid neural net in phase space
	initialize_phase_lnn()
	if phase_lnn:
		print("  🌀 Phasic shadow initialized (LNN in phase space)")


func _create_forest_lindblad_spec() -> BiomeLindblad:
	"""Define StarterForest environmental dissipation (Lindblad terms).
	
	These are BIOME-SPECIFIC irreversible flows that don't exist in factions.
	Factions define what emojis ARE (Hamiltonian), biomes define how they FLOW (Lindblad).
	"""
	var biome_lindblad_script = load("res://Core/Biomes/BiomeLindblad.gd")
	var L = biome_lindblad_script.new()
	
	# ═══════════════════════════════════════════════════════════════
	# ENVIRONMENTAL PUMPS (Celestial drives growth)
	# ═══════════════════════════════════════════════════════════════
	
	# Sun pumps seedlings (photosynthesis)
	L.add_pump("🌱", "☀", 0.03)
	
	# Moon enhances wolf hunting (nocturnal predation)
	L.add_pump("🐺", "🌙", 0.015)
	
	# ═══════════════════════════════════════════════════════════════
	# ENVIRONMENTAL DRAINS (Decay and consumption)
	# ═══════════════════════════════════════════════════════════════
	
	# Trees decay to leaf litter (forest aging)
	L.add_drain("🌲", "🍂", 0.04)

	# Decay fertilizes seedlings (nutrient cycling)
	L.add_pump("🌱", "🍂", 0.03)

	# Vegetation matures into trees (closes the lifecycle loop)
	L.add_pump("🌲", "🌿", 0.02)
	
	return L


func _create_forest_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for forest emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Forest " + emoji

	# Set up basic couplings based on emoji role
	match emoji:
		"☀":  # Sun - drives day cycle
			icon.hamiltonian_couplings = {"🌙": 0.8}
			icon.self_energy = 0.5
		"🌙":  # Moon - night cycle
			icon.hamiltonian_couplings = {"☀": 0.8}
			icon.self_energy = -0.5
		"🐺":  # Wolf - hunts rabbits
			icon.hamiltonian_couplings = {"🐇": PREDATION_RATE, "🌙": 0.04}
			icon.self_energy = 0.3
		"🐇":  # Rabbit - prey
			icon.hamiltonian_couplings = {"🐺": PREDATION_RATE}
			icon.self_energy = -0.2
		"🦅":  # Eagle - apex predator
			icon.hamiltonian_couplings = {"🦌": APEX_HUNT_RATE}
			icon.self_energy = 0.4
		"🦌":  # Deer - large herbivore
			icon.hamiltonian_couplings = {"🦅": APEX_HUNT_RATE}
			icon.self_energy = -0.1
		"🌲":  # Tree - part of forest lifecycle
			icon.hamiltonian_couplings = {"🍂": DECAY_RATE}
			icon.self_energy = 0.2
		"🍂":  # Decay - fertilizes growth
			icon.hamiltonian_couplings = {"🌲": DECAY_RATE, "🌱": 0.08}
			icon.self_energy = -0.3
		"🌱":  # Seedling - grows into vegetation
			icon.hamiltonian_couplings = {"🌿": GROWTH_RATE, "☀": 0.05}
			icon.self_energy = 0.1
		"🌿":  # Vegetation - mature plants
			icon.hamiltonian_couplings = {"🌱": GROWTH_RATE}
			icon.self_energy = 0.2

	return icon


func _configure_forest_dynamics(icons: Dictionary, icon_registry) -> void:
	"""Configure forest-specific Icon dynamics."""
	# Enhance sun → growth coupling
	if icons.has("☀") and icons.has("🌱"):
		icons["☀"].lindblad_incoming["🌱"] = 0.02

	# Moon enhances wolf hunting
	if icons.has("🌙") and icons.has("🐺"):
		icons["🌙"].lindblad_incoming["🐺"] = 0.015

	# Decay fertilizes seedlings
	if icons.has("🍂") and icons.has("🌱"):
		icons["🍂"].lindblad_incoming["🌱"] = 0.03


func get_biome_type() -> String:
	return "StarterForest"


func get_paired_emoji(emoji: String) -> String:
	"""Get the paired emoji for this biome's quantum axis"""
	return emoji_pairings.get(emoji, "?")


func _create_local_icon(emoji: String) -> Icon:
	return _create_forest_emoji_icon(emoji)


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve quantum substrate under Lindblad dynamics + phasic shadow intelligence.

	Integrates LNN phase modulation directly into evolution for atomic operation.
	"""
	if quantum_computer:
		# Single atomic call: evolve + apply LNN phase modulation
		quantum_computer.evolve(dt, max_evolution_dt, phase_lnn if phase_lnn_enabled else null)

	# Apply semantic drift game mechanics (🌀 chaos vs ✨ stability)
	super._update_quantum_substrate(dt)


func _rebuild_quantum_operators_impl() -> void:
	"""Rebuild operators when faction standings change (LIVE REBUILD).
	
	INVARIANT: Uses the SAME BiomeBuilder machinery as boot initialization.
	This ensures boot and live-rebuild have identical behavior.
	"""
	if not quantum_computer:
		return
	
	print("🔧 Rebuilding StarterForest operators (faction standings changed)...")
	
	# Get current faction standings (TODO: hook into reputation system)
	var faction_standings = {}
	
	# Rebuild Icons (Hamiltonian-only) using BiomeBuilder
	var BiomeBuilder = load("res://Core/Biomes/BiomeBuilder.gd")
	var new_icons = BiomeBuilder.rebuild_icons_for_standings(
		quantum_computer.register_map,
		faction_standings
	)
	
	if new_icons.is_empty():
		push_warning("🌲 Rebuild failed: No icons could be built")
		return
	icons = new_icons
	icon_overrides = new_icons.duplicate(true)
	
	# Rebuild Hamiltonian (universal dynamics change with faction power)
	var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
	var verbose = get_node_or_null("/root/VerboseConfig")
	quantum_computer.hamiltonian = HamBuilder.build(new_icons, quantum_computer.register_map, verbose)
	
	# Lindblad stays the same (environmental context unchanged)
	# Only Hamiltonian is rebuilt when faction standings change
	
	# Update time-dependent drivers
	var driven_configs = HamBuilder.get_driven_icons(new_icons, quantum_computer.register_map)
	quantum_computer.set_driven_icons(driven_configs)
	
	print("  ✅ Hamiltonian rebuilt (%dx%d), Lindblad unchanged" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
