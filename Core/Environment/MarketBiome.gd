class_name MarketBiome
extends "res://Core/Environment/BiomeBase.gd"

## Quantum Market Biome: Full quantum system for trading/economics
##
## Two quantum axes drive market dynamics:
## 1. Sentiment qubit: 🐂/🐻 (Bull/Bear) - price direction
## 2. Liquidity qubit: 💰/📦 (Money/Goods) - available resources
##
## Architecture mirrors BioticFlux biome but for economics:
## - Celestial equivalent: market_sentiment_qubit (drives overall mood)
## - Icon equivalents: bull_icon, bear_icon (Hamiltonian attractors)
## - Crop equivalents: trader qubits (💰/📦 money/goods axis)
##
## Biome emoji pairings (what gets attached when injected):
## - 💰 pairs with 📦 (money ↔ goods)
## - 🐂 pairs with 🐻 (bull ↔ bear)

const TIME_SCALE = 1.0  # Market evolution speed

# ═══════════════════════════════════════════════════════════════════════════
# CELESTIAL: Market Sentiment (drives overall market mood)
# ═══════════════════════════════════════════════════════════════════════════
var sentiment_qubit: DualEmojiQubit = null  # 🐂/🐻 Bull/Bear sentiment
var sentiment_period: float = 30.0  # seconds for full bull/bear cycle

# ═══════════════════════════════════════════════════════════════════════════
# ICONS: Market forces (Hamiltonian attractors)
# ═══════════════════════════════════════════════════════════════════════════
var bull_icon: Dictionary = {}  # Attracts toward 🐂 (rising prices)
var bear_icon: Dictionary = {}  # Attracts toward 🐻 (falling prices)

# ═══════════════════════════════════════════════════════════════════════════
# EMOJI PAIRINGS: Registered in _ready() via BiomeBase.register_emoji_pair()
# ═══════════════════════════════════════════════════════════════════════════

# Market-specific constants
var base_price: int = 100  # Starting price per unit
var volatility: float = 0.3  # How much sentiment affects prices

# Granary Guilds influence (merchant collective)
var granary_guilds_qubit: DualEmojiQubit = null  # 🏛️/🏚️ (stable/chaotic markets)


func _ready():
	super._ready()

	# Register emoji pairings for this biome (uses BiomeBase system)
	register_emoji_pair("💰", "📦")  # Money ↔ Goods
	register_emoji_pair("🐂", "🐻")  # Bull ↔ Bear

	# Configure visual properties for QuantumForceGraph
	# Layout: Market (TY) in top-left corner - moved left by ~3/8 screen width total
	visual_color = Color(1.0, 0.55, 0.0, 0.3)  # Sunset orange
	visual_label = "📈 Market"
	visual_center_offset = Vector2(-1.15, -0.25)  # Far left, -0.9 - 0.25 for extra 1/8
	visual_oval_width = 400.0   # 2x larger to match other biomes
	visual_oval_height = 250.0  # Golden ratio maintained

	print("  ✅ MarketBiome running in bath-first mode")


func _initialize_bath() -> void:
	"""Initialize quantum bath for Market biome (Bath-First)"""
	print("🛁 Initializing Market quantum bath...")

	# Create bath with Market emoji basis
	bath = QuantumBath.new()
	var emojis = ["🐂", "🐻", "💰", "📦", "🏛️", "🏚️"]
	bath.initialize_with_emojis(emojis)

	# Initialize weighted distribution
	# Bull/Bear start balanced (neutral market)
	# Money and Goods are equal liquidity
	# Granary Guilds lean toward stability
	bath.initialize_weighted({
		"🐂": 0.20,  # Bull - rising prices
		"🐻": 0.20,  # Bear - falling prices
		"💰": 0.20,  # Money - liquid capital
		"📦": 0.20,  # Goods - commodities
		"🏛️": 0.15,  # Stable - Granary Guilds stability
		"🏚️": 0.05   # Chaotic - market chaos
	})

	# Collect Icons from registry
	# Get IconRegistry (Farm._ensure_iconregistry() guarantees it exists)
	var icon_registry = get_node("/root/IconRegistry")
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
		push_warning("🛁 No icons found for Market bath")

	print("  📈 Market ready for quantum trading dynamics!")


