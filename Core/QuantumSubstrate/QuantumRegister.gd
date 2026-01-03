class_name QuantumRegister
extends Resource

## Logical qubit identifier in a biome's quantum computer
##
## Model B (physics-correct): This represents a logical register (plot) that can be
## entangled with other registers. The actual quantum state is owned by the parent
## QuantumComputer (biome), not by the register itself.

@export var register_id: int = -1  # Unique per biome (typically encoded plot position)
@export var parent_biome_name: String = ""  # Reference to owning BiomeBase name
@export var component_id: int = -1  # Which connected component this register is in

## Measurement basis labels (not quantum state!)
@export var north_emoji: String = "🌾"  # |0⟩ basis state label
@export var south_emoji: String = "🌽"  # |1⟩ basis state label

## Register metadata (non-quantum)
@export var is_planted: bool = false
@export var crop_type: String = ""
@export var measurement_outcome: String = ""  # "north", "south", or empty if unmeasured
@export var has_been_measured: bool = false

## Gate history (for Tool 5 removal/inspection)
@export var applied_gates: Array = []  # [{gate_type, turn}]

## Entanglement tracking
@export var entangled_with: Array[int] = []  # List of register IDs in same component

func _init(rid: int = -1, biome_name: String = "", comp_id: int = -1):
	register_id = rid
	parent_biome_name = biome_name
	component_id = comp_id

func _to_string() -> String:
	return "QuantumRegister(id=%d, biome=%s, comp=%d, %s↔%s)" % [
		register_id, parent_biome_name, component_id, north_emoji, south_emoji
	]

## Get measurement basis as array of emoji labels
func get_basis_labels() -> Array[String]:
	return [north_emoji, south_emoji]

## Record a gate application for history tracking
func record_gate_application(gate_type: String, turn: int) -> void:
	applied_gates.append({
		"type": gate_type,
		"turn": turn,
		"timestamp": Time.get_ticks_msec()
	})

## Clear all gate history (used on plot reassignment)
func clear_gate_history() -> void:
	applied_gates.clear()
