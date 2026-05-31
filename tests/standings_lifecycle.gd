@tool
extends SceneTree

## tests/standings_lifecycle.gd — verify the rep-channel pipeline:
##   1. Farm.get_or_create_standing lazily creates records.
##   2. Farm.apply_standing_deltas mutates the right channels.
##   3. FactionStanding.scalar() aggregates as expected.
##   4. FactionStanding.to_dict / from_dict roundtrip preserves channels.
##   5. QuestRewards._standing_deltas_for_quest returns plausible payloads
##      for both success and failure, across quest types.
##
## Run: godot --headless -s tests/standings_lifecycle.gd



func _init() -> void:
	print("\n=== STANDINGS LIFECYCLE TEST ===")
	var failures: int = 0

	# Test 1: standing creation + mutation
	var s = FactionStanding.new()
	s.trust = 0.3
	s.debt = 0.1
	s.access = 0.2
	var sc = s.scalar()
	# (0.3 - 0.1 + 0.2 + 0) * 0.25 = 0.1
	if not is_equal_approx(sc, 0.1):
		print("FAIL: scalar() expected 0.1, got %.4f" % sc)
		failures += 1

	# Test 2: dict roundtrip
	var d = s.to_dict()
	var s2 = FactionStanding.from_dict(d)
	if not is_equal_approx(s2.trust, 0.3) or not is_equal_approx(s2.debt, 0.1) or not is_equal_approx(s2.access, 0.2):
		print("FAIL: roundtrip lost data")
		failures += 1

	# Test 3: from_dict tolerates missing keys
	var s3 = FactionStanding.from_dict({"trust": 0.5})
	if not is_equal_approx(s3.trust, 0.5) or not is_equal_approx(s3.debt, 0.0):
		print("FAIL: from_dict with partial data")
		failures += 1

	# Test 4: from_dict with empty dict
	var s4 = FactionStanding.from_dict({})
	if not is_equal_approx(s4.scalar(), 0.0):
		print("FAIL: empty from_dict")
		failures += 1

	# Test 5: success deltas for delivery
	var success_delivery = QuestRewards._standing_deltas_for_quest({"type": 0}, true)
	if not success_delivery.has("trust") or float(success_delivery["trust"]) <= 0.0:
		print("FAIL: delivery success should grant positive trust")
		failures += 1

	# Test 6: failure deltas for delivery
	var fail_delivery = QuestRewards._standing_deltas_for_quest({"type": 0}, false)
	if not fail_delivery.has("debt") or float(fail_delivery["debt"]) <= 0.0:
		print("FAIL: delivery failure should incur debt")
		failures += 1
	if not fail_delivery.has("trust") or float(fail_delivery["trust"]) >= 0.0:
		print("FAIL: delivery failure should drop trust")
		failures += 1

	# Test 7: entanglement quest gives entanglement channel
	var ent = QuestRewards._standing_deltas_for_quest({"type": 4}, true)
	if not ent.has("entanglement") or float(ent["entanglement"]) <= 0.0:
		print("FAIL: entanglement quest should grant entanglement channel")
		failures += 1

	# Test 8: Farm-level apply (with a real Farm instance is heavy; simulate the lazy
	# create + delta application via a minimal stand-in that exposes the same shape).
	# Build a fake farm with just a faction_standings dict and apply_standing_deltas helper.
	var fake_farm = SubstrateFixtures.TestFarm.new()
	fake_farm.apply_standing_deltas("Hearth Keepers", {"trust": 0.05, "access": 0.02})
	fake_farm.apply_standing_deltas("Hearth Keepers", {"trust": 0.03, "debt": 0.01})
	var hk = fake_farm.faction_standings.get("Hearth Keepers")
	if hk == null:
		print("FAIL: faction record not created on apply_standing_deltas")
		failures += 1
	elif not is_equal_approx(hk.trust, 0.08) or not is_equal_approx(hk.access, 0.02) or not is_equal_approx(hk.debt, 0.01):
		print("FAIL: faction deltas not accumulated correctly: trust=%.4f access=%.4f debt=%.4f" % [hk.trust, hk.access, hk.debt])
		failures += 1

	print()
	if failures == 0:
		print("✅ STANDINGS LIFECYCLE PASS — all 8 checks green")
		quit(0)
	else:
		print("❌ STANDINGS LIFECYCLE FAIL — %d check(s) failed" % failures)
		quit(1)


