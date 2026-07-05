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


## The faction's line at the rite — the wet-country reap paid from the entropy bank.
static func reap_whisper(faction_name: String) -> String:
	return whisper("reap", faction_name)


static func bridge_whisper(faction_name: String) -> String:
	return whisper("bridge", faction_name)


static func trade_whisper(faction_name: String) -> String:
	return whisper("trade", faction_name)


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

## One line per voice archetype for the RITE — the wet-country reap. v0 kept the
## name "reap" as a placeholder and deliberately gave it no ceremony; this is the
## harvest festival designed once, for the mechanic it honors: a season's
## accumulated dissipation opened and paid from the entropy bank, kT·ΔS
## (docs/OPEN_CAMPAIGN.md, Chapter V). Fires only when the extraction was real.
const REAP_WHISPER := {
	"imperial":  "The Throne taxes order. You have learned to tax its opposite. Do not imagine this goes unnoticed.",
	"guild":     "kT by ΔS, paid in full. The oldest contract there is — signed before there were signatures.",
	"mystic":    "What the world let go returns as coin. Entropy is only generosity, counted.",
	"merchant":  "Disorder consumed, credit issued. The universe keeps this ledger itself — best counterparty you'll ever have.",
	"militant":  "A season's decay, collected and spent. That is not loss. That is logistics.",
	"scavenger": "Everything that leaked, everything that faded — we drink it back at year's end. Nothing is wasted twice.",
	"horror":    "YOU ARE EATING THE FORGETTING ITSELF. CHEW SLOWLY.",
	"defensive": "The harvest is what the year surrendered. Take it gently — it was order once.",
	"cosmic":    "Stars have paid this tithe since the first light. Now you farm the field they burn in.",
	"entity":    "A GRADIENT HAS BEEN SPENT. THE BANK ACKNOWLEDGES THE WITHDRAWAL.",
}

## One line per voice archetype for FUSION — the moment a Majorana bridge is
## read. The joint parity lived between two biomes, in neither; reading it
## collapses and spends the span (BridgeRegister; What Connects). The one
## harvest whose crop was never in any field.
const BRIDGE_WHISPER := {
	"imperial":  "Storage the Throne cannot audit, spent the moment it is counted. The empire finds this... instructive.",
	"guild":     "A span holds by standing on two shores at once. You read it, it fell. That was the price of the reading.",
	"mystic":    "The answer lived between the places, in neither. You asked, and now it lives nowhere. Ask well next time.",
	"merchant":  "Off-ledger holdings, redeemed at spot. No vault to rob — the vault was the distance itself.",
	"militant":  "A supply line no siege can cut — until you use it. One shipment per bridge. Plan accordingly.",
	"scavenger": "Hid it in the gap between two worlds. Even the Bath couldn't reach the gap. Clever. Gone now.",
	"horror":    "IT WAS NEVER IN EITHER PLACE. YOU LOOKED, AND NOW IT IS NOT ANYWHERE.",
	"defensive": "The safest store is the one that isn't anywhere. Was. Build another.",
	"cosmic":    "Two shores, one fermion, no address. The universe permits the trick exactly once per bridge.",
	"entity":    "A NONLOCAL PARITY HAS BEEN LOCALIZED. THE SPAN IS RETIRED.",
}

## One line per voice archetype for a CONTRACT OPENING — a standing Merchant
## channel (thermal/dephase/damp) installed on a plot. The counterparty is the
## Bath itself; the channel runs until settled (F). Fires once per install,
## not per tick — contracts speak when signed, not while they flow.
const TRADE_WHISPER := {
	"imperial":  "The Throne licenses every tax farmer in its lands. You have opened a levy on the world itself. Expect an audit.",
	"guild":     "A standing channel, rate fixed, paid on flow. Mind it — contracts run until settled.",
	"mystic":    "You have opened a small mouth in the world, and it will drink until you close it.",
	"merchant":  "Continuous delivery, the environment as counterparty. The one partner who never defaults.",
	"militant":  "A supply line is a wound you cut on purpose. Guard it, and know when to close it.",
	"scavenger": "A tap in the barrel. Steady drips fill jugs — and empty barrels. Watch the level.",
	"horror":    "IT FLOWS NOW. IT DOES NOT KNOW HOW TO STOP. YOU ARE THE KNOWING.",
	"defensive": "Every open channel is a door. You hold the key — settle it when the weather turns.",
	"cosmic":    "All things exchange with the Bath in the end. You have merely set the rate.",
	"entity":    "CHANNEL REGISTERED. FLOW UNTIL SETTLED. THE LEDGER LISTENS.",
}

