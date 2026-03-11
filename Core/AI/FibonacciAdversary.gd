class_name FibonacciAdversary
extends RefCounted

## FibonacciAdversary — adversarial graph tissue that mutates economy costs
## using Fibonacci-constrained values, targeting a golden-ratio action distribution.
##
## Two-level Fibonacci:
##   1. All cost VALUES are Fibonacci numbers: 1,1,2,3,5,8,13,21,34,55,89,144,233
##   2. The TARGET usage distribution follows φ-cascade (Fibonacci limit ratio):
##      each rank is used 1/φ as much as the rank above it.
##
## "Good game" = sorted action frequency ≈ φ-cascade.  Not max-entropy (boring
## uniformity) and not monoculture (one action dominates).  A clear strategy
## exists, but every action sees meaningful play.
##
## Berry block bookkeeping: chained ledger entries track mutations, divergence,
## and knob state.  Both GDScript and Python write the same format, linked by
## parent_id for branching/merging tuning histories.

const FIB: Array[int] = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]
const FIB_COUNT := 13
const MAX_FIB_INDEX := 12
const PHI := 1.6180339887498949

# The 8 policy actions (must match PolicyQuantumRegister.ACTIONS)
const POLICY_ACTIONS: Array[String] = [
	"quest_cycle", "probe_cycle", "lindblad_drain", "time_skip",
	"discover_biome", "victory_lap_partial", "lock_offer", "channel_drain",
]

# ── Knob storage ──────────────────────────────────────────────────────
# Each knob is a Dictionary: {path, fib_index, min_idx, max_idx, tier, affinity}
var _knobs: Dictionary = {}       # path → knob dict
var _cycle: int = 0
var _last_block_id: String = ""
var _golden_target: PackedFloat64Array

# ── Lifecycle ─────────────────────────────────────────────────────────

func _init() -> void:
	_golden_target = _compute_golden_target(POLICY_ACTIONS.size())
	_register_default_knobs()


static func _compute_golden_target(n: int) -> PackedFloat64Array:
	"""φ-cascade: rank k gets share ∝ 1/φ^(k+1), normalized to sum=1."""
	var target := PackedFloat64Array()
	target.resize(n)
	var total := 0.0
	for i in range(n):
		var share := pow(1.0 / PHI, float(i + 1))
		target[i] = share
		total += share
	if total > 0.0:
		for i in range(n):
			target[i] /= total
	return target


func get_golden_target() -> PackedFloat64Array:
	return _golden_target


# ── Fibonacci helpers ─────────────────────────────────────────────────

static func fib_value(index: int) -> int:
	return FIB[clampi(index, 0, MAX_FIB_INDEX)]


static func nearest_fib_index(value: int) -> int:
	"""Find the fib index whose value is closest to the given integer."""
	var best_idx := 0
	var best_dist := absi(FIB[0] - value)
	for i in range(1, FIB_COUNT):
		var dist := absi(FIB[i] - value)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


# ── Knob registry ────────────────────────────────────────────────────

func _reg(path: String, initial_value: int, affinity: String, tier: int = 1,
		min_idx: int = 0, max_idx: int = MAX_FIB_INDEX) -> void:
	_knobs[path] = {
		"path": path,
		"fib_index": nearest_fib_index(initial_value),
		"min_idx": min_idx,
		"max_idx": max_idx,
		"tier": tier,
		"affinity": affinity,
	}


