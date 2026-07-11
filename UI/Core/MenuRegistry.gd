class_name MenuRegistry
extends RefCounted

## MenuRegistry - Shared source of truth for top-level menu metadata.

const TOP_LEVEL_MENUS := [
	{
		"id": "play",
		"overlay_name": "play",
		"keycode": -1,
		"key_label": "",
		"display_name": "Farm",
		"description": "Return to gameplay",
		"menu_group": "play",
		"button_emoji": "🌾",
		"touch_button": false,
	},
	{
		"id": "controls",
		"overlay_name": "controls",
		"keycode": KEY_X,
		"key_label": "X",
		"display_name": "Playthrough",
		"description": "Self, story, balance, guide — this run",
		"menu_group": "shell",
		"button_emoji": "⌨",
		"touch_button": false,
	},
	{
		"id": "system",
		"overlay_name": "escape_menu",
		"keycode": KEY_Z,
		"key_label": "Z",
		"display_name": "System",
		"description": "Now, save, scenarios, verbs, dev",
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
		"id": "atlas",
		"overlay_name": "atlas",
		"keycode": KEY_V,
		"key_label": "V",
		"display_name": "Knowledge Atlas",
		"description": "atoms · icons · signature · affinity",
		"menu_group": "game",
		"button_emoji": "🧪",
		"touch_button": true,
	},
	{
		"id": "biome_detail",
		"overlay_name": "biome_detail",
		"keycode": KEY_B,
		"key_label": "B",
		"display_name": "Biome Inspector",
		"description": "Whole-biome view",
		"menu_group": "game",
		"button_emoji": "🌍",
		"touch_button": true,
	},
	{
		"id": "inspector",
		"overlay_name": "inspector",
		"keycode": KEY_N,
		"key_label": "N",
		"display_name": "Biome Network",
		"description": "Network of biomes",
		"menu_group": "game",
		"button_emoji": "🕸",
		"touch_button": true,
	},
	{
		"id": "map_meta",
		"overlay_name": "map_meta",
		"keycode": KEY_M,
		"key_label": "M",
		"display_name": "Biome Map",
		"description": "Biome x neighborhood relationships",
		"menu_group": "game",
		"button_emoji": "🗺",
		"touch_button": true,
	},
	{
		# ZXCVBNM is full; the neighborhood graph takes the adjacent "[" key.
		"id": "neighborhood_graph",
		"overlay_name": "neighborhood_graph",
		"keycode": KEY_BRACKETLEFT,
		"key_label": "[",
		"display_name": "Neighborhood Graph",
		"description": "Cluster graph of the active biome's reservoir",
		"menu_group": "game",
		"button_emoji": "🕸",
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
