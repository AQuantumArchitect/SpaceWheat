extends Control

## Test scene for QuantumForceGraph visualization
## Displays colorful qubits with force-directed layout and entanglement
## Now supports MULTI-BIOME visualization with overlapping ovals

const QuantumForceGraphScript = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumNodeScript = preload("res://Core/Visualization/QuantumNode.gd")
const FarmPlotScript = preload("res://Core/GameMechanics/FarmPlot.gd")
const DualEmojiQubitScript = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const BioticFluxBiomeScript = preload("res://Core/Environment/BioticFluxBiome.gd")
const ForestEcosystemBiomeScript = preload("res://Core/Environment/ForestEcosystem_Biome.gd")
const MarketBiomeScript = preload("res://Core/Environment/MarketBiome.gd")
const VennZoneCalculatorScript = preload("res://Core/Visualization/VennZoneCalculator.gd")

@onready var graph_node = $QuantumForceGraph
@onready var qubit_count_label = $UI/InfoPanel/MarginContainer/VBoxContainer/QubitCountLabel
@onready var entanglement_label = $UI/InfoPanel/MarginContainer/VBoxContainer/EntanglementLabel
@onready var coherence_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CoherenceLabel

var graph: Node2D = null

# Multi-biome support
var biotic_flux_biome = null  # BioticFlux biome (wheat/mushroom/sun)
var forest_biome = null        # Forest biome (organisms)
var market_biome = null        # Market biome (traders/sentiment)

# Quantum nodes by biome
var biotic_flux_nodes: Array = []  # Sun, wheat, mushroom nodes
var forest_nodes: Array = []       # Wolf, eagle, etc. nodes
var market_nodes: Array = []       # Trader, sentiment nodes

# ═══════════════════════════════════════════════════════════════════════════
# PARAMETRIC VENN DIAGRAM: Mathematical boundary zones
# ═══════════════════════════════════════════════════════════════════════════
var venn_zones = null  # VennZoneCalculator instance

# ═══════════════════════════════════════════════════════════════════════════
# SIMULATION LAYER: Biome membership tracking
# This is simulation data, NOT visualization. The GUI just displays results.
# ═══════════════════════════════════════════════════════════════════════════
var plot_biome_memberships: Dictionary = {}  # plot_id → Array[String] of biome names
var all_quantum_nodes: Array = []  # All nodes for unified evolution

var update_timer = 0.0

# Stored viewport dimensions (graph.center_position gets reset by _draw())
var stored_center: Vector2
var stored_radius: float

# ═══════════════════════════════════════════════════════════════════════════
# SKATING RINK BLOCH PROJECTION: phi→perimeter, radius→distance from center
# Each biome oval becomes a projected Bloch sphere!
# ═══════════════════════════════════════════════════════════════════════════
var skating_rink_strength: float = 150.0  # Force pulling bubbles to their phi-position
var radial_expansion_strength: float = 80.0  # Force pushing high-R bubbles outward

# Sun/Moon orbit tracking
var sun_orbit_speed: float = 0.08  # Radians per second around BioticFlux perimeter

# Forest dynamic sync
var forest_organism_sync_timer: float = 0.0
var forest_organism_sync_interval: float = 0.5  # Sync every 0.5s

# Life cycle effects
var spawn_effects: Array = []  # [{position, time, color}]
var death_effects: Array = []  # [{position, time, icon}]
var coherence_strike_effects: Array = []  # [{from, to, time}]


func _ready():
	"""Initialize multi-biome visualization with BioticFlux, Forest, and Market"""
	var sep = "════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("⚛️  TRI-BIOME QuantumForceGraph Test")
	print("   Biome 1: BioticFlux (sun + wheat + mushrooms) - bottom")
	print("   Biome 2: ForestEcosystem (organisms) - top-right")
	print("   Biome 3: Market (traders + sentiment) - top-left")
	print(sep)

	# Create and add the QuantumForceGraph
	graph = QuantumForceGraphScript.new()
	graph_node.add_child(graph)

	# Wait for graph to be in scene tree and get viewport
	await get_tree().process_frame

	# Initialize graph visual properties based on actual viewport
	var viewport_size = get_viewport().get_visible_rect().size
	# Fallback for headless mode or tiny viewports
	if viewport_size.x < 200 or viewport_size.y < 200:
		viewport_size = Vector2(1280, 720)

	# Store dimensions for VennZone calculations (graph values get reset by _draw())
	stored_center = viewport_size / 2.0
	stored_radius = min(viewport_size.x, viewport_size.y) * 0.35  # 35% of smaller dimension

	graph.center_position = stored_center
	graph.graph_radius = stored_radius
	# UNLOCK dimensions - the graph's BiomeLayoutCalculator handles parametric resizing
	# When viewport changes, update_layout() recomputes all positions from parametric coords
	graph.lock_dimensions = false
	print("   📐 Graph: center=%s radius=%.0f (BiomeLayoutCalculator-managed)" % [stored_center, stored_radius])

	# ═══════════════════════════════════════════════════════════════
	# BIOME 1: BioticFlux (farming with sun/wheat/mushroom)
	# ═══════════════════════════════════════════════════════════════
	biotic_flux_biome = BioticFluxBiomeScript.new()
	add_child(biotic_flux_biome)
	await get_tree().process_frame

	# Register biome with graph
	graph.biomes["BioticFlux"] = biotic_flux_biome
	print("   🌾 BioticFlux biome registered")

	# ═══════════════════════════════════════════════════════════════
	# BIOME 2: ForestEcosystem (organisms)
	# ═══════════════════════════════════════════════════════════════
	forest_biome = ForestEcosystemBiomeScript.new(4, 1)  # 4x1 patch grid
	add_child(forest_biome)
	await get_tree().process_frame

	# Add diverse ecosystem with predator-prey dynamics!
	# PREDATORS: Hunt the prey, have dual emoji nature
	forest_biome.add_organism(Vector2i(0, 0), "🐺")  # Wolf (🐺/💧) - hunts rabbit, mouse
	forest_biome.add_organism(Vector2i(3, 0), "🦅")  # Eagle (🦅/🌬️) - hunts rabbit, mouse, bird

	# PREY: Flee from predators, reproduce when safe
	forest_biome.add_organism(Vector2i(1, 0), "🐰")  # Rabbit (🐰/🌱) - flees wolf, eagle
	forest_biome.add_organism(Vector2i(2, 0), "🐭")  # Mouse (🐭/🌾) - flees wolf, eagle

	# Register biome with graph
	graph.biomes["Forest"] = forest_biome
	print("   🌲 ForestEcosystem biome registered")
	print("      🐺🦅 Predators: Wolf, Eagle")
	print("      🐰🐭 Prey: Rabbit, Mouse")

	# ═══════════════════════════════════════════════════════════════
	# BIOME 3: Market (traders/sentiment)
	# ═══════════════════════════════════════════════════════════════
	market_biome = MarketBiomeScript.new()
	add_child(market_biome)
	await get_tree().process_frame

	# Register biome with graph
	graph.biomes["Market"] = market_biome
	print("   📈 Market biome registered")

	# ═══════════════════════════════════════════════════════════════
	# PARAMETRIC VENN ZONES: Mathematical boundary calculation
	# ═══════════════════════════════════════════════════════════════
	_create_venn_zone_calculator()

	# ═══════════════════════════════════════════════════════════════
	# CREATE NODES (using BiomeLayoutCalculator parametric placement)
	# ═══════════════════════════════════════════════════════════════
	_create_biotic_flux_nodes()
	_create_forest_organism_nodes()
	_create_market_nodes()

	# ═══════════════════════════════════════════════════════════════
	# SIMULATION: Determine biome memberships (which biomes affect which nodes)
	# ═══════════════════════════════════════════════════════════════
	_determine_all_biome_memberships()

	# ═══════════════════════════════════════════════════════════════
	# Finalize graph setup
	# ═══════════════════════════════════════════════════════════════
	graph.set_process(true)

	var total_nodes = biotic_flux_nodes.size() + forest_nodes.size() + market_nodes.size()
	print("\n✅ Tri-biome visualization ready")
	print("   🔵 %d quantum bubbles total" % total_nodes)
	print("   🌾 BioticFlux: %d nodes (sun + crops)" % biotic_flux_nodes.size())
	print("   🌲 Forest: %d nodes (organisms)" % forest_nodes.size())
	print("   📈 Market: %d nodes (traders + sentiment)" % market_nodes.size())
	print("   ✨ Three biomes evolving with overlapping ovals")
	print(sep + "\n")


