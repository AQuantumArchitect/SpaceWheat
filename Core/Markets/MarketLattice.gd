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
	# Generate n new offers for the given biome, one per admitted faction or
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
		# Pick a RANDOM speaker, not always speakers[0]: multiple factions speak a
		# given biome emoji, and the OFFERING faction determines the reward pool (its
		# cloud / Hamiltonian couplings). Always taking [0] shut some factions out
		# entirely — e.g. Millwright's Union (cloud ⚙/🍞/👥/🔨/💨/🏭) never offered
		# Village contracts, so 🔨 (needed to plant the Mill) was unobtainable. Random
		# selection gives every speaker a turn; re-rolling the market (E refresh) cycles
		# them, so scarce coupling-resources stay reachable.
		var faction_name: String = str(speakers[randi() % speakers.size()])
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
		# Price = base surprisal −kT·log p_avg + cross-biome arbitrage energy.
		var p_avg: float = 0.5 if not entry.shared else 0.5 * (float(entry.p_a) + float(entry.p_b))
		var settle_biome = biome_a if settle_qc == qc_a else biome_b
		var kT: float = EnergyPricing.biome_temperature(settle_biome, _farm)
		var arb: float = _arbitrage_energy(float(entry.p_a), float(entry.p_b), kT) if entry.shared else 0.0
		var price: float = EnergyPricing.surprisal_energy(p_avg, kT) + arb
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


# ---------------- neighborhood tensor offers ----------------

## For the live biome in player focus, find all neighborhoods that share ≥1
## emoji and emit pair-style offers using Lindblad-steady-state marginals for
## the neighborhood side (no live QC required on the neighborhood).
func propose_neighborhood_offers(biome, n: int = 6) -> Array:
	if biome == null or _farm == null:
		return []
	var biome_name: String = _biome_name(biome)
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null:
		return []
	var marg_live: Dictionary = _emoji_marginals(qc)
	if marg_live.is_empty():
		return []

	var br = BiomeRegistry.get_shared()
	var neighborhoods: Array = br.get_biomes_by_tag("neighborhood")

	var scored: Array = []
	for fb in neighborhoods:
		var marg_fb: Dictionary = _static_marginals_from_spec(fb)
		for emoji in marg_live.keys():
			if not marg_fb.has(emoji):
				continue
			var p_live: float = float(marg_live[emoji])
			var p_fb: float = float(marg_fb[emoji])
			var tension: float = abs(p_live - p_fb)
			scored.append({
				"emoji": emoji,
				"rb_name": fb.name,
				"marg_fb": marg_fb,
				"p_live": p_live,
				"p_fb": p_fb,
				"tension": tension,
				"score": (tension + 0.05) * (0.5 + 0.5 * (p_live + p_fb)),
			})
	scored.sort_custom(func(x, y): return float(x.score) > float(y.score))

	var offers: Array = []
	var taken: int = 0
	for entry in scored:
		if taken >= n:
			break
		var emoji: String = str(entry.emoji)
		var p_live: float = float(entry.p_live)
		var pole: int = qc.pole(emoji) if qc.has_method("pole") else 1
		var cost_emoji: String = _pick_faction_cost_emoji(emoji, entry.marg_fb)
		var expiry: int = _current_phrame + HamiltonianConfig.CONTRACT_DEFAULT_EXPIRY_PHRAMES
		var c = MarketContract.make(emoji, str(entry.rb_name), biome_name, pole,
				_current_phrame, 0.0, expiry, cost_emoji, 0.0)
		var kT: float = EnergyPricing.biome_temperature(biome, _farm)
		var arb: float = _arbitrage_energy(p_live, float(entry.p_fb), kT)
		c.price_paid = EnergyPricing.surprisal_energy(p_live, kT) + arb
		c.cost_amount = c.price_paid
		c.set_meta("pair_a", biome_name)
		c.set_meta("pair_b", str(entry.rb_name))
		c.set_meta("tension", float(entry.tension))
		c.set_meta("shared", true)
		register_offer(c)
		offers.append(c)
		taken += 1
	return offers


## Return the name of the neighborhood with the highest tension against `biome`.
## Returns "" if no neighborhoods exist or biome has no QC.
func best_neighborhood_name(biome) -> String:
	if biome == null:
		return ""
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null:
		return ""
	var marg_live: Dictionary = _emoji_marginals(qc)
	if marg_live.is_empty():
		return ""
	var br = BiomeRegistry.get_shared()
	var best_name: String = ""
	var best_score: float = -1.0
	for fb in br.get_biomes_by_tag("neighborhood"):
		var marg_fb: Dictionary = _static_marginals_from_spec(fb)
		var score: float = 0.0
		for emoji in marg_live.keys():
			if marg_fb.has(emoji):
				var tension: float = abs(float(marg_live[emoji]) - float(marg_fb[emoji]))
				score += (tension + 0.05) * (0.5 + 0.5 * (float(marg_live[emoji]) + float(marg_fb[emoji])))
		if score > best_score:
			best_score = score
			best_name = fb.name
	return best_name


