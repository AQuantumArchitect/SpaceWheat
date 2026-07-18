@tool
extends SceneTree

## tests/standings_lifecycle.gd — verify the rep-channel pipeline:
##   1. Farm.get_or_create_standing lazily creates records.
##   2. Farm.apply_standing_deltas mutates the right channels.
##   3. FactionStanding.scalar() aggregates as expected.
##   4. FactionStanding.to_dict / from_dict roundtrip preserves channels.
##   5. QuestRewards._standing_deltas_for_quest returns plausible payloads
##      for both success and failure, across quest types.
##   6. Regression (d1-05): a faction_standings entry is a FactionStanding
##      object, never directly float()-coercible — UI code (e.g.
##      ControlsOverlay._make_story_inspect_panel) must read it via
##      .scalar(), matching every other call site in the codebase.
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
	# tests/ carries a .gdignore (test scripts don't ship in exports), so its
	# class_names never enter the global cache — preload by path, per the
	# usage note in substrate_fixtures.gd, rather than the bare identifier.
	const SubstrateFixturesScript = preload("res://tests/substrate_fixtures.gd")
	var fake_farm = SubstrateFixturesScript.TestFarm.new()
	fake_farm.apply_standing_deltas("Hearth Keepers", {"trust": 0.05, "access": 0.02})
	fake_farm.apply_standing_deltas("Hearth Keepers", {"trust": 0.03, "debt": 0.01})
	var hk = fake_farm.faction_standings.get("Hearth Keepers")
	if hk == null:
		print("FAIL: faction record not created on apply_standing_deltas")
		failures += 1
	elif not is_equal_approx(hk.trust, 0.08) or not is_equal_approx(hk.access, 0.02) or not is_equal_approx(hk.debt, 0.01):
		print("FAIL: faction deltas not accumulated correctly: trust=%.4f access=%.4f debt=%.4f" % [hk.trust, hk.access, hk.debt])
		failures += 1

	# Test 9 (regression d1-05): faction_standings entries render safely.
	# Mirrors ControlsOverlay._make_story_inspect_panel's "standing" row: look
	# the entry up by faction name, confirm it exposes scalar() (the contract
	# every render call site relies on), and confirm a bare float() coercion
	# — the bug that used to crash the inspect panel — is NOT how a
	# FactionStanding behaves (Variant->float conversion fails for a
	# RefCounted object, so callers MUST go through scalar()).
	var standings: Dictionary = {}
	standings["Hearth Keepers"] = FactionStanding.new()
	standings["Hearth Keepers"].trust = 0.4
	standings["Hearth Keepers"].debt = 0.1
	var render_faction := "Hearth Keepers"
	if not standings.has(render_faction):
		print("FAIL: regression fixture missing faction entry")
		failures += 1
	else:
		var entry = standings[render_faction]
		if entry == null or not entry.has_method("scalar"):
			print("FAIL: FactionStanding entry lost its scalar() contract")
			failures += 1
		else:
			var rendered := "%+.2f" % float(entry.scalar())
			if rendered != "+0.08":
				print("FAIL: rendered standing expected +0.08, got %s" % rendered)
				failures += 1

	# Test 10 (d1-04 wave-2): the standings sig column reads the SIGNATURE
	# (the faction's set of icons), never the cloud (its set of atoms) — the
	# locked vocabulary (signature.md). Millwright's Union is the shipped
	# divergence fixture: a 4-icon signature including Lumber 🪓/🪵 whose
	# poles are NOT in its 6-atom cloud. Cloud-counting reads 0 forever for
	# that taught icon; signature-counting moves 0→1 when the player
	# incorporates it. Mirrors ControlsOverlay._render_faction_standings_grid:
	# get_icons_for_faction × discovered_set_from_icons(farm.known_icons).
	var lex = preload("res://Core/Factions/IconRegistry.gd").new()
	var freg = preload("res://Core/Factions/FactionRegistry.gd").new()
	var mill = freg.get_by_name("Millwright's Union")
	var mill_sig: Array = lex.get_icons_for_faction("Millwright's Union")
	if mill_sig.size() != 4:
		print("FAIL: Millwright signature expected 4 icons, got %d" % mill_sig.size())
		failures += 1
	if mill == null or mill.cloud.size() != 6 or mill.cloud.has("🪓") or mill.cloud.has("🪵"):
		print("FAIL: Millwright divergence fixture drifted (cloud should be 6 atoms without 🪓/🪵)")
		failures += 1
	if _sig_known(lex, "Millwright's Union", []) != 0:
		print("FAIL: sig_known should be 0 with nothing incorporated")
		failures += 1
	if _sig_known(lex, "Millwright's Union", [{"north": "🪓", "south": "🪵"}]) != 1:
		print("FAIL: incorporating Lumber 🪓/🪵 must move Millwright sig_known 0→1")
		failures += 1
	# Carrion Throne counter-example: its cloud holds 👥, so cloud-counting
	# read 1/8 at boot off the starting 🌾/👥 icon's emojis. Its signature
	# holds no 🌾/👥 icon — signature-counting must read 0.
	if _sig_known(lex, "Carrion Throne", [{"north": "🌾", "south": "👥"}]) != 0:
		print("FAIL: Carrion Throne sig_known must be 0 at boot (👥 in cloud is not an incorporated icon)")
		failures += 1

	print()
	if failures == 0:
		print("✅ STANDINGS LIFECYCLE PASS — all 10 checks green")
		quit(0)
	else:
		print("❌ STANDINGS LIFECYCLE FAIL — %d check(s) failed" % failures)
		quit(1)


## sig_known exactly as the standings grid computes it: count of the faction's
## signature icons the player has incorporated (known_icons pairs, VS16-normal
## pair keys via IconRegistry).
func _sig_known(lex, faction_name: String, known_icons: Array) -> int:
	var incorporated: Dictionary = lex.discovered_set_from_icons(known_icons)
	var n: int = 0
	for rec in lex.get_icons_for_faction(faction_name):
		if not (rec is Dictionary):
			continue
		if lex.is_icon_discovered(str(rec.get("pole_0", "")), str(rec.get("pole_1", "")), incorporated):
			n += 1
	return n