func _create_venn_zone_calculator():
	"""Create VennZoneCalculator from biome visual configs

	Mathematically defines the three Venn diagram regions:
	- LEFT_ONLY: BioticFlux exclusive zone
	- OVERLAP: Dual-biome zone
	- RIGHT_ONLY: Forest exclusive zone

	Uses stored_center/stored_radius (not graph values which get reset by _draw())
	"""
	if not biotic_flux_biome or not forest_biome:
		print("   ⚠️  Cannot create Venn zones without both biomes")
		return

	var left_config = biotic_flux_biome.get_visual_config()
	var right_config = forest_biome.get_visual_config()

	# Calculate ellipse parameters using STORED values (graph values get reset)
	var scale_factor = stored_radius / 300.0
	var center_y = stored_center.y

	# Left ellipse (BioticFlux)
	var left_cx = stored_center.x + left_config.center_offset.x * stored_radius
	var left_a = left_config.get("oval_width", 180.0) * scale_factor / 2.0
	var left_b = left_config.get("oval_height", 115.0) * scale_factor / 2.0

	# Right ellipse (Forest) - use same size for symmetric Venn
	var right_cx = stored_center.x + right_config.center_offset.x * stored_radius
	var right_a = right_config.get("oval_width", 180.0) * scale_factor / 2.0
	var right_b = right_config.get("oval_height", 115.0) * scale_factor / 2.0

	# Use average for symmetric diagram
	var a = (left_a + right_a) / 2.0
	var b = (left_b + right_b) / 2.0

	venn_zones = VennZoneCalculatorScript.new(left_cx, right_cx, center_y, a, b)
	print("   📐 %s" % venn_zones.debug_info())


