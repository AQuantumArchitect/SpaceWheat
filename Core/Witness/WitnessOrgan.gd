extends Node

## WitnessOrgan — autoload owning the Witness's belief field: one small
## density-matrix cluster per DISCOVERED biome plus one self cluster, evolved
## by the dissipative-role law (relax toward uncertainty) and moved ONLY by
## weak observations of player-visible events (WitnessBridge is the sole
## feeder). Advisory by law: nothing in the game reads the Witness to gate,
## veto, or price anything — it exists to be PROJECTED (rig `witness_graph`,
## seat `look`, later a player-facing overlay).
##
## The architecture is umwelt's (~/ws/umwelt, the reference implementation);
## the substrate is SpaceWheat's own ComplexMatrix. Worlds as data: topology,
## rates, and bindings live in witness_spec.json.

const STRIDE_S := 0.2  # 5Hz decay stride — beliefs ease, they don't tick

var spec: Dictionary = {}
var clusters: Dictionary = {}      # node name → WitnessCluster
var observes_total: int = 0
var last_stride_ms: float = 0.0
var _spec_hash: String = ""
var _stride_accum: float = 0.0
var _unmatched: Dictionary = {}    # sensor/zone/role that matched nothing → count


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	spec = WitnessSpec.load_spec()
	if spec.is_empty():
		push_error("WitnessOrgan: spec failed to load — the Witness stays dark")
		return
	_spec_hash = WitnessSpec.spec_hash(spec)
	_ensure_self_cluster()


func _process(delta: float) -> void:
	if spec.is_empty() or clusters.is_empty():
		return
	if get_tree().paused:
		return
	_stride_accum += delta
	if _stride_accum < STRIDE_S:
		return
	var dt := _stride_accum
	_stride_accum = 0.0
	var t0 := Time.get_ticks_usec()
	for cname in clusters:
		clusters[cname].depolarize(dt)
	last_stride_ms = float(Time.get_ticks_usec() - t0) / 1000.0


func _ensure_self_cluster() -> void:
	if clusters.has("self"):
		return
	var node := WitnessSpec.find_node(spec, "self")
	if node.is_empty():
		push_error("WitnessOrgan: spec has no 'self' node")
		return
	clusters["self"] = WitnessCluster.new("self", node.get("roles", []),
		WitnessSpec.gamma_by_role(spec, node))


## Lazy-mint a biome cluster on first discovery — the Witness only believes
## in worlds the player has seen (player-parity by construction).
func ensure_biome_cluster(biome_name: String) -> void:
	if biome_name.is_empty():
		return
	var cname := "biome:%s" % biome_name
	if clusters.has(cname):
		return
	var node := WitnessSpec.instantiate_biome_node(spec, biome_name)
	if node.is_empty():
		return
	clusters[cname] = WitnessCluster.new(cname, node.get("roles", []),
		WitnessSpec.gamma_by_role(spec, node))


## The bridge's single entry: a weak observation of (node, role) toward Bloch
## (0, 0, z). Unknown targets are counted, never crash — ingest honesty: the
## graph's `unmatched` global shows what fired and found no belief axis.
func observe(node_name: String, role: String, target_z: float, alpha: float,
		confidence: float = 1.0) -> void:
	var cluster = clusters.get(node_name)
	if cluster == null or not cluster.role_index.has(role):
		var key := "%s.%s" % [node_name, role]
		_unmatched[key] = int(_unmatched.get(key, 0)) + 1
		return
	cluster.observe(role, Vector3(0.0, 0.0, clampf(target_z, -1.0, 1.0)), alpha, confidence)
	if alpha > 0.0:
		observes_total += 1


func total_qubits() -> int:
	var n := 0
	for cname in clusters:
		n += clusters[cname].n_qubits
	return n


func unmatched_snapshot() -> Dictionary:
	return {"count": _unmatched.size(), "recent": _unmatched.duplicate()}


func graph_state(compact: bool = true) -> Dictionary:
	if spec.is_empty():
		return {"version": 1, "topology": {"nodes": [], "edges": []}, "globals": [],
			"error": "witness spec failed to load"}
	return WitnessProjection.graph_state(self, compact)


func gauge() -> Dictionary:
	if spec.is_empty():
		return {}
	return WitnessProjection.gauge(self)


## ── persistence (called by GameStateSerializer) ─────────────────────────────

func to_save_dict() -> Dictionary:
	var cluster_saves := {}
	for cname in clusters:
		cluster_saves[cname] = clusters[cname].to_save_dict()
	return {
		"spec_hash": _spec_hash,
		"clusters": cluster_saves,
		"observes_total": observes_total,
		"surprise": {},  # phase 2: per-source innovation EMAs
	}


## Restore beliefs from a save. Spec drift or shape mismatch → cold boot
## (blank, one log line): forgetting is a legal state, corrupt belief is not.
func load_save_dict(saved: Dictionary) -> void:
	reset()
	if saved.is_empty():
		return  # pre-Witness save (v4) or fresh game — blank is correct
	if str(saved.get("spec_hash", "")) != _spec_hash:
		VerboseHelper.info("witness", "👁️",
			"Witness spec changed since save — beliefs cold-boot blank")
		return
	observes_total = int(saved.get("observes_total", 0))
	var cluster_saves = saved.get("clusters", {})
	if not (cluster_saves is Dictionary):
		return
	for cname_v in cluster_saves:
		var cname := str(cname_v)
		if cname.begins_with("biome:"):
			ensure_biome_cluster(cname.trim_prefix("biome:"))
		var cluster = clusters.get(cname)
		if cluster == null:
			continue
		if not cluster.from_save_dict(cluster_saves[cname]):
			cluster.reset()


## Blank the field (new session / pre-restore). The self cluster persists as
## an object but returns to maximal uncertainty.
func reset() -> void:
	observes_total = 0
	_unmatched.clear()
	_stride_accum = 0.0
	var biome_names := []
	for cname in clusters:
		if str(cname).begins_with("biome:"):
			biome_names.append(cname)
	for cname in biome_names:
		clusters.erase(cname)
	if clusters.has("self"):
		clusters["self"].reset()
	else:
		_ensure_self_cluster()
