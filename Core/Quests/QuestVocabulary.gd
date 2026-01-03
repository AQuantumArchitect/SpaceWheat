class_name QuestVocabulary
extends Resource

## Quest vocabulary atoms - verbs, modifiers, templates
## Based on quest_demo.py - 159 atoms total

# =============================================================================
# QUEST VERBS (18 total)
# =============================================================================

const VERBS = {
	"harvest": {
		"affinity": [null, 0, 0, null, 0, 0, null, 0, null, null, null, null],
		"emoji": "🌾",
		"transitive": true
	},
	"deliver": {
		"affinity": [null, 0, null, null, 0, 0, null, 0, null, null, null, null],
		"emoji": "📦",
		"transitive": true
	},
	"defend": {
		"affinity": [null, 0, null, null, 0, 0, 0, 0, null, null, null, null],
		"emoji": "🛡️",
		"transitive": true
	},
	"destroy": {
		"affinity": [null, 0, null, null, 0, 0, null, 0, 0, null, null, null],
		"emoji": "💥",
		"transitive": true
	},
	"build": {
		"affinity": [1, 0, null, null, 1, 0, 0, 0, 1, null, 1, null],
		"emoji": "🏗️",
		"transitive": true
	},
	"repair": {
		"affinity": [1, 0, 0, 0, 0, 0, null, 0, 1, null, null, null],
		"emoji": "🔧",
		"transitive": true
	},
	"negotiate": {
		"affinity": [null, null, 1, null, null, 1, null, 1, null, null, null, null],
		"emoji": "🤝",
		"transitive": false
	},
	"investigate": {
		"affinity": [null, null, null, null, 1, 1, null, 1, null, null, 0, null],
		"emoji": "🔍",
		"transitive": true
	},
	"decode": {
		"affinity": [1, 1, null, null, 1, 1, null, 1, null, null, null, 1],
		"emoji": "🔐",
		"transitive": true
	},
	"observe": {
		"affinity": [null, 1, null, null, 1, 1, null, 1, null, null, 0, null],
		"emoji": "👁️",
		"transitive": true
	},
	"predict": {
		"affinity": [0, 1, 1, 1, 1, 1, 1, 1, null, null, null, 1],
		"emoji": "🔮",
		"transitive": true
	},
	"sanctify": {
		"affinity": [1, 1, 1, null, 1, 1, 0, null, 1, null, 1, null],
		"emoji": "✨",
		"transitive": true
	},
	"transform": {
		"affinity": [null, 1, null, null, null, 1, 1, null, null, 1, null, null],
		"emoji": "🔄",
		"transitive": true
	},
	"commune": {
		"affinity": [0, 1, null, 1, 1, 1, 1, 1, null, 1, 0, null],
		"emoji": "🌌",
		"transitive": false
	},
	"banish": {
		"affinity": [null, 1, 1, null, 0, 1, 0, 0, 0, null, 1, null],
		"emoji": "⚡",
		"transitive": true
	},
	"consume": {
		"affinity": [null, null, null, null, 0, null, null, null, 0, null, null, null],
		"emoji": "🍽️",
		"transitive": true
	},
	"extract": {
		"affinity": [null, 0, null, null, null, 0, null, 0, 0, null, null, null],
		"emoji": "⛏️",
		"transitive": true
	},
	"distribute": {
		"affinity": [1, null, null, null, null, null, null, null, 1, null, 1, 0],
		"emoji": "🎁",
		"transitive": true
	},
}

# =============================================================================
# BIT MODIFIERS (24 pairs = 48 words)
# =============================================================================

const BIT_ADVERBS = {
	0: ["chaotically", "methodically"],
	1: ["physically", "spiritually"],
	2: ["humbly", "nobly"],
	3: ["locally", "universally"],
	4: ["swiftly", "patiently"],
	5: ["forcefully", "thoughtfully"],
	6: ["rigidly", "adaptively"],
	7: ["openly", "covertly"],
	8: ["taking", "giving"],
	9: ["simply", "elaborately"],
	10: ["naturally", "deliberately"],
	11: ["broadly", "precisely"],
}

const BIT_ADJECTIVES = {
	0: ["wild", "ordered"],
	1: ["crude", "sacred"],
	2: ["common", "precious"],
	3: ["nearby", "distant"],
	4: ["urgent", "ancient"],
	5: ["heavy", "ethereal"],
	6: ["crystalline", "flowing"],
	7: ["obvious", "hidden"],
	8: ["depleted", "abundant"],
	9: ["plain", "radiant"],
	10: ["natural", "constructed"],
	11: ["scattered", "concentrated"],
}

# =============================================================================
# URGENCY & TIME
# =============================================================================

const URGENCY = {
	"00": {"text": "", "time": -1, "emoji": "🕰️", "desc": "eternal"},
	"01": {"text": "before the cycle ends", "time": 120, "emoji": "⏰", "desc": "scheduled"},
	"10": {"text": "when the signs align", "time": 180, "emoji": "🌙", "desc": "fate"},
	"11": {"text": "immediately", "time": 60, "emoji": "⚡", "desc": "urgent"},
}

# =============================================================================
# QUANTITY WORDS
# =============================================================================

const QUANTITIES = {
	1: {"word": "a single", "emoji": "1️⃣"},
	2: {"word": "a pair of", "emoji": "2️⃣"},
	3: {"word": "several", "emoji": "3️⃣"},
	5: {"word": "many", "emoji": "🖐️"},
	8: {"word": "abundant", "emoji": "📦"},
	13: {"word": "a great harvest of", "emoji": "🌾🌾"},
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_quantity_word(amount: int) -> String:
	"""Get quantity word for given amount"""
	var thresholds = [1, 2, 3, 5, 8, 13]
	for threshold in thresholds:
		if amount <= threshold:
			return QUANTITIES[threshold]["word"]
	return QUANTITIES[13]["word"]

static func get_quantity_emoji(amount: int) -> String:
	"""Get quantity emoji for given amount"""
	var thresholds = [1, 2, 3, 5, 8, 13]
	for threshold in thresholds:
		if amount <= threshold:
			return QUANTITIES[threshold]["emoji"]
	return QUANTITIES[13]["emoji"]