func _create_biotic_flux_nodes():
	"""Create QuantumNodes for BioticFlux biome using BiomeLayoutCalculator parametric system"""
	if not biotic_flux_biome:
		print("   ⚠️  No BioticFlux biome, cannot create nodes")
		return

	# Ensure layout calculator has computed biome ovals
	graph.update_layout(true)

	# ─────────────────────────────────────────────────────────────────
	# SUN NODE (celestial) - at biome center
	# ─────────────────────────────────────────────────────────────────
	var sun_plot = FarmPlotScript.new()
	sun_plot.plot_id = "biotic_sun"
	sun_plot.grid_position = Vector2i(-1, -1)
	sun_plot.quantum_state = biotic_flux_biome.sun_qubit
	sun_plot.is_planted = true

	# Store parametric coords for auto-scaling (new biome-based system)
	var sun_t = 0.5
	var sun_ring = 0.2
	var sun_anchor = graph.layout_calculator.get_parametric_position("BioticFlux", sun_t, sun_ring)
	var sun_node = QuantumNodeScript.new(sun_plot, sun_anchor, Vector2i(-1, -1), stored_center)
	sun_node.biome_name = "BioticFlux"
	sun_node.has_farm_tether = false  # Free-floating celestial
	sun_node.parametric_t = sun_t
	sun_node.parametric_ring = sun_ring
	sun_node.color = Color(1.0, 0.9, 0.3)  # Golden
	sun_node.emoji_north = biotic_flux_biome.sun_qubit.north_emoji
	sun_node.emoji_south = biotic_flux_biome.sun_qubit.south_emoji
	sun_node.radius = 35.0  # Larger for celestial

	graph.quantum_nodes.append(sun_node)
	graph.node_by_plot_id["biotic_sun"] = sun_node
	biotic_flux_nodes.append(sun_node)

	# ─────────────────────────────────────────────────────────────────
	# WHEAT NODES (3 wheat crops) - distributed in biome oval
	# ─────────────────────────────────────────────────────────────────
	for i in range(3):
		var wheat_qubit = DualEmojiQubitScript.new("🌾", "🏰")
		wheat_qubit.theta = PI / 4.0  # Favor wheat (north=🌾)
		wheat_qubit.phi = randf() * TAU
		wheat_qubit.radius = 0.5
		wheat_qubit.energy = 0.5

		var plot = FarmPlotScript.new()
		plot.plot_id = "biotic_wheat_%d" % i
		plot.grid_position = Vector2i(i, 0)
		plot.quantum_state = wheat_qubit
		plot.is_planted = true

		# Register in biome's quantum_states
		biotic_flux_biome.quantum_states[Vector2i(i, 0)] = wheat_qubit

		# Parametric placement: spread around mid-ring (stay away from overlap zones)
		var t = (i + 1.0) / 4.0  # 0.25, 0.5, 0.75
		var ring = 0.35
		var anchor = graph.layout_calculator.get_parametric_position("BioticFlux", t, ring)
		var node = QuantumNodeScript.new(plot, anchor, Vector2i(i, 0), stored_center)
		node.biome_name = "BioticFlux"
		node.has_farm_tether = false  # Free-floating biome bubble
		node.parametric_t = t
		node.parametric_ring = ring
		node.color = Color(0.8, 0.7, 0.2)  # Wheat gold
		node.emoji_north = "🌾"
		node.emoji_south = "🏰"

		graph.quantum_nodes.append(node)
		graph.node_by_plot_id[plot.plot_id] = node
		biotic_flux_nodes.append(node)

	# ─────────────────────────────────────────────────────────────────
	# MUSHROOM NODES (2 mushrooms) - placed in biome oval
	# ─────────────────────────────────────────────────────────────────
	for i in range(2):
		var mushroom_qubit = DualEmojiQubitScript.new("🍂", "🍄")
		mushroom_qubit.theta = PI * 0.85  # Favor mushroom (south=🍄)
		mushroom_qubit.phi = randf() * TAU
		mushroom_qubit.radius = 0.5
		mushroom_qubit.energy = 0.5

		var plot = FarmPlotScript.new()
		plot.plot_id = "biotic_mushroom_%d" % i
		plot.grid_position = Vector2i(i + 10, 0)
		plot.quantum_state = mushroom_qubit
		plot.is_planted = true

		# Register in biome's quantum_states
		biotic_flux_biome.quantum_states[Vector2i(i + 10, 0)] = mushroom_qubit

		# Parametric placement: different angles (stay away from overlap zones)
		var t = 0.1 + i * 0.4  # 0.1, 0.5
		var ring = 0.5
		var anchor = graph.layout_calculator.get_parametric_position("BioticFlux", t, ring)
		var node = QuantumNodeScript.new(plot, anchor, Vector2i(i + 10, 0), stored_center)
		node.biome_name = "BioticFlux"
		node.has_farm_tether = false  # Free-floating biome bubble
		node.parametric_t = t
		node.parametric_ring = ring
		node.color = Color(0.6, 0.4, 0.5)  # Mushroom purple-brown
		node.emoji_north = "🍂"
		node.emoji_south = "🍄"

		graph.quantum_nodes.append(node)
		graph.node_by_plot_id[plot.plot_id] = node
		biotic_flux_nodes.append(node)

	print("   ✅ Created %d BioticFlux nodes (1 sun + 3 wheat + 2 mushrooms)" % biotic_flux_nodes.size())


func _create_forest_organism_nodes():
	"""Create QuantumNodes for ForestEcosystem organisms using BiomeLayoutCalculator parametric system"""
	if not forest_biome:
		print("   ⚠️  No Forest biome, cannot create organism nodes")
		return

	# Collect all organisms first
	var all_organisms: Array = []
	for patch_pos in forest_biome.patches.keys():
		var patch = forest_biome.patches[patch_pos]
		if not patch.has_meta("organisms"):
			continue

		var organisms = patch.get_meta("organisms")
		for icon in organisms.keys():
			var organism = organisms[icon]
			if organism and organism.qubit:
				all_organisms.append({"icon": icon, "organism": organism, "patch_pos": patch_pos})

	# Create nodes with parametric placement in Forest biome oval
	for organism_idx in range(all_organisms.size()):
		var data = all_organisms[organism_idx]
		var organism = data.organism
		var icon = data.icon
		var patch_pos = data.patch_pos

		# Create plot wrapper for the organism
		var plot = FarmPlotScript.new()
		plot.plot_id = "forest_org_%s_%d" % [icon, organism_idx]
		plot.grid_position = patch_pos
		plot.quantum_state = organism.qubit
		plot.is_planted = true

		# Parametric placement in Forest biome oval
		var t = (organism_idx + 0.5) / max(all_organisms.size(), 1)
		var ring = 0.3 + (organism_idx % 2) * 0.2  # Alternate between rings
		var anchor = graph.layout_calculator.get_parametric_position("Forest", t, ring)

		var node = QuantumNodeScript.new(plot, anchor, patch_pos, stored_center)
		node.biome_name = "Forest"
		node.parametric_t = t
		node.parametric_ring = ring
		node.has_farm_tether = false  # Free-floating biome bubble

		# Color by organism type: predators are warm, prey are cool
		var org_type = organism.organism_type if "organism_type" in organism else ""
		if org_type == "predator" or org_type == "apex":
			node.color = Color(0.9, 0.4, 0.3)  # Red/orange for predators
		elif org_type == "herbivore":
			node.color = Color(0.4, 0.8, 0.5)  # Green for prey
		else:
			node.color = Color.from_hsv(float(organism_idx) / max(all_organisms.size(), 1), 0.7, 0.8)

		# Dual emoji from qubit
		node.emoji_north = organism.qubit.north_emoji
		node.emoji_south = organism.qubit.south_emoji

		graph.quantum_nodes.append(node)
		graph.node_by_plot_id[plot.plot_id] = node
		forest_nodes.append(node)

		# Log the dual emoji nature
		print("      Created %s (%s/%s) - %s" % [icon, node.emoji_north, node.emoji_south, org_type])

	print("   ✅ Created %d Forest organism nodes" % forest_nodes.size())


