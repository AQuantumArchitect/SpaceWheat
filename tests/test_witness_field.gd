extends SceneTree

## Witness belief-field verification (Core/Witness) — the physics contracts
## ported from umwelt (~/ws/umwelt, the reference implementation):
##   1. Weak observe: α=0 is a PROVABLE no-op (η=0 theorem) — packed-ρ hash
##      identical, confidence still recorded; α=1 collapses the marginal to
##      the target; untouched-pair correlations survive; Bloch-ball clamp.
##   2. Dissipative-role law: pump-then-silence decays toward z=0 at the
##      gamma_diss timescale; I/dim is the fixed point; per-role override
##      wins; a bare "gamma" key does NOTHING (the umwelt gamma trap, pinned).
##   3. Spec: loads + validates; >6-qubit nodes rejected; template
##      instantiation mints biome:<name> nodes.
##   4. Gauge: blank-field gauges are byte-identical (diff-stable); one
##      observe diffs exactly the touched role.
##   5. Serialize: save→load preserves the ρ canon hash; shape mismatch
##      cold-boots blank.
##   6. graph_state: v1 schema complete, glyphs for every role.
##
## Run: godot --headless --script tests/test_witness_field.gd

var passed = 0
var failed = 0

const EPS = 1e-9
const DIVIDER = "============================================================"


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  ✓ %s" % name)
	else:
		failed += 1
		print("  ✗ %s %s" % [name, detail])


func _init():
	print("\n" + DIVIDER)
	print("WITNESS BELIEF-FIELD VERIFICATION")
	print(DIVIDER)

	_test_weak_observe()
	_test_dissipative_relax()
	_test_spec()
	_test_gauge_stability()
	_test_serialize()
	_test_graph_projection()

	print("\n" + DIVIDER)
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	print(DIVIDER)
	quit(0 if failed == 0 else 1)


func _cluster3() -> WitnessCluster:
	return WitnessCluster.new("test", ["a", "b", "c"], {"a": 0.1, "b": 0.1, "c": 0.1})


func _test_weak_observe() -> void:
	print("\n-- weak observe (umwelt observe_qubit semantics)")
	var cl := _cluster3()

	# α=0 provable no-op, confidence still recorded
	var h0 := cl.canon_hash()
	cl.observe("b", Vector3(0, 0, 1), 0.0, 0.42)
	check("alpha=0 leaves rho untouched (hash-pinned)", cl.canon_hash() == h0)
	check("alpha=0 still records confidence", absf(float(cl.obs_confidence.get("b", -1.0)) - 0.42) < EPS)

	# α=1 collapses the marginal to the target
	cl.observe("b", Vector3(0, 0, 1), 1.0)
	var b := cl.role_bloch("b")
	check("alpha=1 collapses marginal to target", b.distance_to(Vector3(0, 0, 1)) < 1e-6,
		"got %s" % str(b))
	check("other roles untouched by collapse", cl.role_bloch("a").length() < 1e-6
		and cl.role_bloch("c").length() < 1e-6)
	check("trace stays 1", absf(cl.rho.trace().re - 1.0) < 1e-9)

	# partial α moves partway
	var cl2 := _cluster3()
	cl2.observe("a", Vector3(0, 0, 1), 0.5)
	var za := cl2.role_bloch("a").z
	check("alpha=0.5 moves belief halfway (z=0.5)", absf(za - 0.5) < 1e-6, "z=%f" % za)

	# correlations among untouched roles preserved: correlate b,c via joint
	# observation, then observe a — <σz_b σz_c> must survive.
	var cl3 := _cluster3()
	cl3.observe("b", Vector3(0, 0, 1), 1.0)
	cl3.observe("c", Vector3(0, 0, 1), 1.0)
	var zz_before := _zz_corr(cl3, "b", "c")
	cl3.observe("a", Vector3(0, 0, -1), 0.7)
	var zz_after := _zz_corr(cl3, "b", "c")
	check("untouched-pair <zz> preserved through observe", absf(zz_before - zz_after) < 1e-9,
		"%f -> %f" % [zz_before, zz_after])

	# Bloch-ball clamp: |target|>1 lands ON the sphere, still a valid rho
	var cl4 := _cluster3()
	cl4.observe("a", Vector3(0, 0, 3.0), 1.0)
	check("out-of-ball target is clamped to sphere", absf(cl4.role_bloch("a").z - 1.0) < 1e-6)
	check("clamped observe keeps purity <= 1", cl4.purity() <= 1.0 + 1e-9)

	# unknown role: error path, rho untouched
	var cl5 := _cluster3()
	var h5 := cl5.canon_hash()
	cl5.observe("nope", Vector3(0, 0, 1), 1.0)
	check("unknown role leaves rho untouched", cl5.canon_hash() == h5)


