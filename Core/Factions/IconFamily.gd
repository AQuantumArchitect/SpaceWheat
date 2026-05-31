class_name IconFamily
extends RefCounted

## IconFamily — atom-keyed icon lookup.
##
## Vocabulary (locked):
##   atom            = single emoji
##   family(atom)    = every named (non-anonymous) icon whose poles include `atom`
##
## This is the atom-side inverse of IconRelations.cloud_of: cloud_of(icon)
## returns atoms touched by the icon; family_of(atom) returns icons that
## touch the atom (by pole).
##
## Body scans IconRegistry.get_all() once per call and caches per-instance.
## Cheap: there are only a few hundred icons.


var _by_atom: Dictionary = {}    # atom -> Array[icon record]
var _built_for = null            # WeakRef-able lexicon — invalidate on swap


## Family of an atom: every named icon whose poles include `atom`.
## Returns Array[Dictionary]. Empty if no icon contains the atom.
func family_of(atom: String, lexicon = null) -> Array:
	if atom == "":
		return []
	_ensure_index(lexicon)
	return _by_atom.get(atom, [])


## Union of family(a) over a set of atoms (Dictionary[atom → true] OR Array).
## Returns Array[Dictionary], deduped on (pole_0, pole_1) pair.
func family_of_cloud(cloud, lexicon = null) -> Array:
	_ensure_index(lexicon)
	var atoms_iter
	if cloud is Dictionary:
		atoms_iter = cloud.keys()
	elif cloud is Array:
		atoms_iter = cloud
	else:
		return []
	var seen := {}
	var out: Array = []
	for a in atoms_iter:
		var fam: Array = _by_atom.get(str(a), [])
		for ic in fam:
			var key := "%s|%s" % [str(ic.get("pole_0", "")), str(ic.get("pole_1", ""))]
			if seen.has(key):
				continue
			seen[key] = true
			out.append(ic)
	return out


## Resolve the lexicon and (re)build the atom→icons index if needed.
## Cheap to call repeatedly — the index is keyed by lexicon identity.
func _ensure_index(lexicon = null) -> void:
	if lexicon == null:
		lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if lexicon == null:
		lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if _built_for == lexicon and not _by_atom.is_empty():
		return
	_built_for = lexicon
	_by_atom.clear()
	for record in lexicon.get_all():
		if not (record is Dictionary):
			continue
		if record.get("anonymous", false):
			continue
		for pole_key in ["pole_0", "pole_1"]:
			var atom := str(record.get(pole_key, ""))
			if atom == "":
				continue
			if not _by_atom.has(atom):
				_by_atom[atom] = []
			# A record contributes to its own pole-0 and pole-1 entries; if
			# poles are equal, dedupe so we don't list the same icon twice.
			var bucket: Array = _by_atom[atom]
			var dup := false
			for existing in bucket:
				if existing.get("pole_0", "") == record.get("pole_0", "") \
						and existing.get("pole_1", "") == record.get("pole_1", ""):
					dup = true
					break
			if not dup:
				bucket.append(record)
