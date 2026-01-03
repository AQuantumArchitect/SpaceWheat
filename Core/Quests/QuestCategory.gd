class_name QuestCategory
extends Resource

## Categories/types of quests that can be generated
## Each category has different characteristics and purposes

# =============================================================================
# LEARNING QUESTS
# =============================================================================

const TUTORIAL = "tutorial"              # Teach basic quantum mechanics
const CONCEPT_INTRO = "concept_intro"    # Introduce new quantum concept
const SKILL_PRACTICE = "skill_practice"  # Practice specific technique

# =============================================================================
# CHALLENGE QUESTS
# =============================================================================

const BASIC_CHALLENGE = "basic_challenge"    # Simple objectives
const ADVANCED_CHALLENGE = "adv_challenge"   # Complex multi-step objectives
const EXPERT_CHALLENGE = "expert_challenge"  # Extremely difficult

# =============================================================================
# EXPLORATION QUESTS
# =============================================================================

const DISCOVERY = "discovery"            # Find new quantum phenomena
const EXPERIMENT = "experiment"          # Test hypothesis about system
const OBSERVATION = "observation"        # Record specific observations

# =============================================================================
# STORY QUESTS
# =============================================================================

const MAIN_STORY = "main_story"          # Core narrative quests
const SIDE_STORY = "side_story"          # Optional narrative
const CHARACTER_ARC = "character_arc"    # Character-specific quests

# =============================================================================
# REPEATABLE QUESTS
# =============================================================================

const DAILY = "daily"                    # Reset daily
const WEEKLY = "weekly"                  # Reset weekly
const BOUNTY = "bounty"                  # Random rotating quests

# =============================================================================
# FACTION QUESTS
# =============================================================================

const FACTION_INTRO = "faction_intro"    # Introduction to faction
const FACTION_MISSION = "faction_quest"  # Faction-specific objectives
const FACTION_MASTERY = "faction_master" # Master faction techniques

# =============================================================================
# ACHIEVEMENT QUESTS
# =============================================================================

const MILESTONE = "milestone"            # Long-term achievement
const COLLECTION = "collection"          # Collect specific items/states
const MASTERY = "mastery"                # Master specific skill

# =============================================================================
# SPECIAL QUESTS
# =============================================================================

const SEASONAL = "seasonal"              # Limited-time seasonal
const EVENT = "event"                    # Special event quests
const EMERGENCY = "emergency"            # Urgent time-limited

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_all_categories() -> Array:
	"""Get array of all quest category constants"""
	return [
		# Learning
		TUTORIAL, CONCEPT_INTRO, SKILL_PRACTICE,
		# Challenge
		BASIC_CHALLENGE, ADVANCED_CHALLENGE, EXPERT_CHALLENGE,
		# Exploration
		DISCOVERY, EXPERIMENT, OBSERVATION,
		# Story
		MAIN_STORY, SIDE_STORY, CHARACTER_ARC,
		# Repeatable
		DAILY, WEEKLY, BOUNTY,
		# Faction
		FACTION_INTRO, FACTION_MISSION, FACTION_MASTERY,
		# Achievement
		MILESTONE, COLLECTION, MASTERY,
		# Special
		SEASONAL, EVENT, EMERGENCY
	]

static func get_display_name(category: String) -> String:
	"""Get human-readable name for category"""
	var names = {
		TUTORIAL: "Tutorial",
		CONCEPT_INTRO: "Concept Introduction",
		SKILL_PRACTICE: "Skill Practice",
		BASIC_CHALLENGE: "Basic Challenge",
		ADVANCED_CHALLENGE: "Advanced Challenge",
		EXPERT_CHALLENGE: "Expert Challenge",
		DISCOVERY: "Discovery",
		EXPERIMENT: "Experiment",
		OBSERVATION: "Observation",
		MAIN_STORY: "Main Story",
		SIDE_STORY: "Side Story",
		CHARACTER_ARC: "Character Arc",
		DAILY: "Daily Quest",
		WEEKLY: "Weekly Quest",
		BOUNTY: "Bounty",
		FACTION_INTRO: "Faction Introduction",
		FACTION_MISSION: "Faction Mission",
		FACTION_MASTERY: "Faction Mastery",
		MILESTONE: "Milestone",
		COLLECTION: "Collection",
		MASTERY: "Mastery",
		SEASONAL: "Seasonal Quest",
		EVENT: "Event Quest",
		EMERGENCY: "Emergency"
	}
	return names.get(category, category)

static func get_emoji(category: String) -> String:
	"""Get emoji representation for category"""
	var emojis = {
		TUTORIAL: "📚",
		CONCEPT_INTRO: "💡",
		SKILL_PRACTICE: "🎯",
		BASIC_CHALLENGE: "⭐",
		ADVANCED_CHALLENGE: "⭐⭐",
		EXPERT_CHALLENGE: "⭐⭐⭐",
		DISCOVERY: "🔍",
		EXPERIMENT: "🧪",
		OBSERVATION: "👁️",
		MAIN_STORY: "📖",
		SIDE_STORY: "📜",
		CHARACTER_ARC: "👤",
		DAILY: "📅",
		WEEKLY: "📆",
		BOUNTY: "💰",
		FACTION_INTRO: "🏛️",
		FACTION_MISSION: "⚔️",
		FACTION_MASTERY: "👑",
		MILESTONE: "🏆",
		COLLECTION: "📦",
		MASTERY: "🎓",
		SEASONAL: "🎃",
		EVENT: "🎉",
		EMERGENCY: "🚨"
	}
	return emojis.get(category, "❓")

