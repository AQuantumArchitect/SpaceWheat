@tool
extends SceneTree

## tests/market_lab_biomes.gd — laboratory readout of how the ContractMarket
## behaves under each biome's axial position.
##
## For every biome in biomes.json this script:
##   1. Constructs a fake biome object carrying the biome's native_factions and
##      emoji set (enough surface for ContractMarket._build_biome_bits).
##   2. Asks ContractMarket.propose_offers(biome) for that biome.
##   3. Reports a one-line summary + an optional detail block:
##        - biome bits (12-axis projection from native factions)
##        - top-3 offers (faction, resource, qty, market_score, scarcity)
##        - principal-mode eigenvalue and axis projection
##        - Hamiltonian eigen summary (top-4 eigenvalues + gap)
##        - top-5 most-spoken emojis (demand signal)
##
## Optional flags via OS.get_cmdline_args():
##   --biome NAME    only run a single biome
##   --top N         show top-N offers per biome (default 3)
##   --detail        emit per-biome detail blocks (else: one line each)
##   --csv PATH      also dump a CSV of biome × top-offer rows
##
## Run: godot --headless -s tests/market_lab_biomes.gd [-- --detail]

const ContractMarket = preload("res://Core/Markets/ContractMarket.gd")
const SubstrateFixtures = preload("res://tests/substrate_fixtures.gd")
const FactionAxes = preload("res://Core/Factions/FactionAxes.gd")

const BIOMES_PATH := "res://Core/Biomes/data/biomes.json"


func _init() -> void:
	var args := _parse_args()
	var biomes := _load_biomes()
	if biomes.is_empty():
		printerr("market_lab: failed to load biomes.json")
		quit(1)
		return

	var biome_filter: String = args.get("biome", "")
	var top_n: int = int(args.get("top", 3))
	var detail: bool = bool(args.get("detail", false))
	var csv_path: String = args.get("csv", "")

	var farm = SubstrateFixtures.TestFarm.new()
	var market = ContractMarket.new(farm)

	print("\n=== MARKET LAB · %d biomes · top-%d offers · %s ===" %
		[biomes.size(), top_n, "DETAIL" if detail else "summary"])
	_print_global_state(farm)

	var csv_lines := PackedStringArray()
	if csv_path != "":
		csv_lines.push_back("biome,offer_rank,faction,resource,quantity,market_score,scarcity,alignment")

	var ran := 0
	for biome_dict in biomes:
		var bname: String = str(biome_dict.get("name", ""))
		if bname.begins_with("_"):
			# Synthetic / internal biomes (e.g. _orphan_lindblads); skip.
			continue
		if biome_filter != "" and bname != biome_filter:
			continue
		ran += 1
		var biome := _make_biome_stub(biome_dict)
		var offers: Array = market.propose_offers(biome, top_n)
		_report_biome(biome, offers, top_n, detail, market, farm)
		if csv_path != "":
			for i in range(min(offers.size(), top_n)):
				csv_lines.push_back(_offer_to_csv_row(bname, i + 1, offers[i]))

	print("\n=== LAB DONE · %d biomes scanned ===" % ran)
	if csv_path != "" and not csv_lines.is_empty():
		var fp := FileAccess.open(csv_path, FileAccess.WRITE)
		if fp:
			fp.store_string("\n".join(csv_lines) + "\n")
			fp.close()
			print("CSV → %s (%d rows)" % [csv_path, csv_lines.size() - 1])
	quit(0)


func _parse_args() -> Dictionary:
	# get_cmdline_user_args returns only what's after `--` on the godot
	# command line — what the user actually passed for our script.
	var args := {}
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var a: String = raw[i]
		match a:
			"--biome":
				i += 1
				args["biome"] = str(raw[i]) if i < raw.size() else ""
			"--top":
				i += 1
				args["top"] = int(raw[i]) if i < raw.size() else 3
			"--detail":
				args["detail"] = true
			"--csv":
				i += 1
				args["csv"] = str(raw[i]) if i < raw.size() else ""
		i += 1
	return args


