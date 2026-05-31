extends SceneTree

## Synthetic-input tests for composer.
##
## Run from project root:
##   godot --headless --script res://tests/test_authority_composer.gd
##
## Builds composer inputs by hand (no game data, no Faction/Biome objects)
## and asserts numeric properties of the output. Failure exits 1.

const ComposerScript = preload("res://Core/Quantum/AuthorityComposer.gd")
const AuthorityAdapterScript = preload("res://Core/Factions/AuthorityAdapter.gd")
const FactionRegistryScript = preload("res://Core/Factions/FactionRegistry.gd")
const BiomeRegistryScript = preload("res://Core/Biomes/BiomeRegistry.gd")

var failures: Array = []
var composer = null


func _init() -> void:
	composer = ComposerScript.new()
	test_dissipation_per_basis()
	test_project_basic()
	test_mask_and()
	test_masked_cosine_aligned()
	test_masked_cosine_orthogonal()
	test_masked_cosine_mask_zero()
	test_compose_one_decay_loving_agent()
	test_compose_one_intersection_empty()
	test_access_tree_is_sorted()
	if failures.is_empty():
		print("[composer-test] OK — all checks passed")
		quit(0)
	else:
		printerr("[composer-test] FAIL — %d failures:" % failures.size())
		for f in failures:
			printerr("  - %s" % f)
		quit(1)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _approx(a: float, b: float, tol: float = 1e-6) -> bool:
	return abs(a - b) <= tol


# ----- helpers -----

# Build a 1-qubit jump operator |to><from| with given amplitude (real).
func _jump_1q(from_idx: int, to_idx: int, amp: float) -> ComplexMatrix:
	var m = ComplexMatrix.zeros(2)
	m.set_element(to_idx, from_idx, Complex.new(amp, 0.0))
	return m


# ----- tests -----

func test_dissipation_per_basis() -> void:
	# 2-dim space, single jump |1><0| with amp=2 → column 0 of |L|^2 = 4, col 1 = 0.
	var L := _jump_1q(0, 1, 2.0)
	var d = composer.dissipation_per_basis([L], 2)
	_assert(_approx(d[0], 4.0), "dissipation_per_basis[0] expected 4.0 got %f" % d[0])
	_assert(_approx(d[1], 0.0), "dissipation_per_basis[1] expected 0.0 got %f" % d[1])

	# Add a second jump |0><1| with amp=1 → col 1 += 1.
	var L2 := _jump_1q(1, 0, 1.0)
	var d2 = composer.dissipation_per_basis([L, L2], 2)
	_assert(_approx(d2[0], 4.0), "two-op col 0 expected 4.0 got %f" % d2[0])
	_assert(_approx(d2[1], 1.0), "two-op col 1 expected 1.0 got %f" % d2[1])


func test_project_basic() -> void:
	# 4 basis states, 2 features. Feature 0 = sum of basis 0 + 2; feature 1 = basis 1.
	var per_basis := PackedFloat64Array([1.0, 2.0, 3.0, 4.0])
	var projection: Array = [
		{0: 1.0, 2: 1.0},   # feature 0
		{1: 1.0},           # feature 1
	]
	var v = composer.project(per_basis, projection, 2)
	_assert(_approx(v[0], 4.0), "project feat 0 expected 4.0 got %f" % v[0])
	_assert(_approx(v[1], 2.0), "project feat 1 expected 2.0 got %f" % v[1])


func test_mask_and() -> void:
	var a := PackedByteArray([1, 0, 1, 1])
	var b := PackedByteArray([1, 1, 0, 1])
	var m = composer.mask_and(a, b)
	_assert(m == PackedByteArray([1, 0, 0, 1]), "mask_and got %s" % str(m))


func test_masked_cosine_aligned() -> void:
	var a := PackedFloat64Array([1.0, 0.0, 1.0])
	var b := PackedFloat64Array([2.0, 0.0, 2.0])
	var mask := PackedByteArray([1, 1, 1])
	# Parallel vectors → cosine = 1.0
	_assert(_approx(composer.masked_cosine(a, b, mask), 1.0),
		"aligned cosine != 1.0")


func test_masked_cosine_orthogonal() -> void:
	var a := PackedFloat64Array([1.0, 0.0])
	var b := PackedFloat64Array([0.0, 1.0])
	var mask := PackedByteArray([1, 1])
	_assert(_approx(composer.masked_cosine(a, b, mask), 0.0),
		"orthogonal cosine != 0.0")


