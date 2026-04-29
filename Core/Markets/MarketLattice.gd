class_name MarketLattice
extends RefCounted

## MarketLattice — registry of contracts (open offers, owned options).
##
## "Lattice" is conceptual: the collection of all open and owned contracts
## across all biomes forms a derived view of the biome substrate, not a
## persistent qubit register. Each contract names a biome.qc qubit; pricing
## is recomputed on read; exercising calls the POP path.
##
## Phase VI: no save persistence. Open offers regenerate from substrate on
## next view; owned contracts are session-scoped game state.
##
## Lifecycle: open → owned → exercised | expired

const MarketContract = preload("res://Core/Markets/Contract.gd")
const MarketBiasSources = preload("res://Core/Markets/MarketBiasSources.gd")
const PriceModel = preload("res://Core/Markets/PriceModel.gd")
const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")
const QuantumRounding = preload("res://Core/QuantumSubstrate/QuantumRounding.gd")

var _farm = null                          # weak ref; market doesn't own farm
var _contracts: Dictionary = {}           # id → MarketContract
var _current_phrame: int = 0              # advanced by farm tick


func _init(farm = null) -> void:
	_farm = farm


func set_farm(farm) -> void:
	_farm = farm


func tick(phrame_delta: int = 1) -> void:
	_current_phrame += max(phrame_delta, 0)
	expire_old(_current_phrame)


func clear() -> void:
	_contracts.clear()


# ---------------- offer generation ----------------

func propose_offers(biome, n: int = 1) -> Array:
	# Generate n new offers for the given biome, one per native faction or
	# emoji-axial pair found in biome.qc. Each offer's price is substrate-derived.
	if biome == null or _farm == null:
		return []
	var biome_name: String = biome.get_biome_type() if biome.has_method("get_biome_type") else (biome.biome_name if "biome_name" in biome else "")
	if biome_name == "":
		return []
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null or qc.register_map == null:
		return []
	var emojis: Array = []
	var num_qubits = qc.register_map.num_qubits
	for q in range(num_qubits):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q) if qc.has_method("get_emoji_pair_for_qubit") else {}
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		if north != "":
			emojis.append({"emoji": north, "pole": 0})
		if south != "":
			emojis.append({"emoji": south, "pole": 1})

	if emojis.is_empty():
		return []

	# Pick n distinct emojis; for each, pick a faction whose signature contains it.
	var offers: Array = []
	var fdm = _farm.faction_density if "faction_density" in _farm else null
	if fdm == null:
		return []
	var registry = fdm.get_registry()
	if registry == null:
		return []

	emojis.shuffle()
	var taken: int = 0
	for entry in emojis:
		if taken >= n:
			break
		var emoji: String = entry["emoji"]
		var pole: int = entry["pole"]
		var speakers: Array = []
		if fdm.has_method("factions_speaking"):
			speakers = fdm.factions_speaking(emoji)
		if speakers.is_empty():
			# Fallback: any faction that owns an icon containing this emoji.
			speakers = registry.get_factions_for_emoji(emoji) if registry.has_method("get_factions_for_emoji") else []
			# Convert to names.
			var names: Array = []
			for f in speakers:
				if f != null and "name" in f:
					names.append(str(f.name))
			speakers = names
		if speakers.is_empty():
			continue
		var faction_name: String = str(speakers[0])
		var expiry: int = _current_phrame + HamiltonianConfig.CONTRACT_DEFAULT_EXPIRY_PHRAMES
		# Cost emoji defaults to the resource itself (commodity-to-commodity: pay
		# upfront in the deliverable; receive measured outcome on exercise).
		# PriceModel returns price denominated in cost_emoji units.
		var cost_emoji: String = emoji
		var c = MarketContract.make(emoji, faction_name, biome_name, pole, _current_phrame, 0.0, expiry, cost_emoji, 0.0)
		c.price_paid = PriceModel.price_contract(c, _farm)
		c.cost_amount = c.price_paid
		register_offer(c)
		offers.append(c)
		taken += 1
	return offers


