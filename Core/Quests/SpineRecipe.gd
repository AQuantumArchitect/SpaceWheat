class_name SpineRecipe
extends RefCounted

## Compile a walk from quest/flag fields. The answer is a function of
## auto_accept / auto_claim, state_predicates, reward pair, and PredicateGloss
## targets — not of a second authored `walk:` table and not of hint prose.
##
## Hive `🍄/🧪/hive/spine_recipe.py` is the same compiler for dump/pytest.

const PredicateGloss = preload("res://Core/Quests/PredicateGloss.gd")

const BOOT_BIOMES := ["TheDemos", "Village", "StarterForest"]
const UNSIGNED_KEYS := ["X", "Y", "R", "G"]
const MARKET_KEYS := ["C", "Y", "U", "R", "G"]
const ACE_KEYS := ["8", "Q", "R", "F"]
const PLOT_KEYS := ["G", "H", "J", "K", "L", ";"]
const DISCOVER_KEYS := ["7", "R"]
const STRICT_IDS := [
	"arc_handover", "village_stirs", "new_voices", "woodlot_door",
	"woodlot_wakes", "lumber_flows", "spring_door", "mill_wakes",
	"timber_rhythm",
]


static func taught_pair(quest: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k in ["reward_north", "reward_south", "reward_icon_north", "reward_icon_south"]:
		var g := str(quest.get(k, "")).strip_edges()
		if g != "" and g not in out:
			out.append(g)
	return out


static func is_delivery(quest: Dictionary) -> bool:
	if str(quest.get("resource", "")).strip_edges() != "" and int(quest.get("quantity", 0)) > 0:
		return true
	var t = quest.get("type")
	if t is String:
		var s := str(t).to_upper()
		return s == "DELIVERY" or s == "DELIVER"
	return int(t) == QuestTypes.Type.DELIVERY and str(quest.get("resource", "")) != ""


static func auto_accept_of(quest: Dictionary) -> bool:
	if quest.get("auto_accept") is bool:
		return bool(quest.get("auto_accept"))
	if is_delivery(quest):
		return false
	return str(quest.get("source", "")) == Quest.SOURCE_TUTORIAL \
			or str(quest.get("category", "")) == "TUTORIAL"


static func auto_claim_of(quest: Dictionary) -> bool:
	if quest.get("auto_claim") is bool:
		return bool(quest.get("auto_claim"))
	if is_delivery(quest):
		return false
	var preds = quest.get("state_predicates", [])
	if str(quest.get("category", "")) == "TUTORIAL":
		return preds is Array and not preds.is_empty()
	return false


static func kind(quest: Dictionary) -> String:
	if is_delivery(quest):
		return "delivery"
	var preds: Array = quest.get("state_predicates", []) if quest.get("state_predicates") is Array else []
	if preds.is_empty():
		return "handshake"
	var types: PackedStringArray = []
	for p in preds:
		if p is Dictionary:
			var t := str(p.get("type", ""))
			if t != "" and t not in types:
				types.append(t)
	if types.size() == 1:
		return _kind_for_pred(preds[0])
	var kinds: PackedStringArray = []
	for p in preds:
		if p is Dictionary:
			var k := _kind_for_pred(p)
			if k not in kinds:
				kinds.append(k)
	return "mixed" if kinds.size() > 1 else (kinds[0] if kinds.size() == 1 else "handshake")


static func _kind_for_pred(pred: Dictionary) -> String:
	var t := str(pred.get("type", ""))
	match t:
		"standing_gte":
			return "standing"
		"atom_in_biome", "atom_count_gte":
			return "plant"
		"biome_evolving":
			var b := str(pred.get("biome", ""))
			return "discover" if b != "" and b not in BOOT_BIOMES else "travel"
		"active_biome_is":
			return "travel"
		"biome_explored":
			return "gate"
		"icon_incorporated":
			return "berry"
		"gate_sequence_contains", "gate_order", "lesson_receipt":
			return "gate"
		"berry_consumed_count_gte", "berry_total_phase_gte":
			return "berry"
		"biome_state_gte", "biome_attractor_emoji_gte", "coherence_at_least":
			return "steer"
		"story_flag_set", "story_flag_any":
			return "parent"
	return t if t != "" else "unknown"


static func work_keys(quest: Dictionary, ctx: Dictionary = {}) -> PackedStringArray:
	var keys: PackedStringArray = []
	var unlocked: Array = ctx.get("unlocked_biomes", BOOT_BIOMES)
	if is_delivery(quest) or kind(quest) == "standing":
		_append_all(keys, MARKET_KEYS)
		_append_all(keys, ACE_KEYS)
		_append_all(keys, PLOT_KEYS)
	if not auto_accept_of(quest) and not is_delivery(quest):
		_append_all(keys, UNSIGNED_KEYS)
	var preds: Array = quest.get("state_predicates", []) if quest.get("state_predicates") is Array else []
	for p in preds:
		if not (p is Dictionary):
			continue
		_append_pred_keys(keys, p, unlocked)
	if keys.is_empty() and kind(quest) == "handshake":
		_append_all(keys, UNSIGNED_KEYS)
	return keys


static func _append_pred_keys(keys: PackedStringArray, pred: Dictionary, unlocked: Array) -> void:
	var t := str(pred.get("type", ""))
	if t == "biome_evolving":
		var b := str(pred.get("biome", ""))
		if b != "" and b not in unlocked and b not in BOOT_BIOMES:
			_append_all(keys, DISCOVER_KEYS)
			_append_all(keys, ACE_KEYS)
			return
	var tgt := PredicateGloss.target(pred)
	var k := str(tgt.get("key", ""))
	if k != "":
		_append(keys, k)
	match t:
		"gate_sequence_contains", "lesson_receipt":
			var g := str(pred.get("gate", "")).to_lower()
			var rec := str(pred.get("receipt", ""))
			if g == "explore" or g == "batch_explore":
				_append(keys, "F")
			elif g == "measure" or g == "bell_collapse" or rec == "superpose_warmth":
				_append(keys, "R")
				_append(keys, "Q")
			elif g == "pop" or rec == "superpose_warmth":
				_append(keys, "Q")
			elif g == "hadamard":
				_append(keys, "E")
			elif g == "reap":
				_append(keys, "8")
			_append_all(keys, ACE_KEYS if g in ["explore", "measure", "pop", "reap", "batch_explore", "bell_collapse"] else PackedStringArray())
		"atom_in_biome", "atom_count_gte":
			_append(keys, "5")
			_append(keys, "R")
		"standing_gte":
			_append_all(keys, MARKET_KEYS)
		"berry_consumed_count_gte", "berry_total_phase_gte":
			_append(keys, "5")
			_append(keys, "F")
			_append(keys, "R")
		"active_biome_is", "biome_explored", "biome_state_gte", "biome_attractor_emoji_gte", "biome_evolving":
			_append_all(keys, ACE_KEYS)


static func _append(keys: PackedStringArray, k: String) -> void:
	var u := k.to_upper()
	if u != "" and u not in keys:
		keys.append(u)


static func _append_all(keys: PackedStringArray, more: PackedStringArray) -> void:
	for k in more:
		_append(keys, str(k))


static func allowed_keys(quest: Dictionary, ctx: Dictionary = {}) -> PackedStringArray:
	return work_keys(quest, ctx)


static func compile_quest(quest: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	return {
		"kind": kind(quest),
		"auto_accept": auto_accept_of(quest),
		"auto_claim": auto_claim_of(quest),
		"pair": taught_pair(quest),
		"keys": allowed_keys(quest, ctx),
		"predicates": quest.get("state_predicates", []),
	}
