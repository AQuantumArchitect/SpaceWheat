class_name PlayerProgress
extends Node

## PlayerProgress — owns persistent player state for GameStateManager.
##
## Held as a child Node on the GameStateManager autoload. Custodian of:
##   - discover_pair flow + faction-unlock detection
##   - milk autosave (first 🍼 discovery autosaves to a dedicated slot)
##
## Signals emoji_discovered / pair_discovered / factions_unlocked live on GSM
## (forwarded) so existing listeners don't break.

const FactionDatabase = preload("res://Core/Quests/FactionDatabase.gd")
const SaveStore = preload("res://Core/GameState/SaveStore.gd")
const GameState = preload("res://Core/GameState/GameState.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

const MILK_EMOJI := "🍼"
const MILK_AUTOSAVE_SLOT := 2

var _gsm: Node = null
var _verbose = null


func _init(gsm: Node = null, verbose = null) -> void:
	_gsm = gsm
	_verbose = verbose
	name = "PlayerProgress"


func discover_pair(north: String, south: String) -> void:
	# Player learns a icon (plantable qubit axis). Forwards to the active
	# Farm (canonical icon owner) and emits unlock signals via GSM.
	var old_emojis = get_signature_emojis()

	var farm = _gsm.get_active_farm()
	var added = false
	if farm and farm.has_method("discover_pair"):
		added = farm.discover_pair(north, south)
	elif _gsm.current_state:
		for pair in _gsm.current_state.known_pairs:
			if pair.get("north") == north and pair.get("south") == south:
				return
		_gsm.current_state.known_pairs.append({"north": north, "south": south})
		added = true

	if not added:
		return

	if north not in old_emojis:
		_gsm.emoji_discovered.emit(north)
	if south not in old_emojis:
		_gsm.emoji_discovered.emit(south)

	_gsm.pair_discovered.emit(north, south)
	if _verbose:
		var pair_count = get_signature_icons().size()
		_verbose.info("quest", "📖", "Discovered pair: %s/%s (signature: %d pairs)" % [north, south, pair_count])

	if _gsm.current_state:
		_gsm.current_state.known_pairs = get_signature_icons()

	var new_emojis = get_signature_emojis()
	for emoji in [north, south]:
		if emoji not in old_emojis:
			var newly_accessible = check_newly_accessible_factions(emoji, old_emojis, new_emojis)
			if newly_accessible.size() > 0:
				_gsm.factions_unlocked.emit(newly_accessible)
				if _verbose:
					_verbose.info("quest", "🔓", "Unlocked %d new faction(s)!" % newly_accessible.size())
					for faction in newly_accessible:
						var sig = faction.get("sig", [])
						_verbose.info("quest", "-", "%s %s" % ["".join(sig.slice(0, 3)), faction.get("name", "?")])

	if MILK_EMOJI in new_emojis and MILK_EMOJI not in old_emojis:
		handle_milk_autosave(north, south)


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


func check_newly_accessible_factions(new_emoji: String, old_emojis: Array, new_emojis: Array) -> Array:
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
	if farm and farm.has_method("get_known_pairs"):
		return farm.get_known_pairs()
	if _gsm.current_state:
		return _gsm.current_state.known_pairs.duplicate(true)
	return []


func get_signature_emojis() -> Array:
	var farm = _gsm.get_active_farm()
	if farm and farm.has_method("get_known_pairs"):
		return GameState.derive_known_emojis_from_pairs(farm.get_known_pairs())
	if _gsm.current_state:
		return GameState.derive_known_emojis_from_pairs(_gsm.current_state.known_pairs)
	return []
