extends Node

## PlayerEventBridge — translates game signals into PlayerEventLog entries.
## Autoloaded. Wakes on GameStateManager.farm_ready and chains to the relevant
## subsystems (quest_manager, economy, farm). Headless-safe: only writes to
## PlayerEventLog; spawning UI toasts is PlayerShell's job.

var _farm: Node = null
var _quest_manager: Node = null
var _economy: Node = null
var _wired := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if GameStateManager and GameStateManager.has_signal("farm_ready"):
		GameStateManager.farm_ready.connect(_on_farm_ready)


func _on_farm_ready(farm: Node, _state) -> void:
	if _wired or farm == null:
		return
	_farm = farm
	_quest_manager = _resolve(farm, "quest_manager")
	_economy = _resolve(farm, "economy")
	_wire_quest_signals()
	_wire_economy_signals()
	_wire_farm_signals()
	_wired = true


func _resolve(farm: Node, prop: String) -> Node:
	if prop in farm:
		var v = farm.get(prop)
		return v if v is Node else null
	return null


func _wire_quest_signals() -> void:
	if not _quest_manager:
		return
	if _quest_manager.has_signal("icon_learned"):
		_quest_manager.icon_learned.connect(_on_icon_learned)
	if _quest_manager.has_signal("story_flag_fired"):
		_quest_manager.story_flag_fired.connect(_on_story_flag_fired)
	if _quest_manager.has_signal("quest_completed"):
		_quest_manager.quest_completed.connect(_on_quest_completed)
	if _quest_manager.has_signal("quest_ready_to_claim"):
		_quest_manager.quest_ready_to_claim.connect(_on_quest_ready_to_claim)
	if _quest_manager.has_signal("quest_offered"):
		_quest_manager.quest_offered.connect(_on_quest_offered)
	if _quest_manager.has_signal("quest_failed"):
		_quest_manager.quest_failed.connect(_on_quest_failed)
	if _quest_manager.has_signal("quest_expired"):
		_quest_manager.quest_expired.connect(_on_quest_expired)


func _wire_economy_signals() -> void:
	if not _economy:
		return
	if _economy.has_signal("purchase_failed"):
		_economy.purchase_failed.connect(_on_purchase_failed)
	if _economy.has_signal("resource_mutated"):
		_economy.resource_mutated.connect(_on_resource_mutated)


func _wire_farm_signals() -> void:
	if not _farm:
		return
	if _farm.has_signal("standing_changed"):
		_farm.standing_changed.connect(_on_standing_changed)
	if _farm.has_signal("biome_loaded"):
		_farm.biome_loaded.connect(_on_biome_loaded)


# ─────────────── handlers ───────────────

func _push(message: String, importance: int, icon: String, category: String, path: String = "") -> void:
	PlayerEventLog.push(message, importance, icon, category, path)


func _on_icon_learned(north: String, south: String, faction: String) -> void:
	_push("📖 [b]%s / %s[/b]  taught by %s" % [north, south, faction], 2, "📖", "vocab", "V")


func _on_story_flag_fired(flag_id: String, flag_data: Dictionary) -> void:
	var display := str(flag_data.get("display_name", flag_id))
	var beat := str(flag_data.get("arc_beat", "")).left(80)
	var grants: Dictionary = flag_data.get("standing_grants", {})
	var msg := "✨ [b]%s[/b]  %s" % [display, beat]
	if not grants.is_empty():
		var parts: Array[String] = []
		for f in grants:
			parts.append("%s %+.2f" % [str(f), float(grants[f])])
		msg += "\n   " + ", ".join(parts)
	_push(msg, 3, "✨", "story", "XY")


func _on_quest_completed(qid: int, rewards: Dictionary) -> void:
	_push("✅ Quest %d — %s" % [qid, _format_rewards(rewards)], 1, "✅", "quest", "Q")


func _on_quest_ready_to_claim(qid: int) -> void:
	_push("🏆 [b]Quest %d ready to claim[/b]" % qid, 3, "🏆", "quest", "Q")


func _on_quest_offered(quest: Dictionary) -> void:
	var is_arc := bool(quest.get("is_arc", false)) or bool(quest.get("from_story_flag", false))
	var fac := str(quest.get("faction", ""))
	var imp: int = 3 if is_arc else 1
	_push("📜 New offer from %s" % fac, imp, "📜", "quest", "Q")


func _on_quest_failed(qid: int, reason: String) -> void:
	_push("❌ Quest %d failed — %s" % [qid, reason], 2, "❌", "quest", "Q")


func _on_quest_expired(_qid: int) -> void:
	# Importance 2: at 1 this was dropped by show_hint and commitments
	# vanished silently (fleet: "accepted quest disappears without a word").
	_push("⌛ a commitment ran out of time — check the C board", 2, "⌛", "quest", "Q")


func _on_purchase_failed(reason: String) -> void:
	_push("⚠ %s" % reason, 2, "⚠", "economy", "")


# Player words for wallet-mutation reasons. Ambient trickles (drain, composting)
# are logged too — a wallet delta with no trace reads as haunted (fleet: "🐺+2
# appeared after a refused action"; it was StarterForest's drain trickle).
const REASON_WORDS := {
	"quest_completion": "quest",
	"plot_harvest": "harvest",
	"trade": "trade",
	"synthesis": "synthesis",
	"lindblad_drain": "field drain",
	"lindblad_rainbow": "field drain",
	"composting": "composting",
}


func _on_resource_mutated(emoji: String, delta: float, reason: String, _amount: float) -> void:
	if reason in REASON_WORDS:
		var sign_str: String = "+" if delta >= 0 else ""
		_push("%s %s%d (%s)" % [emoji, sign_str, int(delta), REASON_WORDS[reason]], 1, emoji, "resource", "")


func _on_standing_changed(faction: String, channel: String, delta: float, new_value: float) -> void:
	if absf(delta) < 0.05:
		return
	# Plain words, not a ledger line — "🤝 Packlords · trust +0.12 → 0.45"
	# read as noise to a playtester ("some toast about packlords and 🤝 or
	# something, no idea what that means").
	var direction := "grows" if delta >= 0 else "slips"
	var msg := "🤝 Your %s with the %s %s (%+.2f)" % [channel, faction, direction, delta]
	_push(msg, 2, "🤝", "faction", "XT")


func _on_biome_loaded(biome_name: String, _biome_ref) -> void:
	_push("🗺 Biome loaded: %s" % biome_name, 1, "🗺", "biome", "")


func _format_rewards(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	for k in rewards.get("resource_rewards", {}):
		parts.append("%s×%d" % [k, int(rewards["resource_rewards"][k])])
	for p in rewards.get("learned_pairs", []):
		parts.append("%s/%s" % [str(p.get("north", "?")), str(p.get("south", "?"))])
	return ", ".join(parts) if not parts.is_empty() else "none"
