extends SceneTree

## market_flatness_lab.gd — empirical readout of Phase VI market dynamics.
##
## Runs with the real biomes + factions + IconLexicon + AffinityGraph
## substrate (everything Phase II–V wired) and answers:
##
##   1. How spread is `P_gozouta` across all viable (biome, faction, emoji)
##      contracts? If everything clusters near 0.5 → market is flat (the
##      user's worry).
##   2. How spread is `price`? min / max / median / IQR.
##   3. Is the market a "buy any contract for ~20¢" world, or does the
##      bias-source composition actually create a price gradient?
##   4. How does P move when biome substrate drifts? (Stub — full drift test
##      requires running biome evolution; we report implied marginals only.)
##   5. EV gradient: at each offered contract, what is E[reward at exercise]
##      under the offer-time P, and what is the player's expected profit?
##
## Run:  godot --headless --quit --script tests/market_flatness_lab.gd
##
## Reports a histogram, summary stats, and the worst-case and best-case
## contracts (most extreme P) so we can eyeball the substrate's reach.

const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")
const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")
const BiomeRegistryCls = preload("res://Core/Biomes/BiomeRegistry.gd")
const IconLexicon = preload("res://Core/Factions/IconLexicon.gd")
const MarketBiasSources = preload("res://Core/Markets/MarketBiasSources.gd")
const PriceModel = preload("res://Core/Markets/PriceModel.gd")
const MC = preload("res://Core/Markets/Contract.gd")
const AffinityGraphCls = preload("res://Core/Affinity/AffinityGraph.gd")


# ----- minimal Farm stand-in for sources that introspect farm fields -----
class FakeFarm:
	var faction_density = null
	var faction_standings: Dictionary = {}
	var player_affinity = null
	var grid = null
	var icon_lexicon = null

class FakeFD:
	var _registry = null
	var _icon_to_owners: Dictionary = {}
	func _init(reg, lex):
		_registry = reg
		# Build emoji -> [faction names] map from the registry directly.
		for f in reg.get_all():
			for e in f.signature:
				var key: String = str(e)
				if not _icon_to_owners.has(key):
					_icon_to_owners[key] = []
				_icon_to_owners[key].append(str(f.name))
	func get_registry(): return _registry
	func affinity_for_emoji(emoji: String) -> float:
		# Approximate: count of factions speaking emoji / total factions
		var n = _icon_to_owners.get(emoji, []).size()
		var total = _registry.get_all().size()
		return clampf(float(n) / float(total) if total > 0 else 0.0, 0.0, 1.0)
	func factions_speaking(emoji: String) -> Array:
		return _icon_to_owners.get(emoji, [])
	func get_principal_axis_projection() -> Array:
		# Stub — return uniform 0.5s; real FDM is wired only on full Farm.
		var out: Array = []
		for i in range(12):
			out.append(0.5)
		return out
	func get_weight(name: String) -> float:
		# Stub — uniform 1/F
		var total = _registry.get_all().size()
		return 1.0 / float(total) if total > 0 else 0.0
	# Note: has_method is implicit (Object.has_method covers our funcs).


