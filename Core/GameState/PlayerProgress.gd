class_name PlayerProgress
extends Node

## PlayerProgress — owns persistent player state for GameStateManager.
##
## Held as a child Node on the GameStateManager autoload. Custodian of:
##   - discover_icon flow + faction-unlock detection
##   - milk autosave (first 🍼 discovery autosaves to a dedicated slot)
##
## Signals emoji_discovered / icon_discovered / factions_unlocked live on GSM
## (forwarded) so existing listeners don't break.


const MILK_EMOJI := "🍼"
const MILK_AUTOSAVE_SLOT := 2

var _gsm: Node = null
var _verbose = null


func _init(gsm: Node = null, verbose = null) -> void:
	_gsm = gsm
	_verbose = verbose
	name = "PlayerProgress"


func discover_icon(north: String, south: String) -> bool:
	# Player learns a icon (plantable qubit axis). Forwards to the active
	# Farm (canonical icon owner) and emits unlock signals via GSM.
	# Returns true iff the pair was newly added to the signature.
	var old_emojis = get_signature_emojis()

	var farm = _gsm.get_active_farm()
	var added = false
	if farm and farm.has_method("discover_icon"):
		added = farm.discover_icon(north, south)
	elif _gsm.current_state:
		for icon in _gsm.current_state.known_icons:
			if icon.get("north") == north and icon.get("south") == south:
				return false
		_gsm.current_state.known_icons.append({"north": north, "south": south})
		added = true

	if not added:
		return false

	if _verbose:
		var icon_count = get_signature_icons().size()
		_verbose.info("quest", "📖", "Discovered icon: %s/%s (signature: %d icons)" % [north, south, icon_count])

	if _gsm.current_state:
		_gsm.current_state.known_icons = get_signature_icons()

	var new_emojis = get_signature_emojis()
	for emoji in [north, south]:
		if emoji not in old_emojis:
			var newly_accessible = check_newly_accessible_factions(emoji, old_emojis, new_emojis)
			if newly_accessible.size() > 0:
				if _verbose:
					_verbose.info("quest", "🔓", "Unlocked %d new faction(s)!" % newly_accessible.size())
					for faction in newly_accessible:
						var sig = faction.get("sig", [])
						_verbose.info("quest", "-", "%s %s" % ["".join(sig.slice(0, 3)), faction.get("name", "?")])

	if MILK_EMOJI in new_emojis and MILK_EMOJI not in old_emojis:
		handle_milk_autosave(north, south)

	return true


func handle_milk_autosave(north: String, south: String) -> void:
	if _gsm._milk_autosave_done:
		return
	if not _gsm.active_farm:
		if _verbose:
			_verbose.warn("save", "🥛", "Milk autosave skipped: no active farm")
		return
	var state = _gsm.capture_state_from_game()
	var slot_result = SaveStore.save_state(state, MILK_AUTOSAVE_SLOT)
	if slot_result != OK and _verbose:
		_verbose.warn("save", "🥛", "Milk icon autosave failed (slot %d)" % (MILK_AUTOSAVE_SLOT + 1))

	var stamp = "%s_%s" % [Time.get_datetime_string_from_system().replace(":", ""), str(Time.get_ticks_msec())]
	var milk_path = SaveStore.SAVE_DIR + "milk_autosave_" + stamp + ".tres"
	var file_result = SaveStore.save_state_to_path(state, milk_path)
	if file_result == OK:
		_gsm._milk_autosave_done = true
		_gsm.last_milk_autosave_path = milk_path
		if _verbose:
			_verbose.info("save", "🥛", "Milk icon autosave → slot %d (%s) [%s/%s]" % [
				MILK_AUTOSAVE_SLOT + 1, SaveStore.get_save_path(MILK_AUTOSAVE_SLOT), north, south
			])
			_verbose.info("save", "🥛", "Milk icon autosave file → %s" % milk_path)
	elif _verbose:
		_verbose.warn("save", "🥛", "Milk icon autosave file failed: %s" % milk_path)


func check_newly_accessible_factions(_new_emoji: String, old_emojis: Array, new_emojis: Array) -> Array:
	var newly_accessible = []
	for faction in FactionDatabase.get_all():
		var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
		var old_overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, old_emojis)
		var new_overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, new_emojis)
		if old_overlap.is_empty() and not new_overlap.is_empty():
			newly_accessible.append(faction)
	return newly_accessible


func get_accessible_factions() -> Array:
	var accessible = []
	var known_emojis = get_signature_emojis()
	for faction in FactionDatabase.get_all():
		var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
		var overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, known_emojis)
		if not overlap.is_empty():
			accessible.append(faction)
	return accessible


func get_signature_icons() -> Array:
	var farm = _gsm.get_active_farm()
	if farm and farm.has_method("get_known_icons"):
		return farm.get_known_icons()
	if _gsm.current_state:
		return _gsm.current_state.known_icons.duplicate(true)
	return []


func get_signature_emojis() -> Array:
	var farm = _gsm.get_active_farm()
	if farm and farm.has_method("get_known_icons"):
		return GameState.derive_known_emojis_from_icons(farm.get_known_icons())
	if _gsm.current_state:
		return GameState.derive_known_emojis_from_icons(_gsm.current_state.known_icons)
	return []
