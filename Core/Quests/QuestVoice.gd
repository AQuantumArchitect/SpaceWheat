class_name QuestVoice
extends RefCounted

## QuestVoice — gives every quest a faction-flavored voice, replacing the flavorless
## "deliver 🌾 · pay ~2 🌾". Salvaged from the deprecated FactionVoices (10 archetypes + a
## faction→archetype map) and extended with a quest-type→verb table.
##
## Phase 1 applies this to MARKET quests (the bland ones). Story/tutorial quests keep their
## AUTHORED body/full_text — voicing only fills text that isn't already authored.
## Voice resolution (archetype_for): the authored FACTION_TO_VOICE map wins; factions
## outside it derive their archetype from identity (domain/ring/tags — see
## DOMAIN_TO_VOICE), so all ~99 registry factions speak in character; "guild" is the
## last resort, not the common case. (The 12 axial bits were tried and rejected as the
## derivation source: they encode state-preferences, not diction — 20% agreement with
## the authored map vs 83% for domain identity.)

## Each archetype carries a phrase bank (variant 0 = the classic line; kept as
## "prefix"/"suffix" too for any single-phrase consumer). Selection is a stable
## content hash — no RNG, same quest reads the same forever.
const VOICES := {
	"imperial": {
		"prefix": "By imperial decree:", "suffix": "for the Throne.", "tone": "absolute",
		"prefixes": ["By imperial decree:", "The Throne wills it:", "Let the edict read:"],
		"suffixes": ["for the Throne.", "so the empire endures.", "the ledger of rule remembers."],
	},
	"guild": {
		"prefix": "The Guild requires:", "suffix": "as per contract.", "tone": "collective",
		"prefixes": ["The Guild requires:", "Work order, countersigned:", "The rolls have need:"],
		"suffixes": ["as per contract.", "paid on completion, as always.", "the union thanks you."],
	},
	"mystic": {
		"prefix": "The mysteries demand:", "suffix": "so it is written.", "tone": "mystical",
		"prefixes": ["The mysteries demand:", "It was foretold you would be asked:", "The silence between states requests:"],
		"suffixes": ["so it is written.", "the pattern will remember.", "ask not why; the wheel knows."],
	},
	"merchant": {
		"prefix": "A profitable venture:", "suffix": "payment upon delivery.", "tone": "mercantile",
		"prefixes": ["A profitable venture:", "Opportunity, priced to move:", "Between us — a healthy margin:"],
		"suffixes": ["payment upon delivery.", "buyer assumes the risk.", "profit is proof."],
	},
	"militant": {
		"prefix": "Orders:", "suffix": "for honor.", "tone": "military",
		"prefixes": ["Orders:", "Directive, effective immediately:", "The line holds if you hold it:"],
		"suffixes": ["for honor.", "dismissed.", "no excuses accepted."],
	},
	"scavenger": {
		"prefix": "Opportunity:", "suffix": "finders keepers.", "tone": "opportunistic",
		"prefixes": ["Opportunity:", "Word is there's salvage:", "Saw it first, telling you second:"],
		"suffixes": ["finders keepers.", "before someone else does.", "strip it clean."],
	},
	"horror": {
		"prefix": "IT WHISPERS:", "suffix": "or be consumed.", "tone": "eldritch",
		"prefixes": ["IT WHISPERS:", "THE DARK BENEATH ASKS:", "A MOUTH OPENS IN THE WORLD:"],
		"suffixes": ["or be consumed.", "IT IS ALREADY LISTENING.", "refusal is also an answer."],
	},
	"defensive": {
		"prefix": "For our protection:", "suffix": "for the community.", "tone": "protective",
		"prefixes": ["For our protection:", "The walls ask little:", "So the children sleep:"],
		"suffixes": ["for the community.", "we keep what we keep.", "quietly, if you can."],
	},
	"cosmic": {
		"prefix": "The cosmos requires:", "suffix": "across all dimensions.", "tone": "transcendent",
		"prefixes": ["The cosmos requires:", "Along every worldline at once:", "The spiral arm requests:"],
		"suffixes": ["across all dimensions.", "as above, so below.", "the geometry thanks you."],
	},
	"entity": {
		"prefix": "EXISTENCE DEMANDS:", "suffix": "THUS IT SHALL BE.", "tone": "absolute_cosmic",
		"prefixes": ["EXISTENCE DEMANDS:", "THE SUBSTRATE REQUIRES:", "BE ADVISED, INSTANCE:"],
		"suffixes": ["THUS IT SHALL BE.", "COMPLIANCE IS STRUCTURE.", "IT WAS ALWAYS SO."],
	},
}