func _init() -> void:
	print("=== MARKET FLATNESS LAB ===\n")
	var faction_reg = FactionRegistryCls.new()
	faction_reg.load_factions()
	var biome_reg = BiomeRegistryCls.new()
	biome_reg.load_biomes()
	var lex = IconLexicon.new()  # auto-loads
	var farm = FakeFarm.new()
	farm.faction_density = FakeFD.new(faction_reg, lex)
	# Pick "engaged player" or "fresh player" via env arg.
	var engaged: bool = false
	for arg in OS.get_cmdline_args():
		if arg == "--engaged":
			engaged = true
	for arg in OS.get_cmdline_user_args():
		if arg == "--engaged":
			engaged = true
	if engaged:
		print("[player: ENGAGED — affinity rotated toward 5 random factions, standings populated]\n")
		farm.player_affinity = AffinityGraphCls.from_uniform_superposition()
		# Rotate toward 5 factions (simulates 5 icon-learns).
		var sample: Array = faction_reg.get_all().duplicate()
		sample.shuffle()
		for k in range(5):
			var f = sample[k]
			if f == null or f.bits.size() != AffinityGraphCls.AXIS_COUNT:
				continue
			for axis in range(AffinityGraphCls.AXIS_COUNT):
				var theta: float = 0.3 if int(f.bits[axis]) == 1 else -0.3
				farm.player_affinity.rotate_axis(axis, theta)
			# Populate standing for that faction.
			var fs = load("res://Core/Factions/FactionStanding.gd").new()
			fs.legitimacy = 1.5
			fs.trust = 1.0
			farm.faction_standings[f.name] = fs
	else:
		print("[player: FRESH — uniform |+⟩^12, no standings, day-zero state]\n")
		farm.player_affinity = AffinityGraphCls.from_uniform_superposition()
	# Bias sources will compute biome affinity live (no need to attach).
	# Lab needs farm to expose icon_lexicon for the live path.
	farm.icon_lexicon = lex

	# Sample contracts across all biomes × their signature icons × owner factions.
	var p_values: Array = []
	var price_values: Array = []
	var sample_records: Array = []  # for top/bottom display
	for biome in biome_reg.get_all():
		for pair in biome.get_signature_pairs():
			var icon: Dictionary = lex.find_icon_by_pair(pair.pole_0, pair.pole_1)
			var owner: String = str(icon.get("owner_faction", ""))
			if owner == "":
				continue
			# Build two contracts: one for each pole (gozouta = pole 0 vs 1).
			for pole in [0, 1]:
				var emoji: String = pair.pole_0 if pole == 0 else pair.pole_1
				var c = MC.make(emoji, owner, biome.name, pole, 0, 0.0, 100)
				var p = PriceModel.implied_marginal(c, farm)
				var price = PriceModel.price_contract(c, farm)
				p_values.append(p)
				price_values.append(price)
				sample_records.append({
					"biome": biome.name, "faction": owner, "emoji": emoji,
					"pole": pole, "p": p, "price": price,
				})

	if p_values.is_empty():
		print("no contracts sampled — substrate not wired correctly")
		quit(1)
		return

	print("Contracts sampled: %d\n" % p_values.size())

	_report_distribution("P_gozouta", p_values, 10)
	_report_distribution("price (¢)", price_values, 10)
	_report_ev_gradient(p_values, price_values)
	_report_extremes(sample_records)
	_report_flatness_diagnostic(p_values, price_values)
	quit(0)


func _attach_biome_affinity(biome, lex, faction_reg) -> void:
	# Mirror Phase V _build_biome_affinity logic: equal-weight Lindblad mix of
	# owner factions' affinities. Skips biomes with no resolvable owners.
	var pairs: Array = biome.get_signature_pairs()
	if pairs.is_empty():
		biome.set_meta("affinity", null)
		return
	var owners: Array = []
	for pair in pairs:
		var icon: Dictionary = lex.find_icon_by_pair(pair.pole_0, pair.pole_1)
		var o: String = str(icon.get("owner_faction", "")) if not icon.is_empty() else ""
		if o != "":
			owners.append(o)
	if owners.is_empty():
		return
	var first_f = faction_reg.get_by_name(owners[0])
	if first_f == null or first_f.affinity == null:
		return
	var bg = AffinityGraphCls.from_dict(first_f.affinity.to_dict())
	for i in range(1, owners.size()):
		var f = faction_reg.get_by_name(owners[i])
		if f != null and f.affinity != null:
			bg.lindblad_jump_toward(f.affinity, 1.0 / float(i + 1))
	# Patch the biome with a duck-typed .affinity (Biome.gd has no field; use meta + script var).
	# MarketBiasSources reads via "affinity" in biome — meta-set via direct property.
	biome.affinity = bg


func _report_distribution(label: String, values: Array, bins: int) -> void:
	var sorted = values.duplicate()
	sorted.sort()
	var mn = sorted[0]
	var mx = sorted[sorted.size() - 1]
	var med = sorted[sorted.size() / 2]
	var sum = 0.0
	for v in values:
		sum += v
	var mean = sum / values.size()
	# IQR
	var q1 = sorted[sorted.size() / 4]
	var q3 = sorted[(sorted.size() * 3) / 4]
	print("=== %s ===" % label)
	print("  min=%.4f  Q1=%.4f  med=%.4f  mean=%.4f  Q3=%.4f  max=%.4f"
		% [mn, q1, med, mean, q3, mx])
	# histogram
	if mx > mn:
		var step = (mx - mn) / float(bins)
		var counts: Array[int] = []
		for i in range(bins):
			counts.append(0)
		for v in values:
			var idx = int((v - mn) / step)
			if idx >= bins:
				idx = bins - 1
			counts[idx] += 1
		var max_count = 0
		for c in counts:
			if c > max_count:
				max_count = c
		print("  histogram (each # ≈ %d contracts):" % maxi(max_count / 30, 1))
		for i in range(bins):
			var lo = mn + step * i
			var hi = mn + step * (i + 1)
			var bar = ""
			var n_chars = mini(counts[i] * 30 / maxi(max_count, 1), 30)
			for _j in range(n_chars):
				bar += "#"
			print("    [%7.3f, %7.3f) %s (%d)" % [lo, hi, bar, counts[i]])
	print()


