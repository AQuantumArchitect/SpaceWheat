extends RefCounted

## FactionChatter — factions speak from their own scope (docs/GLYPH_LANGUAGE.md §8).
##
## A faction's scope is its signature: the icons it deals in, wherever in the
## world those registers live. Each line is one faction reading some of its
## registers off the live biomes:
##
##   faction/Swift Herd@9c1e  |🦌🌿⟩  [.71]🦌 [.88]🌿  🐇🦌?  ⟨🦌|
##
## Everything a line contains is driven by the physics, with no thresholds:
##   * who speaks      factions connected to the player's biomes, weighted by how
##                     much their registers moved (they talk about what changes);
##                     the Story room draws separately, weighted by standing
##   * line length     each register comes up with mention_probability(motion):
##                     a quiet world mutters one glyph, a churned one runs on
##   * questions       each register is asked about with ask_probability(p):
##                     settled registers are stated, undecided ones asked
##   * dark registers  icons the player holds nowhere are written as their
##                     pole pair, `🐇🦌?`; they come up as often as the speaker
##                     is talkative. A faction that keeps saying `🐇🦌?` deals
##                     in something you lack.
##   * between lines   when a register a faction mentions lives in two biomes,
##                     it compares them in their product scope: ⚠ when the two
##                     lean to different poles, 🟰 when the same — again only
##                     when the gap between them has moved since last time.
##   * cadence         whether anyone speaks this tick follows the same motion:
##                     a still world speaks about once in 1/SPEAK_FLOOR ticks.
##
## State: the marginals each faction last spoke of (for motion) and a ring of
## recent lines. Random draws use the global RNG (seed() it in tests).

const GlyphLanguage := preload("res://Core/Story/GlyphLanguage.gd")

const MOTION_TAU := 0.05        # marginal motion that makes a mention ~63% likely
const SPEAK_FLOOR := 0.05       # a still faction can still speak, rarely
const PLAYER_FACTION := "The Demos"
const PLAYER_STORY_WEIGHT := 0.25  # your own people talk to you without standing
const RING_SIZE := 96
# Registry buckets that own icons but are not voices.
const NOT_SPEAKERS := ["orphaned_icons"]

var _heard: Dictionary = {}     # faction → {entry_key → p_north last spoken of}
var _lines: Array = []


func reset() -> void:
	_heard.clear()
	_lines.clear()


## One substrate tick. Returns the events emitted (also kept in the ring).
##   biomes        {name → biome} (farm.grid.get_all_biomes())
##   icon_registry IconRegistry (get_icons_for_faction)
##   standings     {faction name → FactionStanding} (farm.faction_standings)
func tick(biomes: Dictionary, icon_registry, faction_registry, standings: Dictionary) -> Array:
	var events: Array = []
	if biomes.is_empty() or icon_registry == null:
		return events
	var world := index_world(biomes)
	var connected: Array = _connected_factions(biomes)
	# General draw: anyone connected to the player's biomes (B and N read these).
	var general := _weigh(connected, world, icon_registry, {}, false)
	# Cadence follows motion too: a still world speaks rarely, a churned one
	# every tick. Weights are SPEAK_FLOOR + motion, so the top weight is the news.
	if randf() < maxf(SPEAK_FLOOR, GlyphLanguage.mention_probability(_top(general) - SPEAK_FLOOR, MOTION_TAU)):
		var speaker := _pick(general)
		if speaker != "":
			events.append_array(_speak(speaker, world, icon_registry, faction_registry, false, connected))
	# Story draw: weighted by standing; fires with probability min(1, Σ standing).
	var story_weights: Dictionary = {}
	for fname in standings:
		var s = standings[fname]
		var v: float = float(s.scalar()) if s != null and s.has_method("scalar") else 0.0
		if v > 0.0:
			story_weights[str(fname)] = v
	if not story_weights.has(PLAYER_FACTION):
		story_weights[PLAYER_FACTION] = PLAYER_STORY_WEIGHT
	var total := 0.0
	for k in story_weights:
		total += float(story_weights[k])
	var story := _weigh(story_weights.keys(), world, icon_registry, {}, false)
	var story_news := GlyphLanguage.mention_probability(_top(story) - SPEAK_FLOOR, MOTION_TAU)
	if randf() < minf(1.0, total) * maxf(SPEAK_FLOOR, story_news):
		story = _weigh(story_weights.keys(), world, icon_registry, story_weights, true)
		var teller := _pick(story)
		if teller != "":
			events.append_array(_speak(teller, world, icon_registry, faction_registry, true, connected))
	for ev in events:
		_lines.append(ev)
	while _lines.size() > RING_SIZE:
		_lines.pop_front()
	return events


## Recent lines matching `filter` (Callable(ev) -> bool), newest last.
func recent(n: int, filter: Callable = Callable()) -> Array:
	var out: Array = []
	for i in range(_lines.size() - 1, -1, -1):
		var ev: Dictionary = _lines[i]
		if filter.is_valid() and not filter.call(ev):
			continue
		out.push_front(ev)
		if out.size() >= n:
			break
	return out


