class_name SemanticOctant
extends RefCounted

## Semantic Octant Detector
##
## Divides 3D phase space into 8 named semantic regions.
## Each region has distinct characteristics that affect gameplay.
##
## The three axes represent:
##   Axis 0 (X): Energy/Activity level
##   Axis 1 (Y): Growth/Stability
##   Axis 2 (Z): Wealth/Resources
##
## Each axis is split at 0.5:
##   Low (< 0.5) vs High (>= 0.5)
##
## This creates 2^3 = 8 octants, each with a unique semantic identity.

## The 8 semantic regions
enum Region {
	PHOENIX,    # High energy, high growth, high wealth - Abundance & transformation
	SAGE,       # Low energy, high growth, low wealth - Wisdom & patience
	WARRIOR,    # High energy, low growth, low wealth - Conflict & struggle
	MERCHANT,   # High energy, low growth, high wealth - Trade & accumulation
	ASCETIC,    # Low energy, low growth, low wealth - Minimalism & conservation
	GARDENER,   # Low energy, high growth, high wealth - Cultivation & harmony
	INNOVATOR,  # High energy, high growth, low wealth - Experimentation & chaos
	GUARDIAN    # Low energy, low growth, high wealth - Defense & protection
}

## Threshold for high/low classification
const THRESHOLD: float = 0.5

## ========================================
## Detection API
## ========================================

static func detect_region(position: Vector3) -> Region:
	"""Detect which semantic octant a position is in

	Args:
		position: Point in phase space (values typically 0-1 on each axis)
		          X = energy/activity
		          Y = growth/stability
		          Z = wealth/resources

	Returns:
		Region enum
	"""
	var high_energy = position.x >= THRESHOLD
	var high_growth = position.y >= THRESHOLD
	var high_wealth = position.z >= THRESHOLD

	# Map 8 combinations to semantic regions
	if high_energy and high_growth and high_wealth:
		return Region.PHOENIX      # +++ : Abundance
	elif not high_energy and high_growth and not high_wealth:
		return Region.SAGE         # -+- : Wisdom
	elif high_energy and not high_growth and not high_wealth:
		return Region.WARRIOR      # +-- : Struggle
	elif high_energy and not high_growth and high_wealth:
		return Region.MERCHANT     # +-+ : Trade
	elif not high_energy and not high_growth and not high_wealth:
		return Region.ASCETIC      # --- : Minimalism
	elif not high_energy and high_growth and high_wealth:
		return Region.GARDENER     # -++ : Cultivation
	elif high_energy and high_growth and not high_wealth:
		return Region.INNOVATOR    # ++- : Experimentation
	else:  # not high_energy and not high_growth and high_wealth
		return Region.GUARDIAN     # --+ : Protection


static func detect_from_quantum_computer(quantum_computer, emoji_axes: Array[String]) -> Region:
	"""Detect region from quantum computer state

	Args:
		quantum_computer: QuantumComputer with current state
		emoji_axes: Array of 3 emojis defining the axes [energy, growth, wealth]

	Returns:
		Current semantic region
	"""
	if emoji_axes.size() < 3:
		push_warning("SemanticOctant: Need 3 emojis for axes, got %d" % emoji_axes.size())
		return Region.ASCETIC  # Default to minimalist

	var position = Vector3(
		quantum_computer.get_population(emoji_axes[0]),
		quantum_computer.get_population(emoji_axes[1]),
		quantum_computer.get_population(emoji_axes[2])
	)

	return detect_region(position)


static func detect_from_attractor(attractor_analyzer) -> Region:
	"""Detect region from attractor's current centroid

	Args:
		attractor_analyzer: StrangeAttractorAnalyzer with trajectory data

	Returns:
		Current semantic region based on attractor centroid
	"""
	var signature = attractor_analyzer.get_signature()
	var centroid = signature.get("centroid", Vector3(0.5, 0.5, 0.5))
	return detect_region(centroid)


