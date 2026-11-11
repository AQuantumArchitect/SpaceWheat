extends RefCounted

## GlyphLanguage — SpaceWheat's glyph language (docs/GLYPH_LANGUAGE.md).
##
## Pure and static: no scene tree, no autoloads, no state, no RNG. Every random
## choice (which register enters a line, whether a register is asked about) is
## drawn by the caller and handed in, so the same inputs always compose the same
## sentence. Rendering a sentence never measures or changes a state.
##
## The one-line version: an emoji is a pole of a qubit; a ket is a statement; a
## bra is a question; and nothing means anything until a scope has declared the
## space. Three kinds of scope speak in SpaceWheat:
##
##   spacewheat/Village@3f9a           a biome: its registers, in qubit order
##   faction/Swift Herd@9c1e           a faction: its signature's registers,
##                                     wherever in the world they live
##   spacewheat/A⊗B@77d0               a product scope: two biomes read together
##
## The @tag is the first four hex digits of sha256 over the scope's ordered pole
## pairs ("north/south,north/south"), so it changes when the vocabulary changes.
##
## A line:
##
##   faction/Swift Herd@9c1e  |🦌🌿⟩  [.71]🦌 [.88]🌿  🐇🦌?  ⟨🦌|
##   └─ scope ─────────────┘ └ ket ┘ └ populations ┘ └ dark┘ └asks┘
##
##   ket          the drawn pole of each register the speaker brought up
##   populations  ρ's marginal at each drawn pole: measured, written straight
##   dark         registers in the scope that no measurement reaches, written
##                as a pole (`🐇?`) or, for a whole register, its pole pair
##                (`🐇🦌?`): for a faction, an icon the player holds nowhere
##   asks         bras on registers the speaker wonders about
##
## Between two biomes (a product scope) a faction can compare one icon's readings:
##
##   spacewheat/BioticFlux⊗StarterForest@77d0  ⚠ [.82]☀₁ [.31]☀₂
##   (⚠: the two readings lean to different poles; 🟰: the same pole)

const SCOPE_BIOME := "spacewheat"
const SCOPE_FACTION := "faction"

const KET_OPEN := "|"
const KET_CLOSE := "⟩"
const BRA_OPEN := "⟨"
const BRA_CLOSE := "|"
const DARK := "?"
const PRODUCT := "⊗"
const TIE := "⌢"
const EPS := 1e-6
const CLAUSE_SEP := "  "
const SUBSCRIPTS := ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]

## The verbs. The Strand Dance keeps upstream's glyphs except null, which is ⚫:
## ✨ and ⚫ are the two poles of the Antimatter icon, so creation and annihilation
## are a qubit in the world. The other verbs move off glyphs that are SpaceWheat
## atoms (🧪 📍 🔮 🪞 🧵 🪢 👁 ⚡ were all already content).
const VERBS := {
	# Strand Dance
	"creation": "✨", "null": "⚫", "transform": "T", "push": "→",
	"pull": "←", "skip": "⤳", "fusion": "∇", "fission": "Δ",
	# the other verbs
	"observe": "❗", "attend": "❔", "verify": "🚦", "commit": "📌",
	"possibility": "⤵", "resonance": "🟰", "tension": "⚠", "reflect": "↩",
	"trace": "➰", "strand": "〰", "braid": "➿",
}


## §5 normalization: two bots must mean the same sun. Strip variation selectors
## (U+FE0F, U+FE0E) and skin-tone modifiers (U+1F3FB..U+1F3FF); keep ZWJ
## sequences whole. The registry holds both `⚙` and `⚙️` (icons.json: Fitting).
static func canonical(glyph: String) -> String:
	var out := ""
	for i in range(glyph.length()):
		var code: int = glyph.unicode_at(i)
		if code == 0xFE0F or code == 0xFE0E:
			continue
		if code >= 0x1F3FB and code <= 0x1F3FF:
			continue
		out += glyph.substr(i, 1)
	return out.strip_edges()


# --- scopes -----------------------------------------------------------------

## The vocabulary a scope declares, as the canonical text its tag hashes:
## pairs [[north, south], …] in order → "n/s,n/s".
static func pairs_text(pairs: Array) -> String:
	var parts: PackedStringArray = []
	for pair in pairs:
		if pair is Array and pair.size() >= 2:
			parts.append("%s/%s" % [canonical(str(pair[0])), canonical(str(pair[1]))])
	return ",".join(parts)


static func scope_tag(pairs: Array) -> String:
	return pairs_text(pairs).sha256_text().substr(0, 4)


static func biome_scope(biome_name: String, pairs: Array) -> String:
	var b := biome_name.strip_edges()
	if b == "":
		return ""
	return "%s/%s@%s" % [SCOPE_BIOME, b, scope_tag(pairs)]


static func faction_scope(faction_name: String, pairs: Array) -> String:
	var f := faction_name.strip_edges()
	if f == "":
		return ""
	return "%s/%s@%s" % [SCOPE_FACTION, f, scope_tag(pairs)]