# --- the world as registers ----------------------------------------------------

## {pair key "n|s" → [{biome, q, north, south, p_north, key}]} plus each biome's
## ordered pairs (for scope tags) under "_pairs".
static func index_world(biomes: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	var pairs_by_biome: Dictionary = {}
	for bname in biomes:
		var biome = biomes[bname]
		if biome == null or not ("quantum_computer" in biome) or biome.quantum_computer == null:
			continue
		var qc = biome.quantum_computer
		var rm = qc.register_map
		if rm == null:
			continue
		var pairs: Array = []
		for q in range(int(rm.num_qubits)):
			var axis: Dictionary = rm.axes.get(q, {})
			var north := GlyphLanguage.canonical(str(axis.get("north", "")))
			var south := GlyphLanguage.canonical(str(axis.get("south", "")))
			if north == "" or south == "":
				continue
			pairs.append([north, south])
			var p_north := _p_north(biome, qc, q)
			var entry := {"biome": str(bname), "q": q, "north": north, "south": south,
				"p_north": p_north, "key": "%s:%d" % [bname, q]}
			var k := "%s|%s" % [north, south]
			if not index.has(k):
				index[k] = []
			index[k].append(entry)
		pairs_by_biome[str(bname)] = pairs
	index["_pairs"] = pairs_by_biome
	return index


static func _p_north(biome, qc, q: int) -> float:
	if "viz_cache" in biome and biome.viz_cache != null and biome.viz_cache.has_method("get_snapshot"):
		var snap: Dictionary = biome.viz_cache.get_snapshot(q)
		if snap.has("p0"):
			return clampf(float(snap.get("p0")), 0.0, 1.0)
	if qc.has_method("get_marginal"):
		return clampf(float(qc.get_marginal(q, 0)), 0.0, 1.0)
	return 0.5


## A faction's registers: [{pair:[n,s], entries:[…]}] in signature order.
static func faction_registers(faction_name: String, world: Dictionary, icon_registry) -> Array:
	var out: Array = []
	for icon in icon_registry.get_icons_for_faction(faction_name):
		if not (icon is Dictionary):
			continue
		var p0 := GlyphLanguage.canonical(str(icon.get("pole_0", "")))
		var p1 := GlyphLanguage.canonical(str(icon.get("pole_1", "")))
		if p0 == "" or p1 == "":
			continue
		var entries: Array = world.get("%s|%s" % [p0, p1], [])
		if entries.is_empty():
			entries = world.get("%s|%s" % [p1, p0], [])
		out.append({"pair": [p0, p1], "entries": entries})
	return out


func _motion(faction_name: String, entry: Dictionary) -> float:
	var heard: Dictionary = _heard.get(faction_name, {})
	var key := str(entry.get("key", ""))
	if not heard.has(key):
		return 1.0  # never spoken of: all news
	return absf(float(entry.get("p_north", 0.5)) - float(heard[key]))


func _connected_factions(biomes: Dictionary) -> Array:
	var seen: Dictionary = {}
	for bname in biomes:
		for f in FactionBiomeMap.factions_for_biome_by_signature(biomes[bname]):
			if not NOT_SPEAKERS.has(str(f)):
				seen[str(f)] = true
	return seen.keys()


## {faction → weight}: (floor + total motion), times standing for the Story draw.
func _weigh(names: Array, world: Dictionary, icon_registry, standing_weights: Dictionary, story: bool) -> Dictionary:
	var out: Dictionary = {}
	for fname in names:
		var motion := 0.0
		for reg in faction_registers(str(fname), world, icon_registry):
			for e in reg["entries"]:
				motion += _motion(str(fname), e)
		var w := SPEAK_FLOOR + motion
		if story:
			w *= float(standing_weights.get(fname, 0.0))
		if w > 0.0:
			out[str(fname)] = w
	return out


static func _top(weights: Dictionary) -> float:
	var top := 0.0
	for k in weights:
		top = maxf(top, float(weights[k]))
	return top


static func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	if total <= 0.0:
		return ""
	var r := randf() * total
	var acc := 0.0
	var last := ""
	for k in weights:
		acc += float(weights[k])
		last = str(k)
		if r <= acc:
			return last
	return last


# --- one line ------------------------------------------------------------------

func _speak(faction_name: String, world: Dictionary, icon_registry, faction_registry, story: bool, connected: Array) -> Array:
	var regs := faction_registers(faction_name, world, icon_registry)
	if regs.is_empty():
		return []
	var scope_pairs: Array = []
	var candidates: Array = []   # {reg_index, entry, motion}
	var darks_all: Array = []
	for i in range(regs.size()):
		var reg: Dictionary = regs[i]
		scope_pairs.append(reg["pair"])
		var entries: Array = reg["entries"]
		if entries.is_empty():
			# Dark: the whole register, written as its pole pair (the sphere, not a
			# direction) — an icon this faction deals in that the player holds nowhere.
			var dark_pair: String = str(reg["pair"][0]) + str(reg["pair"][1])
			if not darks_all.has(dark_pair):
				darks_all.append(dark_pair)
			continue
		# The biome this register is read in: the one that moved most for this speaker.
		var best: Dictionary = entries[0]
		var best_m := _motion(faction_name, best)
		for e in entries:
			var m := _motion(faction_name, e)
			if m > best_m:
				best = e
				best_m = m
		candidates.append({"i": i, "entry": best, "motion": best_m, "entries": entries})

	var chosen: Array = []
	for c in candidates:
		if randf() < GlyphLanguage.mention_probability(float(c["motion"]), MOTION_TAU):
			chosen.append(c)
	if chosen.is_empty() and not candidates.is_empty():
		var top: Dictionary = candidates[0]
		for c in candidates:
			if float(c["motion"]) > float(top["motion"]):
				top = c
		chosen.append(top)

	var fill := 1.0 if candidates.is_empty() else float(chosen.size()) / float(candidates.size())
	var darks: Array = []
	for d in darks_all:
		if randf() < fill:
			darks.append(d)

	var lit: Array = []
	var emojis: Array = []
	var marginals: Array = []
	var asks: Array = []
	var biomes_spoken: Array = []
	var heard: Dictionary = _heard.get(faction_name, {})
	for c in chosen:
		var e: Dictionary = c["entry"]
		var pn := float(e["p_north"])
		var north_drawn := randf() < pn
		var g: String = e["north"] if north_drawn else e["south"]
		var p := pn if north_drawn else 1.0 - pn
		lit.append({"glyph": g, "p": p})
		emojis.append(g)
		marginals.append(p)
		if randf() < GlyphLanguage.ask_probability(p):
			asks.append(g)
		if not biomes_spoken.has(e["biome"]):
			biomes_spoken.append(e["biome"])
		heard[str(e["key"])] = pn
	_heard[faction_name] = heard

	var scope := GlyphLanguage.faction_scope(faction_name, scope_pairs)
	var glyph := GlyphLanguage.compose(scope, lit, darks, asks)
	if str(glyph.get("sentence", "")) == "":
		return []
	var ev := {
		"kind": "faction_line",
		"faction": faction_name,
		"speaker": _speaker_glyph(faction_name, faction_registry, regs),
		"scope": scope,
		"emojis": emojis,
		"marginals": marginals,
		"darks": darks,
		"biome": biomes_spoken[0] if not biomes_spoken.is_empty() else "",
		"connections": biomes_spoken.slice(1),
		"biomes": biomes_spoken,
		"story": story,
		"connected": connected.has(faction_name),
		"topic_node": "",
		"line": " ".join(PackedStringArray(emojis)),
		"glyph": glyph,
	}
	var out: Array = [ev]
	var between := _between(faction_name, chosen, world)
	if not between.is_empty():
		out.append(between)
	return out


## Compare one mentioned register across two biomes in their product scope.
func _between(faction_name: String, chosen: Array, world: Dictionary) -> Dictionary:
	for c in chosen:
		var entries: Array = c["entries"]
		if entries.size() < 2:
			continue
		# The two readings furthest apart.
		var a: Dictionary = entries[0]
		var b: Dictionary = entries[1]
		var spread := -1.0
		for i in range(entries.size()):
			for j in range(i + 1, entries.size()):
				var d := absf(float(entries[i]["p_north"]) - float(entries[j]["p_north"]))
				if d > spread:
					spread = d
					a = entries[i]
					b = entries[j]
		var pairs_by_biome: Dictionary = world.get("_pairs", {})
		var names := [str(a["biome"]), str(b["biome"])]
		var scope := GlyphLanguage.product_scope(names,
			[pairs_by_biome.get(names[0], []), pairs_by_biome.get(names[1], [])])
		var pa := float(a["p_north"])
		var pb := float(b["p_north"])
		# Compared again only when the gap between the two biomes has moved since
		# this faction last compared them.
		var heard: Dictionary = _heard.get(faction_name, {})
		var gap_key := "between:%s|%s" % [str(a["key"]), str(b["key"])]
		var gap := pa - pb
		var gap_motion := absf(gap - float(heard[gap_key])) if heard.has(gap_key) else 1.0
		if randf() >= GlyphLanguage.mention_probability(gap_motion, MOTION_TAU):
			continue
		heard[gap_key] = gap
		_heard[faction_name] = heard
		var verb := GlyphLanguage.between_verb(pa, pb)
		var glyph := GlyphLanguage.compose_between(scope, verb,
			[{"glyph": a["north"], "p": pa}, {"glyph": b["north"], "p": pb}])
		return {"kind": "between", "faction": faction_name, "scope": scope,
			"biomes": names, "verb": verb, "glyph": glyph}
	return {}


static func _speaker_glyph(faction_name: String, faction_registry, regs: Array) -> String:
	if faction_registry != null and faction_registry.has_method("get_by_name"):
		var f = faction_registry.get_by_name(faction_name)
		if f != null and "cloud" in f and f.cloud is Array and not f.cloud.is_empty():
			return GlyphLanguage.canonical(str(f.cloud[0]))
	if not regs.is_empty():
		return str(regs[0]["pair"][0])
	return "·"
