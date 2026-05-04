extends SceneTree

## biome_signature_phase4.gd — Phase IV verification.
##
## Run:  godot --headless --quit --script tests/biome_signature_phase4.gd
##
## Confirms biome.get_signature_pairs() round-trips correctly and that the
## ContractMarket signature → axial projection produces a well-formed
## 12-vec in [0, 1] for each loaded biome that has icons.

const BiomeRegistryCls = preload("res://Core/Biomes/BiomeRegistry.gd")
const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")
const IconLexicon = preload("res://Core/Factions/IconLexicon.gd")
const FactionAxes = preload("res://Core/Factions/FactionAxes.gd")

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	print("=== Biome signature phase IV ===")
	_t_signature_pairs_shape()
	_t_axial_projection()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		print("  ✗ %s" % label)


func _t_signature_pairs_shape() -> void:
	var biome_reg = BiomeRegistryCls.new()
	biome_reg.load_biomes()
	var biomes = biome_reg.get_all()
	_check(biomes.size() > 0, "loaded %d biomes" % biomes.size())
	var biomes_with_signature := 0
	for b in biomes:
		var pairs: Array = b.get_signature_pairs()
		if pairs.is_empty():
			continue
		biomes_with_signature += 1
		# Spot-check first pair has both poles non-empty strings
		var first: Dictionary = pairs[0]
		if str(first.get("pole_0", "")) == "" or str(first.get("pole_1", "")) == "":
			_check(false, "biome '%s' first signature pair has empty pole" % b.name)
			return
	_check(biomes_with_signature > 0,
		"%d/%d biomes expose a non-empty signature" % [biomes_with_signature, biomes.size()])


func _t_axial_projection() -> void:
	var biome_reg = BiomeRegistryCls.new()
	biome_reg.load_biomes()
	var faction_reg = FactionRegistryCls.new()
	faction_reg.load_factions()
	var lex = IconLexicon.new()  # auto-loads on _init()
	var biomes = biome_reg.get_all()

	var biomes_with_axial := 0
	var diverged_from_native := 0
	for b in biomes:
		var pairs: Array = b.get_signature_pairs()
		if pairs.is_empty():
			continue
		var axis_sums: Array = []
		for i in range(FactionAxes.AXIS_COUNT):
			axis_sums.append(0.0)
		var counted := 0
		for pair in pairs:
			var icon: Dictionary = lex.find_icon_by_pair(pair.pole_0, pair.pole_1)
			if icon.is_empty():
				continue
			var owner = str(icon.get("owner_faction", ""))
			if owner == "":
				continue
			var f = faction_reg.get_by_name(owner)
			if f == null:
				continue
			for i in range(FactionAxes.AXIS_COUNT):
				if i < f.get_axial_bits().size():
					axis_sums[i] += float(f.get_axial_bits()[i])
			counted += 1
		if counted == 0:
			continue
		biomes_with_axial += 1
		# All axes in [0, 1]
		for i in range(FactionAxes.AXIS_COUNT):
			var v: float = axis_sums[i] / float(counted)
			if v < 0.0 or v > 1.0:
				_check(false, "biome '%s' axis %d out of range: %.4f" % [b.name, i, v])
				return
		# Compare against native_factions averaging — divergence is expected and OK,
		# we just want to know the new path is producing meaningfully different data.
		var nat_sums: Array = []
		for i in range(FactionAxes.AXIS_COUNT):
			nat_sums.append(0.0)
		var nat_counted := 0
		for fname in b.native_factions:
			var nf = faction_reg.get_by_name(str(fname))
			if nf == null:
				continue
			for i in range(FactionAxes.AXIS_COUNT):
				if i < nf.get_axial_bits().size():
					nat_sums[i] += float(nf.get_axial_bits()[i])
			nat_counted += 1
		if nat_counted == 0:
			continue
		var max_diff := 0.0
		for i in range(FactionAxes.AXIS_COUNT):
			var sig_v: float = axis_sums[i] / float(counted)
			var nat_v: float = nat_sums[i] / float(nat_counted)
			max_diff = max(max_diff, abs(sig_v - nat_v))
		if max_diff > 0.05:
			diverged_from_native += 1

	_check(biomes_with_axial > 0,
		"%d biomes produced a clean axial projection from icons" % biomes_with_axial)
	print("  (info: %d/%d biomes diverged >5%% from native_factions averaging)" %
		[diverged_from_native, biomes_with_axial])