func _initialize_market_qubits():
	"""Set up quantum states for market"""

	# Sentiment qubit: 🐂 Bull (north) / 🐻 Bear (south)
	# θ=0 → pure bull, θ=π → pure bear, θ=π/2 → neutral
	sentiment_qubit = BiomeUtilities.create_qubit("🐂", "🐻", PI / 2.0)
	sentiment_qubit.phi = 0.0
	sentiment_qubit.radius = 1.0
	# energy removed - derived from theta

	# Granary Guilds qubit: 🏛️ Stable (north) / 🏚️ Chaotic (south)
	# Merchants prefer stability (low volatility, predictable prices)
	granary_guilds_qubit = BiomeUtilities.create_qubit("🏛️", "🏚️", PI / 4.0)
	granary_guilds_qubit.radius = 1.0
	# energy removed - derived from theta
	# Model B: Sentiment state is managed by QuantumComputer, not stored in plots


func _initialize_market_icons():
	"""Set up icon Hamiltonians for market forces"""

	# BULL ICON - Attracts prices upward
	var bull_internal = DualEmojiQubit.new()
	bull_internal.north_emoji = "🐂"
	bull_internal.south_emoji = "🐻"
	bull_internal.theta = PI / 6.0  # Leans bullish
	bull_internal.phi = 0.0
	bull_internal.radius = 1.0

	bull_icon = {
		"hamiltonian_terms": {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.0},
		"stable_theta": 0.0,  # Pure bull
		"stable_phi": 0.0,
		"spring_constant": 0.3,  # Bull force strength
		"internal_qubit": bull_internal,
	}

	# BEAR ICON - Attracts prices downward
	var bear_internal = DualEmojiQubit.new()
	bear_internal.north_emoji = "🐂"
	bear_internal.south_emoji = "🐻"
	bear_internal.theta = 5.0 * PI / 6.0  # Leans bearish
	bear_internal.phi = PI
	bear_internal.radius = 1.0

	bear_icon = {
		"hamiltonian_terms": {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.0},
		"stable_theta": PI,  # Pure bear
		"stable_phi": PI,
		"spring_constant": 0.3,  # Bear force strength
		"internal_qubit": bear_internal,
	}


