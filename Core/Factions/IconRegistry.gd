extends Node

## IconRegistry - canonical runtime atlas for icon pair truth and projected atom physics.
##
## This is the one live icon store. It ingests the authored JSON sources once at
## boot and owns:
##   - pair-icon identity / ownership / biome presence
##   - discovered anonymous pairs
##   - derived per-emoji atom physics cache
##
## Pair records are loaded from:
##   - factions.json icons[]
##   - biomes.json icons[]
##   - icons.json physics entries
##
## The per-emoji atom cache is derived from pair records and can be rebuilt on
## demand. Live phase rotation mutates the atom cache only; the authored pair
## records remain the source data that can be rebuilt from.

const IconScript = preload("res://Core/QuantumSubstrate/Icon.gd")

const JSON_FACTIONS = "res://Core/Factions/data/factions.json"
const JSON_BIOMES = "res://Core/Biomes/data/biomes.json"
const JSON_ICONS = "res://Core/Factions/data/icons.json"

## Semantica explorer (W3b): compiled *.icons.json files under this dir, merged
## ADDITIVELY on top of canon when RuntimeEnv.semantica_explorer() is true. Never
## touches icons.json (crafted-artifact law) — see 🍄/🧪/semantica_compiler.py.
const SEMANTICA_DIR = "res://Core/Config/semantica"

var _by_pair: Dictionary = {}
var _by_name: Dictionary = {}
var _by_faction: Dictionary = {}
var _pair_to_factions: Dictionary = {}
var _by_biome: Dictionary = {}

## Derived per-emoji physics cache: emoji -> Icon
var atoms: Dictionary = {}

var _world_built_count: int = 0
var _anonymous_count: int = 0
var _loaded: bool = false


func _init() -> void:
	_reload_all()


func _ready() -> void:
	if not _loaded or _by_faction.is_empty():
		_reload_all()


## Emoji keys ignore U+FE0F (the emoji variation selector): the data ships 5
## emoji in BOTH spellings (⚙ ❄ 🏚 🏛 🏜), and raw string keys split them into
## different addresses — find_icon_by_pair("❄","🔥") missed Hearth (🔥/❄️) and
## the microscope described a different word than the plot held. 360 pole
## records, zero collisions under this normalization (audited 2026-07-15).
## Lookup-layer only: physics addressing and the JSON data are untouched —
## normalizing the DATA would switch on silently-dead couplings (ledgered).
static func norm_emoji(e: String) -> String:
	return e.replace("️", "")


static func _pair_key(p0: String, p1: String) -> String:
	return "%s|%s" % [norm_emoji(p0), norm_emoji(p1)]


func _reload_all() -> void:
	_by_pair.clear()
	_by_name.clear()
	_by_faction.clear()
	_pair_to_factions.clear()
	_by_biome.clear()
	atoms.clear()
	_anonymous_count = 0
	_world_built_count = 0
	_load_pair_records()
	_load_axial_icons()
	_world_built_count = _by_pair.size()
	_load_icon_physics()
	# Semantica explorer: additive pass, OFF by default (boot-neutral). A player
	# never sets SEMANTICA_EXPLORER, so this branch is dead weight for them.
	if RuntimeEnv.semantica_explorer():
		_load_semantica_icon_physics()
	_rebuild_atom_cache()
	_loaded = true