func _register_default_knobs() -> void:
	# ── Tier 1: action costs (direct affordability) ──────────────────
	_reg("action_costs.explore.🍞",              1, "probe_cycle")
	_reg("action_costs.measure.❄️",              1, "probe_cycle")
	_reg("action_costs.pop.👥",                  1, "")
	_reg("action_costs.reap.🍼",                 1, "victory_lap_partial")
	_reg("action_costs.quest_reroll.🐇",         1, "quest_cycle")
	_reg("action_costs.quest_lock.🌲",           1, "lock_offer")
	_reg("action_costs.explore_biome.🦅",        5, "discover_biome")
	_reg("action_costs.remove_vocabulary.🐺",   21, "")
	_reg("action_costs.lindblad_pump.🌱",        8, "lindblad_drain")
	_reg("action_costs.lindblad_drain.⚙",       2, "lindblad_drain")

	# ── Tier 1: dynamic costs ────────────────────────────────────────
	_reg("dynamic.lindblad_drain_gear_cost",      2, "lindblad_drain")
	_reg("dynamic.lindblad_drain_south_cost",     8, "lindblad_drain")
	_reg("dynamic.lindblad_pump_sprout_cost",     8, "lindblad_drain")
	_reg("dynamic.lindblad_pump_north_cost",     34, "lindblad_drain")
	_reg("dynamic.vocab_injection_south_cost",    5, "quest_cycle")
	_reg("dynamic.vocab_injection_sprout_cost",   8, "quest_cycle")

	# ── Tier 2: gate costs ───────────────────────────────────────────
	_reg("gate_costs.pauli_x.☀",   1, "", 2)
	_reg("gate_costs.pauli_y.🌙",  1, "", 2)
	_reg("gate_costs.pauli_z.🍂",  1, "", 2)
	_reg("gate_costs.hadamard.🔥", 1, "", 2)
	_reg("gate_costs.s_gate.🌱",   1, "", 2)
	_reg("gate_costs.t_gate.🌿",   1, "", 2)
	_reg("gate_costs.cnot.🍄",     1, "", 2)
	_reg("gate_costs.cz.🦌",       1, "", 2)
	_reg("gate_costs.swap.🐺",     1, "", 2)

	# ── Tier 3: quest reward structure ───────────────────────────────
	_reg("quest_rewards.resource_reward_min_total",     8, "quest_cycle", 3)
	_reg("quest_rewards.resource_reward_max_total",   233, "quest_cycle", 3)
	_reg("quest_rewards.resource_reward_min_per_emoji",  5, "quest_cycle", 3)

	# ── Tier 3: economy / tuning ─────────────────────────────────────
	_reg("economy_variables.max_biome_qubits",  13, "discover_biome", 3)
	_reg("tuning.reap_evolution_cycles",        13, "victory_lap_partial", 3)
	_reg("tuning.reap_starting_tokens",          5, "victory_lap_partial", 3)


func get_knob_count() -> int:
	return _knobs.size()


func get_knob_value(path: String) -> int:
	if not _knobs.has(path):
		return -1
	return fib_value(_knobs[path].fib_index)


func get_knob_index(path: String) -> int:
	if not _knobs.has(path):
		return -1
	return int(_knobs[path].fib_index)


func get_all_knob_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in _knobs:
		paths.append(str(path))
	return paths


# ── KL divergence ─────────────────────────────────────────────────────

func compute_kl_divergence(observed_sorted: PackedFloat64Array) -> float:
	"""KL(observed || golden_target).  Both arrays must be same length, sorted descending."""
	var target := _golden_target
	var n := mini(observed_sorted.size(), target.size())
	if n == 0:
		return 0.0
	var kl := 0.0
	for i in range(n):
		var p := maxf(1e-10, observed_sorted[i])
		var q := maxf(1e-10, target[i])
		kl += p * log(p / q)
	return kl


func sort_distribution_descending(action_dist: Dictionary) -> PackedFloat64Array:
	"""Extract action frequencies, sort descending."""
	var freqs: Array[float] = []
	for action in POLICY_ACTIONS:
		freqs.append(float(action_dist.get(action, 0.0)))
	freqs.sort()
	freqs.reverse()
	return PackedFloat64Array(freqs)


# ── Mutation engine ───────────────────────────────────────────────────

