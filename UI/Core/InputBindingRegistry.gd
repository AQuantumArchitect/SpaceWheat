class_name InputBindingRegistry
extends RefCounted

## Shared source of truth for player-facing keyboard bindings.
## Keeps help surfaces and input routers aligned on the same row ontology.

const ACTION_KEYCODES := {
	"Q": KEY_Q,
	"E": KEY_E,
	"R": KEY_R,
	"F": KEY_F,
}

const BIOME_KEYS := ["T", "Y", "U", "I", "O", "P"]
const HOMEROW_KEYS := ["G", "H", "J", "K", "L", ";"]
const SUBSPACE_KEYS := ["M", ",", ".", "/"]
const QUEST_SLOT_KEYS := ["U", "I", "O", "P"]

const KEY_LABEL_TO_KEYCODE := {
	"T": KEY_T,
	"Y": KEY_Y,
	"U": KEY_U,
	"I": KEY_I,
	"O": KEY_O,
	"P": KEY_P,
	"J": KEY_J,
	"K": KEY_K,
	"L": KEY_L,
	";": KEY_SEMICOLON,
	"'": KEY_APOSTROPHE,
	"H": KEY_H,
	"G": KEY_G,
	"M": KEY_M,
	",": KEY_COMMA,
	".": KEY_PERIOD,
	"/": KEY_SLASH,
	"Tab": KEY_TAB,
	"Space": KEY_SPACE,
	"-": KEY_MINUS,
	"=": KEY_EQUAL,
}

const BIOME_ROW := {
	"T": 0,
	"Y": 1,
	"U": 2,
	"I": 3,
	"O": 4,
	"P": 5,
}

const HOMEROW := {
	"G": 0,
	"H": 1,
	"J": 2,
	"K": 3,
	"L": 4,
	";": 5,
}

const SUBSPACE_ROW := {
	"M": 0,
	",": 1,
	".": 2,
	"/": 3,
}

