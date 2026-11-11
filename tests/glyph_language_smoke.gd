extends "res://tests/smoke_test_base.gd"

## glyph_language_smoke.gd — drives Core/Story/GlyphLanguage.gd and
## Core/Story/FactionChatter.gd headless.
##
## Prints `GLYPH_CASE <json>` for fixed pure inputs, `GLYPH_TAG <json>` for scope
## tags, and `GLYPH_VOICE <json>` for every line FactionChatter emits over mock
## biomes, so tests/test_glyph_language.py can pin the sentences, recompute the
## tags and asks independently, and parse everything with its own grammar.
##
## The mocks carry a basis distribution and mutual information, so the faction
## voices exercise joint draws and ties (a Bell pair), and paired runs at
## different standing channels exercise the relationship lifts.

const GlyphLanguage := preload("res://Core/Story/GlyphLanguage.gd")
const FactionChatter := preload("res://Core/Story/FactionChatter.gd")
const BiomeMeasurementSampler := preload("res://Core/Story/BiomeMeasurementSampler.gd")
const FactionStandingCls := preload("res://Core/Factions/FactionStanding.gd")


class MockRegisterMap extends RefCounted:
	var num_qubits: int = 0
	var axes: Dictionary = {}
	var poles: Dictionary = {}
	var coordinates: Dictionary = {}
	func pole(emoji: String) -> int:
		return int(poles.get(emoji, 0))

class MockVizCache extends RefCounted:
	var snaps: Array = []
	var mi: Dictionary = {}   # "a:b" → bits
	func get_snapshot(qid: int) -> Dictionary:
		return snaps[qid] if qid < snaps.size() else {}
	func get_mutual_information(a: int, b: int) -> float:
		return float(mi.get("%d:%d" % [mini(a, b), maxi(a, b)], 0.0))

class MockQC extends RefCounted:
	var states: Array = []
	var register_map = null
	func get_basis_state_probabilities() -> Array:
		return states

class MockBiome extends RefCounted:
	var quantum_computer = null
	var viz_cache = null


## A biome over [[north, south, p_north], …]. Basis states are the product
## distribution unless `joint` ({label → probability}) is given.
static func make_biome(regs: Array, joint: Dictionary = {}, mi: Dictionary = {}) -> MockBiome:
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
	vc.mi = mi
	qc.register_map = rm
	b.quantum_computer = qc
	b.viz_cache = vc
	set_basis(b, regs, joint)
	return b