func _load_biomes() -> Array:
	var fp := FileAccess.open(BIOMES_PATH, FileAccess.READ)
	if not fp:
		return []
	var json := JSON.new()
	if json.parse(fp.get_as_text()) != OK:
		fp.close()
		return []
	fp.close()
	var data = json.data
	return data if data is Array else []


func _make_biome_stub(biome_dict: Dictionary) -> Object:
	# Tiny biome-like Object that exposes the fields ContractMarket reads:
	# `name` and `_biome_data.native_factions`.
	var stub := _BiomeStub.new()
	stub.name = str(biome_dict.get("name", ""))
	stub._biome_data = {
		"native_factions": biome_dict.get("native_factions", []),
		"emojis": biome_dict.get("emojis", []),
	}
	return stub


func _print_global_state(farm) -> void:
	var fdm = farm.faction_density
	var n: int = fdm.get_size()
	var purity: float = fdm.get_purity()
	var summary: Dictionary = fdm.get_hamiltonian_eigen_summary(4)
	var ev = summary.get("eigenvalues", PackedFloat64Array())
	var ev_str := ""
	for v in ev:
		ev_str += " %.3f" % float(v)
	print("Substrate: %d factions · purity=%.4f · top-4 λ:%s" % [n, purity, ev_str])
	var lex_summary: String = farm.icon_lexicon.summary()
	print("           %s" % lex_summary)


func _report_biome(biome, offers: Array, top_n: int, detail: bool, market, farm) -> void:
	var bname: String = str(biome.name)
	var top_score: float = 0.0
	if not offers.is_empty():
		top_score = float(offers[0].get("market_projection", {}).get("market_score", 0.0))
	if not detail:
		print("· %-22s offers=%-3d  top_score=%.3f" % [bname, offers.size(), top_score])
		return

	# Detail block
	print("\n— %s —" % bname)
	var native: Array = biome._biome_data.get("native_factions", [])
	print("  native factions (%d): %s" % [native.size(), ", ".join(native.slice(0, 6))])
	var bits: Array = market._build_biome_bits(biome)
	print("  biome bits: [%s]" % _fmt_bits(bits))
	# Top offers
	print("  top %d offers:" % min(top_n, offers.size()))
	for i in range(min(top_n, offers.size())):
		var o: Dictionary = offers[i]
		var proj: Dictionary = o.get("market_projection", {})
		print("    %d. %-26s %s × %-3d  score=%.3f  scarcity=%.3f  align=%.3f" % [
			i + 1,
			str(o.get("faction", "?")),
			str(o.get("resource", "?")),
			int(o.get("quantity", 0)),
			float(proj.get("market_score", 0.0)),
			float(proj.get("scarcity", 0.0)),
			float(proj.get("alignment", 0.0)),
		])
	# Spectral signal — needs a fresh rebuild for THIS biome (propose_offers above did rebuild already)
	var pa: Array = farm.faction_density.get_principal_axis_projection()
	print("  principal axis projection: [%s]" % _fmt_bits(pa))


func _fmt_bits(arr: Array) -> String:
	var parts := PackedStringArray()
	for v in arr:
		parts.push_back("%.2f" % float(v))
	return ", ".join(parts)


func _offer_to_csv_row(biome: String, rank: int, offer: Dictionary) -> String:
	var proj: Dictionary = offer.get("market_projection", {})
	return "%s,%d,%s,%s,%d,%.4f,%.4f,%.4f" % [
		biome, rank,
		str(offer.get("faction", "")),
		str(offer.get("resource", "")),
		int(offer.get("quantity", 0)),
		float(proj.get("market_score", 0.0)),
		float(proj.get("scarcity", 0.0)),
		float(proj.get("alignment", 0.0)),
	]


class _BiomeStub:
	var name: String = ""
	var _biome_data: Dictionary = {}
