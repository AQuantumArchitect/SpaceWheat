class_name SaveStore
extends RefCounted

## SaveStore - persistence layer for GameState resources.
## Centralizes disk IO + scenario/template loading (no Farm/UI dependencies).


const SAVE_DIR = "user://saves/"
const NUM_SAVE_SLOTS = 3
const SCENARIO_DIR = "res://Scenarios/"
const DEFAULT_SCENARIO_ID = "new_game_easy"
const SAVE_ARTIFACT_INDEX_FILE = "emoji_save_index.json"
const EMOJI_SIDECAR_SUFFIX = ".json"


static func ensure_save_dir() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


static func get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_" + str(slot) + ".tres"


static func normalize_boot_request(request: Dictionary) -> Dictionary:
	# Canonical shape for boot/restart requests across AppRoot, GameRoot,
	# SessionLoader, and the rest of the boot pipeline.
	var sid := str(request.get("scenario_id", DEFAULT_SCENARIO_ID))
	if sid == "":
		sid = DEFAULT_SCENARIO_ID
	return {
		"slot": int(request.get("slot", -1)),
		"scenario_id": sid,
		"headless": bool(request.get("headless", DisplayServer.get_name() == "headless")),
	}


static func get_save_artifact_index_path() -> String:
	return SAVE_DIR + SAVE_ARTIFACT_INDEX_FILE


static func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


static func save_state(state: GameState, slot: int) -> int:
	# Atomic save: write to .tmp then rename, so interrupted saves never corrupt.

	# Returns OK or error code from ResourceSaver.save().
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return ERR_INVALID_PARAMETER
	if not state:
		push_error("No game state to save!")
		return ERR_INVALID_DATA
	ensure_save_dir()
	var path = get_save_path(slot)
	var result = _atomic_save(state, path)
	if result == OK:
		_write_save_artifacts(state, slot, path)
	return result


static func save_state_to_path(state: GameState, path: String) -> int:
	# Atomic save to an explicit path (returns OK or error code).
	if not state:
		push_error("No game state to save!")
		return ERR_INVALID_DATA
	ensure_save_dir()
	_ensure_parent_dir(path)
	return _atomic_save(state, path)


static func _atomic_save(state: GameState, path: String) -> int:
	# Write to a .tmp file, then rename atomically.

	# If the process dies mid-write, the .tmp is garbage but the previous
	# save at `path` is untouched. The rename is atomic on all filesystems.
	# A save either succeeds completely or doesn't happen at all.
	# Keep a recognized resource extension in the temp path (`*.tmp.tres`),
	# otherwise ResourceSaver rejects unknown suffixes like `*.tres.tmp`.
	var ext = path.get_extension()
	var tmp_path = path + ".tmp"
	if ext != "":
		var stem = path.substr(0, path.length() - ext.length() - 1)
		tmp_path = "%s.tmp.%s" % [stem, ext]
	var result = ResourceSaver.save(state, tmp_path)
	var dir = DirAccess.open(tmp_path.get_base_dir())
	if result != OK:
		push_error("Atomic save write failed: %d (%s) path=%s" % [result, error_string(result), tmp_path])
		# Clean up failed temp file
		if dir:
			dir.remove(tmp_path.get_file())
		return result
	# Atomic rename: .tmp → final path
	dir = DirAccess.open(tmp_path.get_base_dir())
	if dir:
		# Remove old file first (rename won't overwrite on all platforms)
		if dir.file_exists(path.get_file()):
			dir.remove(path.get_file())
		var rename_result = dir.rename(tmp_path.get_file(), path.get_file())
		if rename_result != OK:
			push_error("Atomic save rename failed: %d (tmp=%s → %s)" % [rename_result, tmp_path, path])
			return rename_result
	return OK


static func load_state(slot: int) -> GameState:
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return null
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var state = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameState
	return state


