extends "res://tests/smoke_test_base.gd"

## glyph_language_smoke.gd — drives Core/Story/GlyphLanguage.gd and
## Core/Story/FactionChatter.gd headless.
##
## Prints `GLYPH_CASE <json>` for fixed pure inputs, `GLYPH_TAG <json>` for scope
## tags, and `GLYPH_VOICE <json>` for every line FactionChatter emits over mock
## biomes, so tests/test_glyph_language.py can pin the sentences, recompute the
## tags and asks independently, and parse everything with its own grammar.

const GlyphLanguage := preload("res://Core/Story/GlyphLanguage.gd")
const FactionChatter := preload("res://Core/Story/FactionChatter.gd")
const BiomeMeasurementSampler := preload("res://Core/Story/BiomeMeasurementSampler.gd")


class MockRegisterMap extends RefCounted:
	var num_qubits: int = 0
	var axes: Dictionary = {}
	var poles: Dictionary = {}
	var coordinates: Dictionary = {}
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


## A biome over the given [[north, south, p_north], …] registers.
static func make_biome(regs: Array) -> MockBiome:
	var b := MockBiome.new()
	var qc := MockQC.new()
	var rm := MockRegisterMap.new()
	var vc := MockVizCache.new()
	rm.num_qubits = regs.size()
	for q in range(regs.size()):
		rm.axes[q] = {"north": regs[q][0], "south": regs[q][1]}
		rm.coordinates[regs[q][0]] = q
		rm.coordinates[regs[q][1]] = q
		vc.snaps.append({"p0": regs[q][2], "p1": 1.0 - regs[q][2]})
	qc.register_map = rm
	b.quantum_computer = qc
	b.viz_cache = vc
	return b


var _ran := false


func _case(name: String, out: Dictionary, inputs: Dictionary = {}) -> Dictionary:
	print("GLYPH_CASE " + JSON.stringify({"name": name, "in": inputs, "out": out}))
	return out


func _init() -> void:
	print("\n=== Glyph language smoke ===")
	# Numbers at ε = 0.01.
	_check(GlyphLanguage.fmt_number(0.8) == ".8", "0.8 → .8")
	_check(GlyphLanguage.fmt_number(0.05) == ".05", "0.05 → .05")
	_check(GlyphLanguage.fmt_number(0.999) == "1", "0.999 → 1")
	_check(GlyphLanguage.fmt_number(0.001) == "0", "0.001 → 0")
	_check(GlyphLanguage.fmt_number(1.7) == "1", "clamped above")
	# §5 normalization.
	_check(GlyphLanguage.canonical("⚙️") == "⚙", "variation selector stripped")
	_check(GlyphLanguage.canonical("👍🏽") == "👍", "skin tone stripped")
	_check(GlyphLanguage.canonical("👨‍🌾") == "👨‍🌾", "ZWJ sequence kept whole")
	# The physics that drives a line.
	_check(GlyphLanguage.ask_probability(0.5) > 0.999, "a coin is always asked about")
	_check(GlyphLanguage.ask_probability(1.0) == 0.0, "a settled pole is never asked about")
	_check(GlyphLanguage.ask_probability(0.9) < GlyphLanguage.ask_probability(0.7), "steadier asks less")
	_check(GlyphLanguage.mention_probability(0.0, 0.05) == 0.0, "no motion, no mention")
	_check(GlyphLanguage.mention_probability(1.0, 0.05) > 0.99, "all news is mentioned")
	_check(absf(GlyphLanguage.fidelity(0.3, 0.3) - 1.0) < 1e-9, "same reading: fidelity 1")
	_check(GlyphLanguage.fidelity(1.0, 0.0) < 1e-9, "opposite poles: fidelity 0")
	_check(GlyphLanguage.VERBS["null"] == "⚫" and GlyphLanguage.VERBS["creation"] == "✨", "null ⚫, creation ✨ (Antimatter)")

	# Scope tags (the pytest recomputes them with hashlib).
	var village := [["🔥", "❄"], ["👥", "🍞"], ["⚙", "💨"]]
	for row in [["Village", village], ["Fitting", [["⚙️", "🔧"]]]]:
		print("GLYPH_TAG " + JSON.stringify({"text": GlyphLanguage.pairs_text(row[1]), "tag": GlyphLanguage.scope_tag(row[1])}))
	var vscope := GlyphLanguage.biome_scope("Village", village)

	# Biome-scope chatter: asks drawn against binary entropy.
	_case("village", GlyphLanguage.compose_chatter(["🔥", "👥", "⚙"], [0.82, 0.61, 0.97], vscope, [0.9, 0.5, 0.1]),
		{"marginals": [0.82, 0.61, 0.97], "draws": [0.9, 0.5, 0.1]})
	_case("village_no_draws", GlyphLanguage.compose_chatter(["🔥", "👥", "⚙"], [0.82, 0.61, 0.97], vscope, []))
	_case("partly_dark", GlyphLanguage.compose_chatter(["☀", "🌾", "🍄"], [0.9], "spacewheat/BioticFlux@0000", [0.0, 0.0, 0.0]))
	_case("no_scope", GlyphLanguage.compose_chatter(["🌾", "👥"], [], "", []))
	_case("selector", GlyphLanguage.compose_chatter(["⚙️", "🔧"], [1.0, 0.25], "spacewheat/StellarForges@0000", [0.5, 0.5]))
	_case("empty", GlyphLanguage.compose_chatter([], [], vscope, []))
	# A faction line with dark registers.
	_case("faction", GlyphLanguage.compose(
		GlyphLanguage.faction_scope("Swift Herd", [["🐇", "🦌"], ["🌿", "🌾"], ["🦌", "🌿"]]),
		[{"glyph": "🦌", "p": 0.71}, {"glyph": "🌿", "p": 0.88}], ["🐇🦌"], ["🦌"]))
	_case("faction_all_dark", GlyphLanguage.compose(
		GlyphLanguage.faction_scope("The Demos", [["👥", "🌾"]]), [], ["👥🌾"], []))
	# Between two biomes.
	var prod := GlyphLanguage.product_scope(["BioticFlux", "StarterForest"], [[["☀", "🌙"]], [["☀", "🌙"]]])
	_case("between", GlyphLanguage.compose_between(prod, "⚠", [{"glyph": "☀", "p": 0.82}, {"glyph": "☀", "p": 0.31}]))
	_check(GlyphLanguage.between_verb(0.9, 0.1) == "⚠", "readings leaning to different poles: tension")
	_check(GlyphLanguage.between_verb(0.95, 0.55) == "🟰", "readings leaning the same way: resonance")

	# Real sampler path: a 2-qubit biome pinned to |🌾👥⟩.
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
	var out := _case("sampler", GlyphLanguage.compose_chatter(sample.get("emojis", []), sample.get("marginals", []),
		"spacewheat/TheDemos@0000", [0.99, 0.0]))
	_check(out.get("ket", "") == "|🌾👥⟩", "sampler ket is the drawn basis state")
	_check(out.get("asks", []) == ["⟨👥|"], "sampler asks only where the draw fell under h(p)")


