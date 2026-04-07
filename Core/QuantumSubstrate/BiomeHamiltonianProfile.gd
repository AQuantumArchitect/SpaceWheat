class_name BiomeHamiltonianProfile
extends RefCounted

## BiomeHamiltonianProfile — biome-crafter's Hamiltonian tuning surface
##
## Loads a per-biome JSONL file from res://Core/Config/Hamiltonians/<biome_lower>.jsonl
## and applies it as an icon_patch_fn in BiomeBuilder.
##
## This layer is INDEPENDENT of the faction system:
##   Faction icons define global quantum physics (universal Hamiltonian)
##   This layer defines biome-local energy landscape (self-energies, couplings, drivers)
##
## Three roles interact with this surface:
##   Biome Crafter  — edits the JSONL to sculpt ecosystem dynamics
##   Gate Architect — probes eigenspectrum + gate trajectories through this landscape
##   Runner         — plays in the resulting state without needing H details
##
## JSONL format:
##   {"op":"set","path":"self_energies.<emoji>","value":<float>}
##   {"op":"set","path":"couplings.<source_emoji>.<target_emoji>","value":<float>}
##   {"op":"set","path":"drivers.<emoji>.type","value":"cosine"|"sine"|"pulse"}
##   {"op":"set","path":"drivers.<emoji>.frequency","value":<float>}   # Hz
##   {"op":"set","path":"drivers.<emoji>.phase","value":<float>}       # radians
##   {"op":"set","path":"drivers.<emoji>.amplitude","value":<float>}   # multiplier
##
## Profile values ADD to faction-derived values; they do not replace them.
## Exception: drivers OVERRIDE (a biome crafter setting a driver wins over faction).

var self_energies: Dictionary = {}  ## {emoji: float} — adds to H diagonal
var couplings: Dictionary = {}       ## {source: {target: float}} — adds to H off-diagonal
var drivers: Dictionary = {}         ## {emoji: {type, frequency, phase, amplitude}}
var _biome_name: String = ""

## ─── Loading ──────────────────────────────────────────────────────────────────

## Load profile for a biome by name (returns empty profile if no JSONL found)
static func load_for_biome(biome_name: String) -> BiomeHamiltonianProfile:
	var ProfileClass = load("res://Core/QuantumSubstrate/BiomeHamiltonianProfile.gd")
	var profile: BiomeHamiltonianProfile = ProfileClass.new()
	profile._biome_name = biome_name

	var path = "res://Core/Config/Hamiltonians/%s.jsonl" % biome_name.to_lower()
	if not FileAccess.file_exists(path):
		return profile  # Empty profile — no-op

	var raw = FileAccess.get_file_as_string(path)
	if raw.strip_edges() == "":
		return profile

	var data: Dictionary = {"self_energies": {}, "couplings": {}, "drivers": {}}

	for line in raw.split("\n"):
		var stripped = line.strip_edges()
		if stripped == "" or stripped.begins_with("#"):
			continue
		var row = JSON.parse_string(stripped)
		if not row is Dictionary:
			continue
		var op = str(row.get("op", ""))
		var path_str = str(row.get("path", ""))
		var value = row.get("value", null)
		if op == "set" and path_str != "" and value != null:
			_set_nested(data, path_str, value)

	profile.self_energies = data.get("self_energies", {})
	profile.couplings = data.get("couplings", {})
	profile.drivers = data.get("drivers", {})
	return profile


## ─── Icon Patch ───────────────────────────────────────────────────────────────

## Apply this profile to an icons dict (suitable as icon_patch_fn target)
## Called AFTER faction icons are built so this adds on top of faction physics.
func apply_to_icons(icons: Dictionary) -> void:
	# Self-energies: additive (biome energy landscape on top of faction baseline)
	for emoji in self_energies:
		var icon = icons.get(emoji, null)
		if icon:
			icon.self_energy += float(self_energies[emoji])

	# Couplings: additive (biome coherent exchange on top of faction couplings)
	for source_emoji in couplings:
		var icon = icons.get(source_emoji, null)
		if not icon:
			continue
		var target_map = couplings[source_emoji]
		if not target_map is Dictionary:
			continue
		for target_emoji in target_map:
			var delta = float(target_map[target_emoji])
			var current = icon.hamiltonian_couplings.get(target_emoji, 0.0)
			# Faction couplings can be float or Vector2 (re+im). Add to real part.
			if current is Vector2:
				icon.hamiltonian_couplings[target_emoji] = Vector2(current.x + delta, current.y)
			else:
				icon.hamiltonian_couplings[target_emoji] = float(current) + delta

	# Drivers: override (biome crafter's intent beats faction default)
	for emoji in drivers:
		var icon = icons.get(emoji, null)
		if not icon:
			continue
		var drv = drivers[emoji]
		if not drv is Dictionary:
			continue
		var drv_type = str(drv.get("type", ""))
		if drv_type != "":
			icon.self_energy_driver = drv_type
			icon.driver_frequency = float(drv.get("frequency", 0.05))
			icon.driver_phase = float(drv.get("phase", 0.0))
			icon.driver_amplitude = float(drv.get("amplitude", 1.0))
			icon.is_driver = true
			icon.is_eternal = true  # Driven emojis never decay

## Return a Callable wrapping apply_to_icons (for use as icon_patch_fn)
func get_patch_callable() -> Callable:
	return Callable(self, "apply_to_icons")

## True if this profile has no content (JSONL not found or empty)
func is_empty() -> bool:
	return self_energies.is_empty() and couplings.is_empty() and drivers.is_empty()

## Human-readable summary for debug/architect inspection
func describe() -> String:
	return "[BiomeHamiltonianProfile:%s | %d energies, %d couplings, %d drivers]" % [
		_biome_name,
		self_energies.size(),
		couplings.size(),
		drivers.size()
	]


## ─── Internals ────────────────────────────────────────────────────────────────

## Recursively set a dot-separated path in a nested Dictionary.
## e.g. _set_nested(d, "couplings.☀.🌙", 0.8) → d.couplings["☀"]["🌙"] = 0.8
static func _set_nested(data: Dictionary, path_str: String, value) -> void:
	var parts = path_str.split(".")
	if parts.size() == 0:
		return
	var node = data
	for i in range(parts.size() - 1):
		var part = parts[i]
		if not node.has(part) or not node[part] is Dictionary:
			node[part] = {}
		node = node[part]
	node[parts[parts.size() - 1]] = value