## Pair-tensor offer generation: for each shared emoji between biome_a and biome_b,
## emit a contract whose price reflects the |P_A − P_B| disagreement on that emoji.
## Cross-axis bridges (where the two biomes pair the same emoji on different qubits)
## get a tension premium. Cost emoji is paid in a *complementary* resource on the
## opposite biome — this is the commodity-to-commodity tensor trade: pay in B's
## product, exercise on A's qubit (or vice versa).
func propose_pair_offers(biome_a, biome_b, n: int = 6) -> Array:
	if biome_a == null or biome_b == null or _farm == null:
		return []
	var name_a: String = _biome_name(biome_a)
	var name_b: String = _biome_name(biome_b)
	if name_a == "" or name_b == "":
		return []
	var qc_a = biome_a.quantum_computer if "quantum_computer" in biome_a else null
	var qc_b = biome_b.quantum_computer if "quantum_computer" in biome_b else null
	if qc_a == null or qc_b == null:
		return []

	# Build emoji → marginal map for each side.
	var marg_a: Dictionary = _emoji_marginals(qc_a)
	var marg_b: Dictionary = _emoji_marginals(qc_b)

	# Tradable emojis: present on at least one side.
	var union: Dictionary = {}
	for e in marg_a.keys():
		union[e] = true
	for e in marg_b.keys():
		union[e] = true

	# Score each by tension × shared_factor; emit a contract on the higher-marginal side.
	var scored: Array = []
	for emoji in union.keys():
		var has_a: bool = marg_a.has(emoji)
		var has_b: bool = marg_b.has(emoji)
		var p_a: float = float(marg_a.get(emoji, 0.0))
		var p_b: float = float(marg_b.get(emoji, 0.0))
		var tension: float = abs(p_a - p_b) if (has_a and has_b) else 0.0
		var p_avg: float = 0.5 * (p_a + p_b) if (has_a and has_b) else (p_a if has_a else p_b)
		# Score: emojis present on both, with high tension, are richest trade signals.
		var shared_bonus: float = 1.0 if (has_a and has_b) else 0.6
		var score: float = (tension + 0.05) * shared_bonus * (0.5 + p_avg)
		scored.append({
			"emoji": emoji,
			"p_a": p_a,
			"p_b": p_b,
			"tension": tension,
			"shared": (has_a and has_b),
			"score": score,
		})
	scored.sort_custom(func(x, y): return float(x.score) > float(y.score))

	var registry = null
	var fdm = _farm.faction_density if "faction_density" in _farm else null
	if fdm != null:
		registry = fdm.get_registry()

	var offers: Array = []
	var taken: int = 0
	for entry in scored:
		if taken >= n:
			break
		var emoji: String = str(entry.emoji)
		# Settlement biome: whichever side has the qubit and the higher marginal —
		# that's where exercise will pop.
		var settle_biome_name: String
		var settle_qc
		if entry.shared:
			if float(entry.p_a) >= float(entry.p_b):
				settle_biome_name = name_a
				settle_qc = qc_a
			else:
				settle_biome_name = name_b
				settle_qc = qc_b
		elif marg_a.has(emoji):
			settle_biome_name = name_a
			settle_qc = qc_a
		else:
			settle_biome_name = name_b
			settle_qc = qc_b

		var pole: int = settle_qc.pole(emoji) if settle_qc.has_method("pole") else 1
		# Faction issuer: prefer one whose signature contains the emoji and lives in either biome.
		var faction_name: String = _resolve_pair_issuer(emoji, biome_a, biome_b, registry)
		# Cost emoji: the *opposite* biome's strongest emoji that the buyer plausibly holds.
		# Default to the deliverable itself (commodity-to-commodity self-cover).
		var cost_emoji: String = _pick_cost_emoji(emoji, settle_biome_name, name_a, name_b, marg_a, marg_b)
		var expiry: int = _current_phrame + HamiltonianConfig.CONTRACT_DEFAULT_EXPIRY_PHRAMES
		var c = MarketContract.make(emoji, faction_name, settle_biome_name, pole, _current_phrame, 0.0, expiry, cost_emoji, 0.0)
		# Price = base 1/p × QC_RATIO × (1 + tension), denominated in cost_emoji.
		var p_clipped: float = clampf(0.5 if not entry.shared else 0.5 * (float(entry.p_a) + float(entry.p_b)),
			HamiltonianConfig.P_MIN, 1.0 - HamiltonianConfig.P_MIN)
		var price: float = (1.0 / p_clipped) * HamiltonianConfig.QUANTUM_CLASSICAL_RATIO * (1.0 + float(entry.tension))
		c.price_paid = price
		c.cost_amount = price
		# Stash tensor-mode metadata for the UI.
		c.set_meta("pair_a", name_a)
		c.set_meta("pair_b", name_b)
		c.set_meta("tension", float(entry.tension))
		c.set_meta("shared", bool(entry.shared))
		register_offer(c)
		offers.append(c)
		taken += 1
	return offers


