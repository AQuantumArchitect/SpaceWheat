@tool
extends SceneTree

## Smoke test: delivery completion must fail cleanly when the live market
## lattice is missing, and must still work when the lattice is present.



class FakeEconomy extends Node:
	var resources: Dictionary = {"🌾": 0, "🍞": 0}
	var remove_calls: int = 0
	var add_calls: Array = []

	func get_resource(emoji: String):
		return resources.get(emoji, 0)

	func remove_resource(emoji: String, amount, reason: String = "") -> bool:
		remove_calls += 1
		if get_resource(emoji) < amount:
			return false
		resources[emoji] = get_resource(emoji) - amount
		return true

	func add_resource(emoji: String, amount, reason: String = "") -> void:
		add_calls.append({"emoji": emoji, "amount": amount, "reason": reason})
		resources[emoji] = get_resource(emoji) + amount


class FakeLattice extends RefCounted:
	var call_count: int = 0
	var outcome_emoji: String = "🍞"
	var classical_reward: int = 4
	var economy: FakeEconomy = null

	func _init(economy_ref: FakeEconomy = null) -> void:
		economy = economy_ref

	func synthesize_and_exercise(emoji: String, faction_name: String = "") -> Dictionary:
		call_count += 1
		if economy != null:
			economy.add_resource(outcome_emoji, classical_reward, "contract_exercise")
		return {
			"ok": true,
			"outcome": outcome_emoji,
			"classical_reward": classical_reward,
		}


class FakeFarm extends RefCounted:
	var lattice = null

	func get_market_lattice():
		return lattice

	func apply_standing_deltas(_faction_name: String, _deltas: Dictionary) -> void:
		pass


class FakeGSM extends RefCounted:
	var farm: FakeFarm
	var player_progress = null

	func _init(farm_ref: FakeFarm) -> void:
		farm = farm_ref

	func get_active_farm():
		return farm


class TestQuestManager extends QuestManager:
	var fake_gsm: FakeGSM

	func _get_gsm():
		return fake_gsm


func _init() -> void:
	print("\n=== QuestManager strict completion smoke ===")

	_run_missing_lattice_case()
	_run_live_lattice_case()

	print("\nResult: strict quest completion paths verified")
	quit(0)


func _run_missing_lattice_case() -> void:
	var economy := FakeEconomy.new()
	economy.resources["🌾"] = 5
	var farm := FakeFarm.new()
	farm.lattice = null
	var gsm := FakeGSM.new(farm)
	var qm := _make_manager(gsm, economy)
	var quest_id := _seed_delivery_quest(qm)

	var success := qm.complete_quest(quest_id)
	_check(not success, "missing lattice rejects completion")
	_check(economy.remove_calls == 0, "missing lattice does not spend resources")
	_check(economy.resources["🌾"] == 5, "missing lattice leaves player resources unchanged")
	_check(economy.add_calls.is_empty(), "missing lattice grants no rewards")
	_check(qm.active_quests.has(quest_id), "failed completion leaves quest active")
	_check(qm.completed_quests.is_empty(), "failed completion does not move quest to completed list")


func _run_live_lattice_case() -> void:
	var economy := FakeEconomy.new()
	economy.resources["🌾"] = 5
	var farm := FakeFarm.new()
	farm.lattice = FakeLattice.new(economy)
	var gsm := FakeGSM.new(farm)
	var qm := _make_manager(gsm, economy)
	var quest_id := _seed_delivery_quest(qm)

	var success := qm.complete_quest(quest_id)
	_check(success, "live lattice completes quest")
	_check(farm.lattice.call_count == 1, "live lattice exercised exactly once")
	_check(economy.remove_calls == 1, "live lattice spends once")
	_check(economy.resources["🌾"] == 3, "live lattice deducts the quest cost")
	_check(economy.resources["🍞"] == 4, "live lattice grants the outcome reward")
	_check(not qm.active_quests.has(quest_id), "successful completion removes quest from active quests")
	_check(qm.completed_quests.size() == 1, "completed quest is recorded")


func _make_manager(gsm: FakeGSM, economy: FakeEconomy) -> TestQuestManager:
	var qm := TestQuestManager.new()
	qm.fake_gsm = gsm
	qm.connect_to_economy(economy)
	return qm


func _seed_delivery_quest(qm: QuestManager) -> int:
	var quest_id := 1
	qm.active_quests[quest_id] = {
		"id": quest_id,
		"type": QuestTypes.Type.DELIVERY,
		"status": "active",
		"resource": "🌾",
		"quantity": 2,
		"faction": "Verdant Pulse",
		"reward_north": "",
		"reward_south": "",
	}
	return quest_id


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
		return
	push_error("  FAIL  %s" % label)