func _create_market_nodes():
	"""Create QuantumNodes for Market biome - 3 core market concepts"""
	if not market_biome:
		print("   ⚠️  No Market biome, cannot create nodes")
		return

	# Ensure layout calculator has computed biome ovals
	graph.update_layout(true)

	# ─────────────────────────────────────────────────────────────────
	# 1. SENTIMENT NODE - bull/bear market indicator (🐂/🐻)
	# ─────────────────────────────────────────────────────────────────
	var sentiment_plot = FarmPlotScript.new()
	sentiment_plot.plot_id = "market_sentiment"
	sentiment_plot.grid_position = Vector2i(-10, -1)
	sentiment_plot.quantum_state = market_biome.sentiment_qubit
	sentiment_plot.is_planted = true

	var sentiment_t = 0.5
	var sentiment_ring = 0.15  # Near center
	var sentiment_anchor = graph.layout_calculator.get_parametric_position("Market", sentiment_t, sentiment_ring)
	var sentiment_node = QuantumNodeScript.new(sentiment_plot, sentiment_anchor, Vector2i(-10, -1), stored_center)
	sentiment_node.biome_name = "Market"
	sentiment_node.has_farm_tether = false  # Free-floating biome bubble
	sentiment_node.parametric_t = sentiment_t
	sentiment_node.parametric_ring = sentiment_ring
	sentiment_node.color = Color(1.0, 0.7, 0.2)  # Gold
	sentiment_node.emoji_north = "🐂"
	sentiment_node.emoji_south = "🐻"
	sentiment_node.radius = 30.0

	graph.quantum_nodes.append(sentiment_node)
	graph.node_by_plot_id["market_sentiment"] = sentiment_node
	market_nodes.append(sentiment_node)

	# ─────────────────────────────────────────────────────────────────
	# 2. LIQUIDITY NODE - goods vs currency (📦/💰)
	# ─────────────────────────────────────────────────────────────────
	var liquidity_qubit = DualEmojiQubitScript.new("💰", "📦")
	liquidity_qubit.theta = PI / 2.0  # Equator - balanced
	liquidity_qubit.phi = 0.0
	liquidity_qubit.radius = 0.9
	liquidity_qubit.energy = 0.8

	var liquidity_plot = FarmPlotScript.new()
	liquidity_plot.plot_id = "market_liquidity"
	liquidity_plot.grid_position = Vector2i(-10, 0)
	liquidity_plot.quantum_state = liquidity_qubit
	liquidity_plot.is_planted = true

	var liquidity_t = 0.25
	var liquidity_ring = 0.4  # Mid-ring, away from edges
	var liquidity_anchor = graph.layout_calculator.get_parametric_position("Market", liquidity_t, liquidity_ring)
	var liquidity_node = QuantumNodeScript.new(liquidity_plot, liquidity_anchor, Vector2i(-10, 0), stored_center)
	liquidity_node.biome_name = "Market"
	liquidity_node.has_farm_tether = false  # Free-floating biome bubble
	liquidity_node.parametric_t = liquidity_t
	liquidity_node.parametric_ring = liquidity_ring
	liquidity_node.color = Color(0.2, 0.7, 0.3)  # Green for money
	liquidity_node.emoji_north = "💰"
	liquidity_node.emoji_south = "📦"

	graph.quantum_nodes.append(liquidity_node)
	graph.node_by_plot_id["market_liquidity"] = liquidity_node
	market_nodes.append(liquidity_node)

	# ─────────────────────────────────────────────────────────────────
	# 3. FLOUR/MONEY NODE - commodity trade (🌾/💰)
	# ─────────────────────────────────────────────────────────────────
	var flour_qubit = DualEmojiQubitScript.new("🌾", "💰")
	flour_qubit.theta = PI / 3.0  # Favor flour slightly
	flour_qubit.phi = PI / 4.0
	flour_qubit.radius = 0.85
	flour_qubit.energy = 0.7

	var flour_plot = FarmPlotScript.new()
	flour_plot.plot_id = "market_flour"
	flour_plot.grid_position = Vector2i(-9, 0)
	flour_plot.quantum_state = flour_qubit
	flour_plot.is_planted = true

	var flour_t = 0.75
	var flour_ring = 0.4  # Mid-ring, away from edges
	var flour_anchor = graph.layout_calculator.get_parametric_position("Market", flour_t, flour_ring)
	var flour_node = QuantumNodeScript.new(flour_plot, flour_anchor, Vector2i(-9, 0), stored_center)
	flour_node.biome_name = "Market"
	flour_node.has_farm_tether = false  # Free-floating biome bubble
	flour_node.parametric_t = flour_t
	flour_node.parametric_ring = flour_ring
	flour_node.color = Color(0.9, 0.8, 0.3)  # Golden wheat
	flour_node.emoji_north = "🌾"
	flour_node.emoji_south = "💰"

	graph.quantum_nodes.append(flour_node)
	graph.node_by_plot_id["market_flour"] = flour_node
	market_nodes.append(flour_node)

	print("   ✅ Created %d Market nodes (sentiment + liquidity + flour)" % market_nodes.size())


# ═══════════════════════════════════════════════════════════════════════════
# SIMULATION LAYER: Biome membership determination
# ═══════════════════════════════════════════════════════════════════════════

func _determine_all_biome_memberships():
	"""Determine which biomes each plot belongs to

	Uses node.biome_name as primary membership.
	VennZoneCalculator is used for overlap detection (nodes in overlap get dual membership).
	"""
	plot_biome_memberships.clear()
	all_quantum_nodes.clear()

	# Collect all nodes from all three biomes
	all_quantum_nodes.append_array(biotic_flux_nodes)
	all_quantum_nodes.append_array(forest_nodes)
	all_quantum_nodes.append_array(market_nodes)

	# For each node, use its biome_name as primary membership
	for node in all_quantum_nodes:
		var memberships: Array = []

		# Primary membership from biome_name
		if not node.biome_name.is_empty():
			memberships.append(node.biome_name)

		# Fallback if no membership determined
		if memberships.is_empty():
			if node in biotic_flux_nodes:
				memberships.append("BioticFlux")
			elif node in forest_nodes:
				memberships.append("Forest")
			elif node in market_nodes:
				memberships.append("Market")

		plot_biome_memberships[node.plot.plot_id] = memberships

	# Log membership summary
	var biotic_count = 0
	var forest_count = 0
	var market_count = 0
	for plot_id in plot_biome_memberships:
		var m = plot_biome_memberships[plot_id]
		if "BioticFlux" in m:
			biotic_count += 1
		if "Forest" in m:
			forest_count += 1
		if "Market" in m:
			market_count += 1

	print("   🔗 Biome memberships: %d BioticFlux, %d Forest, %d Market" % [
		biotic_count, forest_count, market_count
	])


