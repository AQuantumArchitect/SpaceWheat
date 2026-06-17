class_name QuestVoice
extends RefCounted

## QuestVoice — gives every quest a faction-flavored voice, replacing the flavorless
## "deliver 🌾 · pay ~2 🌾". Salvaged from the deprecated FactionVoices (10 archetypes + a
## faction→archetype map) and extended with a quest-type→verb table.
##
## Phase 1 applies this to MARKET quests (the bland ones). Story/tutorial quests keep their
## AUTHORED body/full_text — voicing only fills text that isn't already authored.
## A faction not in the map falls back to the neutral "guild" voice (so new factions still read
## sensibly); per-faction procedural voice from the signature can refine this later.

const VOICES := {
	"imperial":  {"prefix": "By imperial decree:", "suffix": "for the Throne.", "tone": "absolute"},
	"guild":     {"prefix": "The Guild requires:", "suffix": "as per contract.", "tone": "collective"},
	"mystic":    {"prefix": "The mysteries demand:", "suffix": "so it is written.", "tone": "mystical"},
	"merchant":  {"prefix": "A profitable venture:", "suffix": "payment upon delivery.", "tone": "mercantile"},
	"militant":  {"prefix": "Orders:", "suffix": "for honor.", "tone": "military"},
	"scavenger": {"prefix": "Opportunity:", "suffix": "finders keepers.", "tone": "opportunistic"},
	"horror":    {"prefix": "IT WHISPERS:", "suffix": "or be consumed.", "tone": "eldritch"},
	"defensive": {"prefix": "For our protection:", "suffix": "for the community.", "tone": "protective"},
	"cosmic":    {"prefix": "The cosmos requires:", "suffix": "across all dimensions.", "tone": "transcendent"},
	"entity":    {"prefix": "EXISTENCE DEMANDS:", "suffix": "THUS IT SHALL BE.", "tone": "absolute_cosmic"},
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


static func get_voice(faction_name: String) -> Dictionary:
	return VOICES.get(FACTION_TO_VOICE.get(faction_name, "guild"), VOICES["guild"])


static func _verb_for(quest: Dictionary) -> String:
	var t = quest.get("type", QuestTypes.Type.DELIVERY)
	if typeof(t) == TYPE_INT or typeof(t) == TYPE_FLOAT:
		return str(TYPE_VERB.get(int(t), "tend"))
	return "deliver"  # legacy string type (authored story quests)


## Apply faction voice to a quest IN PLACE: sets body/full_text from the faction archetype + the
## quest's resource/quantity/biome. Skips quests that already carry authored text (story/tutorial),
## so authored beats are never clobbered.
static func apply(quest: Dictionary) -> void:
	# Authored sources keep their text.
	if str(quest.get("source", "")) != Quest.SOURCE_MARKET:
		return
	var faction := str(quest.get("faction", ""))
	var v := get_voice(faction)
	var verb := _verb_for(quest)
	var resource := str(quest.get("resource", ""))
	var qty := int(quest.get("quantity", 1))
	var biome := str(quest.get("biome", quest.get("biome_name", "")))
	var prefix := str(v.get("prefix", ""))
	var suffix := str(v.get("suffix", ""))
	var who := faction if faction != "" else "A faction"
	quest["body"] = "%s %s %d× %s %s" % [prefix, verb, qty, resource, suffix]
	quest["full_text"] = "%s %s seek %d× %s from %s — %s %s" % [
		prefix, who, qty, resource, biome, verb, suffix
	]