# ---------------- pair helpers ----------------

func _biome_name(biome) -> String:
	if biome == null:
		return ""
	if biome.has_method("get_biome_type"):
		return str(biome.get_biome_type())
	if "biome_name" in biome:
		return str(biome.biome_name)
	return ""


func _emoji_marginals(qc) -> Dictionary:
	var out: Dictionary = {}
	if qc == null or qc.register_map == null:
		return out
	var n = qc.register_map.num_qubits
	for q in range(n):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q) if qc.has_method("get_emoji_pair_for_qubit") else {}
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		# Convention: pole 1 = south = high-energy half; report pole-1 marginal.
		var p1: float = qc.get_marginal(q, 1) if qc.has_method("get_marginal") else 0.5
		if north != "":
			out[north] = 1.0 - p1
		if south != "":
			out[south] = p1
	return out


func _resolve_pair_issuer(emoji: String, biome_a, biome_b, registry) -> String:
	# Try native_factions on either biome that speak this emoji.
	for biome in [biome_a, biome_b]:
		if biome == null:
			continue
		var natives: Array = []
		if "_biome_data" in biome and biome._biome_data is Dictionary:
			natives = biome._biome_data.get("native_factions", [])
		elif "native_factions" in biome:
			natives = biome.native_factions
		for fname in natives:
			if registry == null:
				continue
			var f = registry.get_by_name(str(fname))
			if f != null and f.has_method("speaks") and f.speaks(emoji):
				return str(fname)
	# Fallback: any faction in registry that speaks this emoji.
	if registry != null and registry.has_method("get_factions_for_emoji"):
		var fs = registry.get_factions_for_emoji(emoji)
		if fs is Array and not fs.is_empty():
			var f0 = fs[0]
			if f0 != null and "name" in f0:
				return str(f0.name)
	return "Unknown"


func _pick_cost_emoji(deliverable: String, settle_name: String, name_a: String, name_b: String,
		marg_a: Dictionary, marg_b: Dictionary) -> String:
	# Default: pay in the deliverable itself (self-cover, simplest semantics).
	# Tensor variant: prefer the opposite biome's most-populated emoji != deliverable.
	var opp_marg: Dictionary = marg_b if settle_name == name_a else marg_a
	var best: String = ""
	var best_p: float = 0.0
	for e in opp_marg.keys():
		if str(e) == deliverable:
			continue
		var p = float(opp_marg[e])
		if p > best_p:
			best_p = p
			best = str(e)
	if best == "" or best_p < 0.30:
		return deliverable
	return best


func register_offer(contract) -> void:
	if contract == null:
		return
	_contracts[contract.id] = contract


# ---------------- buy / exercise / expire ----------------