func _update_biomes(delta: float):
	"""Update biomes and apply quantum evolution based on memberships

	SIMULATION LAYER: Each node receives evolution from ALL biomes it belongs to.
	Nodes in the overlap zone get effects from both biomes.
	"""
	# ─────────────────────────────────────────────────────────────────
	# Step 1: Update biome internal state (celestial cycles, weather, etc.)
	# ─────────────────────────────────────────────────────────────────
	if biotic_flux_biome:
		biotic_flux_biome.time_tracker.update(delta)
		biotic_flux_biome._apply_celestial_oscillation(delta)

	if forest_biome:
		forest_biome.time_tracker.update(delta)
		# Forest internal update (weather, patches - but not individual qubits)
		# We handle qubit evolution below based on membership

	if market_biome:
		market_biome.time_tracker.update(delta)
		market_biome._apply_sentiment_oscillation(delta)

	# ─────────────────────────────────────────────────────────────────
	# Step 2: Apply evolution to each node based on biome membership
	# This is where DUAL-BIOME evolution happens for overlap nodes
	# ─────────────────────────────────────────────────────────────────
	for node in all_quantum_nodes:
		if not node.plot or not node.plot.quantum_state:
			continue

		var qubit = node.plot.quantum_state
		var memberships = plot_biome_memberships.get(node.plot.plot_id, [])

		# Apply evolution from each biome this node belongs to
		for biome_name in memberships:
			if biome_name == "BioticFlux" and biotic_flux_biome:
				_apply_biotic_flux_evolution(qubit, delta)
			elif biome_name == "Forest" and forest_biome:
				_apply_forest_evolution(qubit, delta)
			elif biome_name == "Market" and market_biome:
				_apply_market_evolution(qubit, delta)

		# ─────────────────────────────────────────────────────────────
		# Step 3: Sync visualization properties from quantum state
		# (This bridges simulation → visualization, but is NOT the viz)
		# ─────────────────────────────────────────────────────────────
		node.emoji_north_opacity = pow(cos(qubit.theta / 2.0), 2)
		node.emoji_south_opacity = pow(sin(qubit.theta / 2.0), 2)

		# Color brightness from energy (if present)
		if "energy" in qubit:
			var brightness = 0.4 + qubit.energy * 0.6
			node.color = node.color.lightened(brightness - 0.5)

	# ─────────────────────────────────────────────────────────────
	# Step 4: Apply biome boundary forces (push nodes toward native zones)
	# ─────────────────────────────────────────────────────────────
	_apply_biome_boundary_forces(delta)

	# Tell the graph to redraw (visualization reads the simulation state)
	if graph:
		graph.queue_redraw()


func _apply_biotic_flux_evolution(qubit, delta: float):
	"""Apply BioticFlux biome evolution to a single qubit

	Effects: Hamiltonian evolution, spring attraction, energy transfer from sun
	"""
	# Spring attraction toward stable theta (wheat or mushroom preference)
	var stable_theta = PI / 4.0  # Default wheat-favoring
	if qubit.south_emoji == "🍄":
		stable_theta = 3.0 * PI / 4.0  # Mushroom-favoring

	var spring_constant = 0.3
	var theta_diff = stable_theta - qubit.theta
	qubit.theta += theta_diff * spring_constant * delta

	# Energy transfer from sun (based on alignment)
	if biotic_flux_biome.sun_qubit:
		var sun_brightness = pow(cos(biotic_flux_biome.sun_qubit.theta / 2.0), 2)
		var is_day_crop = qubit.north_emoji in ["🌾", "🌱", "🌿"]
		var alignment = sun_brightness if is_day_crop else (1.0 - sun_brightness)
		qubit.energy = clamp(qubit.energy + alignment * 0.01 * delta, 0.0, 1.0)


func _apply_forest_evolution(qubit, delta: float):
	"""Apply Forest biome evolution to a single qubit

	Effects: Weather influence, ecological dynamics
	"""
	# Weather influence on theta (wind pushes, water stabilizes)
	if forest_biome.weather_qubit:
		var wind_prob = pow(sin(forest_biome.weather_qubit.theta / 2.0), 2)
		var water_prob = pow(cos(forest_biome.weather_qubit.theta / 2.0), 2)

		# Wind causes theta perturbation
		qubit.theta += (randf() - 0.5) * wind_prob * 0.1 * delta

		# Water increases energy (nourishment)
		if "energy" in qubit:
			qubit.energy = clamp(qubit.energy + water_prob * 0.005 * delta, 0.0, 1.0)

	# Keep theta in valid range
	qubit.theta = clamp(qubit.theta, 0.0, PI)


func _apply_market_evolution(qubit, delta: float):
	"""Apply Market biome evolution to a single qubit

	Effects: Sentiment influence, volatility dynamics
	"""
	# Sentiment influence (bull/bear affects trader positions)
	if market_biome.sentiment_qubit:
		var bull_prob = pow(cos(market_biome.sentiment_qubit.theta / 2.0), 2)
		var bear_prob = pow(sin(market_biome.sentiment_qubit.theta / 2.0), 2)

		# Bull market pulls toward money (north), bear toward goods (south)
		if qubit.north_emoji == "💰":
			var target_theta = PI / 4.0 if bull_prob > 0.5 else 3.0 * PI / 4.0
			qubit.theta += (target_theta - qubit.theta) * 0.1 * delta

		# Energy fluctuation based on market volatility
		if "energy" in qubit:
			var volatility = abs(bull_prob - bear_prob)
			qubit.energy = clamp(qubit.energy + volatility * 0.02 * delta, 0.0, 1.0)

	# Keep theta in valid range
	qubit.theta = clamp(qubit.theta, 0.0, PI)


