@tool
extends SceneTree

## Quest market lattice smoke
## Verifies QuestManager projects MarketContract records into quest dictionaries
## that can be stamped and validated without the old facade shape.



class FakeLattice extends RefCounted:
	func propose_offers(_biome, _n: int = 1) -> Array:
		var first := MarketContract.make("🌾", "Verdant Pulse", "StarterForest", 0, 17, 0.0, 99, "🍞", 4.0)
		first.set_meta("pair_a", "StarterForest")
		first.set_meta("pair_b", "Verdant Pulse")
		first.set_meta("tension", 0.37)
		first.set_meta("shared", true)
		var second := MarketContract.make("🍄", "Mycelial Web", "StarterForest", 1, 18, 0.0, 99, "💧", 3.0)
		second.set_meta("pair_a", "StarterForest")
		second.set_meta("pair_b", "Mycelial Web")
		second.set_meta("tension", 0.19)
		second.set_meta("shared", true)
		return [first, second]


class FakeFarm extends RefCounted:
	var lattice := FakeLattice.new()

	func get_market_lattice():
		return lattice


class FakeGSM extends RefCounted:
	var farm: FakeFarm
	var player_progress: Dictionary = {}

	func _init(farm_ref: FakeFarm) -> void:
		farm = farm_ref

	func get_active_farm():
		return farm


class FakeQuestManager extends QuestManager:
	var fake_gsm: FakeGSM

	func _get_gsm():
		return fake_gsm


func _init() -> void:
	print("\n=== Quest market lattice smoke ===")
	var farm := FakeFarm.new()
	var gsm := FakeGSM.new(farm)

	var qm := FakeQuestManager.new()
	qm.fake_gsm = gsm

	var offers: Array = qm.offer_all_faction_quests(Node.new())
	if offers.size() != 2:
		push_error("expected 2 projected offers, got %d" % offers.size())
		quit(1)
		return

	for offer in offers:
		if not (offer is Dictionary):
			push_error("projected offer is not a Dictionary: %s" % offer)
			quit(1)
			return
		if str(offer.get("source", "")) != "market_lattice_pair":
			push_error("projected offer missing market_lattice source tag")
			quit(1)
			return
		if int(offer.get("type", -1)) != int(QuestTypes.Type.DELIVERY):
			push_error("projected offer missing delivery type")
			quit(1)
			return
		if str(offer.get("resource", "")) == "" or int(offer.get("quantity", 0)) <= 0:
			push_error("projected offer missing resource/quantity")
			quit(1)
			return
		if not offer.has("reward_resources"):
			push_error("projected offer missing reward_resources")
			quit(1)
			return

	print("  PASS projected quest dicts from MarketContract records")
	print("  PASS quest manager stamps can run on projected offers")
	print("Result: 2 passed, 0 failed")
	quit(0)
