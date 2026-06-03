class_name NeighborhoodGraph
extends RefCounted

## A first-class, navigable "body" for ONE neighborhood's quantum cluster — the
## 4-6 qubit reservoir realized by a biome × its icon-signature.
##
## It is a DERIVED VIEW over canonical data, never a parallel store: nodes come
## from the biome's realized icons (RegisterMap order), coherent edges from the
## icons.json Hamiltonian couplings, the directed "webway" edges from the biome's
## atom_components (Lindblad), and "ports" mark which node emojis are shared with
## OTHER factions — the seam into the wider emergent vocabulary graph (e.g. The
## Demos' 🌾 → the farming factions, 👥 → the labor factions). Rebuild it any
## time with `from_biome`; editing/write-back is a later, separate concern.
##
## Shapes:
##   node = {qubit:int, icon_name:String, north:String, south:String, self_energy:float}
##   edge = {from_qubit:int, to_qubit:int, from_emoji, to_emoji, kind, strength:float}
##          kind ∈ {"coherent" (undirected H), "webway" (directed L), "sink" (→🗑)}
##          to_qubit == -1 means the target is outside this cluster (a sink/outflow)
##   port = {qubit:int, emoji:String, neighbor_factions:Array[String]}

const SINK_EMOJI := "🗑"

var biome_name: String = ""
var nodes: Array = []
var edges: Array = []
var ports: Array = []
var _emoji_to_qubit: Dictionary = {}


## Derive the body from a biome (Biome data class or BiomeBase node). Registries
## are resolved lazily and may be injected (tests / headless). Pure read.
static func from_biome(biome, icon_registry = null, faction_registry = null) -> NeighborhoodGraph:
	var g := NeighborhoodGraph.new()
	if biome == null:
		return g
	g.biome_name = g._biome_name_of(biome)

	var icons: Array = biome.get_neighborhood_icons() if biome.has_method("get_neighborhood_icons") else []

	# --- Nodes: realized icons = qubits, in realize/allocate order ---
	var signature: Array = []
	for i in range(icons.size()):
		var ic = icons[i]
		if not (ic is Dictionary):
			continue
		var north := str(ic.get("pole_0", ""))
		var south := str(ic.get("pole_1", ""))
		g.nodes.append({
			"qubit": i,
			"icon_name": str(ic.get("name", "")),
			"north": north,
			"south": south,
			"self_energy": 0.0,
		})
		if north != "":
			g._emoji_to_qubit[north] = i
		if south != "":
			g._emoji_to_qubit[south] = i
		signature.append(north)
		signature.append(south)

	# --- Coherent edges (undirected H) + per-node self-energy, from icon physics ---
	var ir = icon_registry if icon_registry != null else g._resolve_icon_registry()
	if ir != null and ir.has_method("get_signature_physics"):
		var phys: Dictionary = ir.get_signature_physics(signature)
		var self_e: Dictionary = phys.get("self_energies", {})
		for n in g.nodes:
			n["self_energy"] = float(self_e.get(n["north"], 0.0)) + float(self_e.get(n["south"], 0.0))
		var ham: Dictionary = phys.get("hamiltonian", {})
		var seen: Dictionary = {}
		for src in ham.keys():
			var row = ham[src]
			if not (row is Dictionary):
				continue
			for tgt in row.keys():
				var qi: int = g._emoji_to_qubit.get(str(src), -1)
				var qj: int = g._emoji_to_qubit.get(str(tgt), -1)
				if qi < 0 or qj < 0 or qi == qj:
					continue  # only cross-qubit coherent couplings are inter-node edges
				var lo: int = mini(qi, qj)
				var hi: int = maxi(qi, qj)
				var key := "%d|%d" % [lo, hi]
				if seen.has(key):
					continue
				seen[key] = true
				g.edges.append({
					"from_qubit": lo, "to_qubit": hi,
					"from_emoji": str(src), "to_emoji": str(tgt),
					"kind": "coherent", "strength": g._coupling_mag(row[tgt]),
				})

	# --- Webway edges (directed L) from canonical atom_components ---
	var ac = biome.atom_components if ("atom_components" in biome and biome.atom_components is Dictionary) else {}
	for src_emoji in ac.keys():
		var comp = ac[src_emoji]
		if not (comp is Dictionary):
			continue
		var s := str(src_emoji)
		var outg = comp.get("lindblad_outgoing", {})
		if outg is Dictionary:
			for tgt in outg.keys():
				g._add_webway(s, str(tgt), float(outg[tgt]), "webway")
		var inc = comp.get("lindblad_incoming", {})
		if inc is Dictionary:
			for s2 in inc.keys():
				g._add_webway(str(s2), s, float(inc[s2]), "webway")
		var decay = comp.get("decay", {})
		if decay is Dictionary and decay.has("rate"):
			var dt := str(decay.get("target", SINK_EMOJI))
			g._add_webway(s, dt, float(decay.get("rate", 0.0)), "sink" if dt == SINK_EMOJI else "webway")

	# --- Vocabulary ports: node emojis shared with OTHER (non-native) factions ---
	var fr = faction_registry if faction_registry != null else g._resolve_faction_registry()
	if fr != null and fr.has_method("get_factions_for_emoji"):
		var own: Dictionary = {}
		var natives = biome.native_factions if ("native_factions" in biome and biome.native_factions is Array) else []
		for f in natives:
			own[str(f)] = true
		for n in g.nodes:
			for emoji in [n["north"], n["south"]]:
				if str(emoji) == "":
					continue
				var neigh: Array = []
				for fac in fr.get_factions_for_emoji(str(emoji)):
					var fname := (str(fac.name) if (fac != null and "name" in fac) else str(fac))
					if fname != "" and not own.has(fname) and not (fname in neigh):
						neigh.append(fname)
				if not neigh.is_empty():
					neigh.sort()
					g.ports.append({"qubit": int(n["qubit"]), "emoji": str(emoji), "neighbor_factions": neigh})

	return g