func _apply_biome_boundary_forces(delta: float):
	"""Enforce biome oval boundaries - push nodes OUT of biomes they don't belong to

	SIMULATION-DRIVEN: The node's biome_name determines which biomes it belongs to.
	If a node drifts into a biome oval it doesn't belong to, push it out.

	Uses ellipse equation to detect intrusion and push toward nearest edge.
	"""
	if not graph or not graph.layout_calculator:
		return

	# Collect all biome ovals
	var biome_ovals = {
		"BioticFlux": graph.layout_calculator.get_biome_oval("BioticFlux"),
		"Forest": graph.layout_calculator.get_biome_oval("Forest"),
		"Market": graph.layout_calculator.get_biome_oval("Market")
	}

	# Strong boundary force - biomes enforce their walls
	var boundary_strength = 800.0

	for node in all_quantum_nodes:
		if node.biome_name.is_empty():
			continue

		var boundary_force = Vector2.ZERO

		# Check each biome this node does NOT belong to
		for biome_name in biome_ovals:
			if biome_name == node.biome_name:
				continue  # Skip own biome

			var oval = biome_ovals[biome_name]
			if oval.is_empty():
				continue

			var center = oval.get("center", Vector2.ZERO)
			var semi_a = oval.get("semi_a", 100.0)
			var semi_b = oval.get("semi_b", 60.0)

			# Check if node is inside this foreign biome's oval
			# Ellipse equation: (dx/a)² + (dy/b)² <= 1 means inside
			var dx = node.position.x - center.x
			var dy = node.position.y - center.y
			var normalized_dist = (dx * dx) / (semi_a * semi_a) + (dy * dy) / (semi_b * semi_b)

			if normalized_dist < 1.0:
				# NODE IS INSIDE A FOREIGN BIOME - push it out!
				# Calculate push direction (outward from center, scaled by ellipse)
				var push_dir = Vector2(dx / semi_a, dy / semi_b).normalized()
				# Scale back to screen space
				push_dir = Vector2(push_dir.x * semi_a, push_dir.y * semi_b).normalized()

				# Force strength increases as node goes deeper into foreign biome
				# At edge (normalized_dist=1): no force
				# At center (normalized_dist=0): maximum force
				var intrusion_depth = 1.0 - normalized_dist
				var force_magnitude = boundary_strength * intrusion_depth

				boundary_force += push_dir * force_magnitude

		# Apply boundary force through velocity
		node.velocity += boundary_force * delta


# ═══════════════════════════════════════════════════════════════════════════
# SKATING RINK BLOCH PROJECTION: Each biome oval is a Bloch sphere projection
# - Phi angle → angular position around perimeter (like skating around a rink)
# - Radius → distance from center (higher R = closer to edge)
# ═══════════════════════════════════════════════════════════════════════════

func _apply_skating_rink_forces(delta: float):
	"""Apply forces to make bubbles orbit based on phi and expand based on radius

	This turns each biome oval into a projected Bloch sphere:
	- Phi (0 to TAU) maps to angular position around the oval perimeter
	- Radius (0 to 1) maps to distance from center (0=center, 1=edge)

	Creates beautiful swirling dynamics as qubits evolve!
	"""
	if not graph or not graph.layout_calculator:
		return

	for node in all_quantum_nodes:
		if not node.plot or not node.plot.quantum_state:
			continue
		if node.biome_name.is_empty():
			continue

		var qubit = node.plot.quantum_state
		var oval = graph.layout_calculator.get_biome_oval(node.biome_name)
		if oval.is_empty():
			continue

		var center = oval.get("center", Vector2.ZERO)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# ─────────────────────────────────────────────────────────────
		# PHI → Angular position on oval perimeter
		# ─────────────────────────────────────────────────────────────
		var phi = qubit.phi if "phi" in qubit else 0.0

		# Target position on oval edge at this phi angle
		# Parametric ellipse: x = a*cos(phi), y = b*sin(phi)
		var target_angle_pos = center + Vector2(
			semi_a * cos(phi),
			semi_b * sin(phi)
		)

		# ─────────────────────────────────────────────────────────────
		# RADIUS → Distance from center (0=center, 1=edge)
		# ─────────────────────────────────────────────────────────────
		var radius = qubit.radius if "radius" in qubit else 0.5
		radius = clamp(radius, 0.0, 1.0)

		# Target distance: lerp between center and edge based on radius
		var target_pos = center.lerp(target_angle_pos, radius)

		# ─────────────────────────────────────────────────────────────
		# Apply attractive force toward target position
		# ─────────────────────────────────────────────────────────────
		var to_target = target_pos - node.position
		var distance = to_target.length()

		if distance > 1.0:
			# Spring force toward phi/radius position
			var force_dir = to_target.normalized()
			var force_magnitude = skating_rink_strength * min(distance / 50.0, 2.0)
			node.velocity += force_dir * force_magnitude * delta


func _apply_sun_moon_orbit(delta: float):
	"""Make sun/moon orbit around BioticFlux biome perimeter

	The sun's phi angle continuously increases, causing it to trace
	the elliptical edge of the BioticFlux biome oval.
	"""
	if not biotic_flux_biome or not biotic_flux_biome.sun_qubit:
		return

	# Evolve sun's phi to orbit the biome
	biotic_flux_biome.sun_qubit.phi += sun_orbit_speed * delta
	if biotic_flux_biome.sun_qubit.phi > TAU:
		biotic_flux_biome.sun_qubit.phi -= TAU

	# Sun radius oscillates slightly (breathing effect)
	var base_radius = 0.85  # Close to edge but not on it
	var breath = sin(biotic_flux_biome.time_tracker.time_elapsed * 0.5) * 0.1
	biotic_flux_biome.sun_qubit.radius = base_radius + breath


