extends SceneTree

## market_kernel_phase5.gd — Phase V verification.
##
## Run:  godot --headless --quit --script tests/market_kernel_phase5.gd
##
## Confirms the market kernel Tr(ρ_f · ρ_biome):
##   - is well-defined (in [0, 1]) for every biome × faction pair on real data
##   - peaks for factions whose affinity matches the biome's signature owners
##   - produces meaningfully different attention rankings than the old
##     mean-abs-diff bit-vector overlap (i.e. the kernel actually moves)

const AffinityGraphCls = preload("res://Core/Affinity/AffinityGraph.gd")
const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")
const BiomeRegistryCls = preload("res://Core/Biomes/BiomeRegistry.gd")
const IconLexicon = preload("res://Core/Factions/IconLexicon.gd")
const FactionAxes = preload("res://Core/Factions/FactionAxes.gd")

var _failed: int = 0
var _passed: int = 0
var _faction_reg
var _biome_reg
var _lex


func _init() -> void:
	print("=== Market kernel phase V ===")
	_faction_reg = FactionRegistryCls.new()
	_faction_reg.load_factions()
	_biome_reg = BiomeRegistryCls.new()
	_biome_reg.load_biomes()
	_lex = IconLexicon.new()

	_t_kernel_range()
	_t_native_owner_peaks()
	_t_kernel_vs_legacy_divergence()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		print("  ✗ %s" % label)


func _build_biome_affinity(biome):
	var pairs: Array = biome.get_signature_pairs()
	if pairs.is_empty():
		return null
	var owners: Array = []
	for pair in pairs:
		var icon: Dictionary = _lex.find_icon_by_pair(pair.pole_0, pair.pole_1)
		if icon.is_empty():
			continue
		var owner: String = str(icon.get("owner_faction", ""))
		if owner != "":
			owners.append(owner)
	if owners.is_empty():
		return null
	var first_f = _faction_reg.get_by_name(owners[0])
	if first_f == null or first_f.affinity == null:
		return null
	var bg = AffinityGraphCls.from_dict(first_f.affinity.to_dict())
	for i in range(1, owners.size()):
		var f = _faction_reg.get_by_name(owners[i])
		if f != null and f.affinity != null:
			bg.lindblad_jump_toward(f.affinity, 1.0 / float(i + 1))
	return bg


static func _legacy_axial_overlap(a: Array, b: Array) -> float:
	var n: int = min(a.size(), b.size())
	if n == 0: return 0.0
	var diff := 0.0
	for i in range(n):
		diff += absf(float(a[i]) - float(b[i]))
	return clampf(1.0 - (diff / float(n)), 0.0, 1.0)


func _t_kernel_range() -> void:
	var biomes = _biome_reg.get_all()
	var factions = _faction_reg.get_all()
	var checked := 0
	var out_of_range := 0
	for b in biomes:
		var bg = _build_biome_affinity(b)
		if bg == null:
			continue
		for f in factions:
			if f.affinity == null:
				continue
			var ov: float = f.affinity.overlap(bg)
			if ov < -1e-9 or ov > 1.0 + 1e-9:
				out_of_range += 1
				if out_of_range <= 3:
					print("    ✗ overlap(%s, %s)=%.6f" % [f.name, b.name, ov])
			checked += 1
	_check(checked > 0, "evaluated kernel on %d (faction, biome) pairs" % checked)
	_check(out_of_range == 0,
		"all kernel values in [0, 1] (%d violations)" % out_of_range)


func _t_native_owner_peaks() -> void:
	# For biomes with a clean signature, the highest-overlap factions should
	# include at least one owner of a signature icon — the kernel should
	# 'see' the biome's authors strongly.
	var biomes = _biome_reg.get_all()
	var factions = _faction_reg.get_all()
	var biomes_checked := 0
	var owner_in_top5 := 0
	for b in biomes:
		var bg = _build_biome_affinity(b)
		if bg == null:
			continue
		var owners: Dictionary = {}
		for pair in b.get_signature_pairs():
			var icon: Dictionary = _lex.find_icon_by_pair(pair.pole_0, pair.pole_1)
			var o: String = str(icon.get("owner_faction", "")) if not icon.is_empty() else ""
			if o != "":
				owners[o] = true
		if owners.is_empty():
			continue
		biomes_checked += 1
		var scored: Array = []
		for f in factions:
			if f.affinity != null:
				scored.append([f.affinity.overlap(bg), f.name])
		scored.sort_custom(func(a, c): return a[0] > c[0])
		var top5: Array = scored.slice(0, 5)
		var hit := false
		for entry in top5:
			if owners.has(entry[1]):
				hit = true
				break
		if hit:
			owner_in_top5 += 1
	_check(biomes_checked > 0, "checked %d biomes with resolvable signatures" % biomes_checked)
	_check(owner_in_top5 >= int(0.7 * float(biomes_checked)),
		"signature owners appear in top-5 attention for %d/%d biomes" %
			[owner_in_top5, biomes_checked])


func _t_kernel_vs_legacy_divergence() -> void:
	# The kernel should rank factions differently than the legacy bit-vec
	# overlap on at least some biomes — otherwise we haven't actually changed
	# the math, just renamed it.
	var biomes = _biome_reg.get_all()
	var factions = _faction_reg.get_all()
	var biomes_checked := 0
	var biomes_with_rank_diff := 0
	for b in biomes:
		var bg = _build_biome_affinity(b)
		if bg == null:
			continue
		# Build biome bit-vec via signature owners (matches Phase IV path)
		var axis_sums: Array = []
		for i in range(FactionAxes.AXIS_COUNT):
			axis_sums.append(0.0)
		var counted := 0
		for pair in b.get_signature_pairs():
			var icon: Dictionary = _lex.find_icon_by_pair(pair.pole_0, pair.pole_1)
			var o: String = str(icon.get("owner_faction", "")) if not icon.is_empty() else ""
			if o == "": continue
			var of = _faction_reg.get_by_name(o)
			if of == null: continue
			for i in range(FactionAxes.AXIS_COUNT):
				if i < of.get_axial_bits().size():
					axis_sums[i] += float(of.get_axial_bits()[i])
			counted += 1
		if counted == 0: continue
		var biome_bits: Array = []
		for i in range(FactionAxes.AXIS_COUNT):
			biome_bits.append(axis_sums[i] / float(counted))
		biomes_checked += 1
		# Compare top-3 by each metric
		var by_kernel: Array = []
		var by_legacy: Array = []
		for f in factions:
			if f.affinity == null: continue
			by_kernel.append([f.affinity.overlap(bg), f.name])
			var fb: Array = []
			for x in f.get_axial_bits():
				fb.append(float(x))
			by_legacy.append([_legacy_axial_overlap(fb, biome_bits), f.name])
		by_kernel.sort_custom(func(a, c): return a[0] > c[0])
		by_legacy.sort_custom(func(a, c): return a[0] > c[0])
		var top3_k: Array = []
		var top3_l: Array = []
		for i in range(3):
			top3_k.append(by_kernel[i][1])
			top3_l.append(by_legacy[i][1])
		if top3_k != top3_l:
			biomes_with_rank_diff += 1
	_check(biomes_with_rank_diff > 0,
		"%d/%d biomes have kernel-vs-legacy top-3 rank divergence (kernel actually moves)" %
			[biomes_with_rank_diff, biomes_checked])
