extends RefCounted

## FactionChatter — factions speak from their own scope (docs/GLYPH_LANGUAGE.md §8).
##
## A faction's scope is its signature: the icons it deals in, wherever in the
## world those registers live. Each line is one faction reading some of its
## registers off the live biomes:
##
##   faction/Pack Lords@3fce  |🐺⌢🦅⟩  [.84]🐺 [.83]🦅  🌾🐑?  ⟨🦅|
##
## Three of Shannon's quantities drive the grammar, one each, with no tuned
## thresholds:
##
##   relative entropy → what comes up. A register comes up with probability
##       1 − e^(−D), D = the relative entropy (nats) of the reading now from what
##       this faction last said of it. A faction speaks when something comes up:
##       cadence and length both follow the news. Never spoken of: D = ∞.
##   entropy          → what is asked. Each register in the line gets a ⟨bra|
##       with probability h(p): settled registers are stated, undecided ones asked.
##   mutual info      → what is tied. Registers of one biome come along with a
##       register that came up, and are written tied ⌢ to their neighbour, with
##       probability MI (bits, of their pole outcomes; 1 for a Bell pair).
##       Different biomes are separate states: never tied.
##
## Poles are drawn jointly per biome from the biome's basis distribution, so
## correlated registers come out correlated.
##
## Your relationship with a faction lifts four of those chances,
## q → q^(1/(1+c)), one channel each (FactionStanding):
##   🤝 trust        → mentions: a trusted faction tells you more
##   🧿 attention    → asks: a faction watching you asks more (⟨| is attend)
##   🗝 access       → darks: hidden information, the icons you hold nowhere
##   🕸 entanglement → ties: shared secrets, what is bound to what
## Debt and legitimacy act through scalar(): who talks to you in the Story room.
##
## Dark registers (icons the player holds nowhere) are written as their pole
## pair, `🐇🦌?`, and come up in proportion to how much of its lit vocabulary
## the faction brought up. Between lines compare one register read in two biomes
## (⚠ the readings lean to different poles, 🟰 the same), when that gap is news.
##
## State: what each faction last said of each register, and a ring of lines.
## Random draws use the global RNG (seed() it in tests).

const GlyphLanguage := preload("res://Core/Story/GlyphLanguage.gd")
const BiomeMeasurementSampler := preload("res://Core/Story/BiomeMeasurementSampler.gd")

const NEWS_CAP := 20.0           # nats; weighs "never spoken of" (∞) against finite news
const PLAYER_FACTION := "The Demos"
const PLAYER_STORY_WEIGHT := 0.25  # your own people talk to you without standing
const RING_SIZE := 96
# Registry buckets that own icons but are not voices.
const NOT_SPEAKERS := ["orphaned_icons"]

var _heard: Dictionary = {}     # faction → {entry key → p_north last said; "between:…" → [pa, pb]}
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
	var story_weights: Dictionary = {}
	for fname in standings:
		var s = standings[fname]
		var v: float = float(s.scalar()) if s != null and s.has_method("scalar") else 0.0
		if v > 0.0 and not NOT_SPEAKERS.has(str(fname)):
			story_weights[str(fname)] = v
	if not story_weights.has(PLAYER_FACTION):
		story_weights[PLAYER_FACTION] = PLAYER_STORY_WEIGHT

	# Each candidate's news this tick: which of its registers came up.
	var plans: Dictionary = {}
	for fname in connected + story_weights.keys():
		if not plans.has(fname):
			plans[fname] = _plan(str(fname), world, icon_registry, _channels(str(fname), standings))

	# The room: one voice per tick from whoever has something to say, weighted by news.
	var general: Dictionary = {}
	for fname in connected:
		if not plans[fname]["fired"].is_empty():
			general[fname] = minf(float(plans[fname]["news"]), NEWS_CAP)
	var speaker := _pick(general)
	# The Story room's own draw: weighted by standing, among those with news.
	var teller := ""
	var total := 0.0
	for k in story_weights:
		total += float(story_weights[k])
	if randf() < minf(1.0, total):
		var story: Dictionary = {}
		for fname in story_weights:
			if not plans[fname]["fired"].is_empty():
				story[fname] = float(story_weights[fname]) * maxf(minf(float(plans[fname]["news"]), NEWS_CAP), 1e-6)
		teller = _pick(story)

	# Every line from a faction you stand well with (or your own people) belongs
	# to the Story room; the standing draw above gives those factions extra air.
	if speaker != "":
		events.append_array(_speak(speaker, plans[speaker], world, faction_registry, story_weights.has(speaker), connected))
	if teller != "" and teller != speaker:
		events.append_array(_speak(teller, plans[teller], world, faction_registry, true, connected))
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