static func load_state_by_path(save_path: String) -> GameState:
	# Load a save directly via full path or save filename under user://saves.
	var path = save_path.strip_edges()
	if path == "":
		return null
	if not path.begins_with("user://") and not path.begins_with("res://") and not _is_absolute_path(path):
		path = SAVE_DIR + save_path
	if not FileAccess.file_exists(path):
		return null
	var state = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameState
	if state:
		print("[SAVE][DEBUG] load_state_by_path known_icons:", state.known_icons.size())
	if state and (not state.known_icons or state.known_icons.size() <= 1):
		var recovered_known_icons = _extract_known_icons_from_resource_text(path)
		if not recovered_known_icons.is_empty():
			print("[SAVE][DEBUG] recovered known_icons from text:", recovered_known_icons.size())
			state.known_icons = recovered_known_icons
	return state


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


static func _extract_known_icons_from_resource_text(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	var text = file.get_as_text()
	file.close()

	var marker = "known_icons = "
	var start = text.find(marker)
	if start < 0:
		return []
	start = text.find("[", start)
	if start < 0:
		return []

	var depth = 0
	var end = -1
	for idx in range(start, text.length()):
		var ch = text.substr(idx, 1)
		if ch == "[":
			depth += 1
		elif ch == "]":
			depth -= 1
			if depth == 0:
				end = idx + 1
				break

	if end <= start:
		return []

	var block = text.substr(start, end - start)
	var parsed = JSON.parse_string(block)
	if parsed is Array:
		return parsed
	return []


static func get_save_info(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {"exists": false, "slot": slot}
	var state = load_state(slot)
	if not state:
		return {"exists": false, "slot": slot}
	var money = state.all_emoji_credits.get("💰", 0) if state.all_emoji_credits else 0
	var artifact_meta = _get_slot_artifact_meta(slot)
	return {
		"exists": true,
		"slot": slot,
		"display_name": state.get_save_display_name(),
		"scenario": state.scenario_id,
		"credits": money,
		"playtime": state.game_time,
		"grid_size": "%dx%d" % [state.grid_width, state.grid_height],
		"save_file": artifact_meta.get("save_file", artifact_meta.get("alias_file", "")),
		"marker_emoji": artifact_meta.get("marker_emoji", artifact_meta.get("emoji", ""))
	}


static func load_scenario(scenario_id: String) -> GameState:
	var id := scenario_id.strip_edges()
	if id == "":
		id = DEFAULT_SCENARIO_ID
	var scenario_path = SCENARIO_DIR + id + ".tres"
	if ResourceLoader.exists(scenario_path):
		return ResourceLoader.load(scenario_path).duplicate()
	push_error("Scenario not found: %s" % scenario_path)
	return null


static func _write_save_artifacts(state: GameState, slot: int, canonical_path: String) -> void:
	var marker_emoji = _choose_marker_emoji(state, slot)
	if marker_emoji == "":
		return

	var stamp = str(int(Time.get_unix_time_from_system()))
	var save_file = "save_slot_%d_%s_%s.tres" % [slot, marker_emoji, stamp]
	var save_path = SAVE_DIR + save_file
	var save_result = ResourceSaver.save(state, save_path)
	if save_result != OK:
		push_warning("SaveStore: failed to write save artifact '%s'" % save_path)
		return
	var sidecar_file = save_file + EMOJI_SIDECAR_SUFFIX
	var sidecar_path = SAVE_DIR + sidecar_file
	_write_save_sidecar(state, slot, marker_emoji, save_file, save_path, canonical_path, sidecar_path)

	var index = _read_save_artifact_index()
	var slots = index.get("slots", {})
	if not (slots is Dictionary):
		slots = {}
	slots[str(slot)] = {
		"slot": slot,
		"marker_emoji": marker_emoji,
		"save_file": save_file,
		"save_path": save_path,
		"sidecar_file": sidecar_file,
		"sidecar_path": sidecar_path,
		"canonical_path": canonical_path,
		"timestamp": int(Time.get_unix_time_from_system())
	}
	index["version"] = 1
	index["slots"] = slots
	index["updated_at"] = int(Time.get_unix_time_from_system())
	_write_save_artifact_index(index)


static func _choose_marker_emoji(state: GameState, slot: int) -> String:
	var candidates: Array[String] = []

	if state:
		for emoji in GameState.derive_known_emojis_from_icons(state.known_icons):
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
		var ml := Engine.get_main_loop()
		var registry = ml.root.get_node_or_null("/root/IconRegistry") if ml and ml.root else null
		if registry == null:
			registry = load("res://Core/Factions/IconRegistry.gd").new()
		for emoji in registry.build_emoji_universe():
			var s = str(emoji)
			if s != "" and s not in candidates:
				candidates.append(s)

	if candidates.is_empty():
		return ""

	candidates.sort()
	var slot_seed = int(Time.get_unix_time_from_system()) + (slot * 17)
	var idx = posmod(slot_seed, candidates.size())
	return candidates[idx]


static func _read_save_artifact_index() -> Dictionary:
	var path = get_save_artifact_index_path()
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


static func _write_save_artifact_index(index: Dictionary) -> void:
	var file = FileAccess.open(get_save_artifact_index_path(), FileAccess.WRITE)
	if not file:
		push_warning("SaveStore: failed to open save artifact index for writing")
		return
	file.store_string(JSON.stringify(index, "\t"))


static func _get_slot_artifact_meta(slot: int) -> Dictionary:
	var index = _read_save_artifact_index()
	var slots = index.get("slots", {})
	if slots is Dictionary and slots.has(str(slot)):
		var slot_meta = slots[str(slot)]
		if slot_meta is Dictionary:
			if not slot_meta.has("save_file") and slot_meta.has("alias_file"):
				slot_meta["save_file"] = slot_meta.get("alias_file", "")
			if not slot_meta.has("save_path") and slot_meta.has("alias_path"):
				slot_meta["save_path"] = slot_meta.get("alias_path", "")
			if not slot_meta.has("marker_emoji") and slot_meta.has("emoji"):
				slot_meta["marker_emoji"] = slot_meta.get("emoji", "")
			return slot_meta
	return {}


static func _write_save_sidecar(
	state: GameState,
	slot: int,
	marker_emoji: String,
	save_file: String,
	save_path: String,
	canonical_path: String,
	sidecar_path: String
) -> void:
	var sidecar_icon_map = state.atom_map_snapshot.duplicate(true)
	var sidecar_icon_source = state.atom_map_snapshot_source
	var sidecar_icon_time = int(state.atom_map_snapshot_time)
	if sidecar_icon_map.is_empty():
		var by_emoji = {}
		for e in GameState.derive_known_emojis_from_icons(state.known_icons):
			var s = str(e)
			if s != "":
				by_emoji[s] = 1.0
		if not by_emoji.is_empty():
			sidecar_icon_map = {"by_emoji": by_emoji, "total": float(by_emoji.size()), "steps": 1}
			sidecar_icon_source = "derived_from_icons"
			sidecar_icon_time = int(Time.get_unix_time_from_system())

	var payload = {
		"version": 1,
		"slot": slot,
		"marker_emoji": marker_emoji,
		"save_file": save_file,
		"save_path": save_path,
		"canonical_path": canonical_path,
		"scenario_id": state.scenario_id,
		"save_timestamp": int(state.save_timestamp),
		"known_icons": state.known_icons.duplicate(true),
		"balance_profile_id": state.balance_profile_id,
		"balance_workbench_config": state.balance_workbench_config,
		"farm_variable_graph_path": state.farm_variable_graph_path,
		"farm_variable_graph_jsonl": state.farm_variable_graph_jsonl,
		"economy_variables": state.economy_variables,
		"atom_map_snapshot": sidecar_icon_map,
		"atom_map_snapshot_source": sidecar_icon_source,
		"atom_map_snapshot_time": sidecar_icon_time,
		"policy_state": state.policy_state.duplicate(true) if ("policy_state" in state and state.policy_state is Dictionary) else {},
		"policy_graph_path": state.policy_graph_path,
		"policy_graph_jsonl": state.policy_graph_jsonl,
	}
	# Include fully-built biome icon physics so Python lab reads exactly what the game ran.
	var biome_icon_snapshots = {}
	for biome_name in state.biome_states:
		var bs = state.biome_states[biome_name]
		if bs is Dictionary and bs.has("icons"):
			biome_icon_snapshots[biome_name] = {
				"icons":         bs["icons"],
				"register_axes": bs.get("register_axes", []),
			}
	if not biome_icon_snapshots.is_empty():
		payload["biome_icon_snapshots"] = biome_icon_snapshots

	var file = FileAccess.open(sidecar_path, FileAccess.WRITE)
	if not file:
		push_warning("SaveStore: failed to write emoji sidecar '%s'" % sidecar_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