func mutate(observed_action_pct: Dictionary, max_mutations: int = 5) -> Array:
	"""Compute ±1 fib_index mutations to push observed distribution toward φ-cascade.

	Returns Array of mutation dicts: {knob, from_idx, to_idx, from_val, to_val, action, excess}
	"""
	# 1. Rank actions by observed frequency (descending)
	var ranked: Array = []
	for action in POLICY_ACTIONS:
		ranked.append({"action": action, "freq": float(observed_action_pct.get(action, 0.0))})
	ranked.sort_custom(func(a, b): return a.freq > b.freq)

	var target := _golden_target
	var mutations: Array = []

	# 2. Walk ranks: overused → increase cost, underused → decrease cost
	for rank_idx in range(ranked.size()):
		if mutations.size() >= max_mutations:
			break

		var action_name: String = ranked[rank_idx].action
		var observed_share: float = ranked[rank_idx].freq
		var target_share: float = target[rank_idx] if rank_idx < target.size() else 0.0
		var excess: float = observed_share - target_share

		# Dead zone: don't mutate if within 5% of target
		if absf(excess) < 0.05:
			continue

		# Find knobs affiliated with this action
		var affiliated: Array = []
		for path in _knobs:
			var k: Dictionary = _knobs[path]
			if str(k.get("affinity", "")) == action_name:
				affiliated.append(k)

		if affiliated.is_empty():
			continue

		# Direction: overused → more expensive (+1), underused → cheaper (-1)
		var direction: int = 1 if excess > 0.0 else -1

		# Sort affiliated by tier (mutate cheapest-tier first)
		affiliated.sort_custom(func(a, b): return int(a.tier) < int(b.tier))

		# Mutate the first eligible knob
		for knob in affiliated:
			if mutations.size() >= max_mutations:
				break
			var old_idx: int = int(knob.fib_index)
			var new_idx: int = clampi(old_idx + direction, int(knob.min_idx), int(knob.max_idx))
			if new_idx == old_idx:
				continue

			var old_val := fib_value(old_idx)
			var new_val := fib_value(new_idx)
			knob.fib_index = new_idx

			mutations.append({
				"knob": str(knob.path),
				"from_idx": old_idx,
				"to_idx": new_idx,
				"from_val": old_val,
				"to_val": new_val,
				"action": action_name,
				"rank": rank_idx,
				"excess": snappedf(excess, 0.001),
			})
			break  # one mutation per action per cycle

	_cycle += 1
	return mutations


# ── Berry block bookkeeping ───────────────────────────────────────────

func write_berry_block(observed_action_pct: Dictionary, mutations: Array,
		extra_observed: Dictionary = {}, ledger_path: String = "") -> Dictionary:
	"""Write a chained berry block to the ledger. Returns the block dict."""
	var block_id := "bb_%04d" % _cycle
	var parent_id := _last_block_id if _last_block_id != "" else "genesis"

	var sorted_obs := sort_distribution_descending(observed_action_pct)
	var kl := compute_kl_divergence(sorted_obs)

	# Snapshot all knob indices
	var knob_snapshot: Dictionary = {}
	for path in _knobs:
		knob_snapshot[path] = int(_knobs[path].fib_index)

	# Build observed payload
	var observed_payload: Dictionary = {
		"action_distribution": observed_action_pct.duplicate(),
	}
	for key in extra_observed:
		observed_payload[key] = extra_observed[key]

	var block: Dictionary = {
		"block_id": block_id,
		"parent_id": parent_id,
		"author": "gdscript",
		"timestamp_unix": Time.get_unix_time_from_system(),
		"cycle": _cycle,
		"observed": observed_payload,
		"divergence": {
			"kl_from_golden": snappedf(kl, 0.0001),
			"sorted_observed": Array(sorted_obs),
			"sorted_target": Array(_golden_target),
		},
		"mutations": mutations,
		"state": {"knob_indices": knob_snapshot},
	}

	# Checksum: sha256(parent_id + json(mutations))
	var check_input := parent_id + JSON.stringify(mutations)
	block["checksum"] = check_input.sha256_text()

	_last_block_id = block_id

	# Append to ledger file
	if ledger_path != "":
		_append_block_to_file(block, ledger_path)

	return block


