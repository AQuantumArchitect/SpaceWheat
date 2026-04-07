class_name MenuRegistry
extends RefCounted

## MenuRegistry - Shared source of truth for top-level menu metadata.

const TOP_LEVEL_MENUS := [
	{
		"id": "controls",
		"overlay_name": "controls",
		"keycode": KEY_Z,
		"key_label": "Z",
		"display_name": "Keyboard Help",
		"description": "This overlay",
		"menu_group": "shell",
		"button_emoji": "⌨",
		"touch_button": false,
	},
	{
		"id": "system",
		"overlay_name": "escape_menu",
		"keycode": KEY_X,
		"key_label": "X",
		"display_name": "System Menu",
		"description": "Quit, save, load, restart",
		"menu_group": "shell",
		"button_emoji": "⏸",
		"touch_button": false,
	},
	{
		"id": "quests",
		"overlay_name": "quests",
		"keycode": KEY_C,
		"key_label": "C",
		"display_name": "Quest Board",
		"description": "View and manage quests",
		"menu_group": "game",
		"button_emoji": "📋",
		"touch_button": true,
	},
	{
		"id": "semantic_map",
		"overlay_name": "semantic_map",
		"keycode": KEY_V,
		"key_label": "V",
		"display_name": "Vocabulary",
		"description": "Semantic map and known pairs",
		"menu_group": "game",
		"button_emoji": "📖",
		"touch_button": true,
	},
	{
		"id": "biome_detail",
		"overlay_name": "biome_detail",
		"keycode": KEY_B,
		"key_label": "B",
		"display_name": "Biome Inspector",
		"description": "Detailed biome info",
		"menu_group": "game",
		"button_emoji": "🌍",
		"touch_button": true,
	},
	{
		"id": "inspector",
		"overlay_name": "inspector",
		"keycode": KEY_N,
		"key_label": "N",
		"display_name": "Inspector",
		"description": "Density matrix and register view",
		"menu_group": "game",
		"button_emoji": "🔬",
		"touch_button": true,
	},
	{
		"id": "balance_workbench",
		"overlay_name": "balance_workbench",
		"keycode": KEY_M,
		"key_label": "M",
		"display_name": "Balance Workbench",
		"description": "Timescale and balance tuning",
		"menu_group": "shell",
		"button_emoji": "⚖️",
		"touch_button": true,
	},
]

const DEBUG_MENUS := [
	{
		"id": "logger",
		"overlay_name": "logger",
		"keycode": -1,
		"key_label": "",
		"display_name": "Logger Config",
		"description": "Debug overlay, intentionally unbound",
		"menu_group": "debug",
		"button_emoji": "🪵",
		"touch_button": false,
	},
]


static func get_top_level_menus() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in TOP_LEVEL_MENUS:
		entries.append(entry)
	return entries


static func get_menu_for_keycode(keycode: int) -> Dictionary:
	for entry in TOP_LEVEL_MENUS:
		if int(entry.get("keycode", -1)) == keycode:
			return entry
	return {}


static func get_touch_button_menus() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in TOP_LEVEL_MENUS:
		if bool(entry.get("touch_button", false)):
			result.append(entry)
	return result


static func get_debug_menus() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in DEBUG_MENUS:
		entries.append(entry)
	return entries