## {pair key "n|s" → [{biome, q, north, south, p_north, key}]}, plus "_pairs"
## (each biome's ordered pole pairs, for scope tags) and "_biomes" (name → biome).
static func index_world(biomes: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	var pairs_by_biome: Dictionary = {}
	var by_name: Dictionary = {}
	for bname in biomes:
		var biome = biomes[bname]
		if biome == null or not ("quantum_computer" in biome) or biome.quantum_computer == null:
			continue
		var qc = biome.quantum_computer
		var rm = qc.register_map
		if rm == null:
			continue
		by_name[str(bname)] = biome
		var pairs: Array = []
		for q in range(int(rm.num_qubits)):
			var axis: Dictionary = rm.axes.get(q, {})
			var north := GlyphLanguage.canonical(str(axis.get("north", "")))
			var south := GlyphLanguage.canonical(str(axis.get("south", "")))
			if north == "" or south == "":
				continue
			pairs.append([north, south])
			var entry := {"biome": str(bname), "q": q, "north": north, "south": south,
				"p_north": _p_north(biome, qc, q), "key": "%s:%d" % [bname, q]}
			var k := "%s|%s" % [north, south]
			if not index.has(k):
				index[k] = []
			index[k].append(entry)
		pairs_by_biome[str(bname)] = pairs
	index["_pairs"] = pairs_by_biome
	index["_biomes"] = by_name
	index["_states"] = {}
	return index


static func _p_north(biome, qc, q: int) -> float:
	if "viz_cache" in biome and biome.viz_cache != null and biome.viz_cache.has_method("get_snapshot"):
		var snap: Dictionary = biome.viz_cache.get_snapshot(q)
		if snap.has("p0"):
			return clampf(float(snap.get("p0")), 0.0, 1.0)
	if qc.has_method("get_marginal"):
		return clampf(float(qc.get_marginal(q, 0)), 0.0, 1.0)
	return 0.5


## Mutual information (bits) of two registers' pole outcomes in one biome, from
## the tick's pole-state distribution (cached in world["_states"]).
static func _mutual_information(world: Dictionary, biome_name: String, a: int, b: int) -> float:
	return BiomeMeasurementSampler.pair_mutual_information(_states(world, biome_name), a, b)


static func _states(world: Dictionary, biome_name: String) -> Array:
	var cache: Dictionary = world.get("_states", {})
	if not cache.has(biome_name):
		cache[biome_name] = BiomeMeasurementSampler.pole_states(world.get("_biomes", {}).get(biome_name, null))
		world["_states"] = cache
	return cache[biome_name]


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


func _news(faction_name: String, entry: Dictionary) -> float:
	var heard: Dictionary = _heard.get(faction_name, {})
	var key := str(entry.get("key", ""))
	if not heard.has(key):
		return INF  # never spoken of: all news
	return GlyphLanguage.relative_entropy(float(entry.get("p_north", 0.5)), float(heard[key]))


static func _channels(faction_name: String, standings: Dictionary) -> Dictionary:
	var s = standings.get(faction_name, null)
	var out := {"trust": 0.0, "attention": 0.0, "access": 0.0, "entanglement": 0.0}
	if s == null:
		return out
	for k in out.keys():
		if k in s:
			out[k] = float(s.get(k))
	return out


func _connected_factions(biomes: Dictionary) -> Array:
	var seen: Dictionary = {}
	for bname in biomes:
		for f in FactionBiomeMap.factions_for_biome_by_signature(biomes[bname]):
			if not NOT_SPEAKERS.has(str(f)):
				seen[str(f)] = true
	return seen.keys()


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


# --- what a faction would say --------------------------------------------------

## Which registers come up this tick. Returns {regs, fired: [reg index], news,
## channels}. Each lit register is read in the biome where it is most news.
func _plan(faction_name: String, world: Dictionary, icon_registry, ch: Dictionary) -> Dictionary:
	var regs := faction_registers(faction_name, world, icon_registry)
	var fired: Array = []
	var news_total := 0.0
	for i in range(regs.size()):
		var reg: Dictionary = regs[i]
		var entries: Array = reg["entries"]
		if entries.is_empty():
			continue
		var best: Dictionary = entries[0]
		var best_d := _news(faction_name, best)
		for e in entries:
			var d := _news(faction_name, e)
			if d > best_d:
				best = e
				best_d = d
		reg["entry"] = best
		reg["news"] = best_d
		news_total += minf(best_d, NEWS_CAP)
		var p := GlyphLanguage.lift(GlyphLanguage.mention_probability(best_d), float(ch["trust"]))
		if randf() < p:
			fired.append(i)
	return {"regs": regs, "fired": fired, "news": news_total, "channels": ch}


# --- one line ------------------------------------------------------------------

func _speak(faction_name: String, plan: Dictionary, world: Dictionary, faction_registry, story: bool, connected: Array) -> Array:
	var regs: Array = plan["regs"]
	var ch: Dictionary = plan["channels"]
	var chosen: Dictionary = {}   # reg index → entry
	for i in plan["fired"]:
		chosen[i] = regs[i]["entry"]
	# Mutual information pulls partners along: a register of the same biome joins
	# one that came up with probability MI (lifted by 🕸).
	var fired_now: Array = chosen.keys()
	for i in fired_now:
		var e: Dictionary = chosen[i]
		for j in range(regs.size()):
			if chosen.has(j):
				continue
			for f in regs[j]["entries"]:
				if f["biome"] != e["biome"]:
					continue
				var mi := _mutual_information(world, str(e["biome"]), int(e["q"]), int(f["q"]))
				if randf() < GlyphLanguage.lift(GlyphLanguage.tie_probability(mi), float(ch["entanglement"])):
					chosen[j] = f
				break

	var lit_total := 0
	var darks_all: Array = []
	var scope_pairs: Array = []
	for reg in regs:
		scope_pairs.append(reg["pair"])
		if reg["entries"].is_empty():
			var dark_pair: String = str(reg["pair"][0]) + str(reg["pair"][1])
			if not darks_all.has(dark_pair):
				darks_all.append(dark_pair)
		else:
			lit_total += 1
	var fill := 1.0 if lit_total == 0 else float(plan["fired"].size()) / float(lit_total)
	var darks: Array = []
	for d in darks_all:
		if randf() < GlyphLanguage.lift(fill, float(ch["access"])):
			darks.append(d)

	# Group by biome (in order of first appearance), qubit order within; draw
	# each group's poles jointly from that biome's basis distribution.
	var order: Array = chosen.keys()
	order.sort()
	var groups: Dictionary = {}
	var group_order: Array = []
	for i in order:
		var b: String = chosen[i]["biome"]
		if not groups.has(b):
			groups[b] = []
			group_order.append(b)
		groups[b].append(chosen[i])
	var lit: Array = []
	var emojis: Array = []
	var marginals: Array = []
	var asks: Array = []
	var heard: Dictionary = _heard.get(faction_name, {})
	for b in group_order:
		var group: Array = groups[b]
		group.sort_custom(func(x, y): return int(x["q"]) < int(y["q"]))
		var draws := joint_draw(_states(world, b), group)
		for k in range(group.size()):
			var e: Dictionary = group[k]
			var north: bool = draws[k]
			var pn := float(e["p_north"])
			var g: String = e["north"] if north else e["south"]
			var p := pn if north else 1.0 - pn
			var tie := false
			if k > 0:
				var mi := _mutual_information(world, b, int(group[k - 1]["q"]), int(e["q"]))
				tie = randf() < GlyphLanguage.lift(GlyphLanguage.tie_probability(mi), float(ch["entanglement"]))
			lit.append({"glyph": g, "p": p, "tie": tie})
			emojis.append(g)
			marginals.append(p)
			if randf() < GlyphLanguage.lift(GlyphLanguage.ask_probability(p), float(ch["attention"])):
				asks.append(g)
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
		"biome": group_order[0] if not group_order.is_empty() else "",
		"connections": group_order.slice(1),
		"biomes": group_order,
		"story": story,
		"connected": connected.has(faction_name),
		"topic_node": "",
		"line": " ".join(PackedStringArray(emojis)),
		"glyph": glyph,
	}
	var out: Array = [ev]
	var between := _between(faction_name, chosen, regs, world)
	if not between.is_empty():
		out.append(between)
	return out


