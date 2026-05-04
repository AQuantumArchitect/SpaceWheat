@tool
extends SceneTree

## tests/contract_market_integration.gd — exercise the ContractMarket facade
## against a live-ish Farm surface and verify offers come out in a shape the
## QuestManager lifecycle can consume.
##
## Run: godot --headless -s tests/contract_market_integration.gd

const ContractMarket = preload("res://Core/Markets/ContractMarket.gd")
const SubstrateFixtures = preload("res://tests/substrate_fixtures.gd")

# Required quest-dict fields (QuestManager-facing). Omitted fields get defaults
# later in QuestManager.offer_all_faction_quests (id, offered_at).
const REQUIRED_FIELDS: Array = [
	"status", "biome", "faction", "type", "time_limit",
	"resource", "quantity", "reward_resources", "source",
]


func _init() -> void:
	print("\n=== CONTRACT MARKET INTEGRATION TEST ===")
	var fake_farm = SubstrateFixtures.TestFarm.new()
	if fake_farm.faction_density.get_size() < 4:
		print("❌ FAIL: registry empty — cannot build scenario")
		quit(1)
		return

	var market = ContractMarket.new(fake_farm)
	print("✓ ContractMarket constructed")

	# Use StarterForest's real natives — they collectively speak the test
	# economy's emojis (Pack Lords/Verdant Pulse → 🌾, Swift Herd → 🌿,
	# Mycelial Web → 🍄, Celestial Archons → 💧), so demand is nonzero.
	var biome = SubstrateFixtures.TestBiome.with_natives(
		"TestBiome",
		["Pack Lords", "Swift Herd", "Wildfire", "Celestial Archons", "Mycelial Web", "Verdant Pulse"]
	)
	var offers: Array = market.propose_offers(biome, 2)
	print("  Offers returned: %d" % offers.size())
	if offers.is_empty():
		print("❌ FAIL: no offers returned")
		quit(1)
		return

	# Inspect first few
	var missing_any: bool = false
	for offer in offers.slice(0, min(offers.size(), 5)):
		if not (offer is Dictionary):
			print("❌ FAIL: non-dict offer: %s" % offer)
			missing_any = true
			continue
		for field in REQUIRED_FIELDS:
			if not offer.has(field):
				print("❌ FAIL: offer missing required field '%s'. Faction=%s" % [field, offer.get("faction", "?")])
				missing_any = true
				break
		if str(offer.get("source", "")) != "contract_market":
			print("⚠ WARN: offer source tag missing/wrong: %s" % offer.get("source"))

	if missing_any:
		quit(1)
		return

	# Sample
	var sample: Dictionary = offers[0]
	print("  Sample offer:")
	print("    faction: %s" % sample.get("faction", "?"))
	print("    resource: %s × %d" % [sample.get("resource", "?"), int(sample.get("quantity", 0))])
	print("    reward resources: %s" % sample.get("reward_resources", {}))
	print("    body: %s" % sample.get("body", ""))
	print("    market_score: %.3f" % float(sample.get("market_projection", {}).get("market_score", 0.0)))

	print("\n✅ CONTRACT MARKET INTEGRATION PASS — facade + adapter produce QuestManager-compatible offers")
	quit(0)