static func set_basis(b: MockBiome, regs: Array, joint: Dictionary = {}) -> void:
	var states: Array = []
	if not joint.is_empty():
		for label in joint:
			states.append({"label": label, "probability": joint[label]})
	else:
		var n := regs.size()
		for i in range(1 << n):
			var label := ""
			var p := 1.0
			for q in range(n):
				var south := (i >> (n - 1 - q)) & 1 == 1
				label += regs[q][1] if south else regs[q][0]
				p *= (1.0 - regs[q][2]) if south else regs[q][2]
			states.append({"label": label, "probability": p})
	b.quantum_computer.states = states


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
	# The three information quantities.
	_check(GlyphLanguage.ask_probability(0.5) > 0.999, "entropy: a coin is always asked about")
	_check(GlyphLanguage.ask_probability(1.0) == 0.0, "entropy: a settled pole is never asked about")
	_check(GlyphLanguage.ask_probability(0.9) < GlyphLanguage.ask_probability(0.7), "entropy: steadier asks less")
	_check(GlyphLanguage.relative_entropy(0.4, 0.4) < 1e-12, "relative entropy: nothing changed, no news")
	_check(GlyphLanguage.relative_entropy(0.9, 0.99) > GlyphLanguage.relative_entropy(0.6, 0.5), "relative entropy: a certainty breaking outweighs a coin wobbling")
	_check(GlyphLanguage.mention_probability(0.0) == 0.0, "no news, no mention")
	_check(GlyphLanguage.mention_probability(INF) == 1.0, "never spoken of: always mentioned")
	_check(absf(GlyphLanguage.mention_probability(1.0) - (1.0 - exp(-1.0))) < 1e-9, "mention = 1 − e^(−D)")
	_check(GlyphLanguage.tie_probability(1.0) == 1.0 and GlyphLanguage.tie_probability(0.0) == 0.0, "mutual information: Bell pair always tied, product never")
	var bell := [{"bits": [1, 1], "p": 0.5}, {"bits": [0, 0], "p": 0.5}]
	var product := [{"bits": [1, 1], "p": 0.25}, {"bits": [1, 0], "p": 0.25}, {"bits": [0, 1], "p": 0.25}, {"bits": [0, 0], "p": 0.25}]
	_check(absf(BiomeMeasurementSampler.pair_mutual_information(bell, 0, 1) - 1.0) < 1e-9, "pole MI of a Bell pair is 1 bit")
	_check(BiomeMeasurementSampler.pair_mutual_information(product, 0, 1) < 1e-9, "pole MI of a product state is 0")
	# Relationship lifts.
	_check(GlyphLanguage.lift(0.25, 0.0) == 0.25, "lift: no channel, no change")
	_check(absf(GlyphLanguage.lift(0.25, 1.0) - 0.5) < 1e-9, "lift: c = 1 is a square root")
	_check(GlyphLanguage.lift(0.25, -0.5) < 0.25, "lift: a negative channel closes")
	_check(GlyphLanguage.lift(0.0, 4.0) == 0.0 and GlyphLanguage.lift(1.0, -0.9) == 1.0, "lift: never invents, never hides a certainty")
	_check(absf(GlyphLanguage.fidelity(0.3, 0.3) - 1.0) < 1e-9, "same reading: fidelity 1")
	_check(GlyphLanguage.VERBS["null"] == "⚫" and GlyphLanguage.VERBS["creation"] == "✨", "null ⚫, creation ✨ (Antimatter)")

	# Scope tags (the pytest recomputes them with hashlib).
	var village := [["🔥", "❄"], ["👥", "🍞"], ["⚙", "💨"]]
	for row in [["Village", village], ["Fitting", [["⚙️", "🔧"]]]]:
		print("GLYPH_TAG " + JSON.stringify({"text": GlyphLanguage.pairs_text(row[1]), "tag": GlyphLanguage.scope_tag(row[1])}))
	var vscope := GlyphLanguage.biome_scope("Village", village)

	# Biome-scope chatter: asks drawn against binary entropy; ties given.
	_case("village", GlyphLanguage.compose_chatter(["🔥", "👥", "⚙"], [0.82, 0.61, 0.97], vscope, [0.9, 0.5, 0.1]),
		{"marginals": [0.82, 0.61, 0.97], "draws": [0.9, 0.5, 0.1]})
	_case("village_no_draws", GlyphLanguage.compose_chatter(["🔥", "👥", "⚙"], [0.82, 0.61, 0.97], vscope, []))
	_case("village_tied", GlyphLanguage.compose_chatter(["🔥", "👥", "⚙"], [0.82, 0.61, 0.97], vscope, [], [true, false]))
	_case("partly_dark", GlyphLanguage.compose_chatter(["☀", "🌾", "🍄"], [0.9], "spacewheat/BioticFlux@0000", [0.0, 0.0, 0.0]))
	_case("no_scope", GlyphLanguage.compose_chatter(["🌾", "👥"], [], "", []))
	_case("selector", GlyphLanguage.compose_chatter(["⚙️", "🔧"], [1.0, 0.25], "spacewheat/StellarForges@0000", [0.5, 0.5]))
	_case("empty", GlyphLanguage.compose_chatter([], [], vscope, []))
	_case("faction", GlyphLanguage.compose(
		GlyphLanguage.faction_scope("Swift Herd", [["🐇", "🦌"], ["🌿", "🌾"], ["🦌", "🌿"]]),
		[{"glyph": "🦌", "p": 0.71}, {"glyph": "🌿", "p": 0.88, "tie": true}], ["🐇🦌"], ["🦌"]))
	_case("faction_all_dark", GlyphLanguage.compose(
		GlyphLanguage.faction_scope("The Demos", [["👥", "🌾"]]), [], ["👥🌾"], []))
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
	var icon_registry = get_root().get_node_or_null("/root/IconRegistry")
	_check(icon_registry != null, "IconRegistry autoload resolves")
	if icon_registry != null:
		_run_voices(icon_registry)
		_run_bell_pair(icon_registry)
		_run_lifts(icon_registry)
	_finish("Glyph language smoke")
	return false


func _standing(channels: Dictionary):
	var s = FactionStandingCls.new()
	for k in channels:
		s.set(k, channels[k])
	return s


## Real icon pairs, so the market's connection rule admits real factions:
## Celestial Archons hold Solar ☀/🌙 and Elemental 🔥/💧 (and Geostorm ⛰/🌬,
## which no mock biome has → dark). Solar lives in both biomes, far apart.
func _world() -> Dictionary:
	return {
		"BioticFlux": make_biome([["☀", "🌙", 0.9], ["🔥", "💧", 0.6]]),
		"StarterForest": make_biome([["☀", "🌙", 0.1]]),
	}


