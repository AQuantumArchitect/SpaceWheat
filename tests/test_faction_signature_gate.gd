extends SceneTree

## Gate audit: verifies the faction-signature admission gate across all biomes.
##
## Run: godot --headless --script tests/test_faction_signature_gate.gd
##
## Reports:
##   - Per-biome: admitted faction count, orphan icon count, owned icon count
##   - Per-faction: how many biomes each faction can enter
##   - Flags biomes with 0 admitted factions (neutral zones or data gaps)
##   - Flags factions admitted to fewer than MIN_BIOMES_PER_FACTION biomes
##
## Exit code 1 if hard errors found; warnings are printed but don't fail.

const IconRegistryCls = preload("res://Core/Factions/IconRegistry.gd")
const BiomeRegistryCls = preload("res://Core/Biomes/BiomeRegistry.gd")

const MIN_BIOMES_PER_FACTION: int = 1   # Factions with fewer accessible biomes are flagged
const WARN_ZERO_FACTION_BIOMES: bool = true  # Zero-faction biomes are warnings (not hard errors)

var passed: int = 0
var failed: int = 0
var warnings: int = 0


func _init() -> void:
	print("\n=== Faction Signature Gate Audit ===")

	var reg = BiomeRegistryCls.get_shared()
	var lexicon := IconRegistryCls.new()
	var all_biomes: Array = reg.get_all()

	print("  biomes loaded: %d" % all_biomes.size())
	_check(all_biomes.size() >= 150, "registry loaded ≥150 biomes")

	# ── Per-biome pass ──────────────────────────────────────────────────
	var faction_to_biome_count: Dictionary = {}  # {faction_name → int}
	var zero_admitted_biomes: Array = []
	var biome_stats: Array = []  # [{name, admitted, owned_icons, orphan_icons}]

	for biome in all_biomes:
		var bname: String = str(biome.name if "name" in biome else "?")
		var admitted: Array = FactionBiomeMap.factions_for_biome_by_signature(biome)
		var owned_count: int = 0
		var orphan_count: int = 0

		# Count owned vs orphan icons for this biome
		var icons: Array = biome.get_neighborhood_signature_icons() if biome.has_method("get_neighborhood_signature_icons") else []
		for icon in icons:
			if not (icon is Dictionary):
				continue
			var north: String = str(icon.get("pole_0", ""))
			var south: String = str(icon.get("pole_1", ""))
			if north == "" or south == "":
				continue
			if not lexicon.get_factions_for_pair(north, south).is_empty():
				owned_count += 1
			else:
				orphan_count += 1

		biome_stats.append({
			"name": bname,
			"admitted": admitted.size(),
			"owned": owned_count,
			"orphan": orphan_count,
		})

		for fname in admitted:
			faction_to_biome_count[fname] = faction_to_biome_count.get(fname, 0) + 1

		if admitted.is_empty() and icons.size() > 0:
			zero_admitted_biomes.append(bname)

	# ── Report ──────────────────────────────────────────────────────────
	print("\n  --- Biome admission summary ---")
	var total_with_factions: int = 0
	for stat in biome_stats:
		if stat.admitted > 0:
			total_with_factions += 1
	print("  biomes with ≥1 admitted faction: %d / %d" % [total_with_factions, all_biomes.size()])
	print("  biomes with 0 admitted factions: %d" % zero_admitted_biomes.size())

	if not zero_admitted_biomes.is_empty():
		print("  biomes with no admitted factions (check icon ownership or accept as neutral zones):")
		for bname in zero_admitted_biomes.slice(0, mini(20, zero_admitted_biomes.size())):
			print("    ⚠  %s" % bname)
		if zero_admitted_biomes.size() > 20:
			print("    … and %d more" % (zero_admitted_biomes.size() - 20))
		warnings += zero_admitted_biomes.size()
		if WARN_ZERO_FACTION_BIOMES:
			print("  (these are warnings, not hard errors — orphan biomes are intentional neutral zones)")

	# ── Faction coverage ────────────────────────────────────────────────
	print("\n  --- Faction coverage ---")
	var total_factions_tracked: int = faction_to_biome_count.size()
	var locked_out_factions: Array = []

	# Find factions with zero access (not in faction_to_biome_count at all)
	var FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
	var freg = FactionRegistry.new()
	for faction in freg.get_all():
		var fname: String = str(faction.name if "name" in faction else "?")
		if not faction_to_biome_count.has(fname):
			locked_out_factions.append(fname)

	print("  factions with biome access: %d" % total_factions_tracked)
	print("  factions with zero biome access: %d" % locked_out_factions.size())
	if not locked_out_factions.is_empty():
		print("  locked-out factions:")
		for fname in locked_out_factions:
			print("    ✗  %s  (no owned icons)" % fname)

	# Factions with fewer than MIN_BIOMES_PER_FACTION
	var sparse_factions: Array = []
	for fname in faction_to_biome_count:
		var cnt: int = faction_to_biome_count[fname]
		if cnt < MIN_BIOMES_PER_FACTION:
			sparse_factions.append({"name": fname, "count": cnt})
	sparse_factions.sort_custom(func(a, b): return int(a.count) < int(b.count))
	if not sparse_factions.is_empty():
		print("  sparse factions (< %d biome):" % MIN_BIOMES_PER_FACTION)
		for entry in sparse_factions:
			print("    ~  %s  (%d biomes)" % [entry.name, entry.count])

	# Top 10 factions by reach
	var sorted_factions: Array = faction_to_biome_count.keys()
	sorted_factions.sort_custom(func(a, b): return faction_to_biome_count[a] > faction_to_biome_count[b])
	print("\n  --- Top 10 factions by biome reach ---")
	for i in range(mini(10, sorted_factions.size())):
		var fname: String = str(sorted_factions[i])
		print("  %2d  %-40s  %d biomes" % [i + 1, fname, faction_to_biome_count[fname]])

	# ── Hard checks ─────────────────────────────────────────────────────
	_check(all_biomes.size() > 0, "at least one biome loaded")
	_check(locked_out_factions.size() <= 4,
		"at most 4 factions with zero icon ownership (known neutral / unowned factions)")
	_check(total_with_factions >= int(all_biomes.size() * 0.5),
		"≥50%% of biomes have ≥1 admitted faction")

	# ── Summary ─────────────────────────────────────────────────────────
	print("\n📊 Results: %d biomes checked, %d passed, %d failed, %d warnings" % [
		all_biomes.size(), passed, failed, warnings
	])
	quit(0 if failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		print("  FAIL  %s" % label)
