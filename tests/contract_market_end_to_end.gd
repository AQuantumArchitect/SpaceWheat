@tool
extends SceneTree

## tests/contract_market_end_to_end.gd — verify ContractMarket.propose_offers
## produces dicts with every field QuestSlot (UI/Overlays/QuestBoard.gd) reads
## when rendering an OFFERED quest. The market is QuestManager's only quest
## source, so every offer it returns must be QuestSlot-render-ready.
##
## Run: godot --headless -s tests/contract_market_end_to_end.gd

const ContractMarket = preload("res://Core/Markets/ContractMarket.gd")
const SubstrateFixtures = preload("res://tests/substrate_fixtures.gd")

## Fields that QuestSlot reads when rendering an OFFERED quest.
const SLOT_REQUIRED_FIELDS: Array = [
	"id", "status", "biome", "faction", "type", "time_limit",
	"resource", "quantity",
	"reward_resources",
	"_alignment", "faction_signature",
	"source",  # provenance marker
]


func _init() -> void:
	print("\n=== CONTRACT MARKET END-TO-END TEST ===")
	# Exercises ContractMarket.propose_offers directly as QuestManager does in
	# offer_all_faction_quests. The market is the only quest source now —
	# no flag, no fallback path.
	var farm = SubstrateFixtures.TestFarm.new()
	farm._ensure_contract_market()
	# Use StarterForest's real natives — they speak the test economy's emojis.
	var biome = SubstrateFixtures.TestBiome.with_natives(
		"E2EBiome",
		["Pack Lords", "Swift Herd", "Wildfire", "Celestial Archons", "Mycelial Web", "Verdant Pulse"]
	)
	var offers: Array = farm.contract_market.propose_offers(biome, 2)
	print("  %d offers via facade" % offers.size())
	if offers.is_empty():
		print("❌ FAIL: no offers")
		quit(1)
		return

	# Simulate QuestManager.offer_all_faction_quests post-stamp step
	var quests: Array = []
	var next_id: int = 1000
	var now_ms: int = Time.get_ticks_msec()
	for offer in offers:
		var quest: Dictionary = offer
		quest["id"] = next_id
		next_id += 1
		quest["offered_at"] = now_ms
		quests.append(quest)

	# Verify each quest is QuestSlot-ready
	var sampled: int = 0
	var failures: int = 0
	for quest in quests.slice(0, 8):
		sampled += 1
		for field in SLOT_REQUIRED_FIELDS:
			if not quest.has(field):
				print("❌ missing field '%s' on quest from %s" % [field, quest.get("faction", "?")])
				failures += 1
				break
		if str(quest.get("source", "")) != "contract_market":
			print("❌ source tag missing on quest from %s" % quest.get("faction", "?"))
			failures += 1
		# _alignment should be numeric (QuestSlot._refresh_offered_ui reads it for bg color)
		if not (quest.get("_alignment") is float or quest.get("_alignment") is int):
			print("❌ _alignment not numeric on quest from %s: %s" % [quest.get("faction"), quest.get("_alignment")])
			failures += 1

	print("  Checked %d quests, %d failures" % [sampled, failures])

	# Sanity: faction_signature must be iterable (QuestSlot slices it)
	var first: Dictionary = quests[0]
	var sig = first.get("faction_signature", [])
	if not (sig is Array):
		print("❌ FAIL: faction_signature is not an Array: %s" % typeof(sig))
		failures += 1

	# Sanity: market_projection dict must carry the provenance fields QuestBoard expects
	var proj: Dictionary = first.get("market_projection", {})
	for k in ["market_score", "scarcity", "alignment", "directional_edge"]:
		if not proj.has(k):
			print("❌ FAIL: market_projection missing '%s'" % k)
			failures += 1

	print()
	if failures == 0:
		print("✅ END-TO-END PASS — %d market-sourced quests render-ready" % quests.size())
		quit(0)
	else:
		print("❌ END-TO-END FAIL — %d issues" % failures)
		quit(1)