func _add_webway(from_emoji: String, to_emoji: String, rate: float, kind: String) -> void:
	if rate <= 0.0:
		return
	var qi: int = _emoji_to_qubit.get(from_emoji, -1)
	if qi < 0:
		return  # source must be a realized node in this cluster
	var qj: int = _emoji_to_qubit.get(to_emoji, -1)  # -1 = sink / out-of-cluster
	edges.append({
		"from_qubit": qi, "to_qubit": qj,
		"from_emoji": from_emoji, "to_emoji": to_emoji,
		"kind": ("sink" if (kind == "sink" or qj < 0 and to_emoji == SINK_EMOJI) else kind),
		"strength": rate,
	})


## Magnitude of a coupling value (float | Vector2 | [re, im]).
func _coupling_mag(v) -> float:
	if v is Vector2:
		return v.length()
	if v is Array and v.size() == 2:
		return sqrt(float(v[0]) * float(v[0]) + float(v[1]) * float(v[1]))
	return absf(float(v))


func _biome_name_of(biome) -> String:
	if "name" in biome and str(biome.name) != "":
		return str(biome.name)
	if biome.has_method("get_biome_type"):
		return str(biome.get_biome_type())
	return "?"


func _resolve_icon_registry():
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	var reg = root.get_node_or_null("/root/IconRegistry") if root else null
	if reg != null:
		return reg
	return load("res://Core/Factions/IconRegistry.gd").new()


func _resolve_faction_registry():
	var fr = load("res://Core/Factions/FactionRegistry.gd")
	if fr != null and fr.has_method("get_shared"):
		return fr.get_shared()
	return null


# --- Navigation API ---

func node_count() -> int:
	return nodes.size()


func get_node(qubit: int):
	for n in nodes:
		if int(n["qubit"]) == qubit:
			return n
	return null


## Qubits coherently/dissipatively connected to `qubit` (excludes sinks).
func neighbors_of(qubit: int) -> Array:
	var out: Array = []
	for e in edges:
		if int(e["to_qubit"]) < 0:
			continue
		if int(e["from_qubit"]) == qubit and not (int(e["to_qubit"]) in out):
			out.append(int(e["to_qubit"]))
		elif int(e["to_qubit"]) == qubit and not (int(e["from_qubit"]) in out):
			out.append(int(e["from_qubit"]))
	return out


func ports_for(qubit: int) -> Array:
	var out: Array = []
	for p in ports:
		if int(p["qubit"]) == qubit:
			out.append(p)
	return out


func to_dict() -> Dictionary:
	return {
		"biome": biome_name,
		"nodes": nodes.duplicate(true),
		"edges": edges.duplicate(true),
		"ports": ports.duplicate(true),
	}