func buy(contract_id: int) -> Dictionary:
	if not _contracts.has(contract_id):
		return {"ok": false, "error": "no_such_contract"}
	var c = _contracts[contract_id]
	if c.status != MarketContract.STATUS_OPEN:
		return {"ok": false, "error": "not_open", "status": c.status}
	if _current_phrame > c.expiry_phrame:
		c.status = MarketContract.STATUS_EXPIRED
		return {"ok": false, "error": "expired"}
	if _farm == null or _farm.economy == null:
		return {"ok": false, "error": "no_economy"}
	# Commodity-to-commodity: pay in cost_emoji (defaults to resource itself).
	var cost_emoji: String = c.cost_emoji if c.cost_emoji != "" else c.resource
	var cost_amount: float = c.cost_amount if c.cost_amount > 0.0 else c.price_paid
	var available: float = float(_farm.economy.get_resource(cost_emoji))
	if available < cost_amount:
		return {"ok": false, "error": "insufficient_funds", "need": cost_amount, "have": available, "cost_emoji": cost_emoji}
	# Quantum rounding: 0.7 cost rounds to 1 with prob 0.7, 0 with prob 0.3.
	# Each buy is its own measurement event.
	var rounded_cost: int = QuantumRounding.stochastic_round(cost_amount)
	if not _farm.economy.remove_resource(cost_emoji, rounded_cost, "contract_buy"):
		return {"ok": false, "error": "debit_failed"}
	c.status = MarketContract.STATUS_OWNED
	return {"ok": true, "contract_id": c.id, "price_paid": cost_amount, "cost_emoji": cost_emoji}


func exercise(contract_id: int) -> Dictionary:
	if not _contracts.has(contract_id):
		return {"ok": false, "error": "no_such_contract"}
	var c = _contracts[contract_id]
	if c.status != MarketContract.STATUS_OWNED:
		return {"ok": false, "error": "not_owned", "status": c.status}
	if _current_phrame > c.expiry_phrame:
		c.status = MarketContract.STATUS_EXPIRED
		return {"ok": false, "error": "expired"}
	if _farm == null or _farm.grid == null:
		return {"ok": false, "error": "no_farm"}

	var biome = _resolve_biome_by_name(c.biome_name)
	if biome == null:
		return {"ok": false, "error": "biome_not_found"}
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null or not qc.has(c.resource):
		# Biome doesn't host this emoji as a register — caller can fall back to
		# legacy classical-only path.
		c.status = MarketContract.STATUS_EXERCISED
		return {"ok": false, "error": "biome_lacks_qubit", "resource": c.resource}

	var qubit_idx: int = qc.qubit(c.resource)
	var pre_marginal: float = qc.get_marginal(qubit_idx, c.qubit_pole)

	# Same POP path used by plot harvest: seeded measurement + 1/p reward.
	var seed_val: int = hash([c.id, _current_phrame])
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var roll: float = rng.randf()
	var outcome_pole: int
	var outcome_emoji: String
	var p_outcome: float
	if roll < pre_marginal:
		outcome_pole = c.qubit_pole
		outcome_emoji = c.resource
		p_outcome = pre_marginal
	else:
		# Opposite pole — get the *other* emoji on this qubit.
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(qubit_idx)
		var other_pole: int = 1 - c.qubit_pole
		outcome_pole = other_pole
		outcome_emoji = str(pair.get("south", "")) if other_pole == 1 else str(pair.get("north", ""))
		p_outcome = 1.0 - pre_marginal

	# Reward: 1/p in quantum units, × QC_RATIO for classical.
	var p_clipped: float = clampf(p_outcome, HamiltonianConfig.P_MIN, 1.0 - HamiltonianConfig.P_MIN)
	var reward_quantum: float = round(1.0 / p_clipped)
	var classical_reward: int = int(reward_quantum * HamiltonianConfig.QUANTUM_CLASSICAL_RATIO)
	if _farm.economy:
		_farm.economy.add_resource(outcome_emoji, classical_reward, "contract_exercise")

	# Biome decoheres from market activity. eta scales with the contract's
	# weight in this biome's economy; capped at ETA_HARD_CAP.
	if biome.has_method("apply_atomic_drain"):
		var eta: float = clampf(p_outcome * 0.1, 0.0, HamiltonianConfig.ETA_HARD_CAP)
		biome.apply_atomic_drain(c.resource, outcome_pole, eta)

	# Symmetric Hamiltonian rotation distribution.
	var post_marginal: float = qc.get_marginal(qubit_idx, c.qubit_pole)
	var theta_total: float = abs(asin(clampf(2.0 * post_marginal - 1.0, -1.0, 1.0)) - asin(clampf(2.0 * pre_marginal - 1.0, -1.0, 1.0)))
	if _farm.has_method("distribute_settlement_theta"):
		_farm.distribute_settlement_theta(theta_total, c)

	c.status = MarketContract.STATUS_EXERCISED
	return {
		"ok": true,
		"contract_id": c.id,
		"outcome": outcome_emoji,
		"p_outcome": p_outcome,
		"reward_quantum": reward_quantum,
		"classical_reward": classical_reward,
		"theta_total": theta_total,
	}