## Product of biome scopes: names joined by ⊗, tag over every pair in order.
static func product_scope(biome_names: Array, pairs_per_biome: Array) -> String:
	var all_pairs: Array = []
	for pairs in pairs_per_biome:
		all_pairs.append_array(pairs)
	var names: PackedStringArray = []
	for n in biome_names:
		names.append(str(n).strip_edges())
	return "%s/%s@%s" % [SCOPE_BIOME, PRODUCT.join(names), scope_tag(all_pairs)]


# --- numbers and words --------------------------------------------------------

## A number at resolution ε = 0.01, written the way the doc writes it: no leading
## zero, no trailing zeros, the ends as bare 0 and 1.
##   0.8 → ".8"   0.05 → ".05"   1.0 → "1"   0.0 → "0"
static func fmt_number(p: float) -> String:
	var hundredths := int(round(clampf(p, 0.0, 1.0) * 100.0))
	if hundredths >= 100:
		return "1"
	if hundredths <= 0:
		return "0"
	return "." + ("%02d" % hundredths).rstrip("0")


## |g₁g₂…⟩; ties[i] true writes g_i⌢g_(i+1): those two are not independent.
static func ket(glyphs: Array, ties: Array = []) -> String:
	var body := ""
	for i in range(glyphs.size()):
		if i > 0 and i - 1 < ties.size() and bool(ties[i - 1]):
			body += TIE
		body += canonical(str(glyphs[i]))
	return KET_OPEN + body + KET_CLOSE


static func population(glyph: String, p: float) -> String:
	return "[%s]%s" % [fmt_number(p), canonical(glyph)]


static func dark(glyph: String) -> String:
	return canonical(glyph) + DARK


static func bra(glyph: String) -> String:
	return BRA_OPEN + canonical(glyph) + BRA_CLOSE


static func subscript(n: int) -> String:
	var out := ""
	for ch in str(n):
		out += SUBSCRIPTS[int(ch)]
	return out


# --- the physics that drives a line --------------------------------------------

## Binary entropy of a marginal, in bits: 0 at a settled pole, 1 at one half.
## A register is asked about with this probability: settled biomes state,
## churning ones ask.
static func ask_probability(p: float) -> float:
	var q := clampf(p, 0.0, 1.0)
	if q <= 0.0 or q >= 1.0:
		return 0.0
	return clampf(-(q * log(q) + (1.0 - q) * log(1.0 - q)) / log(2.0), 0.0, 1.0)


## Relative entropy (nats) of a register's reading now (p) from what the speaker
## last said of it (q): Bernoulli north marginals. 0 when nothing changed; small
## for a coin wobbling (.5→.6 ≈ 0.02); large for a certainty breaking (.99→.9 ≈
## 0.15, .9→.1 ≈ 1.8); ∞ for a certainty overturned.
static func relative_entropy(p: float, q: float) -> float:
	var a := clampf(p, EPS, 1.0 - EPS)
	var b := clampf(q, EPS, 1.0 - EPS)
	return a * log(a / b) + (1.0 - a) * log((1.0 - a) / (1.0 - b))


## A register comes up with probability 1 − e^(−D), D = relative entropy of the
## news in nats. No free parameter: a speaker keeps quiet about a register about
## as often as its last word still covers the truth. Never spoken of: D = ∞.
static func mention_probability(news_nats: float) -> float:
	if is_inf(news_nats):
		return 1.0
	return clampf(1.0 - exp(-maxf(news_nats, 0.0)), 0.0, 1.0)


## A tie ⌢ between two registers of one biome is written with probability
## equal to the mutual information (bits) of their pole outcomes, read from the
## same basis distribution the line's poles are drawn from: 1 for a Bell pair,
## 0 for independent poles. Registers in different biomes are separate states
## and are never tied. A ket states pole outcomes, so ⌢ says exactly that these
## outcomes do not come independently.
static func tie_probability(mutual_information_bits: float) -> float:
	return clampf(mutual_information_bits, 0.0, 1.0)


## A relationship lifts a chance: q^(1/(1+c)). c = 0 leaves q alone; a positive
## channel opens the speaker up (√q at c = 1), a negative one closes them (q² at
## c = −½). 0 and 1 are fixed points: no channel invents what is not there.
static func lift(q: float, c: float) -> float:
	var p := clampf(q, 0.0, 1.0)
	if p <= 0.0 or p >= 1.0:
		return p
	return pow(p, 1.0 / (1.0 + clampf(c, -0.9, 4.0)))


## Classical fidelity of two readings of one register (p, q = north marginals).
## 1 when they agree, 0 when they sit at opposite poles.
static func fidelity(p: float, q: float) -> float:
	var a := clampf(p, 0.0, 1.0)
	var b := clampf(q, 0.0, 1.0)
	return pow(sqrt(a * b) + sqrt((1.0 - a) * (1.0 - b)), 2.0)


