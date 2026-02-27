class_name SaveStore
extends RefCounted

## SaveStore - persistence helper for GameState resources.
## Centralizes disk IO + scenario/template loading (no Farm/UI dependencies).

const GameState = preload("res://Core/GameState/GameState.gd")
const EmojiRegistry = preload("res://Core/Biomes/EmojiRegistry.gd")

const SAVE_DIR = "user://saves/"
const NUM_SAVE_SLOTS = 3
const SCENARIO_DIR = "res://Scenarios/"
const NEW_GAME_TEMPLATE = "new_game_easy.tres"
const EMOJI_INDEX_FILE = "emoji_save_index.json"
const EMOJI_SIDECAR_SUFFIX = ".json"


static func ensure_save_dir() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


static func get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_" + str(slot) + ".tres"


static func get_emoji_index_path() -> String:
	return SAVE_DIR + EMOJI_INDEX_FILE


static func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


static func save_state(state: GameState, slot: int) -> int:
	"""Returns OK or error code from ResourceSaver.save()."""
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return ERR_INVALID_PARAMETER
	if not state:
		push_error("No game state to save!")
		return ERR_INVALID_DATA
	ensure_save_dir()
	var path = get_save_path(slot)
	var result = ResourceSaver.save(state, path)
	if result == OK:
		_write_emoji_alias(state, slot, path)
	return result


static func save_state_to_path(state: GameState, path: String) -> int:
	"""Save GameState to an explicit path (returns OK or error code)."""
	if not state:
		push_error("No game state to save!")
		return ERR_INVALID_DATA
	ensure_save_dir()
	_ensure_parent_dir(path)
	return ResourceSaver.save(state, path)


static func load_state(slot: int) -> GameState:
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return null
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var state = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameState
	return state


static func load_state_by_emoji_alias(alias_filename: String) -> GameState:
	"""Load a save directly via emoji alias file name or full user:// path."""
	var path = alias_filename.strip_edges()
	if path == "":
		return null
	if not path.begins_with("user://") and not path.begins_with("res://") and not _is_absolute_path(path):
		path = SAVE_DIR + alias_filename
	if not FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameState


static func _ensure_parent_dir(path: String) -> void:
	var global_path = ProjectSettings.globalize_path(path)
	var parent = global_path.get_base_dir()
	if parent == "":
		return
	DirAccess.make_dir_recursive_absolute(parent)


static func _is_absolute_path(path: String) -> bool:
	if path.begins_with("/"):
		return true
	if path.length() >= 3 and path[1] == ":" and (path[2] == "/" or path[2] == "\\"):
		return true
	return false