func _append_block_to_file(block: Dictionary, path: String) -> void:
	var line := JSON.stringify(block)
	var fa := FileAccess.open(path, FileAccess.READ_WRITE)
	if fa == null:
		fa = FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.seek_end()
		fa.store_line(line)
		fa.close()


# ── FarmVariableGraph export ──────────────────────────────────────────

func to_graph_lines() -> Array[String]:
	"""Export current knob state as FarmVariableGraph JSONL lines."""
	var lines: Array[String] = []
	for path in _knobs:
		var val := fib_value(int(_knobs[path].fib_index))
		lines.append(JSON.stringify({"op": "set", "path": path, "value": val}))
	return lines


func to_graph_patch() -> Dictionary:
	"""Export current knob state as a nested Dictionary patch."""
	var patch: Dictionary = {}
	for path in _knobs:
		var val := fib_value(int(_knobs[path].fib_index))
		var parts := str(path).split(".")
		var cursor: Dictionary = patch
		for i in range(parts.size() - 1):
			if not cursor.has(parts[i]):
				cursor[parts[i]] = {}
			cursor = cursor[parts[i]]
		cursor[parts[parts.size() - 1]] = val
	return patch


# ── State persistence ─────────────────────────────────────────────────

func export_state() -> Dictionary:
	var knob_indices: Dictionary = {}
	for path in _knobs:
		knob_indices[path] = int(_knobs[path].fib_index)
	return {
		"version": 1,
		"type": "fibonacci_adversary",
		"cycle": _cycle,
		"last_block_id": _last_block_id,
		"knob_indices": knob_indices,
	}


func load_state(data: Dictionary) -> void:
	if not (data is Dictionary):
		return
	if str(data.get("type", "")) != "fibonacci_adversary":
		return
	_cycle = int(data.get("cycle", 0))
	_last_block_id = str(data.get("last_block_id", ""))
	var indices = data.get("knob_indices", {})
	if indices is Dictionary:
		for path in indices:
			if _knobs.has(path):
				_knobs[path].fib_index = clampi(int(indices[path]), 0, MAX_FIB_INDEX)


func load_from_ledger(ledger_path: String) -> bool:
	"""Restore state from the last berry block in a ledger file."""
	if not FileAccess.file_exists(ledger_path):
		return false
	var fa := FileAccess.open(ledger_path, FileAccess.READ)
	if fa == null:
		return false
	var last_block: Dictionary = {}
	while not fa.eof_reached():
		var line := fa.get_line().strip_edges()
		if line == "":
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			last_block = parsed
	fa.close()
	if last_block.is_empty():
		return false
	_cycle = int(last_block.get("cycle", 0))
	_last_block_id = str(last_block.get("block_id", ""))
	var state = last_block.get("state", {})
	if state is Dictionary:
		var indices = state.get("knob_indices", {})
		if indices is Dictionary:
			for path in indices:
				if _knobs.has(path):
					_knobs[path].fib_index = clampi(int(indices[path]), 0, MAX_FIB_INDEX)
	return true


# ── Debug / inspection ────────────────────────────────────────────────

func get_snapshot() -> Dictionary:
	var knobs: Dictionary = {}
	for path in _knobs:
		var k: Dictionary = _knobs[path]
		knobs[path] = {
			"fib_index": int(k.fib_index),
			"value": fib_value(int(k.fib_index)),
			"tier": int(k.tier),
			"affinity": str(k.get("affinity", "")),
		}
	return {
		"cycle": _cycle,
		"last_block_id": _last_block_id,
		"knob_count": _knobs.size(),
		"knobs": knobs,
		"golden_target": Array(_golden_target),
	}
