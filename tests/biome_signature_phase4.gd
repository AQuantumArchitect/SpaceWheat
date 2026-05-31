extends SceneTree

## biome_signature_phase4.gd — Phase IV verification.
##
## Run:  godot --headless --quit --script tests/biome_signature_phase4.gd
##
## Confirms biome.get_neighborhood_signature_icons() round-trips correctly and that the
## icon → axial projection produces a well-formed 12-vec in [0, 1] for
## each loaded biome that has icons.

const BiomeRegistryCls = preload("res://Core/Biomes/BiomeRegistry.gd")
const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	print("=== Biome signature phase IV ===")
	_t_signature_icons_shape()
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


func _t_signature_icons_shape() -> void:
	var biome_reg = BiomeRegistryCls.new()
	biome_reg.load_biomes()
	var biomes = biome_reg.get_all()
	_check(biomes.size() > 0, "loaded %d biomes" % biomes.size())
	var biomes_with_signature := 0
	for b in biomes:
		var icons: Array = b.get_neighborhood_signature_icons()
		if icons.is_empty():
			continue
		biomes_with_signature += 1
		# Spot-check first icon has both poles non-empty strings
		var first: Dictionary = icons[0]
		if str(first.get("pole_0", "")) == "" or str(first.get("pole_1", "")) == "":
			_check(false, "biome '%s' first signature icon has empty pole" % b.name)
			return
	_check(biomes_with_signature > 0,
		"%d/%d biomes expose a non-empty signature" % [biomes_with_signature, biomes.size()])


func _t_axial_projection() -> void:
	var biome_reg = BiomeRegistryCls.new()
	biome_reg.load_biomes()
	var faction_reg = FactionRegistryCls.new()
	faction_reg.load_factions()
	var lex = get_node_or_null("/root/IconRegistry")  # auto-loads on _init()
	var biomes = biome_reg.get_all()

	var biomes_with_axial := 0
	for b in biomes:
		var icons: Array = b.get_neighborhood_signature_icons()
		if icons.is_empty():
			continue
		var axis_sums: Array = []
		for i in range(FactionAxes.AXIS_COUNT):
			axis_sums.append(0.0)
		var counted := 0
		for icon_record in icons:
			var icon: Dictionary = lex.find_icon_by_pair(icon_record.pole_0, icon_record.pole_1)
			if icon.is_empty():
				continue
			var owners: Array = lex.get_factions_for_pair(icon_record.pole_0, icon_record.pole_1)
			if owners.is_empty():
				continue
			for owner in owners:
				var f = faction_reg.get_by_name(str(owner))
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
	_check(biomes_with_axial > 0,
		"%d biomes produced a clean axial projection from icons" % biomes_with_axial)
