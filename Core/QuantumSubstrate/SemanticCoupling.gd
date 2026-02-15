class_name SemanticCoupling
extends RefCounted

## Semantic Coupling - Quantum Attraction/Repulsion Between Emoji Pairs
## Based on "Vocabulary Virus" design from Revolutionary Biome Collection
##
## Similar concepts attract (monocultures stabilize)
## Different concepts repel (polycultures innovate)
## Neutral concepts drift (Brownian semantic motion)

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

# Emoji semantic categories — canonical emoji→category mapping.
# VocabularyEvolution derives its category→[emojis] from this via invert_categories().
const EMOJI_CATEGORIES = {
	# Natural/Agricultural
	"🌾": "agriculture", "🌱": "agriculture", "🌿": "agriculture",
	"🍂": "agriculture", "🌳": "agriculture", "🌻": "agriculture",
	"🪴": "agriculture", "🌲": "agriculture",

	# Human/Labor
	"👥": "labor", "👁️": "labor", "🛠️": "labor",
	"⚙": "labor", "⚙️": "labor",

	# Cosmic/Abstract
	"🌌": "cosmic", "🌀": "cosmic", "✨": "cosmic",
	"🕳️": "cosmic", "🌟": "cosmic", "☄️": "cosmic",
	"☀": "cosmic", "🌙": "cosmic",

	# Economic/Resource
	"💰": "economic", "🍅": "economic", "💎": "economic",
	"📈": "economic", "🏦": "economic", "💳": "economic",
	"🍞": "economic", "🍼": "economic",

	# Elemental
	"🔥": "elemental", "❄️": "elemental", "💧": "elemental",
	"💨": "elemental", "🏜️": "elemental", "⚡": "elemental",

	# Biological
	"🍄": "biological", "🐇": "biological", "🐺": "biological",
	"🦌": "biological", "🦅": "biological", "🐂": "biological",
	"🐻": "biological", "🧬": "biological", "🦠": "biological",
	"🐛": "biological",

	# Political/Authority
	"🏰": "political", "⚔️": "political", "⚖️": "political",
	"👑": "political", "🗡️": "political",

	# Emotional
	"😭": "emotional", "☀️": "emotional", "💔": "emotional",
	"❤️‍🔥": "emotional", "😴": "emotional",
}


static func invert_categories() -> Dictionary:
	"""Return category→[emojis] dict derived from EMOJI_CATEGORIES."""
	var inverted: Dictionary = {}
	for emoji in EMOJI_CATEGORIES:
		var cat = EMOJI_CATEGORIES[emoji]
		if not inverted.has(cat):
			inverted[cat] = []
		if emoji not in inverted[cat]:
			inverted[cat].append(emoji)
	return inverted


static func calculate_emoji_similarity(emoji_a: String, emoji_b: String) -> float:
	"""Calculate semantic similarity between two emojis

	Returns:
		Similarity (0.0 to 1.0)
		- 1.0: Identical or same category
		- 0.5: Neutral/unrelated
		- 0.0: Opposite categories
	"""
	# Exact match
	if emoji_a == emoji_b:
		return 1.0

	# Get categories
	var cat_a = EMOJI_CATEGORIES.get(emoji_a, "unknown")
	var cat_b = EMOJI_CATEGORIES.get(emoji_b, "unknown")

	# Same category = high similarity
	if cat_a == cat_b:
		return 0.85

	# Special oppositions
	if _are_opposites(cat_a, cat_b):
		return 0.1

	# Neutral/unrelated
	return 0.5


static func _are_opposites(cat_a: String, cat_b: String) -> bool:
	"""Check if two categories are semantic opposites"""
	var oppositions = [
		["agriculture", "cosmic"],  # Natural vs abstract
		["labor", "economic"],      # Work vs wealth
		["political", "agriculture"] # Control vs growth
	]

	for pair in oppositions:
		if (cat_a == pair[0] and cat_b == pair[1]) or (cat_a == pair[1] and cat_b == pair[0]):
			return true

	return false


static func calculate_pair_similarity(qubit_a: DualEmojiQubit, qubit_b: DualEmojiQubit) -> float:
	"""Calculate similarity between two dual-emoji qubit pairs

	Compares both north and south emojis to get overall similarity.

	Returns:
		Average similarity (0.0 to 1.0)
	"""
	var north_sim = calculate_emoji_similarity(qubit_a.north_emoji, qubit_b.north_emoji)
	var south_sim = calculate_emoji_similarity(qubit_a.south_emoji, qubit_b.south_emoji)
	var cross_sim_1 = calculate_emoji_similarity(qubit_a.north_emoji, qubit_b.south_emoji)
	var cross_sim_2 = calculate_emoji_similarity(qubit_a.south_emoji, qubit_b.north_emoji)

	# Average all comparisons
	return (north_sim + south_sim + cross_sim_1 + cross_sim_2) / 4.0


static func apply_semantic_coupling(qubit_a: DualEmojiQubit, qubit_b: DualEmojiQubit, dt: float, strength: float = 1.0) -> void:
	"""Apply semantic coupling between two qubits

	Based on Vocabulary Virus design:
	- High similarity (>0.7): Attraction - states converge (monoculture stability)
	- Low similarity (<0.3): Repulsion - states diverge (polyculture innovation)
	- Medium similarity: Brownian drift (neutral interaction)

	Args:
		qubit_a: First qubit (will be modified)
		qubit_b: Second qubit (reference, not modified)
		dt: Time step
		strength: Coupling strength multiplier (default 1.0)
	"""
	var similarity = calculate_pair_similarity(qubit_a, qubit_b)

	# Get current Bloch vectors
	var vec_a = qubit_a.get_bloch_vector()
	var vec_b = qubit_b.get_bloch_vector()

	# High similarity: Attraction (monocultures stabilize)
	if similarity > 0.7:
		var target = vec_a.lerp(vec_b, 0.1 * dt * strength)
		qubit_a.set_bloch_vector(target)

	# Low similarity: Repulsion (polycultures innovate)
	elif similarity < 0.3:
		var direction = (vec_a - vec_b).normalized()
		var repelled = vec_a + direction * 0.05 * dt * strength
		qubit_a.set_bloch_vector(repelled.normalized())

	# Medium similarity: Brownian drift
	else:
		var drift = Vector3(
			randf_range(-0.02, 0.02),
			randf_range(-0.02, 0.02),
			randf_range(-0.02, 0.02)
		) * dt * strength
		qubit_a.set_bloch_vector((vec_a + drift).normalized())


static func get_coupling_description(similarity: float) -> String:
	"""Get human-readable description of coupling type"""
	if similarity > 0.7:
		return "🧲 Attraction (monoculture stability)"
	elif similarity < 0.3:
		return "💥 Repulsion (polyculture innovation)"
	else:
		return "🌊 Drift (neutral interaction)"