func test_masked_cosine_mask_zero() -> void:
	# All-zero mask → 0.0 (no axes counted).
	var a := PackedFloat64Array([1.0, 1.0])
	var b := PackedFloat64Array([1.0, 1.0])
	var mask := PackedByteArray([0, 0])
	_assert(_approx(composer.masked_cosine(a, b, mask), 0.0),
		"zero-mask cosine != 0.0")


func test_compose_one_decay_loving_agent() -> void:
	# Agent that points entirely at axis 0; space whose fingerprint is
	# entirely on axis 0; profile A points at axis 0, profile B at axis 1.
	# Expect fit ≈ 1, profile A ≈ 1, profile B ≈ 0.
	var agent_state := PackedFloat64Array([1.0, 0.0])
	var agent_mask  := PackedByteArray([1, 1])
	var fingerprint := PackedFloat64Array([1.0, 0.0])
	var space_mask  := PackedByteArray([1, 1])
	var prof_a := PackedFloat64Array([1.0, 0.0])
	var prof_b := PackedFloat64Array([0.0, 1.0])
	var r = composer.compose_one(agent_state, agent_mask,
		fingerprint, space_mask, [prof_a, prof_b])
	_assert(_approx(float(r["fit"]), 1.0),
		"decay-loving fit expected 1.0 got %f" % r["fit"])
	_assert(_approx(float(r["profile_scores"][0]), 1.0),
		"profile A expected 1.0 got %f" % r["profile_scores"][0])
	_assert(_approx(float(r["profile_scores"][1]), 0.0),
		"profile B expected 0.0 got %f" % r["profile_scores"][1])


func test_compose_one_intersection_empty() -> void:
	# Disjoint masks → all scores 0.
	var agent_state := PackedFloat64Array([1.0, 1.0])
	var agent_mask  := PackedByteArray([1, 0])
	var fingerprint := PackedFloat64Array([1.0, 1.0])
	var space_mask  := PackedByteArray([0, 1])
	var prof := PackedFloat64Array([1.0, 1.0])
	var r = composer.compose_one(agent_state, agent_mask,
		fingerprint, space_mask, [prof])
	_assert(_approx(float(r["fit"]), 0.0), "disjoint-mask fit != 0.0")
	_assert(_approx(float(r["profile_scores"][0]), 0.0), "disjoint-mask profile != 0.0")


func test_access_tree_is_sorted() -> void:
	var adapter = AuthorityAdapterScript.new()
	var factions = FactionRegistryScript.new().get_all()
	var biomes = BiomeRegistryScript.new().get_all()
	if factions.is_empty() or biomes.size() < 2:
		_assert(false, "authority tree fixtures missing")
		return

	var tree: Dictionary = adapter.compose_access_tree([factions[0]], biomes)
	var entries: Array = tree.get(String(factions[0].name), [])
	_assert(entries.size() == biomes.size(), "access tree preserves one entry per biome")
	for i in range(1, entries.size()):
		var prev: Dictionary = entries[i - 1]
		var cur: Dictionary = entries[i]
		var prev_fit := float(prev.get("fit", 0.0))
		var cur_fit := float(cur.get("fit", 0.0))
		var prev_hats := (prev.get("hats", []) as Array).size()
		var cur_hats := (cur.get("hats", []) as Array).size()
		var prev_icons := (prev.get("icons", []) as Array).size()
		var cur_icons := (cur.get("icons", []) as Array).size()
		var prev_name := String(prev.get("biome", ""))
		var cur_name := String(cur.get("biome", ""))
		var ordered := true
		if prev_fit < cur_fit - 1e-9:
			ordered = false
		elif abs(prev_fit - cur_fit) <= 1e-9 and prev_hats < cur_hats:
			ordered = false
		elif abs(prev_fit - cur_fit) <= 1e-9 and prev_hats == cur_hats and prev_icons < cur_icons:
			ordered = false
		elif abs(prev_fit - cur_fit) <= 1e-9 and prev_hats == cur_hats and prev_icons == cur_icons and prev_name > cur_name:
			ordered = false
		_assert(ordered, "access tree order regression at %d: %s before %s" % [i, prev_name, cur_name])
