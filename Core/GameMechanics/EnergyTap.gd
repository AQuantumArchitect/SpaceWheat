class_name EnergyTap
extends FarmPlot

## EnergyTap - Quantum-to-Classical Converter
## Extracts energy from quantum qubits and converts to classical resources
## Primary output: Water (💧), but can work with any emoji in vocabulary

# Tap configuration
var target_emoji: String = "💧"  # Water by default (can be 🌾, 👥, 💧, etc.)
var conversion_rate: float = 0.1  # Energy → resource conversion efficiency
var max_capacity: float = 10.0   # Max accumulated resource before harvest
var accumulated_resource: float = 0.0  # Currently stored resource

# Adjacent plots to tap from (if any)
var adjacent_qubits: Array = []


func _init():
	super._init()
	plot_type = PlotType.ENERGY_TAP
	is_planted = true  # Always "active"
	target_emoji = "💧"  # Water by default


## Quantum-to-Classical Conversion


func extract_energy_from_qubit(qubit: Node) -> float:
	"""Extract energy from a DualEmojiQubit and accumulate resource"""
	if not qubit or not qubit.has_method("get_energy"):
		return 0.0

	var extracted_energy = qubit.get_energy()
	if extracted_energy <= 0:
		return 0.0

	# Convert quantum energy to classical resource
	# Energy ratio scales with how much of the qubit's energy we extract
	var resource_amount = extracted_energy * conversion_rate
	accumulated_resource += resource_amount

	print("🚰 Tapped %.2f energy → %.2f %s" % [extracted_energy, resource_amount, target_emoji])

	return resource_amount


func harvest_accumulated_resource() -> Dictionary:
	"""Harvest accumulated resource from the tap"""
	if accumulated_resource <= 0:
		return {"success": false, "resource": target_emoji, "amount": 0}

	var amount = accumulated_resource
	accumulated_resource = 0.0

	print("💾 Harvested %.2f %s from tap" % [amount, target_emoji])

	return {
		"success": true,
		"resource": target_emoji,
		"amount": amount,
		"type": "quantum_to_classical_conversion"
	}


## Configuration


func set_target_emoji(emoji: String) -> void:
	"""Change what resource this tap produces"""
	target_emoji = emoji
	print("🚰 Tap now targets: %s" % emoji)


func set_conversion_rate(rate: float) -> void:
	"""Adjust efficiency of energy conversion"""
	conversion_rate = clampf(rate, 0.0, 1.0)
	print("🚰 Conversion rate: %.1f%%" % (conversion_rate * 100))


## Display


func get_plot_emojis() -> Dictionary:
	"""Energy tap shows target emoji and power"""
	return {"north": "🚰", "south": "⚡"}


func get_semantic_emoji() -> String:
	"""Show tap emoji to indicate it's active"""
	return "🚰"


## Prevent farming operations


func plant(labor_input = 0.0, wheat_input = 0.0, target_biome = null):
	"""Energy taps are always active, cannot be replanted"""
	print("⚠️ Cannot plant on energy tap - already active")


func harvest() -> Dictionary:
	"""Use harvest_accumulated_resource instead"""
	return harvest_accumulated_resource()