static func get_save_info(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {"exists": false, "slot": slot}
	var state = load_state(slot)
	if not state:
		return {"exists": false, "slot": slot}
	var money = state.all_emoji_credits.get("💰", 0) if state.all_emoji_credits else 0
	var alias_meta = _get_slot_alias_meta(slot)
	return {
		"exists": true,
		"slot": slot,
		"display_name": state.get_save_display_name(),
		"scenario": state.scenario_id,
		"credits": money,
		"playtime": state.game_time,
		"grid_size": "%dx%d" % [state.grid_width, state.grid_height],
		"emoji_alias": alias_meta.get("alias_file", ""),
		"emoji": alias_meta.get("emoji", "")
	}


static func load_scenario(scenario_id: String) -> GameState:
	var scenario_path = SCENARIO_DIR + scenario_id + ".tres"
	if ResourceLoader.exists(scenario_path):
		return ResourceLoader.load(scenario_path).duplicate()
	var state = GameState.new()
	state.scenario_id = scenario_id
	return state


static func load_new_game_template() -> GameState:
	# Prefer user override, then project template, then default scenario.
	var user_path = SAVE_DIR + NEW_GAME_TEMPLATE
	if FileAccess.file_exists(user_path):
		var user_state = ResourceLoader.load(user_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if user_state:
			return user_state
	var project_path = SCENARIO_DIR + NEW_GAME_TEMPLATE
	if ResourceLoader.exists(project_path):
		var project_state = ResourceLoader.load(project_path).duplicate()
		if project_state:
			return project_state
	return load_scenario("default")


static func _write_emoji_alias(state: GameState, slot: int, canonical_path: String) -> void:
	var emoji = _choose_alias_emoji(state, slot)
	if emoji == "":
		return

	var stamp = str(int(Time.get_unix_time_from_system()))
	var alias_file = "save_slot_%d_%s_%s.tres" % [slot, emoji, stamp]
	var alias_path = SAVE_DIR + alias_file
	var alias_save_result = ResourceSaver.save(state, alias_path)
	if alias_save_result != OK:
		push_warning("SaveStore: failed to write emoji alias save '%s'" % alias_path)
		return
	var sidecar_file = alias_file + EMOJI_SIDECAR_SUFFIX
	var sidecar_path = SAVE_DIR + sidecar_file
	_write_emoji_sidecar(state, slot, emoji, alias_file, alias_path, canonical_path, sidecar_path)

	var index = _read_emoji_index()
	var slots = index.get("slots", {})
	if not (slots is Dictionary):
		slots = {}
	slots[str(slot)] = {
		"slot": slot,
		"emoji": emoji,
		"alias_file": alias_file,
		"alias_path": alias_path,
		"sidecar_file": sidecar_file,
		"sidecar_path": sidecar_path,
		"canonical_path": canonical_path,
		"timestamp": int(Time.get_unix_time_from_system())
	}
	index["version"] = 1
	index["slots"] = slots
	index["updated_at"] = int(Time.get_unix_time_from_system())
	_write_emoji_index(index)


static func _choose_alias_emoji(state: GameState, slot: int) -> String:
	var candidates: Array[String] = []

	if state and state.has_method("get_known_emojis"):
		for emoji in state.get_known_emojis():
			var s = str(emoji)
			if s != "" and s not in candidates:
				candidates.append(s)

	if candidates.is_empty() and state and state.all_emoji_credits:
		for emoji in state.all_emoji_credits.keys():
			var amount = float(state.all_emoji_credits[emoji])
			var s = str(emoji)
			if amount > 0.0 and s != "" and s not in candidates:
				candidates.append(s)

	if candidates.is_empty():
		var registry = EmojiRegistry.new()
		for emoji in registry.get_all_emojis():
			var s = str(emoji)
			if s != "" and s not in candidates:
				candidates.append(s)

	if candidates.is_empty():
		return ""

	candidates.sort()
	var seed = int(Time.get_unix_time_from_system()) + (slot * 17)
	var idx = posmod(seed, candidates.size())
	return candidates[idx]


static func _read_emoji_index() -> Dictionary:
	var path = get_emoji_index_path()
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


static func _write_emoji_index(index: Dictionary) -> void:
	var file = FileAccess.open(get_emoji_index_path(), FileAccess.WRITE)
	if not file:
		push_warning("SaveStore: failed to open emoji index for writing")
		return
	file.store_string(JSON.stringify(index, "\t"))


static func _get_slot_alias_meta(slot: int) -> Dictionary:
	var index = _read_emoji_index()
	var slots = index.get("slots", {})
	if slots is Dictionary and slots.has(str(slot)):
		var slot_meta = slots[str(slot)]
		if slot_meta is Dictionary:
			return slot_meta
	return {}


static func _write_emoji_sidecar(
	state: GameState,
	slot: int,
	emoji: String,
	alias_file: String,
	alias_path: String,
	canonical_path: String,
	sidecar_path: String
) -> void:
	var sidecar_icon_map = state.icon_map_snapshot.duplicate(true)
	var sidecar_icon_source = state.icon_map_snapshot_source
	var sidecar_icon_time = int(state.icon_map_snapshot_time)
	if sidecar_icon_map.is_empty():
		var by_emoji = {}
		for e in state.get_known_emojis():
			var s = str(e)
			if s != "":
				by_emoji[s] = 1.0
		if not by_emoji.is_empty():
			sidecar_icon_map = {"by_emoji": by_emoji, "total": float(by_emoji.size()), "steps": 1}
			sidecar_icon_source = "derived_from_pairs"
			sidecar_icon_time = int(Time.get_unix_time_from_system())

	var payload = {
		"version": 1,
		"slot": slot,
		"emoji": emoji,
		"alias_file": alias_file,
		"alias_path": alias_path,
		"canonical_path": canonical_path,
		"scenario_id": state.scenario_id,
		"save_timestamp": int(state.save_timestamp),
		"known_pairs": state.known_pairs.duplicate(true),
		"known_emojis": state.get_known_emojis(),
		"balance_profile_id": state.balance_profile_id,
		"balance_overrides": state.balance_overrides,
		"balance_workbench_config": state.balance_workbench_config,
		"economy_variables": state.economy_variables,
		"icon_map_snapshot": sidecar_icon_map,
		"icon_map_snapshot_source": sidecar_icon_source,
		"icon_map_snapshot_time": sidecar_icon_time
	}
	var file = FileAccess.open(sidecar_path, FileAccess.WRITE)
	if not file:
		push_warning("SaveStore: failed to write emoji sidecar '%s'" % sidecar_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
