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
	# Digit row: sub-mode (1/2/3) + archetype hats (4-0).
	"0": KEY_0, "1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4,
	"5": KEY_5, "6": KEY_6, "7": KEY_7, "8": KEY_8, "9": KEY_9,
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

# ── Canonical ring keycodes (single source for overlays + Surface) ───────────
# The plot/item ring is G H J K L ; with an optional 7th slot ' (apostrophe) used
# by ControlsOverlay's wider tabs. The biome ring is T Y U I O P. Overlays used to
# each re-hardcode an ITEM_BY_KEYCODE map; they now read these.
const PLOT_ROW_KEYCODES: Array = [KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE]
const BIOME_ROW_KEYCODES: Array = [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]

## Index of a plot-ring keycode within the first `slots` positions, or -1.
## `slots` keeps callers honest about their item count (6 = G-; , 7 = + apostrophe),
## so a 6-item menu never treats ' as a phantom 7th selector.
static func plot_index_for_keycode(keycode: int, slots: int = 6) -> int:
	var i: int = PLOT_ROW_KEYCODES.find(keycode)
	return i if (i >= 0 and i < slots) else -1

## The plot-ring keycodes a caller responds to, sliced to its item count.
static func plot_keycodes(slots: int = 6) -> Array:
	return PLOT_ROW_KEYCODES.slice(0, slots)

## Index of a biome-ring keycode (T Y U I O P), or -1.
static func biome_index_for_keycode(keycode: int) -> int:
	return BIOME_ROW_KEYCODES.find(keycode)
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
	{"key": "Shift+Q", "label": "Mass Gather", "description": "Gather every bound terminal in the checked set"},
	{"key": "]", "label": "Descend", "description": "Enter the focused register's icon world (costs; needs the incorporation gate)"},
	{"key": "Shift+]", "label": "Ascend", "description": "Surface one fractal level back toward the world above (free)"},
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


## Single source for keycode → label decoding. Built once from KEY_LABEL_TO_KEYCODE
## (digit/punct/row keys) + ACTION_KEYCODES (Q/E/R/F). Replaces the duplicate
## QuantumInstrumentInput._keycode_to_string match table.
static var _keycode_to_label_cache: Dictionary = {}

static func get_label_for_keycode(keycode: int) -> String:
	if _keycode_to_label_cache.is_empty():
		for label in KEY_LABEL_TO_KEYCODE:
			_keycode_to_label_cache[int(KEY_LABEL_TO_KEYCODE[label])] = label
		for label in ACTION_KEYCODES:
			_keycode_to_label_cache[int(ACTION_KEYCODES[label])] = label
	return str(_keycode_to_label_cache.get(keycode, ""))


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