## ========================================
## Region Information
## ========================================

static func get_region_name(region: Region) -> String:
	"""Get display name for region"""
	match region:
		Region.PHOENIX: return "Phoenix"
		Region.SAGE: return "Sage"
		Region.WARRIOR: return "Warrior"
		Region.MERCHANT: return "Merchant"
		Region.ASCETIC: return "Ascetic"
		Region.GARDENER: return "Gardener"
		Region.INNOVATOR: return "Innovator"
		Region.GUARDIAN: return "Guardian"
		_: return "Unknown"


static func get_region_emoji(region: Region) -> String:
	"""Get emoji icon for region"""
	match region:
		Region.PHOENIX: return "🔥"
		Region.SAGE: return "📿"
		Region.WARRIOR: return "⚔️"
		Region.MERCHANT: return "💰"
		Region.ASCETIC: return "🧘"
		Region.GARDENER: return "🌱"
		Region.INNOVATOR: return "💡"
		Region.GUARDIAN: return "🛡️"
		_: return "❓"


static func get_region_description(region: Region) -> String:
	"""Get detailed description of region characteristics"""
	match region:
		Region.PHOENIX:
			return "High energy, rapid growth, abundant resources. A state of transformation and rebirth."
		Region.SAGE:
			return "Calm wisdom, patient growth, spiritual focus. Knowledge over material wealth."
		Region.WARRIOR:
			return "High conflict, aggressive action, scarce resources. Survival through struggle."
		Region.MERCHANT:
			return "Trade focus, wealth accumulation, stable but not growing. Prosperity through exchange."
		Region.ASCETIC:
			return "Minimalist, conservative, preservation. Simplicity and endurance."
		Region.GARDENER:
			return "Balanced cultivation, harmony with growth. Patient abundance."
		Region.INNOVATOR:
			return "Experimental, chaotic creativity. Growth through risk and invention."
		Region.GUARDIAN:
			return "Defensive, protective, resource hoarding. Security over expansion."
		_:
			return "Unknown semantic region"


static func get_region_color(region: Region) -> Color:
	"""Get color for region visualization"""
	match region:
		Region.PHOENIX: return Color(1.0, 0.4, 0.1)      # Orange-red
		Region.SAGE: return Color(0.4, 0.6, 0.9)         # Steel blue
		Region.WARRIOR: return Color(0.7, 0.1, 0.1)      # Dark red
		Region.MERCHANT: return Color(1.0, 0.84, 0.0)    # Gold
		Region.ASCETIC: return Color(0.5, 0.5, 0.5)      # Gray
		Region.GARDENER: return Color(0.13, 0.55, 0.13)  # Forest green
		Region.INNOVATOR: return Color(0.6, 0.2, 0.8)    # Purple
		Region.GUARDIAN: return Color(0.28, 0.24, 0.55)  # Dark slate blue
		_: return Color.WHITE


## ========================================
## Gameplay Modifiers
## ========================================