func _report_ev_gradient(p_values: Array, price_values: Array) -> void:
	# At each contract: cost = price; E[reward at exercise] = 2 quantum × QC_RATIO = 20 classical
	# (constant!). E[profit] = 20 - price.
	# If prices span widely, E[profit] spans widely → market is NOT flat in EV.
	var profits: Array = []
	for i in range(p_values.size()):
		profits.append(20.0 - price_values[i])
	var sorted = profits.duplicate()
	sorted.sort()
	var positive = 0
	var negative = 0
	for v in profits:
		if v > 0.5:
			positive += 1
		elif v < -0.5:
			negative += 1
	print("=== Player EV after price ===")
	print("  E[reward at exercise] = 20 classical (qubit dim × QC_RATIO; constant by design)")
	print("  E[profit] = 20 − price; range %.2f to %.2f" % [sorted[0], sorted[sorted.size() - 1]])
	print("  +EV contracts: %d   −EV contracts: %d   ~neutral: %d"
		% [positive, negative, p_values.size() - positive - negative])
	print()


func _report_extremes(records: Array) -> void:
	records.sort_custom(func(a, b): return a.p < b.p)
	print("=== Cheapest contracts (highest P_gozouta — high price would be paid here too) ===")
	for r in records.slice(records.size() - 5, records.size()):
		print("  P=%.3f  ¢%.1f  %s/%s in %s (pole %d)" %
			[r.p, r.price, r.faction, r.emoji, r.biome, r.pole])
	print()
	print("=== Most expensive contracts (lowest P_gozouta — lottery lottery) ===")
	for r in records.slice(0, 5):
		print("  P=%.3f  ¢%.1f  %s/%s in %s (pole %d)" %
			[r.p, r.price, r.faction, r.emoji, r.biome, r.pole])
	print()


func _report_flatness_diagnostic(p_values: Array, price_values: Array) -> void:
	# Heuristics:
	#  - p_range = max(P) − min(P): how much does the bias composition span?
	#  - price_ratio = max/min: how much do prices vary?
	#  - p_std: cluster around 0.5 → small std; spread → large std.
	var sorted_p = p_values.duplicate()
	sorted_p.sort()
	var sorted_price = price_values.duplicate()
	sorted_price.sort()
	var p_range = sorted_p[sorted_p.size() - 1] - sorted_p[0]
	var price_ratio = sorted_price[sorted_price.size() - 1] / max(sorted_price[0], 0.0001)
	var sum_p = 0.0
	for v in p_values:
		sum_p += v
	var mean_p = sum_p / p_values.size()
	var sum_sq = 0.0
	for v in p_values:
		sum_sq += (v - mean_p) * (v - mean_p)
	var std_p = sqrt(sum_sq / p_values.size())
	print("=== Flatness diagnostic ===")
	print("  P_gozouta range: %.4f  (1.0 = full spread, 0 = totally flat)" % p_range)
	print("  P_gozouta std:   %.4f  (0.288 = uniform [0,1], 0 = constant)" % std_p)
	print("  price max/min:   %.2fx (1.0 = totally flat, ∞ = wide)" % price_ratio)
	if p_range < 0.2:
		print("  ⚠️ MARKET IS FLAT — P only spans %.1f%% of [0,1]" % (p_range * 100.0))
	elif p_range < 0.5:
		print("  ◔ Market is partially flat — P spans %.1f%% of [0,1]" % (p_range * 100.0))
	else:
		print("  ✓ Market has range — P spans %.1f%% of [0,1]" % (p_range * 100.0))
	print()