func _zz_corr(cl: WitnessCluster, ra: String, rb: String) -> float:
	# <σz_a σz_b> read straight off the packed diagonal.
	var packed = cl.rho._to_packed()
	var qa: int = cl.role_index[ra]
	var qb: int = cl.role_index[rb]
	var sa: int = cl.n_qubits - 1 - qa
	var sb: int = cl.n_qubits - 1 - qb
	var s := 0.0
	for i in range(cl.dim):
		var za := 1.0 if ((i >> sa) & 1) == 0 else -1.0
		var zb := 1.0 if ((i >> sb) & 1) == 0 else -1.0
		s += za * zb * packed[(i * cl.dim + i) * 2]
	return s


func _test_dissipative_relax() -> void:
	print("\n-- dissipative-role law (depolarize toward I/dim)")
	var cl := WitnessCluster.new("relax", ["fast", "slow"], {"fast": 1.0, "slow": 0.01})
	cl.observe("fast", Vector3(0, 0, 1), 1.0)
	cl.observe("slow", Vector3(0, 0, 1), 1.0)

	# fixed point: a blank cluster stays blank under decay
	var blank := WitnessCluster.new("blank", ["x"], {"x": 5.0})
	var hb := blank.canon_hash()
	blank.depolarize(10.0)
	check("I/dim is the fixed point (blank stays blank)", blank.canon_hash() == hb)

	# pump-then-silence decays at the declared timescale: z(t) = z0·exp(−γt)
	cl.depolarize(1.0)
	var zf := cl.role_bloch("fast").z
	var zs := cl.role_bloch("slow").z
	check("gamma=1 decays z to ~exp(-1)", absf(zf - exp(-1.0)) < 1e-6, "z=%f" % zf)
	check("per-role gamma respected (slow barely moves)", absf(zs - exp(-0.01)) < 1e-6, "z=%f" % zs)
	check("decay heads toward z=0, never overshoots", zf > 0.0 and zs > zf)

	# the umwelt gamma trap: a bare "gamma" key must do NOTHING
	var spec := WitnessSpec.load_spec()
	var trap_node := {"name": "trap", "roles": ["r"], "params": {"gamma": 99.0}}
	var gammas := WitnessSpec.gamma_by_role(spec, trap_node)
	var expected_default := float(spec.get("defaults", {}).get("gamma_diss", 0.02))
	check("bare 'gamma' key is inert (gamma_diss is the real knob)",
		absf(float(gammas.get("r", -1.0)) - expected_default) < EPS,
		"got %s" % str(gammas))


func _test_spec() -> void:
	print("\n-- spec load / validate / template")
	var spec := WitnessSpec.load_spec()
	check("shipping spec loads and validates", not spec.is_empty())
	check("spec has a self node", not WitnessSpec.find_node(spec, "self").is_empty())
	check("spec has a template node", not WitnessSpec.template_node(spec).is_empty())

	var minted := WitnessSpec.instantiate_biome_node(spec, "StarterForest")
	check("template mints biome:StarterForest", str(minted.get("name", "")) == "biome:StarterForest")
	check("minted node is no longer a template", not minted.has("template"))

	var too_big := {"version": 1, "nodes": [
		{"name": "fat", "roles": ["a", "b", "c", "d", "e", "f", "g"]}]}
	check(">6-role node rejected", not WitnessSpec.validate(too_big))
	var bad_mode := {"version": 1, "nodes": [
		{"name": "n", "roles": ["a"], "role_modes": {"a": "psychic"}}]}
	check("unknown role_mode rejected", not WitnessSpec.validate(bad_mode))