const FACTION_TO_VOICE := {
	"Carrion Throne": "imperial", "House of Thorns": "imperial", "Granary Guilds": "imperial",
	"Station Lords": "imperial",
	"Obsidian Will": "guild", "Millwright's Union": "guild", "Tinker Team": "guild",
	"Seamstress Syndicate": "guild", "Gravedigger's Union": "guild", "Symphony Smiths": "guild",
	"Keepers of Silence": "mystic", "Sacred Flame Keepers": "mystic", "Iron Confessors": "mystic",
	"Yeast Prophets": "mystic", "Hearth Keepers": "mystic",
	"Syndicate of Glass": "merchant", "Memory Merchants": "merchant", "Bone Merchants": "merchant",
	"Nexus Wardens": "merchant",
	"Iron Shepherds": "militant", "Brotherhood of Ash": "militant", "Children of the Ember": "militant",
	"Order of the Crimson Scale": "militant",
	"Rust Fleet": "scavenger", "Locusts": "scavenger", "Cartographers": "scavenger",
	"Laughing Court": "horror", "Cult of the Drowned Star": "horror", "Chorus of Oblivion": "horror",
	"Flesh Architects": "horror",
	"Void Serfs": "defensive", "Clan of the Hidden Root": "defensive", "Veiled Sisters": "defensive",
	"Terrarium Collective": "defensive",
	"Resonance Dancers": "cosmic", "Causal Shepherds": "cosmic", "Empire Shepherds": "cosmic",
	"Entropy Shepherds": "entity", "Void Emperors": "entity", "Reality Midwives": "entity",
}

## Domain → voice archetype for factions OUTSIDE the authored map (the plan's
## "derive voice per faction" — the authored FACTION_TO_VOICE above always wins;
## this rule covers the other ~60 registry factions so nobody defaults to the
## bland guild voice by accident). Validated offline against the 35 authored
## assignments: 29/35 agree; the 6 divergents are authored exceptions and the
## authored row shadows them at runtime. Compound domains ("Imperial/Horror")
## resolve by first matching segment; Civic and outer-ring Mystic get the
## tag/ring refinements the authored set exhibits.
const DOMAIN_TO_VOICE := {
	"Commerce": "merchant", "Criminal": "merchant", "Intelligence": "merchant",
	"Military": "militant", "Enforcement": "militant", "Security": "militant",
	"Scavenger": "scavenger", "Navigation": "scavenger",
	"Horror": "horror", "Dissolution": "horror", "Boundary": "horror",
	"Predation": "horror", "Threshold": "horror",
	"Mystic": "mystic", "Knowledge": "mystic", "Memory": "mystic",
	"Infrastructure": "guild", "Administration": "guild", "Administrative": "guild",
	"Science": "guild", "Industrial": "guild", "Deep-Math": "guild",
	"Labor": "defensive", "Medicine": "defensive", "Ecology": "defensive", "Subsistence": "defensive",
	"Art-Signal": "cosmic", "Chronology": "cosmic", "Emission": "cosmic",
	"Aristocracy": "imperial", "Imperial": "imperial", "Executive": "imperial",
}
const IMPERIAL_TAGS := ["imperial", "authority", "aristocracy", "law", "edict", "politics"]
const ENTITY_TAGS := ["void", "nothing", "creation", "emergence"]

static var _archetype_cache: Dictionary = {}