func _sync_forest_organisms(delta: float):
	"""Dynamically sync Forest visualization with actual organism population

	Organisms are born, die, and change - the visualization must track this.
	"""
	forest_organism_sync_timer += delta
	if forest_organism_sync_timer < forest_organism_sync_interval:
		return
	forest_organism_sync_timer = 0.0

	if not forest_biome:
		return

	# Collect current organisms from simulation
	var current_organisms: Dictionary = {}  # icon_key → organism
	for patch_pos in forest_biome.patches.keys():
		var patch = forest_biome.patches[patch_pos]
		if not patch.has_meta("organisms"):
			continue
		var organisms = patch.get_meta("organisms")
		for icon_key in organisms.keys():
			var organism = organisms[icon_key]
			if organism and organism.alive and organism.qubit:
				current_organisms[icon_key] = {
					"organism": organism,
					"patch_pos": patch_pos
				}

	# Find nodes that no longer have organisms (deaths)
	var nodes_to_remove: Array = []
	for node in forest_nodes:
		var plot_id = node.plot.plot_id
		# Extract icon_key from plot_id (format: "forest_org_ICON_INDEX")
		var found = false
		for icon_key in current_organisms.keys():
			if plot_id.contains(icon_key.left(2)):  # Match emoji prefix
				found = true
				break

		# Check by matching the node's emoji to living organisms
		var node_emoji = node.emoji_north
		found = false
		for icon_key in current_organisms.keys():
			if icon_key.begins_with(node_emoji):
				found = true
				break

		if not found:
			nodes_to_remove.append(node)
			# Add death effect
			death_effects.append({
				"position": node.position,
				"time": 0.0,
				"icon": node_emoji
			})

	# Remove dead organism nodes
	for node in nodes_to_remove:
		forest_nodes.erase(node)
		all_quantum_nodes.erase(node)
		graph.quantum_nodes.erase(node)
		if node.plot:
			graph.node_by_plot_id.erase(node.plot.plot_id)

	# Find organisms that don't have nodes (births)
	for icon_key in current_organisms.keys():
		var data = current_organisms[icon_key]
		var organism = data.organism

		# Check if we already have a node for this organism
		var has_node = false
		for node in forest_nodes:
			if node.plot and node.plot.quantum_state == organism.qubit:
				has_node = true
				# Update existing node's qubit reference (in case it changed)
				node.emoji_north = organism.qubit.north_emoji
				node.emoji_south = organism.qubit.south_emoji
				break

		if not has_node:
			# Create new node for this organism
			_create_single_forest_node(organism, icon_key, data.patch_pos)
			# Add spawn effect
			spawn_effects.append({
				"position": stored_center,  # Will be updated by skating rink
				"time": 0.0,
				"color": Color.GREEN
			})


func _create_single_forest_node(organism, icon_key: String, patch_pos: Vector2i):
	"""Create a single QuantumNode for a forest organism (dynamic spawn)"""
	var plot = FarmPlotScript.new()
	plot.plot_id = "forest_org_%s_%d" % [icon_key, randi()]
	plot.grid_position = patch_pos
	plot.quantum_state = organism.qubit
	plot.is_planted = true

	# Initial position at biome center (skating rink will move it)
	var oval = graph.layout_calculator.get_biome_oval("Forest")
	var center = oval.get("center", stored_center) if not oval.is_empty() else stored_center

	var node = QuantumNodeScript.new(plot, center, patch_pos, stored_center)
	node.biome_name = "Forest"
	node.parametric_t = randf()
	node.parametric_ring = 0.3 + randf() * 0.2
	node.has_farm_tether = false  # Free-floating biome bubble

	# Color by organism type
	var org_type = organism.organism_type if "organism_type" in organism else ""
	if org_type == "predator" or org_type == "apex":
		node.color = Color(0.9, 0.4, 0.3)  # Red/orange for predators
	elif org_type == "herbivore":
		node.color = Color(0.4, 0.8, 0.5)  # Green for prey
	else:
		node.color = Color.from_hsv(randf(), 0.7, 0.8)

	# Dual emoji from qubit
	node.emoji_north = organism.qubit.north_emoji
	node.emoji_south = organism.qubit.south_emoji

	graph.quantum_nodes.append(node)
	graph.node_by_plot_id[plot.plot_id] = node
	forest_nodes.append(node)
	all_quantum_nodes.append(node)

	# Update biome membership
	plot_biome_memberships[plot.plot_id] = ["Forest"]

	print("      🌱 Spawned %s (%s/%s)" % [icon_key, node.emoji_north, node.emoji_south])


func _update_life_cycle_effects(delta: float):
	"""Update and expire life cycle visual effects, sync to graph for drawing"""
	var effect_duration = 1.0

	# Update spawn effects
	var spawn_to_remove: Array = []
	for effect in spawn_effects:
		effect.time += delta
		if effect.time > effect_duration:
			spawn_to_remove.append(effect)
	for e in spawn_to_remove:
		spawn_effects.erase(e)

	# Update death effects
	var death_to_remove: Array = []
	for effect in death_effects:
		effect.time += delta
		if effect.time > effect_duration:
			death_to_remove.append(effect)
	for e in death_to_remove:
		death_effects.erase(e)

	# Update coherence strike effects
	var strike_to_remove: Array = []
	for effect in coherence_strike_effects:
		effect.time += delta
		if effect.time > 0.5:  # Quick flash
			strike_to_remove.append(effect)
	for e in strike_to_remove:
		coherence_strike_effects.erase(e)

	# Sync effects to graph for drawing
	if graph:
		graph.life_cycle_effects["spawns"] = spawn_effects.duplicate()
		graph.life_cycle_effects["deaths"] = death_effects.duplicate()
		graph.life_cycle_effects["strikes"] = coherence_strike_effects.duplicate()


func _evolve_forest_phi(delta: float):
	"""Evolve forest organism phi angles to create orbiting movement

	Different organism types orbit at different speeds:
	- Predators (🐺🦅): Slower, stalking movement
	- Prey (🐰🐭): Faster, nervous movement
	- Weather qubits: Slow environmental drift
	"""
	if not forest_biome:
		return

	# Evolve weather qubits phi (slow drift)
	if forest_biome.weather_qubit:
		forest_biome.weather_qubit.phi += 0.02 * delta
		if forest_biome.weather_qubit.phi > TAU:
			forest_biome.weather_qubit.phi -= TAU

	if forest_biome.season_qubit:
		forest_biome.season_qubit.phi += 0.01 * delta
		if forest_biome.season_qubit.phi > TAU:
			forest_biome.season_qubit.phi -= TAU

	# Evolve organism phi based on type
	for node in forest_nodes:
		if not node.plot or not node.plot.quantum_state:
			continue

		var qubit = node.plot.quantum_state
		var emoji = node.emoji_north

		# Different orbit speeds by organism type
		var orbit_speed = 0.1  # Default
		match emoji:
			"🐺":  # Wolf - slow stalking
				orbit_speed = 0.05
			"🦅":  # Eagle - circling
				orbit_speed = 0.08
			"🐦":  # Bird - moderate
				orbit_speed = 0.12
			"🐰":  # Rabbit - fast nervous
				orbit_speed = 0.2
			"🐭":  # Mouse - very fast
				orbit_speed = 0.25
			"🐛":  # Caterpillar - slow
				orbit_speed = 0.03

		# Add some variation based on theta (stressed = faster)
		var stress = abs(qubit.theta - PI / 2.0) / (PI / 2.0)  # 0-1 stress level
		orbit_speed *= 1.0 + stress * 0.5

		qubit.phi += orbit_speed * delta
		if qubit.phi > TAU:
			qubit.phi -= TAU