## Draw the poles of one biome's registers jointly: marginalise the biome's
## pole-state distribution onto them and sample once. Returns [bool north, …]
## in the group's order. Independent draws if the distribution is unavailable.
static func joint_draw(states: Array, group: Array) -> Array:
	var out: Array = []
	var dist: Dictionary = {}
	var total := 0.0
	for s in states:
		var key := ""
		for e in group:
			key += "1" if int(s["bits"][int(e["q"])]) == 1 else "0"
		dist[key] = float(dist.get(key, 0.0)) + float(s["p"])
		total += float(s["p"])
	if dist.is_empty() or total <= 0.0:
		for e in group:
			out.append(randf() < float(e["p_north"]))
		return out
	var r := randf() * total
	var acc := 0.0
	var picked := ""
	for key in dist:
		acc += float(dist[key])
		picked = key
		if r <= acc:
			break
	for c in picked:
		out.append(c == "1")
	return out


## Compare one mentioned register across two biomes in their product scope,
## when the readings moved since this faction last compared them (the same
## 1 − e^(−D) rule, D summed over both sides).
func _between(faction_name: String, chosen: Dictionary, regs: Array, world: Dictionary) -> Dictionary:
	var heard: Dictionary = _heard.get(faction_name, {})
	for i in chosen:
		var entries: Array = regs[i]["entries"]
		if entries.size() < 2:
			continue
		var a: Dictionary = entries[0]
		var b: Dictionary = entries[1]
		var spread := -1.0
		for x in range(entries.size()):
			for y in range(x + 1, entries.size()):
				var d := absf(float(entries[x]["p_north"]) - float(entries[y]["p_north"]))
				if d > spread:
					spread = d
					a = entries[x]
					b = entries[y]
		var pa := float(a["p_north"])
		var pb := float(b["p_north"])
		var gap_key := "between:%s|%s" % [str(a["key"]), str(b["key"])]
		var news := INF
		if heard.has(gap_key):
			news = GlyphLanguage.relative_entropy(pa, float(heard[gap_key][0])) \
				+ GlyphLanguage.relative_entropy(pb, float(heard[gap_key][1]))
		if randf() >= GlyphLanguage.mention_probability(news):
			continue
		heard[gap_key] = [pa, pb]
		_heard[faction_name] = heard
		var pairs_by_biome: Dictionary = world.get("_pairs", {})
		var names := [str(a["biome"]), str(b["biome"])]
		var scope := GlyphLanguage.product_scope(names,
			[pairs_by_biome.get(names[0], []), pairs_by_biome.get(names[1], [])])
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