func _load_pair_records() -> void:
	# Pass 1: faction-authored icons.
	var faction_data = _read_json(JSON_FACTIONS)
	if faction_data is Array:
		for f in faction_data:
			var fname = str(f.get("name", ""))
			if fname == "":
				continue
			for icon in f.get("icons", []):
				if not (icon is Dictionary):
					continue
				var icon_name = str(icon.get("name", ""))
				var p0 = str(icon.get("pole_0", ""))
				var p1 = str(icon.get("pole_1", ""))
				if p0 == "" or p1 == "":
					continue
				var key = _pair_key(p0, p1)
				if not _by_pair.has(key):
					_register({
						"name": icon_name,
						"pole_0": p0,
						"pole_1": p1,
						"biomes_present_in": [],
						"anonymous": false,
					})
				if not _by_faction.has(fname):
					_by_faction[fname] = []
				if not _by_faction[fname].has(key):
					_by_faction[fname].append(key)
				if not _pair_to_factions.has(key):
					_pair_to_factions[key] = []
				if not _pair_to_factions[key].has(fname):
					_pair_to_factions[key].append(fname)

	# Pass 2: biome placements.
	var biome_data = _read_json(JSON_BIOMES)
	if biome_data is Array:
		for b in biome_data:
			var bname = str(b.get("name", ""))
			if bname == "":
				continue
			for icon in b.get("icons", []):
				if not (icon is Dictionary):
					continue
				var icon_name = str(icon.get("name", ""))
				var p0 = str(icon.get("pole_0", ""))
				var p1 = str(icon.get("pole_1", ""))
				if p0 == "" or p1 == "":
					continue
				var key = _pair_key(p0, p1)
				if not _by_pair.has(key):
					_register({
						"name": icon_name,
						"pole_0": p0,
						"pole_1": p1,
						"biomes_present_in": [],
						"anonymous": false,
					})
				if not _by_biome.has(bname):
					_by_biome[bname] = []
				if not _by_biome[bname].has(key):
					_by_biome[bname].append(key)
				if not _by_pair[key]["biomes_present_in"].has(bname):
					_by_pair[key]["biomes_present_in"].append(bname)


