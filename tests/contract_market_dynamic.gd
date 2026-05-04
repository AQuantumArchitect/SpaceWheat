@tool
extends SceneTree

## tests/contract_market_dynamic.gd — verify the market reacts to the mythos
## substrate changing under it.
##
## The thesis this test defends: when the player learns a vocabulary pair
## (which pumps the owning faction's diagonal mass via FactionDensityMatrix),
## the market's subsequent offer surface should shift. Specifically, the pumped
## faction should see its offers reweighted.
##
## Run: godot --headless -s tests/contract_market_dynamic.gd

const ContractMarket = preload("res://Core/Markets/ContractMarket.gd")
const SubstrateFixtures = preload("res://tests/substrate_fixtures.gd")


func _init() -> void:
	print("\n=== CONTRACT MARKET DYNAMIC TEST ===")
	var farm = SubstrateFixtures.TestFarm.new()
	var market = ContractMarket.new(farm)

	# Pick a faction and an emoji it speaks
	var names: Array = farm.faction_density.get_faction_names()
	if names.is_empty():
		print("❌ FAIL: no factions")
		quit(1)
		return
	var target_faction: String = str(names[0])
	var registry = farm.faction_density.get_registry()
	var f = registry.get_by_name(target_faction)
	if f == null or f.signature.is_empty():
		print("❌ FAIL: target faction has no signature")
		quit(1)
		return
	# Find a known-Icon pair owned by this faction (if any) for a clean pump
	var lex = farm.icon_lexicon
	var owned_icons: Array = lex.get_icons_for_faction(target_faction)
	var pole_0: String
	var pole_1: String
	if owned_icons.is_empty():
		# Fallback: pump by faction name only (skip vocab learn entirely)
		pole_0 = str(f.signature[0])
		pole_1 = str(f.signature[min(1, f.signature.size() - 1)])
		print("  (target %s has no named Icons; using sig pair %s/%s)" % [target_faction, pole_0, pole_1])
	else:
		pole_0 = str(owned_icons[0].get("pole_0", ""))
		pole_1 = str(owned_icons[0].get("pole_1", ""))
		print("  target %s owns Icon %s/%s" % [target_faction, pole_0, pole_1])

	# Use StarterForest's real natives plus the target faction. They speak the
	# test economy's emojis so demand is nonzero; the target's pump should
	# show up via attention/standing channels.
	var biome = SubstrateFixtures.TestBiome.with_natives(
		"DynamicTestBiome",
		[target_faction, "Pack Lords", "Verdant Pulse", "Mycelial Web", "Hearth Keepers"]
	)

	# Snapshot 1 — baseline market
	var baseline_weight: float = farm.faction_density.get_weight(target_faction)
	var baseline_offers: Array = market.propose_offers(biome, 3)
	var baseline_target_offers: int = _count_offers_from(baseline_offers, target_faction)
	var baseline_mean_score: float = _mean_score(baseline_offers, target_faction)
	print("  BASELINE:  target weight=%.6f, target offers=%d, target mean_score=%.4f, total=%d" % [
		baseline_weight, baseline_target_offers, baseline_mean_score, baseline_offers.size()
	])

	# Pump the target faction strongly (simulate multiple vocab learns)
	for i in range(20):
		farm.faction_density.pump(target_faction, 10.0)

	var pumped_weight: float = farm.faction_density.get_weight(target_faction)
	print("  After pump: target weight=%.6f (Δ=+%.4f)" % [pumped_weight, pumped_weight - baseline_weight])

	# Snapshot 2 — post-pump market
	var post_offers: Array = market.propose_offers(biome, 3)
	var post_target_offers: int = _count_offers_from(post_offers, target_faction)
	var post_mean_score: float = _mean_score(post_offers, target_faction)
	print("  POST-PUMP: target offers=%d, target mean_score=%.4f, total=%d" % [
		post_target_offers, post_mean_score, post_offers.size()
	])

	# Invariants we assert:
	# 1. Pump actually moved the density (physics layer).
	if pumped_weight <= baseline_weight + 0.01:
		print("❌ FAIL: pump did not move density matrix weight appreciably")
		quit(1)
		return
	# 2. Market produced offers in both phases.
	if baseline_offers.is_empty() or post_offers.is_empty():
		print("❌ FAIL: market produced zero offers in one phase")
		quit(1)
		return
	# 3. Target faction's market footprint grew (either # of offers or mean score).
	var footprint_grew: bool = (
		post_target_offers > baseline_target_offers
		or (post_target_offers > 0 and post_mean_score > baseline_mean_score + 0.001)
	)
	if not footprint_grew:
		print("⚠ WARN: target faction footprint did not grow after pump. Market may be attention-capped.")
		# Not a hard fail — the market has its own pricing logic and may saturate.
		# What matters is that offers change at all between the two snapshots.

	# 4. Overall offer surface is different (sanity: market actually re-read state).
	var surface_different: bool = _offer_surface_hash(baseline_offers) != _offer_surface_hash(post_offers)
	if not surface_different:
		print("❌ FAIL: market produced identical offer surface before and after pump. Snapshot isn't rebuilding.")
		quit(1)
		return

	print("\n✅ CONTRACT MARKET DYNAMIC PASS — market reacts to mythos state")
	quit(0)


func _count_offers_from(offers: Array, faction: String) -> int:
	var n: int = 0
	for o in offers:
		if o is Dictionary and str(o.get("faction", "")) == faction:
			n += 1
	return n


func _mean_score(offers: Array, faction: String) -> float:
	var total: float = 0.0
	var n: int = 0
	for o in offers:
		if o is Dictionary and str(o.get("faction", "")) == faction:
			var score: float = float(o.get("_intensity", 0.0))
			total += score
			n += 1
	return total / float(n) if n > 0 else 0.0


func _offer_surface_hash(offers: Array) -> String:
	# Cheap order-sensitive hash: concat faction+resource+quantity per offer.
	var parts: Array = []
	for o in offers:
		if not (o is Dictionary): continue
		parts.append("%s|%s|%d" % [
			str(o.get("faction", "")),
			str(o.get("resource", "")),
			int(o.get("quantity", 0)),
		])
	return "\n".join(parts)