## Resolve a faction's voice archetype: authored map first, then derived from
## its identity (domain/ring/tags via the registry), guild as the last resort.
static func archetype_for(faction_name: String) -> String:
	if FACTION_TO_VOICE.has(faction_name):
		return str(FACTION_TO_VOICE[faction_name])
	if _archetype_cache.has(faction_name):
		return str(_archetype_cache[faction_name])
	var arch := "guild"
	var reg = FactionRegistry.get_shared()
	var fac = reg.get_by_name(faction_name) if reg != null else null
	if fac != null:
		arch = archetype_from_identity(
				str(fac.domain) if "domain" in fac else "",
				str(fac.ring) if "ring" in fac else "center",
				fac.tags if ("tags" in fac and fac.tags is Array) else [])
	_archetype_cache[faction_name] = arch
	return arch


## Pure derivation (also directly testable headless): identity → archetype.
static func archetype_from_identity(domain: String, ring: String, tags: Array) -> String:
	var tagset := {}
	for t in tags:
		tagset[str(t)] = true
	for seg_raw in domain.split("/"):
		var seg := str(seg_raw).strip_edges()
		if seg == "Mystic" and ring == "outer":
			return "entity"
		if seg == "Civic":
			if ring == "outer" or _any_tag(tagset, IMPERIAL_TAGS):
				return "imperial"
			if _any_tag(tagset, ENTITY_TAGS):
				return "entity"
			return "defensive"
		if DOMAIN_TO_VOICE.has(seg):
			return str(DOMAIN_TO_VOICE[seg])
	return "guild"


static func _any_tag(tagset: Dictionary, list: Array) -> bool:
	for t in list:
		if tagset.has(str(t)):
			return true
	return false


## Quest type → an evocative verb for the voiced line.
const TYPE_VERB := {
	QuestTypes.Type.DELIVERY: "deliver",
	QuestTypes.Type.SHAPE_ACHIEVE: "shape",
	QuestTypes.Type.SHAPE_MAINTAIN: "hold",
	QuestTypes.Type.EVOLUTION: "shift",
	QuestTypes.Type.ENTANGLEMENT: "entangle",
	QuestTypes.Type.ACHIEVE_EIGENSTATE: "crystallize",
	QuestTypes.Type.MAINTAIN_COHERENCE: "weave",
	QuestTypes.Type.INDUCE_BELL_STATE: "bind",
	QuestTypes.Type.PREVENT_DECOHERENCE: "ward",
	QuestTypes.Type.COLLAPSE_DELIBERATELY: "collapse",
}


## One line per voice archetype about the SEALED webway — the dry Lindblad
## channels drawn dark in the graph views (docs/glossary/webway.md). Words only,
## no mechanics: surfaced where the player stands at the channels (M · Graph
## drill-down). Each archetype tells you what it *wants* from Act 2 without a
## single mechanic existing yet.
const WEBWAY_WHISPER := {
	"imperial":  "The Throne remembers when these rivers ran. They will run again — and the Throne will own the mouths.",
	"guild":     "The channels once turned wheels without anyone's hand. Dry, not gone. Mind the difference.",
	"mystic":    "The old flows sleep behind the seal. Do not pity them — sleep is also a keeping.",
	"merchant":  "Dry channels still have carrying capacity. When they open, fortunes will move. Position yourself.",
	"militant":  "A sealed gate is a defensible gate. Pray the enclave holds.",
	"scavenger": "Dry riverbeds are roads. Walk them now, before the water remembers.",
	"horror":    "IT REMEMBERS FLOWING. THE SEAL IS A PROMISE, NOT A WALL.",
	"defensive": "The seal keeps more out than in. Do not ask what drank from the flow before.",
	"cosmic":    "Channels are worldlines waiting for their arrow. Nothing here has direction — yet.",
	"entity":    "STASIS IS A CHOICE. THE ENCLAVE CHOSE. WE WERE NOT CONSULTED.",
}


static func get_voice(faction_name: String) -> Dictionary:
	return VOICES.get(archetype_for(faction_name), VOICES["guild"])


## The faction's line about the sealed webway (falls back to the guild voice).
static func webway_whisper(faction_name: String) -> String:
	return whisper("webway", faction_name)