func _load_axial_icons() -> void:
	for i in range(FactionAxes.AXIS_COUNT):
		var axis: Dictionary = FactionAxes.get_axis(i)
		if axis.is_empty():
			continue
		var p0 := str(axis.get("pole_0", ""))
		var p1 := str(axis.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var key := _pair_key(p0, p1)
		if _by_pair.has(key):
			_by_pair[key]["axial"] = true
			_by_pair[key]["axis_index"] = i
			continue
		_register({
			"name": "Axis_%s" % str(axis.get("key", "axis_%d" % i)),
			"pole_0": p0,
			"pole_1": p1,
			"biomes_present_in": [],
			"anonymous": false,
			"axial": true,
			"axis_index": i,
		})


func _load_icon_physics() -> void:
	_merge_icon_physics_from(JSON_ICONS)


## Semantica explorer: additively merge every compiled *.icons.json under
## Core/Config/semantica/ (produced by 🍄/🧪/semantica_compiler.py). Same record
## shape as icons.json, so the same merge path applies unchanged.
func _load_semantica_icon_physics() -> void:
	var dir := DirAccess.open(SEMANTICA_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".icons.json"):
			_merge_icon_physics_from(SEMANTICA_DIR.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()


## Merge authored pair physics from a single icons.json-shaped file. Missing
## pair records are created here so physics-only entries can still exist in
## the atlas. Shared by the canonical load and the semantica additive pass.
func _merge_icon_physics_from(path: String) -> void:
	var physics_data = _read_json(path)
	if not physics_data is Array:
		return
	var physics_fields := [
		"self_energy_0", "self_energy_1", "rabi_coupling",
		"hamiltonian_couplings", "energy_couplings", "driver", "measurement_behavior",
	]
	for entry in physics_data:
		if not (entry is Dictionary):
			continue
		var p0 := str(entry.get("pole_0", ""))
		var p1 := str(entry.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var record = find_icon_by_pair(p0, p1)
		if record.is_empty():
			record = {
				"name": str(entry.get("name", "%s/%s" % [p0, p1])),
				"pole_0": p0,
				"pole_1": p1,
				"biomes_present_in": [],
				"anonymous": false,
			}
			_register(record)
		for field in physics_fields:
			if field in entry and not record.has(field):
				record[field] = entry[field]


func _rebuild_atom_cache() -> void:
	atoms.clear()
	for key in _by_pair:
		var record: Dictionary = _by_pair[key]
		if record.get("anonymous", false):
			continue
		_accumulate_atom_from_record(record)


func _accumulate_atom_from_record(record: Dictionary) -> void:
	var pole_0 := str(record.get("pole_0", ""))
	var pole_1 := str(record.get("pole_1", ""))
	if pole_0 != "":
		_accumulate_atom_for_pole(pole_0, record, true)
	if pole_1 != "" and pole_1 != pole_0:
		_accumulate_atom_for_pole(pole_1, record, false)


func _accumulate_atom_for_pole(emoji: String, record: Dictionary, is_pole_0: bool) -> void:
	var self_key := "self_energy_0" if is_pole_0 else "self_energy_1"
	var self_energy := float(record.get(self_key, 0.0))
	var h_couplings: Dictionary = record.get("hamiltonian_couplings", {})
	var e_couplings: Dictionary = record.get("energy_couplings", {})
	var driver: Dictionary = record.get("driver", {})

	if atoms.has(emoji):
		var existing = atoms[emoji]
		existing.self_energy += self_energy
		for target in h_couplings:
			if target not in existing.hamiltonian_couplings:
				existing.hamiltonian_couplings[target] = h_couplings[target]
		for obs in e_couplings:
			existing.energy_couplings[obs] = float(existing.energy_couplings.get(obs, 0.0)) + float(e_couplings[obs])
		if is_pole_0 and existing.self_energy_driver == "" and driver.has("type"):
			existing.self_energy_driver = str(driver.get("type", ""))
			existing.driver_frequency = float(driver.get("freq", 0.0))
			existing.driver_phase = float(driver.get("phase", 0.0))
			existing.driver_amplitude = float(driver.get("amp", 1.0))
		return

	var atom := IconScript.new()
	atom.emoji = emoji
	atom.display_name = emoji
	atom.self_energy = self_energy
	for target in h_couplings:
		atom.hamiltonian_couplings[target] = h_couplings[target]
	for obs in e_couplings:
		atom.energy_couplings[obs] = float(e_couplings[obs])
	if is_pole_0 and driver.has("type"):
		atom.self_energy_driver = str(driver.get("type", ""))
		atom.driver_frequency = float(driver.get("freq", 0.0))
		atom.driver_phase = float(driver.get("phase", 0.0))
		atom.driver_amplitude = float(driver.get("amp", 1.0))
	if record.has("measurement_behavior"):
		atom.description = str(record.get("measurement_behavior", ""))
	atoms[emoji] = atom


func _read_json(path: String) -> Variant:
	# One JSON-load authority (slop knot #7); null on failure as before.
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		path, {"context": "IconRegistry"})
	return res.data if res.ok else null


func _register(record: Dictionary) -> void:
	var key = _pair_key(str(record.get("pole_0", "")), str(record.get("pole_1", "")))
	_by_pair[key] = record
	var icon_name = str(record.get("name", ""))
	if not _by_name.has(icon_name):
		_by_name[icon_name] = []
	if not _by_name[icon_name].has(key):
		_by_name[icon_name].append(key)


## Find an icon record by either of its pole emojis. Returns {} if not found.
## Cheap linear scan over icons; small set, called rarely.
func find_icon_by_emoji(emoji: String) -> Dictionary:
	if emoji == "":
		return {}
	var e := norm_emoji(emoji)
	for key in _by_pair:
		var rec = _by_pair[key]
		if norm_emoji(str(rec.get("pole_0", ""))) == e or norm_emoji(str(rec.get("pole_1", ""))) == e:
			return rec
	return {}


func find_icon_by_pair(pole_0: String, pole_1: String) -> Dictionary:
	var key = _pair_key(pole_0, pole_1)
	if _by_pair.has(key):
		return _by_pair[key]
	var rev = _pair_key(pole_1, pole_0)
	if _by_pair.has(rev):
		return _by_pair[rev]
	return {}


func get_icons_by_name(_name: String) -> Array:
	var keys = _by_name.get(_name, [])
	var out: Array = []
	for k in keys:
		out.append(_by_pair[k])
	return out


func get_icon_physics_by_pair(pole_0: String, pole_1: String) -> Dictionary:
	var record = find_icon_by_pair(pole_0, pole_1)
	if record.is_empty():
		return {}
	return _physics_from_record(record)


func _physics_from_record(record: Dictionary) -> Dictionary:
	return {
		"self_energy_0": float(record.get("self_energy_0", 0.0)),
		"self_energy_1": float(record.get("self_energy_1", 0.0)),
		"rabi_coupling": float(record.get("rabi_coupling", 0.0)),
		"hamiltonian_couplings": record.get("hamiltonian_couplings", {}),
		"energy_couplings": record.get("energy_couplings", {}),
		"driver": record.get("driver", {}),
		"measurement_behavior": record.get("measurement_behavior", {}),
	}


func get_factions_for_pair(p0: String, p1: String) -> Array:
	var key = _pair_key(p0, p1)
	var facs = _pair_to_factions.get(key, [])
	if not facs.is_empty():
		return facs
	return _pair_to_factions.get(_pair_key(p1, p0), [])


func get_primary_faction_for_pair(p0: String, p1: String) -> String:
	var facs = get_factions_for_pair(p0, p1)
	return str(facs[0]) if not facs.is_empty() else ""


func get_icons_for_faction(faction_name: String) -> Array:
	var keys = _by_faction.get(faction_name, [])
	var out: Array = []
	for k in keys:
		out.append(_by_pair[k])
	return out


func register_anonymous(pole_0: String, pole_1: String) -> Dictionary:
	var existing = find_icon_by_pair(pole_0, pole_1)
	if not existing.is_empty():
		return existing
	var record = {
		"name": "Anon(%s/%s)" % [pole_0, pole_1],
		"pole_0": pole_0,
		"pole_1": pole_1,
		"biomes_present_in": [],
		"anonymous": true,
	}
	_register(record)
	_anonymous_count += 1
	return record


static func discovered_set_from_icons(icon: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in icon:
		if not (entry is Dictionary):
			continue
		var n = str(entry.get("north", ""))
		var s = str(entry.get("south", ""))
		if n == "" or s == "":
			continue
		out[_pair_key(n, s)] = true
		out[_pair_key(s, n)] = true
	return out


func is_icon_discovered(pole_0: String, pole_1: String, discovered: Dictionary) -> bool:
	if discovered.has(_pair_key(pole_0, pole_1)):
		return true
	return discovered.has(_pair_key(pole_1, pole_0))


func filter_discovered_records(discovered: Dictionary) -> Array:
	var out: Array = []
	for key in _by_pair:
		var r = _by_pair[key]
		if r.get("anonymous", false):
			continue
		if is_icon_discovered(r["pole_0"], r["pole_1"], discovered):
			out.append(r)
	return out


func get_all() -> Array:
	var out: Array = []
	for key in _by_pair:
		out.append(_by_pair[key])
	return out


func size() -> int:
	return _by_pair.size()


func summary() -> String:
	var claimed = 0
	var orphans = 0
	var axial = 0
	for key in _by_pair:
		var r = _by_pair[key]
		if r.get("anonymous", false):
			continue
		if r.get("axial", false):
			axial += 1
			continue
		if _pair_to_factions.has(key):
			claimed += 1
		else:
			orphans += 1
	return "IconRegistry: %d total (%d faction-claimed + %d biome-orphan + %d axial + %d anonymous)" % [
		_by_pair.size(), claimed, orphans, axial, _anonymous_count
	]


func get_all_emojis() -> Array:
	return atoms.keys()


## Union of every emoji the simulation knows about: atoms cache, biome.emojis,
## faction signatures, and faction.alignment_couplings keys. Source of truth
## for save/runtime emoji enumeration. Replaces the deleted EmojiRegistry.
func build_emoji_universe() -> Array:
	var BiomeRegistryCls = load("res://Core/Biomes/BiomeRegistry.gd")
	var FactionRegistryCls = load("res://Core/Factions/FactionRegistry.gd")
	var u: Dictionary = {}
	for emoji in atoms.keys():
		u[emoji] = true
	var biome_registry = BiomeRegistryCls.get_shared() if BiomeRegistryCls else null
	if biome_registry:
		for biome in biome_registry.get_all():
			for emoji in biome.emojis:
				u[emoji] = true
	var faction_registry = FactionRegistryCls.new() if FactionRegistryCls else null
	if faction_registry:
		for f in faction_registry.get_all():
			for emoji in f.cloud:
				u[emoji] = true
			for emoji in f.alignment_couplings.keys():
				u[emoji] = true
				var row = f.alignment_couplings[emoji]
				if row is Dictionary:
					for observable_emoji in row.keys():
						u[observable_emoji] = true
	return u.keys()


func get_all_atoms() -> Array:
	var result: Array = []
	for atom in atoms.values():
		result.append(atom)
	return result


func get_atom(emoji: String):
	return atoms.get(emoji, null)


func rebuild_from_icons() -> void:
	_reload_all()


## Physics over a CLOUD (set of atoms): per-atom self-energy + Hamiltonian
## couplings. Returns {cloud, self_energies, hamiltonian}.
func get_cloud_physics(cloud: Array) -> Dictionary:
	var out: Dictionary = {
		"cloud": [],
		"self_energies": {},
		"hamiltonian": {},
	}
	if cloud.is_empty():
		return out
	var seen: Dictionary = {}
	for raw_emoji in cloud:
		var emoji := str(raw_emoji)
		if emoji == "" or seen.has(emoji):
			continue
		seen[emoji] = true
		out["cloud"].append(emoji)
		var atom = get_atom(emoji)
		if atom == null:
			continue
		out["self_energies"][emoji] = float(out["self_energies"].get(emoji, 0.0)) + float(atom.self_energy)
		_merge_nested_couplings(out["hamiltonian"], emoji, atom.hamiltonian_couplings)
	return out


func rotate_phase_for_emojis(emojis: Array, phase_delta: float) -> int:
	var changed: int = 0
	for raw_emoji in emojis:
		if rotate_phase_for_emoji(str(raw_emoji), phase_delta):
			changed += 1
	return changed


func rotate_phase_for_emoji(emoji: String, phase_delta: float) -> bool:
	var updated: bool = false
	for key in _by_pair:
		var record: Dictionary = _by_pair[key]
		var p0 := str(record.get("pole_0", ""))
		var p1 := str(record.get("pole_1", ""))
		if emoji != p0 and emoji != p1:
			continue
		var couplings: Dictionary = record.get("hamiltonian_couplings", {})
		for target in couplings.keys():
			var value = couplings[target]
			var rotated = _rotate_coupling_phase(value, phase_delta)
			if rotated != value:
				couplings[target] = rotated
				updated = true
		record["hamiltonian_couplings"] = couplings
		_by_pair[key] = record
	if updated:
		_rebuild_atom_cache()
	return updated


static func _merge_nested_couplings(dest: Dictionary, source_emoji: String, couplings: Dictionary) -> void:
	if couplings.is_empty():
		return
	if not dest.has(source_emoji) or not (dest[source_emoji] is Dictionary):
		dest[source_emoji] = {}
	var row: Dictionary = dest[source_emoji]
	for target in couplings:
		row[target] = _add_coupling(row.get(target, null), couplings[target])


static func _merge_row_couplings(dest: Dictionary, source_emoji: String, couplings: Dictionary) -> void:
	if couplings.is_empty():
		return
	if not dest.has(source_emoji) or not (dest[source_emoji] is Dictionary):
		dest[source_emoji] = {}
	var row: Dictionary = dest[source_emoji]
	for target in couplings:
		row[target] = float(row.get(target, 0.0)) + float(couplings[target])


static func _add_coupling(current, incoming) -> Variant:
	if current == null:
		return incoming
	if current is Vector2 or incoming is Vector2:
		var c: Vector2 = current if current is Vector2 else Vector2(float(current), 0.0)
		var i: Vector2 = incoming if incoming is Vector2 else Vector2(float(incoming), 0.0)
		return c + i
	if current is Array and incoming is Array and current.size() == 2 and incoming.size() == 2:
		return [
			float(current[0]) + float(incoming[0]),
			float(current[1]) + float(incoming[1]),
		]
	return float(current) + float(incoming)


static func _rotate_coupling_phase(value, phase_delta: float):
	if value is Vector2:
		return Vector2(value.x, clampf(value.y + phase_delta, -1.0, 1.0))
	if value is Array and value.size() == 2:
		return [float(value[0]), clampf(float(value[1]) + phase_delta, -1.0, 1.0)]
	return value
