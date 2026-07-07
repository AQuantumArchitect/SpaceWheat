extends RefCounted

## UIProgression — single authority for progressive UI disclosure.
##
## The day-one interface drowned new players (7 hats × modes + 9 menu surfaces
## before their first key press). This maps STORY PROGRESS → which chrome is
## visible. Derived entirely from farm.story_flags_fired (already persisted):
## no new save state, old saves see everything they've already reached.
##
## VISUAL-ONLY (phase 1): hidden buttons are not rendered, but their KEYS STILL
## WORK — no mechanic is gated (anti-gating law), drives/tests are unaffected,
## and players who know the grammar lose nothing.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

## Hat → the story flag that surfaces it ("" = always visible).
## Starter kit is Ace + Icon + Druid — exactly what Act-0 teaches.
## Spark is the open-regime (Lindblad) verb: useless inside the enclave, so it
## surfaces when the wet country opens.
const HAT_UNLOCK_FLAGS: Dictionary = {
	ToolConfig.FRAME_ACE: "",
	ToolConfig.FRAME_ICON: "",
	ToolConfig.FRAME_DRUID: "",
	ToolConfig.FRAME_OPERATOR: "forest_listener",
	ToolConfig.FRAME_MERCHANT: "village_stirs",
	ToolConfig.FRAME_CAPTAIN: "island_lives",
	ToolConfig.FRAME_SPARK: "edge_of_the_enclave",
}

## Menu id (MenuRegistry) → surfacing flag ("" = always).
const MENU_UNLOCK_FLAGS: Dictionary = {
	"play": "",
	"system": "",
	"controls": "",
	"quests": "",
	"atlas": "first_breath",
	"biome_detail": "forest_evolving",
	"inspector": "village_stirs",
	"map_meta": "village_stirs",
	"neighborhood_graph": "village_stirs",
}


static func _flags() -> Dictionary:
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	var farm = gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null
	if farm != null and is_instance_valid(farm) and "story_flags_fired" in farm:
		return farm.story_flags_fired
	# No farm (visual tests, early boot): show everything — fail open.
	return {}


static func _unlocked(flag: String, flags: Dictionary) -> bool:
	return flag == "" or flags.has(flag)


static func is_hat_visible(frame_name: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	return _unlocked(str(HAT_UNLOCK_FLAGS.get(frame_name, "")), flags)


static func is_menu_visible(menu_id: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	return _unlocked(str(MENU_UNLOCK_FLAGS.get(menu_id, "")), flags)


static func _no_farm() -> bool:
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	return gsm == null or not gsm.has_method("get_active_farm") or gsm.get_active_farm() == null