static func get_category_type(category: String) -> String:
	"""Get general type of category"""
	if category in [TUTORIAL, CONCEPT_INTRO, SKILL_PRACTICE]:
		return "Learning"
	elif category in [BASIC_CHALLENGE, ADVANCED_CHALLENGE, EXPERT_CHALLENGE]:
		return "Challenge"
	elif category in [DISCOVERY, EXPERIMENT, OBSERVATION]:
		return "Exploration"
	elif category in [MAIN_STORY, SIDE_STORY, CHARACTER_ARC]:
		return "Story"
	elif category in [DAILY, WEEKLY, BOUNTY]:
		return "Repeatable"
	elif category in [FACTION_INTRO, FACTION_MISSION, FACTION_MASTERY]:
		return "Faction"
	elif category in [MILESTONE, COLLECTION, MASTERY]:
		return "Achievement"
	elif category in [SEASONAL, EVENT, EMERGENCY]:
		return "Special"
	else:
		return "Unknown"

static func is_repeatable(category: String) -> bool:
	"""Check if quest category is repeatable"""
	return category in [DAILY, WEEKLY, BOUNTY, FACTION_MISSION]

static func is_time_limited(category: String) -> bool:
	"""Check if quest category is time-limited"""
	return category in [DAILY, WEEKLY, SEASONAL, EVENT, EMERGENCY]

static func is_tutorial(category: String) -> bool:
	"""Check if quest category is educational"""
	return category in [TUTORIAL, CONCEPT_INTRO, SKILL_PRACTICE]

static func is_faction_quest(category: String) -> bool:
	"""Check if quest is faction-specific"""
	return category in [FACTION_INTRO, FACTION_MISSION, FACTION_MASTERY]

static func get_difficulty_range(category: String) -> Dictionary:
	"""Get typical difficulty range for category"""
	var ranges = {
		TUTORIAL: {"min": 0.0, "max": 0.2},
		CONCEPT_INTRO: {"min": 0.1, "max": 0.3},
		SKILL_PRACTICE: {"min": 0.2, "max": 0.5},
		BASIC_CHALLENGE: {"min": 0.3, "max": 0.5},
		ADVANCED_CHALLENGE: {"min": 0.5, "max": 0.8},
		EXPERT_CHALLENGE: {"min": 0.8, "max": 1.0},
		DISCOVERY: {"min": 0.2, "max": 0.6},
		EXPERIMENT: {"min": 0.3, "max": 0.7},
		OBSERVATION: {"min": 0.1, "max": 0.4},
		MAIN_STORY: {"min": 0.3, "max": 0.7},
		SIDE_STORY: {"min": 0.2, "max": 0.6},
		CHARACTER_ARC: {"min": 0.4, "max": 0.8},
		DAILY: {"min": 0.2, "max": 0.5},
		WEEKLY: {"min": 0.4, "max": 0.7},
		BOUNTY: {"min": 0.3, "max": 0.9},
		FACTION_INTRO: {"min": 0.2, "max": 0.4},
		FACTION_MISSION: {"min": 0.4, "max": 0.8},
		FACTION_MASTERY: {"min": 0.7, "max": 1.0},
		MILESTONE: {"min": 0.5, "max": 1.0},
		COLLECTION: {"min": 0.3, "max": 0.7},
		MASTERY: {"min": 0.6, "max": 1.0},
		SEASONAL: {"min": 0.3, "max": 0.7},
		EVENT: {"min": 0.4, "max": 0.8},
		EMERGENCY: {"min": 0.5, "max": 0.9}
	}
	return ranges.get(category, {"min": 0.0, "max": 1.0})

static func get_reward_multiplier(category: String) -> float:
	"""Get reward multiplier for category"""
	var multipliers = {
		TUTORIAL: 0.5,
		CONCEPT_INTRO: 0.7,
		SKILL_PRACTICE: 0.8,
		BASIC_CHALLENGE: 1.0,
		ADVANCED_CHALLENGE: 1.5,
		EXPERT_CHALLENGE: 2.5,
		DISCOVERY: 1.2,
		EXPERIMENT: 1.3,
		OBSERVATION: 0.9,
		MAIN_STORY: 1.5,
		SIDE_STORY: 1.2,
		CHARACTER_ARC: 1.8,
		DAILY: 0.8,
		WEEKLY: 1.5,
		BOUNTY: 1.3,
		FACTION_INTRO: 1.0,
		FACTION_MISSION: 1.4,
		FACTION_MASTERY: 2.0,
		MILESTONE: 3.0,
		COLLECTION: 1.6,
		MASTERY: 2.5,
		SEASONAL: 1.8,
		EVENT: 2.0,
		EMERGENCY: 2.2
	}
	return multipliers.get(category, 1.0)

static func is_valid(category: String) -> bool:
	"""Check if category is valid"""
	return category in get_all_categories()