const BIOME_ACTIONS := ["biome_0", "biome_1", "biome_2", "biome_3", "biome_4", "biome_5"]
const HOMEROW_ACTIONS := ["plot_0", "plot_1", "plot_2", "plot_3", "plot_4", "plot_5"]
const SUBSPACE_ACTIONS := ["subspace_0", "subspace_1", "subspace_2", "subspace_3"]
const TOOL_GROUP_KEYS := ["1", "2", "3", "4"]
const ACTION_KEYS := ["Q", "E", "R", "F"]
const MENU_CONFIRM_KEYCODES := [KEY_Q, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const MENU_CANCEL_KEYCODES := [KEY_ESCAPE, KEY_E]
const MENU_MOVE_PREV_KEYCODES := [KEY_UP, KEY_W]
const MENU_MOVE_NEXT_KEYCODES := [KEY_DOWN, KEY_S]
const MENU_PAGE_PREV_KEYCODES := [KEY_PAGEUP, KEY_LEFT, KEY_A, KEY_R]
const MENU_PAGE_NEXT_KEYCODES := [KEY_PAGEDOWN, KEY_RIGHT, KEY_D, KEY_F]
const GLOBAL_BINDINGS := [
	# Descriptions state what the RUNTIME does (PlayerShell is the authority);
	# aspirational bindings are labeled reserved, not advertised as working.
	{"key": "Tab", "label": "Cycle Hat", "description": "Advance the archetype frame (4-0)"},
	{"key": "-", "label": "Time Down", "description": "Reserved — sim-speed wiring pending (PlayerShell stub)"},
	{"key": "=", "label": "Time Up", "description": "Reserved — sim-speed wiring pending (PlayerShell stub)"},
	{"key": "Shift+-", "label": "Resolution Down", "description": "Use finer substeps with a 10x smaller dt"},
	{"key": "Shift+=", "label": "Resolution Up", "description": "Use coarser substeps with a 10x larger dt"},
	{"key": "Shift+Q", "label": "Mass Harvest", "description": "Harvest (extract) all bound terminals in the checked set"},
	{"key": "F12", "label": "Postcard", "description": "Capture the view with the physics watermark + sidecar certificate (user://postcards/)"},
]

const OVERLAY_SHORTCUTS := {
	"escape_menu": [
		{"key": ",", "label": "Volume Down", "description": "Lower music volume while the system menu is open"},
		{"key": ".", "label": "Volume Up", "description": "Raise music volume while the system menu is open"},
		{"key": "/", "label": "Mute", "description": "Toggle music mute while the system menu is open"},
	],
	"balance_workbench": [
		{"key": "T", "label": "Quest Ratio +", "description": "Raise quest reward base ratio in advanced mode"},
		{"key": "Y", "label": "Quest Ratio -", "description": "Lower quest reward base ratio in advanced mode"},
	],
}


static func get_biome_keys() -> Array[String]:
	var keys: Array[String] = []
	for key_label in BIOME_KEYS:
		keys.append(key_label)
	return keys


static func get_plot_keys() -> Array[String]:
	var keys: Array[String] = []
	for key_label in HOMEROW_KEYS:
		keys.append(key_label)
	return keys


static func get_subspace_keys() -> Array[String]:
	var keys: Array[String] = []
	for key_label in SUBSPACE_KEYS:
		keys.append(key_label)
	return keys


static func get_quest_slot_keys() -> Array[String]:
	var keys: Array[String] = []
	for key_label in QUEST_SLOT_KEYS:
		keys.append(key_label)
	return keys


static func get_biome_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key_label in BIOME_KEYS:
		entries.append({
			"key": key_label,
			"slot": int(BIOME_ROW[key_label]),
			"label": "Biome Slot %d" % (int(BIOME_ROW[key_label]) + 1),
			"description": "Switch active biome spindle slot"
		})
	return entries


static func get_plot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key_label in HOMEROW_KEYS:
		entries.append({
			"key": key_label,
			"slot": int(HOMEROW[key_label]),
			"label": "Plot %d" % (int(HOMEROW[key_label]) + 1),
			"description": "Highlight plot and toggle its batch checkbox on repeat press"
		})
	return entries


static func get_subspace_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key_label in SUBSPACE_KEYS:
		entries.append({
			"key": key_label,
			"slot": int(SUBSPACE_ROW[key_label]),
			"label": "Subspace %d" % (int(SUBSPACE_ROW[key_label]) + 1),
			"description": "Reserved for future subspace navigation"
		})
	return entries


static func get_quest_slot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for idx in range(QUEST_SLOT_KEYS.size()):
		entries.append({
			"key": QUEST_SLOT_KEYS[idx],
			"slot": idx,
			"label": "Quest Slot %d" % (idx + 1),
			"description": "Direct-select the quest slot in the 2x2 oracle grid"
		})
	return entries


static func get_keycode_for_label(key_label: String) -> int:
	return int(KEY_LABEL_TO_KEYCODE.get(key_label, 0))


static func get_action_keycode(action_key: String) -> int:
	return int(ACTION_KEYCODES.get(action_key, 0))


static func is_menu_confirm_key(keycode: int) -> bool:
	return keycode in MENU_CONFIRM_KEYCODES


static func is_menu_cancel_key(keycode: int) -> bool:
	return keycode in MENU_CANCEL_KEYCODES


static func is_menu_move_prev_key(keycode: int) -> bool:
	return keycode in MENU_MOVE_PREV_KEYCODES


static func is_menu_move_next_key(keycode: int) -> bool:
	return keycode in MENU_MOVE_NEXT_KEYCODES


static func is_menu_page_prev_key(keycode: int) -> bool:
	return keycode in MENU_PAGE_PREV_KEYCODES


static func is_menu_page_next_key(keycode: int) -> bool:
	return keycode in MENU_PAGE_NEXT_KEYCODES


static func get_quest_slot_index_for_keycode(keycode: int) -> int:
	for idx in range(QUEST_SLOT_KEYS.size()):
		if get_keycode_for_label(QUEST_SLOT_KEYS[idx]) == keycode:
			return idx
	return -1


static func ensure_inputmap_actions() -> void:
	_ensure_key_actions(BIOME_ACTIONS, BIOME_KEYS)
	_ensure_key_actions(HOMEROW_ACTIONS, HOMEROW_KEYS)
	_ensure_key_actions(SUBSPACE_ACTIONS, SUBSPACE_KEYS)


static func _ensure_key_actions(action_names: Array, key_labels: Array) -> void:
	for idx in range(min(action_names.size(), key_labels.size())):
		var action_name = str(action_names[idx])
		var key_label = str(key_labels[idx])
		var keycode = get_keycode_for_label(key_label)
		if action_name == "" or keycode == 0:
			continue

		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		if _action_has_keycode(action_name, keycode):
			continue

		var event := InputEventKey.new()
		event.keycode = keycode as Key
		InputMap.action_add_event(action_name, event)


static func _action_has_keycode(action_name: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false


static func get_global_bindings() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in GLOBAL_BINDINGS:
		entries.append(entry.duplicate(true))
	return entries


static func get_overlay_shortcuts(overlay_name: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in OVERLAY_SHORTCUTS.get(overlay_name, []):
		entries.append(entry.duplicate(true))
	return entries


static func overlay_has_shortcut(overlay_name: String, keycode: int) -> bool:
	for entry in OVERLAY_SHORTCUTS.get(overlay_name, []):
		if get_keycode_for_label(str(entry.get("key", ""))) == keycode:
			return true
	return false
