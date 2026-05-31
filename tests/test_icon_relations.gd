extends SceneTree

## Synthetic-input tests for IconRelations + IconFamily. Hand-rolled icon
## dicts and a fake registry; no real game data.


var rel = null
var fail_count := 0


func _init() -> void:
	rel = IconRelations.new()
	test_cloud_of_poles_only()
	test_cloud_of_with_couplings()
	test_is_sibling()
	test_siblings_of()
	test_siblings_via_cloud_of()
	test_union_of_clouds()
	test_family_of_synthetic()
	if fail_count == 0:
		print("[icon-relations-test] OK — all checks passed")
		quit(0)
	else:
		printerr("[icon-relations-test] FAIL — %d failure(s)" % fail_count)
		quit(1)


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ok  %s" % label)
	else:
		printerr("  FAIL %s" % label)
		fail_count += 1


func test_cloud_of_poles_only() -> void:
	print("test_cloud_of_poles_only")
	var icon := {"pole_0": "☀", "pole_1": "🌙"}
	var c: Dictionary = rel.cloud_of(icon)
	_check("size==2", c.size() == 2)
	_check("has ☀",   c.has("☀"))
	_check("has 🌙",  c.has("🌙"))


func test_cloud_of_with_couplings() -> void:
	print("test_cloud_of_with_couplings")
	var icon := {
		"pole_0": "☀",
		"pole_1": "🌙",
		"hamiltonian_couplings": {"⭐": 0.5},
		"energy_couplings":      {"🔥": 0.3},
	}
	var c: Dictionary = rel.cloud_of(icon)
	_check("size==4", c.size() == 4)
	_check("has ⭐",  c.has("⭐"))
	_check("has 🔥",  c.has("🔥"))


func test_is_sibling() -> void:
	print("test_is_sibling")
	var a := {"pole_0": "☀", "pole_1": "🌙"}
	var b := {"pole_0": "🌙", "pole_1": "⭐"}
	var c := {"pole_0": "🔥", "pole_1": "💧"}
	_check("a~b shares 🌙",  rel.is_sibling(a, b))
	_check("a~c disjoint",    not rel.is_sibling(a, c))


func test_siblings_of() -> void:
	print("test_siblings_of")
	var a := {"pole_0": "☀", "pole_1": "🌙"}
	var b := {"pole_0": "🌙", "pole_1": "⭐"}
	var c := {"pole_0": "🔥", "pole_1": "💧"}
	var sibs: Array = rel.siblings_of(a, [a, b, c])
	_check("siblings_of(a)==[b]", sibs.size() == 1 and sibs[0] == b)


func test_siblings_via_cloud_of() -> void:
	print("test_siblings_via_cloud_of")
	var a := {
		"pole_0": "☀",
		"pole_1": "🌙",
		"hamiltonian_couplings": {"🔥": 1.0},
	}
	var b := {"pole_0": "🌙", "pole_1": "⭐"}    # sibling via 🌙 (pole-share)
	var c := {"pole_0": "🔥", "pole_1": "💧"}    # via cloud (🔥 ∈ cloud(a))
	var d := {"pole_0": "🌳", "pole_1": "🪨"}    # disjoint
	var via: Array = rel.siblings_via_cloud_of(a, [a, b, c, d])
	_check("includes b (pole-share)", via.has(b))
	_check("includes c (cloud-touch)", via.has(c))
	_check("excludes d (disjoint)", not via.has(d))


func test_union_of_clouds() -> void:
	print("test_union_of_clouds")
	var icons := [
		{"pole_0": "☀", "pole_1": "🌙"},
		{"pole_0": "🔥", "pole_1": "💧", "hamiltonian_couplings": {"🌳": 0.2}},
	]
	var u: Dictionary = rel.union_of_clouds(icons)
	_check("union size==5", u.size() == 5)
	for atom in ["☀", "🌙", "🔥", "💧", "🌳"]:
		_check("has %s" % atom, u.has(atom))


# Synthetic IconFamily test: build a fake "lexicon" object exposing get_all().
func test_family_of_synthetic() -> void:
	print("test_family_of_synthetic")
	var fake_lex := FakeLexicon.new([
		{"name": "Solar",     "pole_0": "☀", "pole_1": "🌙", "anonymous": false},
		{"name": "Sunfire",   "pole_0": "☀", "pole_1": "🔥", "anonymous": false},
		{"name": "Quench",    "pole_0": "🔥", "pole_1": "💧", "anonymous": false},
		{"name": "Anon",      "pole_0": "☀", "pole_1": "💧", "anonymous": true},  # ignored
	])
	var fam := IconFamily.new()
	var sun: Array = fam.family_of("☀", fake_lex)
	_check("family(☀) size==2 (Solar + Sunfire; Anon excluded)", sun.size() == 2)
	var fire: Array = fam.family_of("🔥", fake_lex)
	_check("family(🔥) size==2 (Sunfire + Quench)", fire.size() == 2)
	var none: Array = fam.family_of("🌳", fake_lex)
	_check("family(🌳) empty",  none.size() == 0)
	var via_cloud: Array = fam.family_of_cloud({"🔥": true, "💧": true}, fake_lex)
	# Expected: Sunfire (🔥), Quench (🔥, 💧 both → still one entry, deduped)
	_check("family_of_cloud({🔥, 💧}) size==2", via_cloud.size() == 2)


class FakeLexicon:
	var _records: Array
	func _init(records: Array) -> void:
		_records = records
	func get_all() -> Array:
		return _records