## Like propose_neighborhood_offers but scoped to one specific neighborhood by name.
func propose_neighborhood_offers_scoped(biome, neighborhood_name: String, n: int = 6) -> Array:
	if biome == null or _farm == null or neighborhood_name == "":
		return []
	var biome_name: String = _biome_name(biome)
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null:
		return []
	var marg_live: Dictionary = _emoji_marginals(qc)
	if marg_live.is_empty():
		return []

	var br = BiomeRegistry.get_shared()
	var fb_spec = null
	for fb in br.get_biomes_by_tag("neighborhood"):
		if fb.name == neighborhood_name:
			fb_spec = fb
			break
	if fb_spec == null:
		return []

	var marg_fb: Dictionary = _static_marginals_from_spec(fb_spec)
	var scored: Array = []
	for emoji in marg_live.keys():
		if not marg_fb.has(emoji):
			continue
		var p_live: float = float(marg_live[emoji])
		var p_fb: float = float(marg_fb[emoji])
		var tension: float = abs(p_live - p_fb)
		scored.append({
			"emoji": emoji,
		"fb_name": neighborhood_name,
			"marg_fb": marg_fb,
			"p_live": p_live,
			"p_fb": p_fb,
			"tension": tension,
			"score": (tension + 0.05) * (0.5 + 0.5 * (p_live + p_fb)),
		})
	scored.sort_custom(func(x, y): return float(x.score) > float(y.score))

	var nb_fdm = _farm.faction_density if "faction_density" in _farm else null
	var nb_registry = nb_fdm.get_registry() if nb_fdm != null else null
	var offers: Array = []
	var taken: int = 0
	for entry in scored:
		if taken >= n:
			break
		var emoji: String = str(entry.emoji)
		var p_live: float = float(entry.p_live)
		var pole: int = qc.pole(emoji) if qc.has_method("pole") else 1
		var cost_emoji: String = _pick_faction_cost_emoji(emoji, entry.marg_fb)
		var expiry: int = _current_phrame + HamiltonianConfig.CONTRACT_DEFAULT_EXPIRY_PHRAMES
		# Issuer is a CANONICAL faction that speaks this emoji (not the neighborhood
		# key): the offering faction's coupling-cloud is the reward pool. Using the
		# raw neighborhood name (e.g. "HearthKeepers") broke FactionDatabase lookup,
		# collapsing rewards to a degenerate deliver-X-get-X and shutting out every
		# faction but one. Per-emoji speaker resolution restores multi-faction variety
		# and makes scarce coupling-resources (🔨) reachable from the keyboard market.
		var issuer: String = _resolve_neighborhood_issuer(emoji, biome, nb_registry)
		var c = MarketContract.make(emoji, issuer, biome_name, pole,
				_current_phrame, 0.0, expiry, cost_emoji, 0.0)
		var kT: float = EnergyPricing.biome_temperature(biome, _farm)
		var arb: float = _arbitrage_energy(p_live, float(entry.p_fb), kT)
		c.price_paid = EnergyPricing.surprisal_energy(p_live, kT) + arb
		c.cost_amount = c.price_paid
		c.set_meta("pair_a", biome_name)
		c.set_meta("pair_b", neighborhood_name)
		c.set_meta("tension", float(entry.tension))
		c.set_meta("shared", true)
		register_offer(c)
		offers.append(c)
		taken += 1
	return offers


## Returns the highest-tension live biome pair from `biomes_dict` ({name→biome}).
## Uses the same tension formula as the N Network frame: Σ|Δmarginal| + 0.05×shared.
## Returns {} when fewer than 2 live biomes are present.
func best_live_tension_pair(biomes_dict: Dictionary) -> Dictionary:
	var bnames: Array = biomes_dict.keys()
	bnames.sort()
	var best: Dictionary = {}
	var best_score: float = -1.0
	for i in range(bnames.size()):
		var ba = biomes_dict[bnames[i]]
		var qca = ba.quantum_computer if "quantum_computer" in ba else null
		if qca == null:
			continue
		var ma: Dictionary = _emoji_marginals(qca)
		for j in range(i + 1, bnames.size()):
			var bb = biomes_dict[bnames[j]]
			var qcb = bb.quantum_computer if "quantum_computer" in bb else null
			if qcb == null:
				continue
			var mb: Dictionary = _emoji_marginals(qcb)
			var shared_count: int = 0
			var tension: float = 0.0
			for emoji in ma.keys():
				if mb.has(emoji):
					shared_count += 1
					tension += absf(float(ma[emoji]) - float(mb[emoji]))
			if shared_count == 0:
				continue
			var score: float = tension + 0.05 * float(shared_count)
			if score > best_score:
				best_score = score
				best = {"a": str(bnames[i]), "b": str(bnames[j]), "tension": tension, "shared": shared_count}
	return best