static func get_region_modifiers(region: Region) -> Dictionary:
	"""Get gameplay modifiers for this region

	Returns dictionary with modifier values that can affect:
	- growth_rate: Multiplier for crop growth
	- harvest_yield: Multiplier for harvest amounts
	- coherence_decay: Rate of quantum decoherence
	- energy_extraction: Efficiency of spark extraction
	- tool_variants: Which tool variants are available

	All values are multipliers (1.0 = normal)
	"""
	match region:
		Region.PHOENIX:
			return {
				"growth_rate": 1.5,
				"harvest_yield": 1.3,
				"coherence_decay": 1.2,  # Faster decoherence (volatile)
				"energy_extraction": 1.0,
				"dominant_element": "fire"
			}
		Region.SAGE:
			return {
				"growth_rate": 0.8,
				"harvest_yield": 1.0,
				"coherence_decay": 0.6,  # Slower decoherence (stable)
				"energy_extraction": 1.2,
				"dominant_element": "wisdom"
			}
		Region.WARRIOR:
			return {
				"growth_rate": 0.9,
				"harvest_yield": 0.8,
				"coherence_decay": 1.5,  # Fast decoherence (chaotic)
				"energy_extraction": 0.8,
				"dominant_element": "conflict"
			}
		Region.MERCHANT:
			return {
				"growth_rate": 1.0,
				"harvest_yield": 1.5,
				"coherence_decay": 1.0,
				"energy_extraction": 1.3,
				"dominant_element": "trade"
			}
		Region.ASCETIC:
			return {
				"growth_rate": 0.6,
				"harvest_yield": 0.7,
				"coherence_decay": 0.5,  # Very stable
				"energy_extraction": 0.6,
				"dominant_element": "void"
			}
		Region.GARDENER:
			return {
				"growth_rate": 1.3,
				"harvest_yield": 1.2,
				"coherence_decay": 0.8,
				"energy_extraction": 1.0,
				"dominant_element": "earth"
			}
		Region.INNOVATOR:
			return {
				"growth_rate": 1.2,
				"harvest_yield": 0.9,
				"coherence_decay": 1.3,
				"energy_extraction": 1.5,  # High extraction efficiency
				"dominant_element": "lightning"
			}
		Region.GUARDIAN:
			return {
				"growth_rate": 0.7,
				"harvest_yield": 1.1,
				"coherence_decay": 0.7,
				"energy_extraction": 0.9,
				"dominant_element": "stone"
			}
		_:
			return {
				"growth_rate": 1.0,
				"harvest_yield": 1.0,
				"coherence_decay": 1.0,
				"energy_extraction": 1.0,
				"dominant_element": "neutral"
			}


## ========================================
## Region Transitions
## ========================================

static func get_adjacent_regions(region: Region) -> Array[Region]:
	"""Get regions that are adjacent (differ by one axis)

	Returns array of 3 adjacent regions (each axis flip)
	"""
	var result: Array[Region] = []

	# Get current octant bits
	var bits = _region_to_bits(region)

	# Flip each bit to get adjacent regions
	for i in range(3):
		var adjacent_bits = bits ^ (1 << i)  # XOR to flip bit i
		result.append(_bits_to_region(adjacent_bits))

	return result


static func get_transition_difficulty(from_region: Region, to_region: Region) -> float:
	"""Get difficulty of transitioning between regions

	Returns:
		0.0 = same region
		1.0 = adjacent (1 axis different)
		2.0 = diagonal (2 axes different)
		3.0 = opposite (3 axes different)
	"""
	var from_bits = _region_to_bits(from_region)
	var to_bits = _region_to_bits(to_region)

	var diff = from_bits ^ to_bits  # XOR shows different bits

	# Count set bits (Hamming distance)
	var count = 0
	while diff > 0:
		count += diff & 1
		diff >>= 1

	return float(count)


static func _region_to_bits(region: Region) -> int:
	"""Convert region to 3-bit representation (energy, growth, wealth)"""
	match region:
		Region.PHOENIX: return 0b111    # +++
		Region.SAGE: return 0b010       # -+-
		Region.WARRIOR: return 0b100    # +--
		Region.MERCHANT: return 0b101   # +-+
		Region.ASCETIC: return 0b000    # ---
		Region.GARDENER: return 0b011   # -++
		Region.INNOVATOR: return 0b110  # ++-
		Region.GUARDIAN: return 0b001   # --+
		_: return 0b000


static func _bits_to_region(bits: int) -> Region:
	"""Convert 3-bit representation to region"""
	match bits:
		0b111: return Region.PHOENIX
		0b010: return Region.SAGE
		0b100: return Region.WARRIOR
		0b101: return Region.MERCHANT
		0b000: return Region.ASCETIC
		0b011: return Region.GARDENER
		0b110: return Region.INNOVATOR
		0b001: return Region.GUARDIAN
		_: return Region.ASCETIC