## ⚠ tension when two readings of one register lean to different poles (they
## would collapse different ways), 🟰 resonance when they lean the same way.
## The pole is the boundary, not a tuned number.
static func between_verb(p: float, q: float) -> String:
	var a := clampf(p, 0.0, 1.0) - 0.5
	var b := clampf(q, 0.0, 1.0) - 0.5
	return VERBS["resonance"] if a * b > 0.0 else VERBS["tension"]


static func _is_number(v) -> bool:
	if not (v is float or v is int):
		return false
	var f := float(v)
	return not (is_nan(f) or is_inf(f))


# --- composing ---------------------------------------------------------------

## Compose one line.
##   scope   a scope string ("" → undefined: everything is written dark)
##   lit     [{glyph, p, tie?}, …] — drawn pole and its marginal, in scope
##           order; tie = written ⌢ to the previous lit glyph
##   darks   [glyph, …] — registers no measurement reaches
##   asks    [glyph, …] — each must be a lit glyph
## Returns {scope, ket, populations, darks, asks, short, sentence}.
static func compose(scope: String, lit: Array, darks: Array, asks: Array) -> Dictionary:
	var out := {"scope": scope, "ket": "", "populations": [], "darks": [], "asks": [],
		"short": "", "sentence": ""}
	var glyphs: Array = []
	var pops: Array = []
	var ties: Array = []   # ties[i]: glyph i is tied to glyph i+1
	for r in lit:
		var g := canonical(str(r.get("glyph", "")))
		if g == "":
			continue
		if scope != "" and _is_number(r.get("p", null)):
			if not glyphs.is_empty():
				ties.append(bool(r.get("tie", false)))
			glyphs.append(g)
			pops.append(population(g, float(r.get("p"))))
		else:
			darks = darks + [g]
	var dark_tokens: Array = []
	for d in darks:
		var g := canonical(str(d))
		if g != "":
			dark_tokens.append(dark(g))
	var ask_tokens: Array = []
	for a in asks:
		var g := canonical(str(a))
		if g != "" and g in glyphs:
			ask_tokens.append(bra(g))
	out["populations"] = pops
	out["darks"] = dark_tokens
	out["asks"] = ask_tokens
	if scope == "":
		out["short"] = " ".join(PackedStringArray(dark_tokens))
		out["sentence"] = out["short"]
		return out
	var short_parts: Array = []
	var clauses: Array = [scope]
	if not glyphs.is_empty():
		out["ket"] = ket(glyphs, ties)
		short_parts.append(out["ket"])
		clauses.append(out["ket"])
		clauses.append(" ".join(PackedStringArray(pops)))
	if not dark_tokens.is_empty():
		short_parts.append(" ".join(PackedStringArray(dark_tokens)))
		clauses.append(" ".join(PackedStringArray(dark_tokens)))
	if not ask_tokens.is_empty():
		short_parts.append(" ".join(PackedStringArray(ask_tokens)))
		clauses.append(" ".join(PackedStringArray(ask_tokens)))
	if clauses.size() == 1:
		return out  # nothing to say
	out["short"] = " ".join(PackedStringArray(short_parts))
	out["sentence"] = CLAUSE_SEP.join(PackedStringArray(clauses))
	return out


## A biome-scope line from one basis-state draw (SocialiteCluster): every qubit
## comes up (the draw is joint); register j is asked about iff ask_draws[j] <
## ask_probability(marginal j); ties[j] writes qubit j ⌢ qubit j+1. Missing
## marginals are dark.
static func compose_chatter(emojis: Array, marginals: Array, scope: String, ask_draws: Array = [], ties: Array = []) -> Dictionary:
	var lit: Array = []
	var asks: Array = []
	for j in range(emojis.size()):
		var g := canonical(str(emojis[j]))
		if g == "":
			continue
		var has_p: bool = j < marginals.size() and _is_number(marginals[j])
		var tied: bool = j > 0 and j - 1 < ties.size() and bool(ties[j - 1])
		lit.append({"glyph": g, "p": float(marginals[j]) if has_p else null, "tie": tied})
		if has_p and j < ask_draws.size() and _is_number(ask_draws[j]) \
				and float(ask_draws[j]) < ask_probability(float(marginals[j])):
			asks.append(g)
	return compose(scope, lit, [], asks)


## A product-scope line comparing readings of one icon in several biomes:
##   spacewheat/A⊗B@tag  ⚠ [.82]☀₁ [.31]☀₂
## readings: [{glyph, p}] in biome order; verb: a VERBS glyph.
static func compose_between(scope: String, verb: String, readings: Array) -> Dictionary:
	var ops: PackedStringArray = []
	for i in range(readings.size()):
		var r: Dictionary = readings[i]
		ops.append(population(str(r.get("glyph", "")), float(r.get("p", 0.0))) + subscript(i + 1))
	var sentence := "%s%s%s %s" % [scope, CLAUSE_SEP, verb, " ".join(ops)]
	return {"scope": scope, "verb": verb, "short": "%s %s" % [verb, " ".join(ops)], "sentence": sentence}
