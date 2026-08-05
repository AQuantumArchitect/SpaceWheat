class_name BiomeSelectionRow
extends "res://UI/Widgets/SelectionButtonRow.gd"


## BiomeSelectionRow - Top bar with biome selection buttons (T/Y/U/I/O/P).
## Dynamically expands as new biomes are unlocked.

# Access autoload safely
@onready var _verbose = get_node_or_null("/root/VerboseConfig")

var active_biome_router: Node = null

# Biome display names (more user-friendly)
const BIOME_LABELS: Dictionary = {
	"StarterForest": "Starter Forest",
	"Village": "Village",
	"BioticFlux": "Quantum Fields",
	"StellarForges": "Stellar Forges",
	"FungalNetworks": "Fungal Networks",
	"VolcanicWorlds": "Volcanic Worlds",
}


func _ready() -> void:
	super._ready()

	active_biome_router = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if active_biome_router:
		if not active_biome_router.active_biome_changed.is_connected(_on_active_biome_changed):
			active_biome_router.active_biome_changed.connect(_on_active_biome_changed)
		if active_biome_router.has_signal("biome_order_changed"):
			if not active_biome_router.biome_order_changed.is_connected(_on_biome_order_changed):
				active_biome_router.biome_order_changed.connect(_on_biome_order_changed)
		_rebuild_buttons()
		_set_selected_from_active()
	else:
		_verbose.warn("ui", "⚠️", "BiomeSelectionRow: ActiveBiomeManager not found")

	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)


func _rebuild_buttons() -> void:
	if not active_biome_router:
		return

	var button_specs: Array[Dictionary] = []
	var slot_count = active_biome_router.get_slot_count()
	for slot_idx in range(slot_count):
		var biome_name = active_biome_router.get_biome_for_slot(slot_idx)
		if biome_name == "":
			continue

		var label = BIOME_LABELS.get(biome_name, biome_name)
		var emoji = active_biome_router.get_biome_info(biome_name).get("emoji", "")
		var key_label = active_biome_router.get_slot_key(slot_idx)
		var text = "%s %s [%s]" % [emoji, label, key_label]

		button_specs.append({
			"id": slot_idx,
			"text": text,
			"enabled": true
		})

	build_buttons(button_specs)


func _on_button_selected(slot_idx: int) -> void:
	if not active_biome_router:
		return
	var biome_name = active_biome_router.get_biome_for_slot(slot_idx)
	if biome_name == "":
		return
	var current_idx = active_biome_router.get_biome_index(active_biome_router.get_active_biome())
	var target_idx = active_biome_router.get_biome_index(biome_name)
	var direction = 1 if target_idx > current_idx else -1 if target_idx < current_idx else 0
	active_biome_router.set_active_biome(biome_name, direction)


func _on_active_biome_changed(_new_biome: String, _old_biome: String) -> void:
	_set_selected_from_active()


func _on_biome_order_changed(_new_order: Array) -> void:
	_rebuild_buttons()
	_set_selected_from_active()


func _set_selected_from_active() -> void:
	if not active_biome_router:
		return
	var active = active_biome_router.get_active_biome()
	var slot_idx = _find_slot_for_biome(active)
	if slot_idx >= 0:
		set_selected(slot_idx)


## Pulse hook for ObjectiveSpotlight — same contract as MenuSelectionRow /
## ToolSelectionRow: the uncontested node the spotlight may Tween. Biome chips
## render through their Label ("text" spec — no icon_path), so pulse that.
## Looked up by BIOME NAME (the objective carries a biome, not a slot).
func get_button_pulse_target(biome_name: String) -> Control:
	var slot := _find_slot_for_biome(biome_name)
	if slot < 0:
		return null  # undiscovered / unassigned — nothing honest to pulse
	var data := _get_button_data(slot)
	return data.get("label", null) if not data.is_empty() else null


func _find_slot_for_biome(biome_name: String) -> int:
	if not active_biome_router:
		return -1
	for slot_idx in range(active_biome_router.get_slot_count()):
		if active_biome_router.get_biome_for_slot(slot_idx) == biome_name:
			return slot_idx
	return -1