## One line per voice archetype for the moment a Berry loop is INCORPORATED —
## the qubit walked a closed loop on its sphere, the signed solid angle ripened
## past 2π, and the player wove the axis into their signature
## (docs/glossary/berry.md). The harvest moment was mute; now it answers.
const BERRY_WHISPER := {
	"imperial":  "Another word annexed. The Throne's lexicon grows through you.",
	"guild":     "A loop closed clean is a wheel trued. The word is yours.",
	"mystic":    "You walked the circle and came back changed. That is the only way anyone learns anything.",
	"merchant":  "A word earned is a word you can sell. Twice, if you're careful.",
	"militant":  "Ground taken on the sphere is ground held. Mark it.",
	"scavenger": "Picked clean off the curve itself. Nothing wasted — take the word and move.",
	"horror":    "THE CIRCLE REMEMBERS BEING WALKED. NOW SO DO YOU.",
	"defensive": "A word of your own is a wall of your own. Add it to the stockade.",
	"cosmic":    "The sphere kept the angle; the angle became a name. Geometry is generous today.",
	"entity":    "A HOLONOMY HAS BEEN FILED. THE LEXICON ACKNOWLEDGES YOU.",
}


## One line per voice archetype for an IMPROBABLE measurement — the Born sample
## landed on a thin branch (small p, big surprisal payout). The scar that taught
## you most deserves a witness (docs/glossary/measurement.md).
const MEASURE_WHISPER := {
	"imperial":  "An unlikely writ, notarized by collapse. The Throne pays best for what it did not expect.",
	"guild":     "Long odds, clean read. That's craft — or luck wearing craft's apron.",
	"mystic":    "The improbable answered. You did not find it; it chose to be found.",
	"merchant":  "A rare outcome is a rare good. Sell the story with it.",
	"militant":  "Struck the narrow target. Wear the scar.",
	"scavenger": "Everyone walked past that one. You looked. Finders keepers.",
	"horror":    "IT WAS ALMOST NOT. NOW IT CANNOT BE UNKNOWN.",
	"defensive": "The unlikely is where danger hides. You dragged it into the light — good.",
	"cosmic":    "A thin branch of the wavefunction, and you stood on it as it became the trunk.",
	"entity":    "AN IMPROBABILITY HAS BEEN COLLECTED. THE LEDGER SMILES.",
}

## The whisper registers: one voice line per archetype at each of the world's
## speaking moments — the sealed channels, the closed loop, the improbable scar.
const WHISPERS := {
	"webway": WEBWAY_WHISPER,
	"berry": BERRY_WHISPER,
	"measure": MEASURE_WHISPER,
}

## Authored per-faction whisper lines — checked BEFORE the archetype tables.
## The home for signature lines that belong to ONE faction, not its voice class.
## Shape: register -> {faction_name: line}.
const FACTION_WHISPER_OVERRIDES := {
	"measure": {
		"Measure Scribes": "Every glance is an entry in the ledger. The ledger is the world.",
	},
}


## Unified whisper access: authored per-faction line first, then the faction's
## archetype line in the given register ("webway" | "berry" | "measure").
## Guild-voiced fallback for unmapped factions; "" for unknown registers.
static func whisper(register: String, faction_name: String) -> String:
	var overrides = FACTION_WHISPER_OVERRIDES.get(register, {})
	if overrides is Dictionary and overrides.has(faction_name):
		return str(overrides[faction_name])
	var table = WHISPERS.get(register, {})
	if not (table is Dictionary):
		return ""
	return str(table.get(archetype_for(faction_name), ""))


## The faction's line for an incorporated Berry loop (guild-voiced fallback).
static func berry_whisper(faction_name: String) -> String:
	return whisper("berry", faction_name)


static func _verb_for(quest: Dictionary) -> String:
	var t = quest.get("type", QuestTypes.Type.DELIVERY)
	if typeof(t) == TYPE_INT or typeof(t) == TYPE_FLOAT:
		return str(TYPE_VERB.get(int(t), "tend"))
	return "deliver"  # legacy string type (authored story quests)


