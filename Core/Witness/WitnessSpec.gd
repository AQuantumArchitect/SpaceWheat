class_name WitnessSpec
extends RefCounted

## Loader/validator for the Witness's world-as-data spec (witness_spec.json,
## umwelt DomainSpec shape). Worlds are DATA: topology, roles, dissipation
## rates, and sensor bindings all live in the JSON; this file only knows how
## to read, validate, and instantiate it. Validation fails LOUD (push_error +
## empty return) — a half-loaded world model is worse than none.
##
## The one post-build transform (flagged in the spec itself, per umwelt's law):
## the `"template": true` biome node is minted per DISCOVERED biome at runtime
## via instantiate_biome_node() — the Witness only believes in worlds the
## player has seen.

const SPEC_PATH := "res://Core/Witness/witness_spec.json"
const MAX_ROLES_PER_NODE := 6
const VALID_ROLE_MODES := ["unitary", "dissipative"]


static func load_spec(path: String = SPEC_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("WitnessSpec: spec file missing at %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("WitnessSpec: %s is not valid JSON" % path)
		return {}
	if not validate(parsed):
		return {}
	return parsed


static func validate(spec: Dictionary) -> bool:
	if int(spec.get("version", 0)) != 1:
		push_error("WitnessSpec: unsupported spec version %s" % str(spec.get("version")))
		return false
	var nodes = spec.get("nodes", [])
	if not (nodes is Array) or nodes.is_empty():
		push_error("WitnessSpec: spec has no nodes")
		return false
	var names := {}
	for node in nodes:
		if not (node is Dictionary):
			push_error("WitnessSpec: node entry is not a dict")
			return false
		var name := str(node.get("name", ""))
		if name.is_empty() or names.has(name):
			push_error("WitnessSpec: missing or duplicate node name '%s'" % name)
			return false
		names[name] = true
		var roles = node.get("roles", [])
		if not (roles is Array):
			push_error("WitnessSpec: node %s roles is not an array" % name)
			return false
		if roles.size() > MAX_ROLES_PER_NODE:
			push_error("WitnessSpec: node %s has %d roles — cap is %d qubits (dim 2^n)"
				% [name, roles.size(), MAX_ROLES_PER_NODE])
			return false
		var modes = node.get("role_modes", {})
		if modes is Dictionary:
			for role in modes:
				if not VALID_ROLE_MODES.has(str(modes[role])):
					push_error("WitnessSpec: node %s role %s has unknown mode '%s'"
						% [name, role, str(modes[role])])
					return false
	for binding in spec.get("bindings", []):
		if not (binding is Dictionary) or str(binding.get("sensor_id", "")).is_empty():
			push_error("WitnessSpec: binding without sensor_id")
			return false
	return true


## Stable content hash of the spec — persisted saves carry it; a mismatch on
## restore means the world's shape changed and beliefs cold-boot (forgetting
## is legal; loading old beliefs into a reshaped topology is not).
static func spec_hash(spec: Dictionary) -> String:
	return JSON.stringify(spec, "", true).md5_text()


static func find_node(spec: Dictionary, name: String) -> Dictionary:
	for node in spec.get("nodes", []):
		if str(node.get("name", "")) == name:
			return node
	return {}


static func template_node(spec: Dictionary) -> Dictionary:
	for node in spec.get("nodes", []):
		if bool(node.get("template", false)):
			return node
	return {}


## Mint a concrete biome node from the template: name `biome:<biome_name>`.
static func instantiate_biome_node(spec: Dictionary, biome_name: String) -> Dictionary:
	var tpl := template_node(spec)
	if tpl.is_empty():
		push_error("WitnessSpec: no template node in spec")
		return {}
	var node := tpl.duplicate(true)
	node.erase("template")
	node["name"] = "biome:%s" % biome_name
	return node


## E2 decay-variant lane (gamma research): WITNESS_GAMMA_SCALE multiplies
## every gamma_diss uniformly — the belief field's confidence half-life ladder
## for A/B on live runners. Unset/empty/non-positive → 1.0, the authored spec.
## The gauge stamps the scale so every banked tape self-describes its variant.
static func gamma_scale() -> float:
	var raw := OS.get_environment("WITNESS_GAMMA_SCALE")
	if raw.is_empty():
		return 1.0
	var s := raw.to_float()
	return s if s > 0.0 else 1.0


## role → gamma_diss for a node: per-role `gamma_diss_<role>` wins over the
## node's `gamma_diss`, which wins over spec defaults. NOTE the umwelt gamma
## trap, honored here: a bare "gamma" key does NOTHING by design.
static func gamma_by_role(spec: Dictionary, node: Dictionary) -> Dictionary:
	var defaults = spec.get("defaults", {})
	var params = node.get("params", {})
	var base := float(params.get("gamma_diss", defaults.get("gamma_diss", 0.02)))
	var scale := gamma_scale()
	var out := {}
	for role in node.get("roles", []):
		out[str(role)] = float(params.get("gamma_diss_%s" % str(role), base)) * scale
	return out


## Intra-node exchange couplings from spec data: [{roles: [a, b], j}] →
## [{a, b, j}] with both roles verified against the node.
static func couplings_for(node: Dictionary) -> Array:
	var out := []
	var node_roles: Array = node.get("roles", [])
	for coupling in node.get("couplings", []):
		if not (coupling is Dictionary):
			continue
		var pair = coupling.get("roles", [])
		if not (pair is Array) or pair.size() != 2:
			push_error("WitnessSpec: coupling needs exactly 2 roles: %s" % str(coupling))
			continue
		if not (node_roles.has(pair[0]) and node_roles.has(pair[1])):
			push_error("WitnessSpec: coupling roles %s not on node %s"
				% [str(pair), str(node.get("name"))])
			continue
		out.append({"a": str(pair[0]), "b": str(pair[1]), "j": float(coupling.get("j", 0.0))})
	return out


static func binding_for(spec: Dictionary, sensor_id: String) -> Dictionary:
	for binding in spec.get("bindings", []):
		if str(binding.get("sensor_id", "")) == sensor_id:
			return binding
	return {}


## The binding's collapse strength — umwelt BindingSpec.measurement_alpha():
## strength·efficiency (k·η) when both set, else collapse_alpha, else default.
static func binding_alpha(spec: Dictionary, binding: Dictionary) -> float:
	if binding.has("strength") and binding.has("efficiency"):
		return float(binding["strength"]) * float(binding["efficiency"])
	var defaults = spec.get("defaults", {})
	return float(binding.get("collapse_alpha", defaults.get("collapse_alpha", 0.3)))


## Normalize a raw signal value to a Bloch z target per the binding's declared
## normalizer (data, not code): unit_pos → +1, unit_neg → −1,
## {type: tanh, scale} → tanh(v/scale), {type: signed_clamp, scale} →
## sign(v)·min(1,|v|/scale). measurement_polarity is resolved by the CALLER
## (it needs the plot's remembered axis, not just the value).
static func normalize(binding: Dictionary, value: float) -> float:
	var norm = binding.get("normalizer", "unit_pos")
	if norm is String:
		match norm:
			"unit_pos":
				return 1.0
			"unit_neg":
				return -1.0
			_:
				push_error("WitnessSpec: unknown normalizer '%s'" % norm)
				return 0.0
	if norm is Dictionary:
		var scale := float(norm.get("scale", 1.0))
		match str(norm.get("type", "")):
			"tanh":
				return tanh(value / maxf(scale, 1e-9))
			"signed_clamp":
				return signf(value) * minf(1.0, absf(value) / maxf(scale, 1e-9))
			_:
				push_error("WitnessSpec: unknown normalizer type '%s'" % str(norm.get("type")))
				return 0.0
	return 0.0