## One line per voice archetype for the soul RESOLVING — the identity ρ
## crossed a purity band upward (Farm.identity_band_changed, rising). Learning
## concentrated the diagonal: of all the selves superposed, one is winning.
const SELF_RESOLVE_WHISPER := {
	"imperial":  "The Throne prefers its subjects legible. You are becoming a name it can write.",
	"guild":     "A tool ground to one edge cuts. You are taking an edge.",
	"mystic":    "The many yous are agreeing on something. Listen while they do.",
	"merchant":  "A known buyer gets better prices. It pays to be somebody.",
	"militant":  "A sharpened line holds. You are easier to follow now — and to command.",
	"scavenger": "Less of you scattered about to lose. Good. Carry all of it.",
	"horror":    "THE OTHER SELVES ARE GOING QUIET. ONLY YOU REMAIN. WAS THAT THE PLAN?",
	"defensive": "A resolved soul is a wall with one gate. Easier to hold.",
	"cosmic":    "Of all the lives superposed in you, this one is brightening.",
	"entity":    "IDENTITY CONVERGENCE LOGGED. THE LEXICON KNOWS WHO IS READING.",
}

## One line per voice archetype for the soul BLURRING — the identity ρ crossed
## a purity band downward. A learn spread your mass across factions, or kicked
## coherences faded (τ = 300 s); either way, the superposition is reclaiming you.
const SELF_FADE_WHISPER := {
	"imperial":  "The Throne cannot tax what it cannot name. Decide who you are.",
	"guild":     "An unswung hammer forgets its handle. Work, or blur.",
	"mystic":    "You are becoming everyone again. There is peace in it, and no one left to feel it.",
	"merchant":  "An unknown customer pays list price. Being no one is expensive.",
	"militant":  "Your line is smearing. Reform it, or be overrun by your own maybes.",
	"scavenger": "Bits of you are drifting off. Gather yourself before someone else does.",
	"horror":    "YOU ARE FORGETTING WHICH ONE YOU WERE. THE OTHERS REMEMBER BEING YOU.",
	"defensive": "The wall of you is thinning. Choose something, and shore it.",
	"cosmic":    "The superposition reclaims you gently. Every unchosen life grows brighter.",
	"entity":    "IDENTITY DISPERSAL DETECTED. RENEWAL ADVISED.",
}

## The whisper registers: one voice line per archetype at each of the world's
## speaking moments — the sealed channels, the closed loop, the improbable scar,
## the rite that opens the season's entropy bank, the fusion that spends a span,
## and the soul crossing a purity band in either direction.
const WHISPERS := {
	"webway": WEBWAY_WHISPER,
	"berry": BERRY_WHISPER,
	"measure": MEASURE_WHISPER,
	"reap": REAP_WHISPER,
	"bridge": BRIDGE_WHISPER,
	"trade": TRADE_WHISPER,
	"self_resolve": SELF_RESOLVE_WHISPER,
	"self_fade": SELF_FADE_WHISPER,
}

## Authored per-faction whisper lines — checked BEFORE the archetype tables.
## The home for signature lines that belong to ONE faction, not its voice class.
## Shape: register -> {faction_name: line}.
const FACTION_WHISPER_OVERRIDES := {
	"measure": {
		"Measure Scribes": "Every glance is an entry in the ledger. The ledger is the world.",
	},
	"webway": {
		"Lamplighters": "The fog channels are shut, and good riddance. A lamp that cannot gutter burns honest — what the pattern holds, it holds forever.",
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


## The dominant faction's line when the player's identity ρ resolves upward.
static func self_resolve_whisper(faction_name: String) -> String:
	return whisper("self_resolve", faction_name)


## The dominant faction's line when the player's identity ρ blurs downward.
static func self_fade_whisper(faction_name: String) -> String:
	return whisper("self_fade", faction_name)


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
