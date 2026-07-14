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
var surprise: Dictionary = {}      # source → {ema, n, node, role} — innovation ledger
var _spec_hash: String = ""
var _stride_accum: float = 0.0
var _unmatched: Dictionary = {}    # sensor/zone/role that matched nothing → count

# Innovation EMA rate + the frozen-world alarm: a source that keeps reporting
# (n ≥ ALARM_MIN_N) yet never surprises its own belief (ema < ALARM_EMA) is
# the frozen-Born signature — honest randomness keeps innovations high
# because the belief settles mid-range while outcomes land at ±1.
const SURPRISE_EMA_RATE := 0.15
const ALARM_MIN_N := 12
const ALARM_EMA := 0.15


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
		clusters[cname].stride(dt)
	last_stride_ms = float(Time.get_ticks_usec() - t0) / 1000.0


func _ensure_self_cluster() -> void:
	if clusters.has("self"):
		return
	var node := WitnessSpec.find_node(spec, "self")
	if node.is_empty():
		push_error("WitnessOrgan: spec has no 'self' node")
		return
	var cluster := WitnessCluster.new("self", node.get("roles", []),
		WitnessSpec.gamma_by_role(spec, node))
	cluster.couplings = WitnessSpec.couplings_for(node)
	clusters["self"] = cluster


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
	var cluster := WitnessCluster.new(cname, node.get("roles", []),
		WitnessSpec.gamma_by_role(spec, node))
	cluster.couplings = WitnessSpec.couplings_for(node)
	clusters[cname] = cluster


## The bridge's single entry: a weak observation of (node, role) toward Bloch
## (0, 0, z). Unknown targets are counted, never crash — ingest honesty: the
## graph's `unmatched` global shows what fired and found no belief axis.
## `source` stamps the innovation ledger (surprise tape, umwelt-style): the
## innovation is |target − belief| BEFORE the update — how much this
## observation disagreed with what the field already believed.
func observe(node_name: String, role: String, target_z: float, alpha: float,
		confidence: float = 1.0, source: String = "") -> void:
	var cluster = clusters.get(node_name)
	if cluster == null or not cluster.role_index.has(role):
		var key := "%s.%s" % [node_name, role]
		_unmatched[key] = int(_unmatched.get(key, 0)) + 1
		return
	var z := clampf(target_z, -1.0, 1.0)
	if alpha > 0.0 and not source.is_empty():
		var innovation: float = absf(z - cluster.role_bloch(role).z)
		var entry: Dictionary = surprise.get(source, {"ema": innovation, "n": 0})
		entry["ema"] = lerpf(float(entry["ema"]), innovation, SURPRISE_EMA_RATE)
		entry["n"] = int(entry["n"]) + 1
		entry["node"] = node_name
		entry["role"] = role
		surprise[source] = entry
	cluster.observe(role, Vector3(0.0, 0.0, z), alpha, confidence)
	if alpha > 0.0:
		observes_total += 1


## The frozen-world alarm (regression smoke detector): sources that report
## steadily but never surprise a SATURATED belief. The frozen-Born bug
## (always-wheat) has exactly this shape; honest randomness cannot.
func surprise_alarms() -> Array:
	var alarms := []
	for source in surprise:
		var entry: Dictionary = surprise[source]
		if int(entry.get("n", 0)) < ALARM_MIN_N or float(entry.get("ema", 1.0)) >= ALARM_EMA:
			continue
		var cluster = clusters.get(str(entry.get("node", "")))
		if cluster == null:
			continue
		if absf(cluster.role_bloch(str(entry.get("role", ""))).z) > 0.85:
			alarms.append(str(source))
	alarms.sort()
	return alarms


## Dream the belief field forward under its OWN dynamics (couplings + decay),
## side-effect-free: snapshot ρ, stride, read, restore. Forecasts BELIEFS —
## never ground truth (the parity membrane holds in the future too).
## leaves: Array of [node_name, role]; returns {"node.role": z_at_horizon}.
func forecast(leaves: Array, horizon_s: float) -> Dictionary:
	var out := {}
	var by_cluster := {}
	for leaf in leaves:
		if leaf is Array and leaf.size() == 2:
			var node := str(leaf[0])
			if not by_cluster.has(node):
				by_cluster[node] = []
			by_cluster[node].append(str(leaf[1]))
	for node in by_cluster:
		var cluster = clusters.get(node)
		if cluster == null:
			continue
		var snapshot: PackedFloat64Array = cluster.rho._to_packed().duplicate()
		var remaining := clampf(horizon_s, 0.0, 3600.0)
		while remaining > 0.0:
			var dt := minf(remaining, STRIDE_S)
			cluster.stride(dt)
			remaining -= dt
		for role in by_cluster[node]:
			out["%s.%s" % [node, role]] = snappedf(cluster.role_bloch(role).z, 0.001)
		cluster.rho._from_packed(snapshot, cluster.dim)
	return out


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
		"surprise": surprise.duplicate(true),
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
	if saved.get("surprise") is Dictionary:
		surprise = (saved.get("surprise") as Dictionary).duplicate(true)
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
	surprise.clear()
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
