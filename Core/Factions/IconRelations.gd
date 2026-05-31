class_name IconRelations
extends RefCounted

## IconRelations — pure relations between icon records.
##
## Vocabulary (locked):
##   atom        = single emoji
##   cloud       = set of atoms (an icon's cloud = poles ∪ H-couplings ∪ E-couplings)
##   icon        = two-pole physics record
##   sibling     = pole-share between icons (depth-0 relation)
##
## NOTE: "Neighborhood" is NOT defined here. A neighborhood is a configured
## (biome, signature) cluster — that lives in AuthorityAdapter. The
## per-icon graph relations below are siblings (poles only) or
## siblings-via-cloud (poles touching the wider cloud).
##
## All inputs are icon record Dictionaries (as produced by IconRegistry):
##   {pole_0, pole_1, hamiltonian_couplings: {atom: float},
##    energy_couplings: {atom: float}, ...}
##
## No game state, no Node graph. Pure dict/array work.


## Cloud of one icon: poles ∪ H-coupling targets ∪ E-coupling targets.
## Returns Dictionary[atom → true] for O(1) membership checks.
func cloud_of(icon: Dictionary) -> Dictionary:
	var out := {}
	if icon == null or icon.is_empty():
		return out
	var p0 := str(icon.get("pole_0", ""))
	var p1 := str(icon.get("pole_1", ""))
	if p0 != "":
		out[p0] = true
	if p1 != "":
		out[p1] = true
	var hc = icon.get("hamiltonian_couplings", {})
	if hc is Dictionary:
		for k in hc.keys():
			out[str(k)] = true
	var ec = icon.get("energy_couplings", {})
	if ec is Dictionary:
		for k in ec.keys():
			out[str(k)] = true
	return out


## Sibling test: a and b share at least one pole atom.
func is_sibling(a: Dictionary, b: Dictionary) -> bool:
	if a == null or b == null:
		return false
	var ap0 := str(a.get("pole_0", ""))
	var ap1 := str(a.get("pole_1", ""))
	var bp0 := str(b.get("pole_0", ""))
	var bp1 := str(b.get("pole_1", ""))
	if ap0 != "" and (ap0 == bp0 or ap0 == bp1):
		return true
	if ap1 != "" and (ap1 == bp0 or ap1 == bp1):
		return true
	return false


## Helper: do icons a and b share the same pole-pair identity?
func _same_pair(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("pole_0", "")) == str(b.get("pole_0", "")) \
		and str(a.get("pole_1", "")) == str(b.get("pole_1", ""))


## All icons in `all` sharing a pole with `icon` (excluding self).
func siblings_of(icon: Dictionary, all: Array) -> Array:
	var out: Array = []
	for other in all:
		if not (other is Dictionary):
			continue
		if _same_pair(icon, other):
			continue
		if is_sibling(icon, other):
			out.append(other)
	return out


## Wider relation: icons in `all` whose poles touch any atom in cloud_of(icon),
## excluding self. NOT a "neighborhood" — neighborhood is a configured cluster.
func siblings_via_cloud_of(icon: Dictionary, all: Array) -> Array:
	var out: Array = []
	var cloud := cloud_of(icon)
	if cloud.is_empty():
		return out
	for other in all:
		if not (other is Dictionary):
			continue
		if _same_pair(icon, other):
			continue
		var op0 := str(other.get("pole_0", ""))
		var op1 := str(other.get("pole_1", ""))
		if (op0 != "" and cloud.has(op0)) or (op1 != "" and cloud.has(op1)):
			out.append(other)
	return out


## Union of cloud_of over a list of icons. Returns Dictionary[atom → true].
## Useful aggregate utility — does NOT mention faction in its name because
## a faction's cloud is one specific use of this; the function is general.
func union_of_clouds(icons: Array) -> Dictionary:
	var out := {}
	for ic in icons:
		if not (ic is Dictionary):
			continue
		var c := cloud_of(ic)
		for k in c.keys():
			out[k] = true
	return out