func _test_gauge_stability() -> void:
	print("\n-- gauge diff-stability")
	# Script-mode run has no autoloads — exercise the organ off-tree.
	var organ = load("res://Core/Witness/WitnessOrgan.gd").new()
	organ.spec = WitnessSpec.load_spec()
	organ._spec_hash = WitnessSpec.spec_hash(organ.spec)
	organ._ensure_self_cluster()
	organ.reset()
	organ.ensure_biome_cluster("StarterForest")
	var g1 := JSON.stringify(organ.gauge(), "", true)
	var g2 := JSON.stringify(organ.gauge(), "", true)
	check("blank-field gauges are byte-identical", g1 == g2)
	organ.observe("biome:StarterForest", "yield", 1.0, 0.4)
	var g3 := JSON.stringify(organ.gauge(), "", true)
	check("one observe changes the gauge", g1 != g3)
	check("only the touched cluster differs", _gauge_diff_clusters(
		organ.gauge()["clusters"], JSON.parse_string(g1)["clusters"]) == ["biome:StarterForest"])
	organ.free()


func _gauge_diff_clusters(a: Dictionary, b: Dictionary) -> Array:
	var diff := []
	for k in a:
		if not b.has(k) or JSON.stringify(a[k], "", true) != JSON.stringify(b[k], "", true):
			diff.append(str(k))
	diff.sort()
	return diff


func _test_serialize() -> void:
	print("\n-- serialize round-trip")
	var cl := _cluster3()
	cl.observe("a", Vector3(0, 0, 0.8), 0.6, 0.9)
	cl.observe("c", Vector3(0, 0, -0.5), 0.3)
	var h := cl.canon_hash()
	var saved := cl.to_save_dict()

	var cl2 := _cluster3()
	check("from_save_dict accepts a matching shape", cl2.from_save_dict(saved))
	check("rho canon hash survives round-trip", cl2.canon_hash() == h)
	check("confidence ledger survives round-trip",
		absf(float(cl2.obs_confidence.get("a", -1.0)) - 0.9) < EPS)

	var wrong := WitnessCluster.new("other", ["x", "y"], {})
	check("shape mismatch refuses (stays blank)", not wrong.from_save_dict(saved))


func _test_graph_projection() -> void:
	print("\n-- graph_state v1 projection")
	var organ = load("res://Core/Witness/WitnessOrgan.gd").new()
	organ.spec = WitnessSpec.load_spec()
	organ._spec_hash = WitnessSpec.spec_hash(organ.spec)
	organ._ensure_self_cluster()
	organ.ensure_biome_cluster("StarterForest")
	organ.observe("biome:StarterForest", "outcome", 1.0, 0.5)

	var g = organ.graph_state(true)
	check("graph version == 1", int(g.get("version", 0)) == 1)
	var nodes: Array = g.get("topology", {}).get("nodes", [])
	check("graph has witness + self + biome nodes", nodes.size() == 3)
	var required := ["path", "name", "kind", "depth", "is_leaf", "parent",
		"children", "roles", "grid_pos", "organs"]
	var complete := true
	for node in nodes:
		for key in required:
			if not node.has(key):
				complete = false
	check("every node carries the full v1 field set", complete)
	var known_organs := ["bloch_cluster"]
	var organs_ok := true
	var glyphs_ok := true
	for node in nodes:
		for organ_entry in node.get("organs", []):
			if not known_organs.has(str(organ_entry.get("type", ""))):
				organs_ok = false
			var glyphs = organ_entry.get("glyphs", {})
			for role in node.get("roles", []):
				if not glyphs.has(role):
					glyphs_ok = false
	check("organ types all known", organs_ok)
	check("every role has an emoji glyph", glyphs_ok)
	var globals_types := []
	for gl in g.get("globals", []):
		globals_types.append(str(gl.get("type", "")))
	check("globals carry ingest + summary", globals_types.has("ingest") and globals_types.has("summary"))
	var compact_size := JSON.stringify(g).length()
	check("compact graph under 2KB with one biome", compact_size < 2048, "%d bytes" % compact_size)
	organ.free()