func exercise_immediate(contract) -> Dictionary:
	# Register + immediately exercise (used by icon-learn and tests).
	if contract == null:
		return {"ok": false, "error": "null_contract"}
	contract.status = MarketContract.STATUS_OWNED
	register_offer(contract)
	return exercise(contract.id)


func expire_old(current_p: int) -> int:
	var expired_count: int = 0
	for cid in _contracts.keys():
		var c = _contracts[cid]
		if c.status == MarketContract.STATUS_OPEN or c.status == MarketContract.STATUS_OWNED:
			if current_p > c.expiry_phrame:
				c.status = MarketContract.STATUS_EXPIRED
				expired_count += 1
	return expired_count


# ---------------- queries ----------------

func get_open_offers(biome_name: String = "") -> Array:
	var out: Array = []
	for c in _contracts.values():
		if c.status != MarketContract.STATUS_OPEN:
			continue
		if biome_name == "" or c.biome_name == biome_name:
			out.append(c)
	return out


func get_player_portfolio() -> Array:
	var out: Array = []
	for c in _contracts.values():
		if c.status == MarketContract.STATUS_OWNED:
			out.append(c)
	out.sort_custom(func(a, b): return a.expiry_phrame < b.expiry_phrame)
	return out


func get_contract(contract_id: int):
	return _contracts.get(contract_id, null)


# ---------------- internal ----------------

func _resolve_biome_by_name(name: String):
	if _farm == null or _farm.grid == null:
		return null
	for b in _farm.grid.get_all_biomes().values():
		var bname = b.get_biome_type() if b.has_method("get_biome_type") else (b.biome_name if "biome_name" in b else "")
		if str(bname) == name:
			return b
	return null


func _find_biome_for_emoji(emoji: String):
	"""Find first live biome whose quantum computer holds a qubit for this emoji."""
	if _farm == null or _farm.grid == null:
		return null
	for b in _farm.grid.get_all_biomes().values():
		var qc = b.quantum_computer if "quantum_computer" in b else null
		if qc != null and qc.has_method("has") and qc.has(emoji):
			return b
	return null


func synthesize_and_exercise(emoji: String, faction_name: String = "") -> Dictionary:
	"""Synthesize a minimal one-shot contract for emoji in any live biome and
	immediately exercise it. Used by icon-learn and settlement-rotation events
	to get a substrate-derived θ via distribute_settlement_theta."""
	var biome = _find_biome_for_emoji(emoji)
	if biome == null:
		return {"ok": false, "error": "no_biome_for_emoji", "emoji": emoji}
	var biome_name: String = _biome_name(biome)
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null:
		return {"ok": false, "error": "no_qc"}
	var pole: int = qc.pole(emoji) if qc.has_method("pole") else 1
	var c = MarketContract.make(emoji, faction_name, biome_name, pole,
		_current_phrame, 0.0, _current_phrame + 1, emoji, 0.0)
	return exercise_immediate(c)