## Arbitrage energy between two biomes' marginals for the SAME good:
## kT·|log(p_x/p_y)| = |surprisal_x − surprisal_y|. The energy you'd gain moving
## the good from the cheap biome to the dear one. Zero when they agree; additive
## premium on top of the base surprisal (log bundles add). Replaces the old
## (1 + |p_x − p_y|) multiplier. Cross-biome only (no joint state → not MI).
static func _arbitrage_energy(p_x: float, p_y: float, kT: float) -> float:
	var px: float = clampf(p_x, EnergyPricing.P_FLOOR, 1.0)
	var py: float = clampf(p_y, EnergyPricing.P_FLOOR, 1.0)
	return kT * absf(log(px) - log(py))


static func _static_marginals_from_spec(biome_spec) -> Dictionary:
	## Prior marginals from a Biome spec's atom_components + icons, used to price offers
	## for biomes without a live QC. Open system: steady-state of the decay cycle,
	## p[atom] ∝ 1/rate_out (flux-balance per node). Closed system: there is no steady
	## state (the state oscillates unitarily), so the only honest prior is uniform —
	## every atom equally weighted, giving ≈0.5 marginals until the biome is measured.
	var closed: bool = not BalanceConfig.dissipative_enabled()
	var atom_pop: Dictionary = {}
	var components: Dictionary = biome_spec.atom_components if "atom_components" in biome_spec else {}
	for atom in components.keys():
		var comp = components[atom]
		if not comp is Dictionary:
			continue
		if closed:
			atom_pop[atom] = 1.0  # uniform prior — no dissipative steady state
			continue
		var rate_out: float = 0.0
		if comp.has("decay") and comp["decay"] is Dictionary:
			rate_out += float(comp["decay"].get("rate", 0.0))
		if comp.has("lindblad_outgoing") and comp["lindblad_outgoing"] is Dictionary:
			for t in comp["lindblad_outgoing"].keys():
				rate_out += float(comp["lindblad_outgoing"][t])
		atom_pop[atom] = 1.0 / rate_out if rate_out > 0.0 else 1.0
	var icons: Array = biome_spec.get_neighborhood_icons() if biome_spec.has_method("get_neighborhood_icons") else []
	if atom_pop.is_empty():
		var rate_by_emoji: Dictionary = {}
		for icon in icons:
			if not icon is Dictionary:
				continue
			var cloud = icon.get("cloud", {})
			if not cloud is Dictionary:
				continue
			for emoji in cloud:
				var terms = cloud[emoji]
				if not terms is Dictionary:
					continue
				var r: float = 0.0
				if terms.has("lindblad_outgoing") and terms["lindblad_outgoing"] is Dictionary:
					for t in terms["lindblad_outgoing"].keys():
						r += float(terms["lindblad_outgoing"][t])
				if terms.has("decay") and terms["decay"] is Dictionary:
					r += float(terms["decay"].get("rate", 0.0))
				rate_by_emoji[emoji] = rate_by_emoji.get(emoji, 0.0) + r
		for emoji in rate_by_emoji:
			var r = rate_by_emoji[emoji]
			atom_pop[emoji] = 1.0 if closed else (1.0 / r if r > 0.0 else 1.0)
	var total: float = 0.0
	for v in atom_pop.values():
		total += float(v)
	if total <= 0.0:
		return {}
	for a in atom_pop.keys():
		atom_pop[a] = float(atom_pop[a]) / total
	var marg: Dictionary = {}
	for icon in icons:
		if not icon is Dictionary:
			continue
		var p0: String = str(icon.get("pole_0", ""))
		var p1: String = str(icon.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var w0: float = float(atom_pop.get(p0, 0.0))
		var w1: float = float(atom_pop.get(p1, 0.0))
		var pair_total: float = w0 + w1
		if pair_total <= 0.0:
			marg[p0] = 0.5
			marg[p1] = 0.5
		else:
			marg[p0] = w0 / pair_total
			marg[p1] = w1 / pair_total
	return marg


func _pick_faction_cost_emoji(deliverable: String, marg_fb: Dictionary) -> String:
	var best: String = ""
	var best_p: float = 0.0
	for e in marg_fb.keys():
		if str(e) == deliverable:
			continue
		var p = float(marg_fb[e])
		if p > best_p:
			best_p = p
			best = str(e)
	return best if best != "" else deliverable


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


func _resolve_neighborhood_issuer(emoji: String, biome, registry) -> String:
	# Canonical faction that (a) is admitted to the live biome by signature and
	# (b) speaks this emoji. Random pick among qualifiers so re-rolls (E refresh)
	# cycle factions — every speaker gets a turn, so scarce coupling-resources stay
	# reachable. Falls back to any registry faction speaking the emoji.
	var qualifiers: Array = []
	if biome != null:
		for fname in FactionBiomeMap.factions_for_biome_by_signature(biome):
			if registry == null:
				continue
			var f = registry.get_by_name(str(fname))
			if f != null and f.has_method("speaks") and f.speaks(emoji):
				qualifiers.append(str(fname))
	if not qualifiers.is_empty():
		return str(qualifiers[randi() % qualifiers.size()])
	if registry != null and registry.has_method("get_factions_for_emoji"):
		var fs = registry.get_factions_for_emoji(emoji)
		if fs is Array and not fs.is_empty():
			var f0 = fs[randi() % fs.size()]
			if f0 != null and "name" in f0:
				return str(f0.name)
	return "Unknown"


func _resolve_pair_issuer(emoji: String, biome_a, biome_b, registry) -> String:
	# Signature gate: faction admitted iff it owns an icon in the biome's register.
	for biome in [biome_a, biome_b]:
		if biome == null:
			continue
		var natives: Array = FactionBiomeMap.factions_for_biome_by_signature(biome)
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


func _pick_cost_emoji(deliverable: String, settle_name: String, name_a: String, _name_b: String,
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
		# the classical-only path.
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

	# Reward: surprisal energy −kT·log p (EnergyPricing), bounded and smooth.
	var kT: float = EnergyPricing.biome_temperature(biome, _farm)
	var classical_reward: int = int(round(EnergyPricing.surprisal_energy(p_outcome, kT)))
	if _farm.economy:
		_farm.economy.add_resource(outcome_emoji, classical_reward, "contract_exercise")

	# Collapse on exercise. Closed system: a full projective (von Neumann) collapse —
	# measurement is the only irreversible act, and the qubit re-spreads under H. Open
	# system (DLC): a partial atomic drain whose η scales with the contract's weight.
	if not BalanceConfig.dissipative_enabled():
		qc.project_qubit(qubit_idx, outcome_pole)
	elif biome.has_method("apply_atomic_drain"):
		var eta: float = clampf(p_outcome * 0.1, 0.0, HamiltonianConfig.ETA_HARD_CAP)
		biome.apply_atomic_drain(c.resource, outcome_pole, eta)

	# Symmetric Hamiltonian rotation distribution.
	var post_marginal: float = qc.get_marginal(qubit_idx, c.qubit_pole)
	var theta_total: float = abs(asin(clampf(2.0 * post_marginal - 1.0, -1.0, 1.0)) - asin(clampf(2.0 * pre_marginal - 1.0, -1.0, 1.0)))
	if _farm.has_method("distribute_settlement_theta"):
		_farm.distribute_settlement_theta(theta_total, c)

	c.status = MarketContract.STATUS_EXERCISED

	# Inter-faction substrate: notify StoryEngine so the player faction's
	# AlignmentGraph mixes (Lindblad jump) toward the seller faction's posture.
	# Player → seller only; seller unchanged. Standings are NOT touched here.
	var story_engine = null
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		story_engine = main_loop.root.get_node_or_null("/root/StoryEngine")
	if story_engine != null and story_engine.has_method("on_contract_exercised"):
		story_engine.on_contract_exercised(c.faction, float(c.cost_amount), c.resource, c.biome_name)

	return {
		"ok": true,
		"contract_id": c.id,
		"outcome": outcome_emoji,
		"p_outcome": p_outcome,
		"reward_quantum": classical_reward,  # kT is the anchor now; no separate QC conversion
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
	# Find first live biome whose quantum computer holds a qubit for this emoji.
	if _farm == null or _farm.grid == null:
		return null
	for b in _farm.grid.get_all_biomes().values():
		var qc = b.quantum_computer if "quantum_computer" in b else null
		if qc != null and qc.has_method("has") and qc.has(emoji):
			return b
	return null


func synthesize_and_exercise(emoji: String, faction_name: String = "") -> Dictionary:
	# Synthesize a minimal one-shot contract for emoji in any live biome and
	# immediately exercise it. Used by icon-learn and settlement-rotation events
	# to get a substrate-derived θ via distribute_settlement_theta.
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
