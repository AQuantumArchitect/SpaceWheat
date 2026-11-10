extends "res://tests/smoke_test_base.gd"

## glyph_language_smoke.gd — drives Core/Story/GlyphLanguage.gd headless.
##
## Prints one `GLYPH_CASE <json>` line per fixed input so tests/test_glyph_language.py
## can pin the exact sentences and parse them with an independent reference grammar.
## Also runs the real chatter path (BiomeMeasurementSampler over a mock biome) so the
## event's marginals reach the composer the way SocialiteCluster.tick feeds them.

const GlyphLanguage := preload("res://Core/Story/GlyphLanguage.gd")
const BiomeMeasurementSampler := preload("res://Core/Story/BiomeMeasurementSampler.gd")


class MockRegisterMap extends RefCounted:
	var poles: Dictionary = {}
	func pole(emoji: String) -> int:
		return int(poles.get(emoji, 0))

class MockVizCache extends RefCounted:
	var snaps: Array = []
	func get_snapshot(qid: int) -> Dictionary:
		return snaps[qid] if qid < snaps.size() else {}

class MockQC extends RefCounted:
	var states: Array = []
	var register_map = null
	func get_basis_state_probabilities() -> Array:
		return states

class MockBiome extends RefCounted:
	var quantum_computer = null
	var viz_cache = null


func _case(name: String, emojis: Array, marginals: Array, biome: String) -> Dictionary:
	var out: Dictionary = GlyphLanguage.compose_chatter(emojis, marginals, biome)
	var row := {"name": name, "emojis": emojis, "marginals": marginals, "biome": biome, "out": out}
	print("GLYPH_CASE " + JSON.stringify(row))
	return out


func _init() -> void:
	print("\n=== Glyph language smoke ===")

	# Numbers at ε = 0.01.
	_check(GlyphLanguage.fmt_number(0.8) == ".8", "0.8 → .8")
	_check(GlyphLanguage.fmt_number(0.825) == ".83" or GlyphLanguage.fmt_number(0.825) == ".82", "0.825 rounds to hundredths")
	_check(GlyphLanguage.fmt_number(0.05) == ".05", "0.05 → .05")
	_check(GlyphLanguage.fmt_number(0.999) == "1", "0.999 → 1")
	_check(GlyphLanguage.fmt_number(0.001) == "0", "0.001 → 0")
	_check(GlyphLanguage.fmt_number(1.7) == "1", "clamped above")
	# §5 normalization.
	_check(GlyphLanguage.canonical("⚙️") == "⚙", "variation selector stripped")
	_check(GlyphLanguage.canonical("👍🏽") == "👍", "skin tone stripped")
	_check(GlyphLanguage.canonical("👨‍🌾") == "👨‍🌾", "ZWJ sequence kept whole")

	# Fixed cases (pinned verbatim by the pytest).
	_case("village", ["🔥", "👥", "⚙", "💰"], [0.82, 0.61, 0.5, 0.97], "Village")
	_case("demos_tie", ["👥", "🌾"], [0.7, 0.3], "TheDemos")
	_case("partly_dark", ["☀", "🌾", "🍄"], [0.9], "BioticFlux")
	_case("no_scope", ["🌾", "👥"], [], "")
	_case("selector", ["⚙️", "🔧"], [1.0, 0.25], "StellarForges")
	_case("all_dark", ["🐺", "🦅"], [], "StarterForest")
	_case("empty", [], [], "Village")

	# Real sampler path: a 2-qubit biome pinned to |🌾👥⟩ with known marginals.
	var biome := MockBiome.new()
	var qc := MockQC.new()
	qc.states = [{"label": "🌾👥", "probability": 1.0}]
	var rm := MockRegisterMap.new()
	rm.poles = {"🌾": 0, "👥": 1}
	qc.register_map = rm
	biome.quantum_computer = qc
	var vc := MockVizCache.new()
	vc.snaps = [{"p0": 0.9, "p1": 0.1}, {"p0": 0.35, "p1": 0.65}]
	biome.viz_cache = vc
	var sample: Dictionary = BiomeMeasurementSampler.sample_basis_with_marginals(biome)
	var out := _case("sampler", sample.get("emojis", []), sample.get("marginals", []), "TheDemos")
	_check(out.get("ket", "") == "|🌾👥⟩", "sampler ket is the drawn basis state")
	_check(out.get("ask", "") == "⟨👥|", "sampler asks about the least-sure register")

	_finish("Glyph language smoke")