func _initialize_bath_market() -> void:
	"""Initialize quantum bath for Market biome (Bath-First)

	Market emojis: 🐂 🐻 💰 📦 🏛️ 🏚️
	Dynamics:
	  - Bull/Bear oscillate with time-dependent self-energy (sentiment cycle)
	  - Money flows toward bull markets (Lindblad transfer)
	  - Goods flow toward bear markets (accumulation in downturns)
	  - Stability/Chaos affects volatility
	"""
	print("🛁 Initializing Market quantum bath...")

	# Create bath with Market emoji basis
	bath = QuantumBath.new()
	var emojis = ["🐂", "🐻", "💰", "📦", "🏛️", "🏚️"]
	bath.initialize_with_emojis(emojis)

	# Initialize weighted distribution
	# Bull/Bear start balanced (neutral market)
	# Money and Goods are equal liquidity
	# Granary Guilds lean toward stability
	bath.initialize_weighted({
		"🐂": 0.20,  # Bull - rising prices
		"🐻": 0.20,  # Bear - falling prices
		"💰": 0.20,  # Money - liquid capital
		"📦": 0.20,  # Goods - commodities
		"🏛️": 0.15,  # Stable - Granary Guilds stability
		"🏚️": 0.05   # Chaotic - market chaos
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
		push_warning("🛁 No icons found for Market bath")

	print("  📈 Market ready for quantum trading dynamics!")


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Evolve market quantum state"""
	# Bath mode: quantum evolution handled by BiomeBase
	# Market sentiment and trader dynamics come from bath amplitudes
	pass


func _apply_sentiment_oscillation(delta: float):
	"""Sentiment qubit oscillates between bull and bear"""
	if not sentiment_qubit:
		return

	# Oscillation parameters (like sun/moon)
	var omega = TAU / sentiment_period
	var t = time_tracker.time_elapsed

	# Theta oscillates around equator with some amplitude
	var amplitude = PI / 3.0  # ±60° swing
	var base_theta = PI / 2.0
	sentiment_qubit.theta = base_theta + amplitude * sin(omega * t)

	# Phi rotates slowly (seasonal patterns)
	sentiment_qubit.phi = fmod(omega * t * 0.1, TAU)

	# Clamp theta to valid range
	sentiment_qubit.theta = clamp(sentiment_qubit.theta, 0.0, PI)


func _apply_market_hamiltonian(delta: float):
	"""Apply market forces to all trader qubits"""
	if not sentiment_qubit:
		return

	# Get current market mood
	var bull_prob = pow(cos(sentiment_qubit.theta / 2.0), 2)  # P(bull)
	var bear_prob = pow(sin(sentiment_qubit.theta / 2.0), 2)  # P(bear)

	# Model B: Market qubit evolution is handled by quantum_computer and bath evolution
	# Market forces (bull/bear sentiment) affect prices through Hamiltonian evolution
	# Spring forces are applied through icon Hamiltonians, not direct qubit manipulation


# ═══════════════════════════════════════════════════════════════════════════
# PUBLIC API: Market operations
# ═══════════════════════════════════════════════════════════════════════════

func get_paired_emoji(emoji: String) -> String:
	"""Get the paired emoji for this biome's axis"""
	return emoji_pairings.get(emoji, "?")


func create_trader_qubit(position: Vector2i, initial_resources: float = 0.5) -> DualEmojiQubit:
	"""Create a new trader qubit (💰/📦) at the given position"""
	var qubit = BiomeUtilities.create_qubit("💰", "📦", PI / 2.0)
	qubit.phi = randf() * TAU
	qubit.radius = clamp(initial_resources, 0.1, 1.0)
	# energy removed - derived from theta
	# Model B: Trader state is managed by QuantumComputer, not stored in plots
	return qubit


func get_current_price() -> int:
	"""Calculate current price based on sentiment"""
	if not sentiment_qubit:
		return base_price

	# Bull = high prices, Bear = low prices
	var bull_prob = pow(cos(sentiment_qubit.theta / 2.0), 2)
	var price_modifier = 0.5 + bull_prob  # Range: 0.5 to 1.5

	return int(base_price * price_modifier)


func get_sentiment_string() -> String:
	"""Get human-readable sentiment"""
	if not sentiment_qubit:
		return "Unknown"

	var bull_prob = pow(cos(sentiment_qubit.theta / 2.0), 2)
	if bull_prob > 0.7:
		return "🐂 Strong Bull"
	elif bull_prob > 0.5:
		return "🐂 Mild Bull"
	elif bull_prob > 0.3:
		return "🐻 Mild Bear"
	else:
		return "🐻 Strong Bear"


func execute_trade(trader_qubit: DualEmojiQubit, sell_amount: float) -> Dictionary:
	"""
	Execute a trade - collapse part of the qubit to classical resources

	The trader qubit is in superposition 💰/📦 (money/goods)
	Selling collapses toward 💰 (money), buying collapses toward 📦 (goods)

	Returns: {success, credits_received, goods_remaining}
	"""
	if not trader_qubit:
		return {"success": false, "credits_received": 0, "goods_remaining": 0.0}

	var current_price = get_current_price()
	var credits = int(sell_amount * current_price)

	# Selling shifts qubit toward 💰 (money side = north pole)
	var shift_amount = sell_amount * 0.5  # Partial collapse
	trader_qubit.theta = max(0.0, trader_qubit.theta - shift_amount)

	# Reduce radius (goods consumed)
	trader_qubit.radius = max(0.1, trader_qubit.radius - sell_amount)

	# Affect market sentiment (large sales push toward bear)
	if sell_amount > 0.5:
		sentiment_qubit.theta = min(PI, sentiment_qubit.theta + 0.1)

	return {
		"success": true,
		"credits_received": credits,
		"goods_remaining": trader_qubit.radius,
		"price_per_unit": current_price,
		"sentiment": get_sentiment_string()
	}


func get_market_status() -> Dictionary:
	"""Get full market state for display"""
	if not sentiment_qubit:
		return {}

	var bull_prob = pow(cos(sentiment_qubit.theta / 2.0), 2)

	return {
		"sentiment": get_sentiment_string(),
		"bull_probability": bull_prob,
		"bear_probability": 1.0 - bull_prob,
		"current_price": get_current_price(),
		"sentiment_theta": sentiment_qubit.theta,
		"sentiment_phi": sentiment_qubit.phi,
		"volatility": volatility,
		"time_elapsed": time_tracker.time_elapsed,
	}


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "Market"