func _evolve_market_phi(delta: float):
	"""Evolve market qubit phi angles - traders swirl around the market"""
	if not market_biome:
		return

	# Sentiment orbits slowly (market cycles)
	if market_biome.sentiment_qubit:
		market_biome.sentiment_qubit.phi += 0.03 * delta
		if market_biome.sentiment_qubit.phi > TAU:
			market_biome.sentiment_qubit.phi -= TAU

	# Traders orbit based on market conditions
	for node in market_nodes:
		if not node.plot or not node.plot.quantum_state:
			continue
		if node.plot.plot_id == "market_sentiment":
			continue  # Already handled above

		var qubit = node.plot.quantum_state

		# Faster orbit in volatile markets
		var volatility = 0.5
		if market_biome.sentiment_qubit:
			var bull_prob = pow(cos(market_biome.sentiment_qubit.theta / 2.0), 2)
			volatility = abs(bull_prob - 0.5) * 2.0  # Higher at extremes

		var orbit_speed = 0.1 + volatility * 0.15
		qubit.phi += orbit_speed * delta
		if qubit.phi > TAU:
			qubit.phi -= TAU


func _evolve_biotic_flux_phi(delta: float):
	"""Evolve BioticFlux crop phi angles - wheat and mushrooms gently orbit"""
	# Sun already orbits via _apply_sun_moon_orbit()

	# Crops orbit slowly, following the sun
	for node in biotic_flux_nodes:
		if not node.plot or not node.plot.quantum_state:
			continue
		if node.plot.plot_id == "biotic_sun":
			continue  # Sun handled separately

		var qubit = node.plot.quantum_state

		# Crops slowly orbit, lagging behind sun
		var orbit_speed = 0.04
		if node.emoji_south == "🍄":
			orbit_speed = 0.02  # Mushrooms are slower

		qubit.phi += orbit_speed * delta
		if qubit.phi > TAU:
			qubit.phi -= TAU


func _process(delta):
	"""Update both biomes and visualization"""
	# Check for viewport resize and update Venn zones parametrically
	_check_viewport_resize()

	# Update both biomes with quantum evolution
	_update_biomes(delta)

	# ═══════════════════════════════════════════════════════════════
	# SKATING RINK: Phi→perimeter, Radius→distance
	# ═══════════════════════════════════════════════════════════════
	_apply_skating_rink_forces(delta)
	_apply_sun_moon_orbit(delta)

	# ═══════════════════════════════════════════════════════════════
	# PHI EVOLUTION: All biomes orbit their qubits
	# ═══════════════════════════════════════════════════════════════
	_evolve_forest_phi(delta)
	_evolve_market_phi(delta)
	_evolve_biotic_flux_phi(delta)

	# ═══════════════════════════════════════════════════════════════
	# FOREST DYNAMICS: Sync with organism population
	# ═══════════════════════════════════════════════════════════════
	_sync_forest_organisms(delta)

	# ═══════════════════════════════════════════════════════════════
	# LIFE CYCLE EFFECTS: Spawn, death, coherence strikes
	# ═══════════════════════════════════════════════════════════════
	_update_life_cycle_effects(delta)

	# Update metrics display
	update_timer += delta
	if update_timer > 0.5:
		_update_metrics()
		update_timer = 0.0

	# Close on Q
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()


func _check_viewport_resize():
	"""Check for viewport changes and update layout via BiomeLayoutCalculator

	The graph's update_layout() method handles all parametric recalculation.
	We just track stored values for any test-specific calculations.
	"""
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < 200 or viewport_size.y < 200:
		viewport_size = Vector2(1280, 720)  # Headless fallback

	var new_center = viewport_size / 2.0
	var new_radius = min(viewport_size.x, viewport_size.y) * 0.35

	# Only update if dimensions changed significantly
	if abs(new_radius - stored_radius) < 1.0 and new_center.distance_to(stored_center) < 1.0:
		return

	# Store new dimensions
	stored_center = new_center
	stored_radius = new_radius

	# Graph's update_layout() handles everything via BiomeLayoutCalculator
	# The layout calculator recomputes biome ovals and updates node positions
	graph.update_layout(true)

	# Also recalculate VennZones for membership determination (legacy compatibility)
	_create_venn_zone_calculator()


func _update_metrics():
	"""Update the displayed metrics from multi-biome simulation"""
	var total_nodes = biotic_flux_nodes.size() + forest_nodes.size()
	if total_nodes == 0:
		return

	var total_coherence = 0.0
	var total_energy = 0.0

	# Collect stats from BioticFlux nodes
	for node in biotic_flux_nodes:
		if node.plot and node.plot.quantum_state:
			var qubit = node.plot.quantum_state
			total_coherence += qubit.radius
			total_energy += qubit.energy

	# Collect stats from Forest nodes
	for node in forest_nodes:
		if node.plot and node.plot.quantum_state:
			var qubit = node.plot.quantum_state
			total_coherence += qubit.radius

	# Get sun phase info
	var sun_phase = "Day"
	if biotic_flux_biome and biotic_flux_biome.sun_qubit:
		var sun_prob = pow(cos(biotic_flux_biome.sun_qubit.theta / 2.0), 2)
		sun_phase = "Day" if sun_prob > 0.5 else "Night"

	# Update labels
	if qubit_count_label:
		qubit_count_label.text = "Qubits: %d (🌾%d + 🌲%d)" % [total_nodes, biotic_flux_nodes.size(), forest_nodes.size()]
	if entanglement_label:
		entanglement_label.text = "Sun Phase: %s | Energy: %.1f" % [sun_phase, total_energy]
	if coherence_label and total_nodes > 0:
		var avg_coherence = total_coherence / total_nodes
		coherence_label.text = "Avg Coherence: %.2f" % avg_coherence