## Apply faction voice to a quest IN PLACE: sets body/full_text from the faction archetype.
## Delivery quests read resource/quantity; quantum quests read observable/target. Skips quests
## that already carry authored text (story/tutorial), so authored beats are never clobbered.
static func apply(quest: Dictionary) -> void:
	if str(quest.get("source", "")) != Quest.SOURCE_MARKET:
		return
	var faction := str(quest.get("faction", ""))
	var v := get_voice(faction)
	var biome := str(quest.get("biome", quest.get("biome_name", "")))
	# Stable content hash (market ids are stamped after voicing, so the id can't
	# seed this): same quest content → same phrasing forever; different quests →
	# different bank variants. Prefix and suffix are decorrelated.
	var seed_i: int = absi(hash("%s|%s|%s|%s" % [faction,
			str(quest.get("resource", quest.get("observable", ""))),
			str(quest.get("quantity", 0)), biome]))
	var prefix := _variant(v, "prefixes", "prefix", seed_i)
	var suffix := _variant(v, "suffixes", "suffix", seed_i / 7)
	var who := faction if faction != "" else "A faction"
	var t = quest.get("type", QuestTypes.Type.DELIVERY)
	var ti := int(t) if (typeof(t) == TYPE_INT or typeof(t) == TYPE_FLOAT) else QuestTypes.Type.DELIVERY
	if ti == QuestTypes.Type.DELIVERY:
		var resource := str(quest.get("resource", ""))
		var qty := int(quest.get("quantity", 1))
		quest["body"] = "%s deliver %d× %s %s" % [prefix, qty, resource, suffix]
		quest["full_text"] = "%s %s seek %d× %s from %s — deliver %s" % [prefix, who, qty, resource, biome, suffix]
	else:
		var verb := str(TYPE_VERB.get(ti, "tend"))
		var obj := _quantum_object(quest, ti)
		quest["body"] = "%s %s %s %s" % [prefix, verb, obj, suffix]
		quest["full_text"] = "%s %s call you to %s %s in %s — %s" % [prefix, who, verb, obj, biome, suffix]


## Deterministic phrase-bank pick: bank[seed % size], falling back to the
## single-phrase key when an archetype carries no bank.
static func _variant(v: Dictionary, bank_key: String, single_key: String, seed_i: int) -> String:
	var bank = v.get(bank_key, [])
	if bank is Array and not bank.is_empty():
		return str(bank[seed_i % bank.size()])
	return str(v.get(single_key, ""))


## Phrase a quantum quest's objective from its type-specific fields.
static func _quantum_object(quest: Dictionary, ti: int) -> String:
	match ti:
		QuestTypes.Type.SHAPE_ACHIEVE, QuestTypes.Type.SHAPE_MAINTAIN:
			# Composed (multi) asks carry predicates, not a single observable.
			if not quest.has("observable"):
				var preds = quest.get("state_predicates", [])
				if preds is Array and not preds.is_empty():
					return "%d threads at once" % preds.size()
			var cmp := "past" if str(quest.get("comparison", ">")) != "<" else "below"
			var ob := str(quest.get("observable", "coherence"))
			if ob == "max_mutual_information":
				ob = "entanglement"
			elif ob.begins_with("population:"):
				ob = "%s population" % ob.trim_prefix("population:")
			elif ob.begins_with("balance:"):
				var pr := ob.trim_prefix("balance:").split("/")
				if pr.size() == 2:
					ob = "%s over %s" % [pr[0], pr[1]]
			return "%s %s %.2f" % [ob, cmp, float(quest.get("target", 0.7))]
		QuestTypes.Type.EVOLUTION:
			return "%s by %+.2f" % [str(quest.get("observable", "coherence")), float(quest.get("delta", 0.2))]
		QuestTypes.Type.ENTANGLEMENT:
			return "coherence past %.2f" % float(quest.get("target_coherence", 0.6))
		QuestTypes.Type.MAINTAIN_COHERENCE:
			return "coherence above %.2f" % float(quest.get("target_coherence", quest.get("target", 0.5)))
		QuestTypes.Type.ACHIEVE_EIGENSTATE:
			return "a dominant eigenstate"
		_:
			return "the quantum state"