func _process(_delta: float) -> bool:
	# FactionChatter reads the IconRegistry autoload, live only once the tree runs.
	if _ran:
		return false
	_ran = true
	_run_voices()
	_finish("Glyph language smoke")
	return false


func _run_voices() -> void:
	var icon_registry = get_root().get_node_or_null("/root/IconRegistry")
	_check(icon_registry != null, "IconRegistry autoload resolves")
	if icon_registry == null:
		return
	seed(7)
	# Real icon pairs, so the market's connection rule admits real factions:
	# Celestial Archons hold Solar ☀/🌙 and Elemental 🔥/💧 (and Geostorm ⛰/🌬,
	# which no mock biome has → dark). Solar lives in both biomes, far apart.
	var biomes := {
		"BioticFlux": make_biome([["☀", "🌙", 0.9], ["🔥", "💧", 0.6]]),
		"StarterForest": make_biome([["☀", "🌙", 0.1]]),
	}
	var voices := FactionChatter.new()
	var standings := {}
	var archon_lines: Array = []
	var between: Array = []
	var story_lines := 0
	for t in range(160):
		# Move ☀ in BioticFlux a little each tick so motion keeps some talk alive.
		var p := 0.9 - 0.3 * absf(sin(float(t) * 0.2))
		biomes["BioticFlux"].viz_cache.snaps[0] = {"p0": p, "p1": 1.0 - p}
		for ev in voices.tick(biomes, icon_registry, null, standings):
			print("GLYPH_VOICE " + JSON.stringify(ev))
			if ev.get("kind", "") == "between":
				between.append(ev)
			elif str(ev.get("faction", "")) == "Celestial Archons":
				archon_lines.append(ev)
			if bool(ev.get("story", false)):
				story_lines += 1
	_check(not archon_lines.is_empty(), "Celestial Archons speak (connected by Solar/Elemental)")
	var saw_dark := false
	var lengths := {}
	for ev in archon_lines:
		var g: Dictionary = ev.get("glyph", {})
		_check(str(g.get("scope", "")).begins_with("faction/Celestial Archons@"), "archon line is in the faction's scope")
		for d in ev.get("darks", []):
			saw_dark = saw_dark or d == "⛰🌬"
		lengths[ev.get("emojis", []).size()] = true
	_check(saw_dark, "Geostorm ⛰🌬 is written dark: an icon you hold nowhere")
	_check(lengths.size() >= 2, "line length varies with motion")
	_check(not between.is_empty(), "Solar read in two biomes yields a between line")
	for ev in between:
		_check(str(ev.get("scope", "")).contains("⊗"), "between line is in a product scope")
	_check(story_lines > 0, "the Story draw speaks with no standing (your own people)")
	var orphan := false
	for ev in voices.recent(96):
		orphan = orphan or str(ev.get("faction", "")) == "orphaned_icons"
	_check(not orphan, "the orphaned_icons bucket never speaks")