func _run_voices(icon_registry) -> void:
	seed(7)
	var biomes := _world()
	var voices := FactionChatter.new()
	var standings := {"Celestial Archons": _standing({"trust": 1.0})}
	var archon_lines: Array = []
	var between: Array = []
	var story_lines := 0
	var silent_ticks := 0
	for t in range(200):
		# ☀ in BioticFlux swings; ticks 100–120 a "strike" pins it near the south pole.
		var p := 0.9 - 0.3 * absf(sin(float(t) * 0.2))
		if t >= 100 and t < 120:
			p = 0.03
		biomes["BioticFlux"].viz_cache.snaps[0] = {"p0": p, "p1": 1.0 - p}
		set_basis(biomes["BioticFlux"], [["☀", "🌙", p], ["🔥", "💧", 0.6]])
		var evs: Array = voices.tick(biomes, icon_registry, null, standings)
		if evs.is_empty():
			silent_ticks += 1
		for ev in evs:
			print("GLYPH_VOICE " + JSON.stringify(ev))
			if ev.get("kind", "") == "between":
				between.append(ev)
			elif str(ev.get("faction", "")) == "Celestial Archons":
				archon_lines.append(ev)
			if bool(ev.get("story", false)):
				story_lines += 1
	_check(not archon_lines.is_empty(), "Celestial Archons speak (connected by Solar/Elemental)")
	_check(silent_ticks > 0, "no news, no line: some ticks are silent")
	var saw_dark := false
	var lengths := {}
	for ev in archon_lines:
		var g: Dictionary = ev.get("glyph", {})
		_check(str(g.get("scope", "")).begins_with("faction/Celestial Archons@"), "archon line is in the faction's scope")
		for d in ev.get("darks", []):
			saw_dark = saw_dark or d == "⛰🌬"
		lengths[ev.get("emojis", []).size()] = true
	_check(saw_dark, "Geostorm ⛰🌬 is written dark: an icon you hold nowhere")
	_check(lengths.size() >= 2, "line length varies with the news")
	_check(not between.is_empty(), "Solar read in two biomes yields a between line")
	for ev in between:
		_check(str(ev.get("scope", "")).contains("⊗"), "between line is in a product scope")
	_check(story_lines > 0, "the Story room hears a faction you stand well with")
	var orphan := false
	for ev in voices.recent(96):
		orphan = orphan or str(ev.get("faction", "")) == "orphaned_icons"
	_check(not orphan, "the orphaned_icons bucket never speaks")


## Q2: a Bell pair. Solar and Elemental in one biome, perfectly correlated
## (☀ with 🔥, 🌙 with 💧: 1 bit of mutual information between the poles).
## Every Archon line that brings up one brings up both, tied, and the poles agree.
## (The snapshot marginals wobble only to make news; ties and draws read the
## basis distribution.)
func _run_bell_pair(icon_registry) -> void:
	seed(11)
	var regs := [["☀", "🌙", 0.5], ["🔥", "💧", 0.5]]
	var biomes := {"BioticFlux": make_biome(regs, {"☀🔥": 0.5, "🌙💧": 0.5})}
	var voices := FactionChatter.new()
	var lines := 0
	var tied := 0
	var agree := 0
	for t in range(120):
		# Wobble the marginals so there is news; the joint stays a Bell pair.
		var p := 0.5 + 0.3 * sin(float(t) * 0.3)
		biomes["BioticFlux"].viz_cache.snaps = [{"p0": p, "p1": 1.0 - p}, {"p0": p, "p1": 1.0 - p}]
		# The basis distribution stays a 50/50 Bell pair: MI = 1 bit of the poles.
		for ev in voices.tick(biomes, icon_registry, null, {}):
			print("GLYPH_VOICE " + JSON.stringify(ev))
			if ev.get("kind", "") != "faction_line" or str(ev.get("faction", "")) != "Celestial Archons":
				continue
			lines += 1
			var e: Array = ev.get("emojis", [])
			if e.size() == 2:
				if str(ev["glyph"]["ket"]).contains("⌢"):
					tied += 1
				if (e[0] == "☀" and e[1] == "🔥") or (e[0] == "🌙" and e[1] == "💧"):
					agree += 1
	_check(lines > 0, "Bell pair: the Archons speak")
	_check(tied == lines, "Bell pair: 1 bit of MI pulls the partner in and ties it, every line (%d/%d)" % [tied, lines])
	_check(agree == lines, "Bell pair: joint draws keep the poles correlated (%d/%d)" % [agree, lines])


## Q3: relationship lifts. The same world, the same seed, two standings.
func _run_lifts(icon_registry) -> void:
	var counts := {}
	for label in ["plain", "open"]:
		seed(23)
		var biomes := _world()
		var voices := FactionChatter.new()
		var channels := {"trust": 0.0} if label == "plain" else {"trust": 0.0, "attention": 3.0, "access": 3.0}
		var standings := {"Celestial Archons": _standing(channels)}
		var asks := 0
		var darks := 0
		var lit := 0
		for t in range(200):
			var p := 0.6 + 0.3 * sin(float(t) * 0.25)
			biomes["BioticFlux"].viz_cache.snaps[0] = {"p0": p, "p1": 1.0 - p}
			set_basis(biomes["BioticFlux"], [["☀", "🌙", p], ["🔥", "💧", 0.6]])
			for ev in voices.tick(biomes, icon_registry, null, standings):
				if ev.get("kind", "") != "faction_line" or str(ev.get("faction", "")) != "Celestial Archons":
					continue
				lit += ev.get("emojis", []).size()
				asks += ev["glyph"].get("asks", []).size()
				darks += ev.get("darks", []).size()
		counts[label] = {"asks": float(asks) / maxf(1.0, float(lit)), "darks": darks, "lit": lit}
		print("GLYPH_LIFT " + JSON.stringify({"label": label, "counts": counts[label]}))
	_check(counts["open"]["asks"] > counts["plain"]["asks"], "🧿 attention: a faction watching you asks more")
	_check(counts["open"]["darks"] > counts["plain"]["darks"], "🗝 access: a faction that lets you in reveals more of what you lack")
