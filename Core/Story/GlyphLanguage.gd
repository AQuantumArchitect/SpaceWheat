extends RefCounted

## GlyphLanguage — SpaceWheat's dialect of the glyph language (docs/GLYPH_LANGUAGE.md).
##
## Pure and static: no scene tree, no autoloads, no state. Rendering a sentence
## never measures or changes a state (the language's first rule); this module
## only formats numbers the caller already read off ρ.
##
## The one-line version: an emoji is a pole of a qubit; a ket is a statement; a
## bra is a question; and nothing means anything until a scope (here: a biome)
## has declared the space.
##
## A chatter utterance is three clauses read against one scope:
##
##   spacewheat/Village  |🔥👥⚙💰⟩  [.82]🔥 [.61]👥 [.5]⚙ [.97]💰  ⟨⚙|
##   └─ scope ─────────┘ └─ ket ──┘ └─ populations ─────────────┘ └ ask ┘
##
##   ket          the basis outcome the speaker drew (one Born sample)
##   populations  ρ's marginal at each drawn pole, written straight (read off ρ)
##   ask          a bra on the register the speaker is least sure of
##                (marginal nearest one half) — what the speaker wonders about
##
## A register with no marginal is dark (`⚙?`), never a half. A line with no scope
## (a socialite that could not measure a biome and fell back to its own glyphs)
## is undefined in the language: every glyph is written dark and there is no ket.

const SCOPE_ROOT := "spacewheat"

const KET_OPEN := "|"
const KET_CLOSE := "⟩"
const BRA_OPEN := "⟨"
const BRA_CLOSE := "|"
const DARK := "?"
const CLAUSE_SEP := "  "


## §5 normalization: two bots must mean the same sun. Strip variation selectors
## (U+FE0F, U+FE0E) and skin-tone modifiers (U+1F3FB..U+1F3FF); keep ZWJ
## sequences whole. The registry already holds both `⚙` and `⚙️` (icons.json:
## Fitting) — this is why they must stop differing.
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


## The scope a biome declares. Empty biome → empty scope (undefined).
static func scope_for_biome(biome_name: String) -> String:
	var b := biome_name.strip_edges()
	if b == "":
		return ""
	return "%s/%s" % [SCOPE_ROOT, b]


## A number at the scope's resolution ε = 0.01, written the way the doc writes
## it: no leading zero, no trailing zeros, the ends as bare 0 and 1.
##   0.8 → ".8"   0.825 → ".83"   0.05 → ".05"   1.0 → "1"   0.0 → "0"
## Non-finite input is not a number; the caller must write the register dark.
static func fmt_number(p: float) -> String:
	var q := clampf(p, 0.0, 1.0)
	var hundredths := int(round(q * 100.0))
	if hundredths >= 100:
		return "1"
	if hundredths <= 0:
		return "0"
	var s := "%02d" % hundredths
	s = s.rstrip("0")
	return "." + s


## |g₁g₂…⟩ — juxtaposition inside a ket means product: siblings read jointly.
static func ket(glyphs: Array) -> String:
	var body := ""
	for g in glyphs:
		body += canonical(str(g))
	return KET_OPEN + body + KET_CLOSE


## [p]g — a population: support p along the pole g. [p]g ≡ [1−p]ḡ.
static func population(glyph: String, p: float) -> String:
	return "[%s]%s" % [fmt_number(p), canonical(glyph)]


## g? — dark: nothing has measured it. Not zero, not a half.
static func dark(glyph: String) -> String:
	return canonical(glyph) + DARK


## ⟨g| — a question: how much g?
static func bra(glyph: String) -> String:
	return BRA_OPEN + canonical(glyph) + BRA_CLOSE


static func _is_number(v) -> bool:
	if not (v is float or v is int):
		return false
	var f := float(v)
	return not (is_nan(f) or is_inf(f))


## Compose one chatter utterance from a measurement event's parts.
##
##   emojis     the drawn pole per qubit, in qubit order (BiomeMeasurementSampler)
##   marginals  ρ's marginal at each drawn pole (may be shorter, or empty)
##   biome      the biome the sample came from ("" → no scope)
##
## Returns {scope, ket, populations: Array[String], ask, short, sentence}.
##   short     ket + ask — the compact form a chat bubble shows
##   sentence  every clause, scope first — the canonical line
static func compose_chatter(emojis: Array, marginals: Array, biome: String) -> Dictionary:
	var glyphs: Array = []
	for e in emojis:
		var g := canonical(str(e))
		if g != "":
			glyphs.append(g)
	var scope := scope_for_biome(biome)
	var out := {"scope": scope, "ket": "", "populations": [], "ask": "", "short": "", "sentence": ""}
	if glyphs.is_empty():
		return out

	if scope == "":
		# Outside a scope the language is undefined, not wrong: a sentence
		# waiting for one. Every glyph is dark; nothing is asserted.
		var darks: Array = []
		for g in glyphs:
			darks.append(dark(g))
		out["populations"] = darks
		out["short"] = " ".join(PackedStringArray(darks))
		out["sentence"] = out["short"]
		return out

	var pops: Array = []
	var ask_idx := -1
	var ask_dist := INF
	for j in range(glyphs.size()):
		var g: String = glyphs[j]
		if j < marginals.size() and _is_number(marginals[j]):
			var m := clampf(float(marginals[j]), 0.0, 1.0)
			pops.append(population(g, m))
			# Least sure = nearest one half. Strict < keeps the first on ties.
			var d := absf(m - 0.5)
			if d < ask_dist:
				ask_dist = d
				ask_idx = j
		else:
			pops.append(dark(g))

	out["ket"] = ket(glyphs)
	out["populations"] = pops
	if ask_idx >= 0:
		out["ask"] = bra(glyphs[ask_idx])
	var short_parts: Array = [out["ket"]]
	if out["ask"] != "":
		short_parts.append(out["ask"])
	out["short"] = " ".join(PackedStringArray(short_parts))
	var clauses: Array = [scope, out["ket"], " ".join(PackedStringArray(pops))]
	if out["ask"] != "":
		clauses.append(out["ask"])
	out["sentence"] = CLAUSE_SEP.join(PackedStringArray(clauses))
	return out
