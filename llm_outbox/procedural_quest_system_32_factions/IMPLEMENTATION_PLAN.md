# SpaceWheat Procedural Quest System - Implementation Plan
## From Python Proof-of-Concept to GDScript Production

---

## Executive Summary

**Source Material**:
- `quest_demo.py`: Basic system (~159 atoms, 24M quests)
- `quest_vocabulary_unlimited.py`: Expanded system (~400 atoms, 2T+ quests)

**Target**: GDScript implementation in SpaceWheat with incremental rollout

**Philosophy**: Ship **minimal viable** first (quest_demo.py), then expand to **unlimited** (quest_vocabulary_unlimited.py) based on playtesting

---

## Phase 1: Core Data Structures (Week 1)

### 1.1 Create Quest Vocabulary Resource
**File**: `Core/Quests/QuestVocabulary.gd`

```gdscript
class_name QuestVocabulary
extends Resource

## Quest vocabulary atoms - verbs, modifiers, templates

# Verbs with bit affinity scoring
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
    # ... 18 verbs from quest_demo.py
}

# Bit modifiers
const BIT_ADVERBS = {
    0: ["chaotically", "methodically"],
    1: ["physically", "spiritually"],
    # ... 12 pairs
}

const BIT_ADJECTIVES = {
    0: ["wild", "ordered"],
    1: ["crude", "sacred"],
    # ... 12 pairs
}

# Urgency templates
const URGENCY = {
    "00": {"text": "", "time": -1, "emoji": "🕰️"},
    "01": {"text": "before the cycle ends", "time": 120, "emoji": "⏰"},
    "10": {"text": "when the signs align", "time": 180, "emoji": "🌙"},
    "11": {"text": "immediately", "time": 60, "emoji": "⚡"},
}

# Quantity words
const QUANTITIES = {
    1: "a single",
    2: "a pair of",
    3: "several",
    5: "many",
    8: "abundant",
    13: "a great harvest of",
}
```

**Why**: Centralized vocabulary that can be easily expanded without touching generation logic.

---

### 1.2 Create Faction Voice Resource
**File**: `Core/Quests/FactionVoices.gd`

```gdscript
class_name FactionVoices
extends Resource

## Faction-specific voice templates and personality

const FACTION_VOICE = {
    "imperial": {
        "prefix": "By imperial decree:",
        "suffix": "for the Throne.",
        "failure": "The Throne is displeased.",
        "tone": "absolute"
    },
    "guild": {
        "prefix": "The Guild requires:",
        "suffix": "as per contract.",
        "failure": "Contract violated.",
        "tone": "collective"
    },
    # ... 10 voice categories from quest_demo.py
}

const FACTION_TO_VOICE = {
    "Carrion Throne": "imperial",
    "House of Thorns": "imperial",
    "Granary Guilds": "imperial",
    # ... all 32 factions
}

static func get_voice(faction_name: String) -> Dictionary:
    var voice_key = FACTION_TO_VOICE.get(faction_name, "guild")
    return FACTION_VOICE[voice_key]
```

**Why**: Factions need unique personalities, but can share voice categories (10 voices for 32 factions is manageable).

---

### 1.3 Create Biome Location Data
**File**: `Core/Quests/BiomeLocations.gd`

```gdscript
class_name BiomeLocations
extends Resource

## Location names for each biome

const LOCATIONS = {
    "BioticFlux": [
        "the wheat fields",
        "the mushroom groves",
        "the sun altar",
        "the moon shrine",
        "the detritus pits"
    ],
    "Kitchen": [
        "the eternal flame",
        "the ice stores",
        "the bread ovens",
        "the fermentation vats",
        "the grinding stones"
    ],
    # ... Forest, Market, GranaryGuilds
}

static func get_random_location(biome_name: String) -> String:
    var locs = LOCATIONS.get(biome_name, LOCATIONS["BioticFlux"])
    return locs[randi() % locs.size()]
```

**Why**: Biome locations provide flavor and tie quests to specific game spaces.

---

## Phase 2: Quest Generation Engine (Week 2)

### 2.1 Create Quest Generator
**File**: `Core/Quests/QuestGenerator.gd`

```gdscript
class_name QuestGenerator
extends Node

## Procedural quest generation from faction bits + biome context

# Core generation function
static func generate_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
    """Generate quest from faction data and context

    Args:
        faction: {name: String, bits: Array[int], emoji: String}
        biome_name: String (e.g., "BioticFlux")
        resources: Array[String] (available emojis in biome)

    Returns:
        Dictionary with quest data
    """
    var bits = faction["bits"]
    var faction_name = faction["name"]

    # Select resource from biome's available resources
    var resource = resources[randi() % resources.size()]
    var quantity = _get_quantity_from_bits(bits)

    # Select verb based on bit affinity
    var verb = _select_verb_for_bits(bits)

    # Get modifiers
    var adverb = _get_adverb(bits)
    var adjective = _get_adjective(bits)
    var urgency = _get_urgency(bits)
    var qty_word = _get_quantity_word(quantity)
    var location = BiomeLocations.get_random_location(biome_name)

    # Get faction voice
    var voice = FactionVoices.get_voice(faction_name)

    # Build quest text
    var body = _build_quest_body(verb, qty_word, adjective, resource, location, urgency)

    return {
        "faction": faction_name,
        "faction_emoji": faction["emoji"],
        "prefix": voice["prefix"],
        "body": body,
        "suffix": voice["suffix"],
        "full_text": "%s %s %s" % [voice["prefix"], body, voice["suffix"]],
        "failure_text": voice["failure"],
        "time_limit": urgency["time"],
        "resource": resource,
        "quantity": quantity,
        "location": location,
        "verb": verb,
        "biome": biome_name,
    }

# Helper: Select verb based on bit affinity scoring
static func _select_verb_for_bits(bits: Array) -> String:
    var best_verb = ""
    var best_score = -1.0

    for verb_name in QuestVocabulary.VERBS.keys():
        var verb_data = QuestVocabulary.VERBS[verb_name]
        var affinity = verb_data["affinity"]

        # Score = count of matching bits
        var score = 0
        for i in range(12):
            if affinity[i] != null and affinity[i] == bits[i]:
                score += 1

        # Add randomness (0.0-0.5)
        score += randf() * 0.5

        if score > best_score:
            best_score = score
            best_verb = verb_name

    return best_verb

# Helper: Get adverb based on bits
static func _get_adverb(bits: Array) -> String:
    if randf() < 0.4:  # 40% chance to include adverb
        var idx = randi() % 12
        return QuestVocabulary.BIT_ADVERBS[idx][bits[idx]]
    return ""

# Helper: Get adjective based on bits
static func _get_adjective(bits: Array) -> String:
    var idx = randi() % 12
    return QuestVocabulary.BIT_ADJECTIVES[idx][bits[idx]]

# Helper: Get urgency from bits 0 and 4
static func _get_urgency(bits: Array) -> Dictionary:
    var key = "%d%d" % [bits[0], bits[4]]
    return QuestVocabulary.URGENCY[key]

# Helper: Get quantity word
static func _get_quantity_word(amount: int) -> String:
    for threshold in [1, 2, 3, 5, 8, 13]:
        if amount <= threshold:
            return QuestVocabulary.QUANTITIES[threshold]
    return QuestVocabulary.QUANTITIES[13]

# Helper: Determine quantity from bits (common=low, elite=high)
static func _get_quantity_from_bits(bits: Array) -> int:
    var is_common = bits[2] == 0  # Bit 3: Common vs Elite
    if is_common:
        return randi() % 5 + 1  # 1-5
    else:
        return randi() % 8 + 5  # 5-13

# Helper: Build quest body text
static func _build_quest_body(verb: String, qty: String, adj: String,
                               resource: String, location: String, urgency: Dictionary) -> String:
    var body = "%s %s %s %s at %s" % [verb.capitalize(), qty, adj, resource, location]
    if urgency["text"] != "":
        body += " " + urgency["text"]
    return body
```

**Why**: Core generation logic separated from data. Easy to test, easy to expand.

---

### 2.2 Create Quest Manager
**File**: `Core/Quests/QuestManager.gd`

```gdscript
class_name QuestManager
extends Node

## Manages active quests, completion, failure

signal quest_offered(quest: Dictionary)
signal quest_accepted(quest: Dictionary)
signal quest_completed(quest: Dictionary)
signal quest_failed(quest: Dictionary)

# Active quests
var active_quests: Array[Dictionary] = []

# Quest history
var completed_quests: Array[Dictionary] = []
var failed_quests: Array[Dictionary] = []

# References
var economy: Node  # FarmEconomy
var farm_grid: Node  # FarmGrid
var faction_manager: Node  # FactionManager

func _ready():
    print("🎯 QuestManager initialized")

# Generate and offer a quest
func generate_and_offer_quest(faction: Dictionary, biome_name: String) -> Dictionary:
    # Get available resources from biome
    var biome = _get_biome_node(biome_name)
    if not biome:
        return {}

    var resources = biome.get_producible_emojis()
    if resources.is_empty():
        return {}

    # Generate quest
    var quest = QuestGenerator.generate_quest(faction, biome_name, resources)

    # Add metadata
    quest["id"] = _generate_quest_id()
    quest["offered_at"] = Time.get_unix_time_from_system()
    quest["status"] = "offered"

    # Emit signal
    quest_offered.emit(quest)

    print("📜 Quest offered: %s" % quest["full_text"])

    return quest

# Accept a quest
func accept_quest(quest: Dictionary) -> void:
    quest["status"] = "active"
    quest["accepted_at"] = Time.get_unix_time_from_system()
    active_quests.append(quest)
    quest_accepted.emit(quest)

    # Start timer if quest has time limit
    if quest["time_limit"] > 0:
        _start_quest_timer(quest)

# Check quest completion
func check_quest_completion(quest_id: String) -> bool:
    var quest = _find_active_quest(quest_id)
    if not quest:
        return false

    # Check if player has required resources
    var has_resources = economy.can_afford_resource(
        quest["resource"],
        quest["quantity"] * economy.QUANTUM_TO_CREDITS
    )

    if has_resources:
        complete_quest(quest_id)
        return true

    return false

# Complete quest (success)
func complete_quest(quest_id: String) -> void:
    var quest = _find_active_quest(quest_id)
    if not quest:
        return

    # Remove resources
    economy.remove_resource(
        quest["resource"],
        quest["quantity"] * economy.QUANTUM_TO_CREDITS,
        "quest_completion"
    )

    # Give rewards (TODO: implement reward system)
    _give_quest_rewards(quest)

    # Update quest status
    quest["status"] = "completed"
    quest["completed_at"] = Time.get_unix_time_from_system()

    # Move to completed list
    active_quests.erase(quest)
    completed_quests.append(quest)

    quest_completed.emit(quest)
    print("✅ Quest completed: %s" % quest["full_text"])

# Fail quest
func fail_quest(quest_id: String, reason: String = "") -> void:
    var quest = _find_active_quest(quest_id)
    if not quest:
        return

    quest["status"] = "failed"
    quest["failed_at"] = Time.get_unix_time_from_system()
    quest["failure_reason"] = reason

    # Move to failed list
    active_quests.erase(quest)
    failed_quests.append(quest)

    quest_failed.emit(quest)
    print("❌ Quest failed: %s - %s" % [quest["full_text"], quest["failure_text"]])

# Helpers
func _generate_quest_id() -> String:
    return "quest_%d" % Time.get_unix_time_from_system()

func _find_active_quest(quest_id: String) -> Dictionary:
    for q in active_quests:
        if q["id"] == quest_id:
            return q
    return {}

func _get_biome_node(biome_name: String) -> Node:
    # Get biome from game tree
    # TODO: implement proper biome lookup
    return null

func _start_quest_timer(quest: Dictionary) -> void:
    # Create timer for quest time limit
    var timer = Timer.new()
    timer.wait_time = quest["time_limit"]
    timer.one_shot = true
    timer.timeout.connect(func(): fail_quest(quest["id"], "time_limit_exceeded"))
    add_child(timer)
    timer.start()

func _give_quest_rewards(quest: Dictionary) -> void:
    # TODO: implement reward system
    # For now, give 10x the resources back as reward
    var reward_amount = quest["quantity"] * 10
    economy.add_resource("💰", reward_amount, "quest_reward")
```

**Why**: Manages quest lifecycle, integrates with economy and biomes.

---

## Phase 3: Faction Integration (Week 3)

### 3.1 Create Faction Database
**File**: `Core/Quests/FactionDatabase.gd`

```gdscript
class_name FactionDatabase
extends Resource

## 32-faction database with bit patterns

const FACTIONS = {
    # Imperial Powers
    "Carrion Throne": {
        "bits": [1,1,0,1,1,1,0,0,1,1,0,1],
        "emoji": "👑💀🏛️",
        "category": "imperial"
    },
    "House of Thorns": {
        "bits": [1,1,1,1,1,1,0,1,0,1,0,1],
        "emoji": "🌹🗡️👑",
        "category": "imperial"
    },
    "Granary Guilds": {
        "bits": [1,1,0,1,1,1,0,1,1,1,0,1],
        "emoji": "🌾💰⚖️",
        "category": "imperial"
    },
    "Station Lords": {
        "bits": [1,1,0,1,1,1,0,0,0,1,0,1],
        "emoji": "🏢👑🌌",
        "category": "imperial"
    },

    # Working Guilds
    "Obsidian Will": {
        "bits": [1,1,0,1,1,1,0,0,0,1,0,1],
        "emoji": "🏭⚙️🔧",
        "category": "guild"
    },
    "Millwright's Union": {
        "bits": [1,1,0,1,0,0,0,0,0,0,0,1],
        "emoji": "🌾⚙️🏭",
        "category": "guild"
    },
    # ... all 32 factions
}

static func get_faction(name: String) -> Dictionary:
    var faction = FACTIONS.get(name, {})
    if faction.is_empty():
        return {}
    faction["name"] = name
    return faction

static func get_factions_by_category(category: String) -> Array:
    var result = []
    for fname in FACTIONS.keys():
        if FACTIONS[fname]["category"] == category:
            var f = FACTIONS[fname].duplicate()
            f["name"] = fname
            result.append(f)
    return result

static func get_all_factions() -> Array:
    var result = []
    for fname in FACTIONS.keys():
        var f = FACTIONS[fname].duplicate()
        f["name"] = fname
        result.append(f)
    return result
```

**Why**: Central source of truth for all 32 factions with their bit patterns.

---

### 3.2 Update FactionManager
**File**: `Core/GameMechanics/FactionManager.gd` (modify existing)

Add quest integration:

```gdscript
# Add to existing FactionManager

var quest_manager: QuestManager

func _ready():
    # ... existing code ...

    # Initialize quest manager
    quest_manager = QuestManager.new()
    add_child(quest_manager)
    quest_manager.economy = economy
    quest_manager.farm_grid = farm_grid

# New method: Generate faction quest
func offer_faction_quest(faction_name: String, biome_name: String) -> Dictionary:
    var faction = FactionDatabase.get_faction(faction_name)
    if faction.is_empty():
        return {}

    return quest_manager.generate_and_offer_quest(faction, biome_name)

# New method: Check if faction can offer quest in biome
func can_faction_quest_in_biome(faction_name: String, biome_name: String) -> bool:
    # Check if faction's emoji theme matches biome resources
    # TODO: implement emoji matching logic
    return true
```

**Why**: Ties quest system into existing faction reputation and contract system.

---

## Phase 4: UI Integration (Week 4)

### 4.1 Create Quest Panel UI
**File**: `UI/Panels/QuestPanel.gd`

```gdscript
class_name QuestPanel
extends PanelContainer

## UI panel showing active quests

@onready var quest_list: VBoxContainer = $MarginContainer/VBoxContainer/QuestList
@onready var accept_button: Button = $MarginContainer/VBoxContainer/AcceptButton

var quest_manager: QuestManager
var current_offered_quest: Dictionary = {}

func _ready():
    accept_button.pressed.connect(_on_accept_pressed)
    accept_button.disabled = true

func connect_to_quest_manager(qm: QuestManager) -> void:
    quest_manager = qm
    quest_manager.quest_offered.connect(_on_quest_offered)
    quest_manager.quest_accepted.connect(_on_quest_accepted)
    quest_manager.quest_completed.connect(_on_quest_completed)
    quest_manager.quest_failed.connect(_on_quest_failed)

func _on_quest_offered(quest: Dictionary) -> void:
    current_offered_quest = quest
    accept_button.disabled = false
    _display_quest_offer(quest)

func _on_quest_accepted(quest: Dictionary) -> void:
    current_offered_quest = {}
    accept_button.disabled = true
    _add_active_quest_display(quest)

func _on_quest_completed(quest: Dictionary) -> void:
    _remove_quest_display(quest["id"])
    _show_completion_feedback(quest)

func _on_quest_failed(quest: Dictionary) -> void:
    _remove_quest_display(quest["id"])
    _show_failure_feedback(quest)

func _on_accept_pressed() -> void:
    if not current_offered_quest.is_empty():
        quest_manager.accept_quest(current_offered_quest)

func _display_quest_offer(quest: Dictionary) -> void:
    # Show quest offer in panel
    var offer_label = Label.new()
    offer_label.text = quest["full_text"]
    offer_label.add_theme_font_size_override("font_size", 14)
    quest_list.add_child(offer_label)

func _add_active_quest_display(quest: Dictionary) -> void:
    var quest_item = _create_quest_item(quest)
    quest_list.add_child(quest_item)

func _remove_quest_display(quest_id: String) -> void:
    for child in quest_list.get_children():
        if child.has_meta("quest_id") and child.get_meta("quest_id") == quest_id:
            child.queue_free()

func _create_quest_item(quest: Dictionary) -> HBoxContainer:
    var item = HBoxContainer.new()
    item.set_meta("quest_id", quest["id"])

    # Faction emoji
    var emoji_label = Label.new()
    emoji_label.text = quest["faction_emoji"]
    emoji_label.add_theme_font_size_override("font_size", 20)
    item.add_child(emoji_label)

    # Quest text
    var text_label = Label.new()
    text_label.text = quest["body"]
    text_label.add_theme_font_size_override("font_size", 12)
    text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item.add_child(text_label)

    # Time remaining
    if quest["time_limit"] > 0:
        var time_label = Label.new()
        time_label.text = "⏱️ %ds" % quest["time_limit"]
        time_label.add_theme_font_size_override("font_size", 10)
        item.add_child(time_label)

    return item

func _show_completion_feedback(quest: Dictionary) -> void:
    print("✅ %s" % quest["full_text"])

func _show_failure_feedback(quest: Dictionary) -> void:
    print("❌ %s" % quest["failure_text"])
```

**Why**: Visual representation of quests for player.

---

### 4.2 Add Quest Panel to FarmView
**File**: `Core/FarmView.gd` (modify existing)

```gdscript
# Add to existing FarmView._ready()

# Create quest panel
var quest_panel = preload("res://UI/Panels/QuestPanel.tscn").instantiate()
quest_panel.position = Vector2(20, 400)  # Position below resource panel
add_child(quest_panel)
quest_panel.connect_to_quest_manager(faction_manager.quest_manager)

# Test: Offer a quest
faction_manager.offer_faction_quest("Millwright's Union", "BioticFlux")
```

**Why**: Integrates quests into main game view.

---

## Phase 5: Testing & Balancing (Week 5)

### 5.1 Create Quest Test Suite
**File**: `Tests/test_quest_system.gd`

```gdscript
extends SceneTree

func _init():
    print("🧪 QUEST SYSTEM TESTS")

    # Test 1: Verb selection
    print("\n=== Test 1: Verb Selection ===")
    var bits1 = [1,1,0,1,0,0,0,0,0,0,0,1]  # Millwright's Union
    var verb1 = QuestGenerator._select_verb_for_bits(bits1)
    print("Millwright bits → verb: %s" % verb1)
    assert(verb1 in ["harvest", "build", "repair"], "Expected physical verb")

    # Test 2: Urgency mapping
    print("\n=== Test 2: Urgency Mapping ===")
    var urgency1 = QuestGenerator._get_urgency([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    print("Bits [0,0] → %s" % urgency1["text"])
    assert(urgency1["time"] == -1, "Expected eternal")

    var urgency2 = QuestGenerator._get_urgency([1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0])
    print("Bits [1,1] → %s" % urgency2["text"])
    assert(urgency2["time"] == 60, "Expected immediate")

    # Test 3: Full quest generation
    print("\n=== Test 3: Full Quest Generation ===")
    var faction = FactionDatabase.get_faction("Millwright's Union")
    var resources = ["🌾", "🍄", "💧"]
    var quest = QuestGenerator.generate_quest(faction, "BioticFlux", resources)

    print("Generated quest:")
    print("  %s" % quest["full_text"])
    print("  Time limit: %d" % quest["time_limit"])
    print("  Resource: %s × %d" % [quest["resource"], quest["quantity"]])

    assert(quest["faction"] == "Millwright's Union", "Wrong faction")
    assert(quest["resource"] in resources, "Resource not from biome")

    # Test 4: Quest manager lifecycle
    print("\n=== Test 4: Quest Manager Lifecycle ===")
    var qm = QuestManager.new()
    var economy = preload("res://Core/GameMechanics/FarmEconomy.gd").new()
    qm.economy = economy

    # Generate quest
    var faction2 = FactionDatabase.get_faction("Yeast Prophets")
    var quest2 = QuestGenerator.generate_quest(faction2, "Kitchen", ["🍞", "🔥"])
    quest2["id"] = "test_quest_1"

    # Accept quest
    qm.accept_quest(quest2)
    assert(qm.active_quests.size() == 1, "Quest not added to active")

    # Add resources to economy
    economy.add_resource(quest2["resource"], quest2["quantity"] * 10 + 100, "test")

    # Check completion
    var completed = qm.check_quest_completion("test_quest_1")
    assert(completed, "Quest should have completed")
    assert(qm.completed_quests.size() == 1, "Quest not in completed list")

    print("\n✅ All tests passed!")
    quit()
```

**Why**: Ensures quest generation works correctly before shipping.

---

### 5.2 Playtest Protocol

**Manual testing checklist**:
- [ ] Generate 10 quests from different factions
- [ ] Verify verb affinity scoring (physical factions → physical verbs)
- [ ] Test urgency (instant vs eternal vs scheduled)
- [ ] Test quantity scaling (common vs elite)
- [ ] Test biome location integration
- [ ] Accept and complete a quest
- [ ] Fail a quest (time limit)
- [ ] Check resource deduction on completion
- [ ] Verify faction voice personality

**Balancing metrics**:
- Quest completion rate (target: 70-80%)
- Average quest duration (target: 60-180 seconds)
- Resource cost vs reward ratio (target: 1:10)

---

## Phase 6: Expansion to Unlimited (Week 6+)

### 6.1 Add Compound Verbs
Based on `quest_vocabulary_unlimited.py`:

```gdscript
# Add to QuestGenerator.gd

const VERB_CONNECTORS = {
    "sequential": ["then", "and then", "before you", "after which"],
    "conditional": ["only if you first", "but only after", "provided you"],
    "alternative": ["or else", "or instead", "failing that"],
    "simultaneous": ["while also", "as you", "even as"],
}

static func generate_compound_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
    var bits = faction["bits"]

    # Get two verbs
    var verb1 = _select_verb_for_bits(bits)
    var modified_bits = bits.duplicate()
    modified_bits[randi() % 12] = 1 - modified_bits[randi() % 12]
    var verb2 = _select_verb_for_bits(modified_bits)

    # Select connector based on bits
    var connector_type = "sequential"
    if bits[6] == 1:  # fluid
        connector_type = "alternative"
    elif bits[7] == 1:  # subtle
        connector_type = "conditional"

    var connector = VERB_CONNECTORS[connector_type][randi() % VERB_CONNECTORS[connector_type].size()]

    # Build compound body
    var resource1 = resources[randi() % resources.size()]
    var resource2 = resources[randi() % resources.size()]
    var body = "%s %s %s %s %s" % [verb1.capitalize(), resource1, connector, verb2, resource2]

    # ... rest of quest building
```

**Rollout**: Enable compound quests after Phase 5 testing completes.

---

### 6.2 Add Narrative Arcs
Based on `quest_vocabulary_unlimited.py`:

```gdscript
# Add to QuestVocabulary.gd

const NARRATIVE_ARCS = {
    "origin": {
        "intro": "This is how it begins:",
        "frame": "{verb} {quantity} {adj} {resource} {location}",
        "outro": "And so the first step is taken."
    },
    "crisis": {
        "intro": "Everything hangs in the balance:",
        "frame": "{verb} {resource} {urgency} {stakes}",
        "outro": "There will be no second chances."
    },
    # ... 12 arc types
}
```

**Rollout**: Enable narrative arcs for elite quests (bit 2 = 1) after compound quests are tested.

---

### 6.3 Add Expanded Vocabulary

Incrementally expand from 159 atoms → 400 atoms:

1. **Week 6**: Add 18 more verbs (18 → 36)
2. **Week 7**: Add intensifiers, temporal modifiers
3. **Week 8**: Add spatial modifiers, relationships
4. **Week 9**: Add stakes, consequences, secret objectives
5. **Week 10**: Add mythological references, Bloch sphere refs

**Why**: Incremental expansion allows playtesting each addition.

---

## Phase 7: Polish & Optimization (Week 11-12)

### 7.1 Quest Filtering
Prevent quest spam:

```gdscript
# Add to QuestManager.gd

const MAX_ACTIVE_QUESTS = 5
const QUEST_COOLDOWN_PER_FACTION = 300.0  # 5 minutes

var faction_cooldowns: Dictionary = {}  # faction_name → last_quest_time

func can_generate_quest(faction_name: String) -> bool:
    # Check active quest limit
    if active_quests.size() >= MAX_ACTIVE_QUESTS:
        return false

    # Check faction cooldown
    var last_time = faction_cooldowns.get(faction_name, 0.0)
    var current_time = Time.get_unix_time_from_system()
    if current_time - last_time < QUEST_COOLDOWN_PER_FACTION:
        return false

    return true
```

---

### 7.2 Emoji-Only Quest Mode
For minimal English:

```gdscript
# Add to QuestGenerator.gd

static func generate_emoji_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
    var bits = faction["bits"]
    var resource = resources[randi() % resources.size()]
    var quantity = _get_quantity_from_bits(bits)
    var urgency = _get_urgency(bits)
    var verb = _select_verb_for_bits(bits)
    var verb_emoji = QuestVocabulary.VERBS[verb]["emoji"]

    var qty_display = ""
    if quantity <= 3:
        qty_display = resource.repeat(quantity)
    else:
        qty_display = "%s×%d" % [resource, quantity]

    var display = "%s: %s %s → 🏛️ %s" % [
        faction["emoji"],
        verb_emoji,
        qty_display,
        urgency["emoji"]
    ]

    return {
        "faction": faction["name"],
        "display": display,
        "resource": resource,
        "quantity": quantity,
        "time_limit": urgency["time"],
        "is_emoji_only": true
    }
```

---

### 7.3 Performance Optimization

**Quest generation caching**:
```gdscript
# Cache generated quest templates
var quest_cache: Dictionary = {}  # faction_name+biome → Array[quest_template]

func get_cached_quest(faction_name: String, biome_name: String) -> Dictionary:
    var key = "%s_%s" % [faction_name, biome_name]
    if not quest_cache.has(key) or quest_cache[key].is_empty():
        # Generate 10 quests and cache
        quest_cache[key] = _generate_quest_batch(faction_name, biome_name, 10)

    # Pop one from cache
    return quest_cache[key].pop_back()
```

**Why**: Pre-generate quests to avoid stuttering during gameplay.

---

## File Structure Summary

```
Core/
  Quests/
    QuestVocabulary.gd          # Vocabulary atoms (verbs, modifiers)
    FactionVoices.gd            # Faction voice templates
    BiomeLocations.gd           # Biome location names
    FactionDatabase.gd          # 32-faction bit patterns
    QuestGenerator.gd           # Core generation engine
    QuestManager.gd             # Quest lifecycle management

  GameMechanics/
    FactionManager.gd           # Modified: quest integration

UI/
  Panels/
    QuestPanel.gd               # Quest display UI
    QuestPanel.tscn             # Quest panel scene

Tests/
  test_quest_system.gd          # Quest system tests
```

---

## Rollout Timeline

| Week | Phase | Deliverable |
|------|-------|-------------|
| 1 | Core Data | QuestVocabulary, FactionVoices, BiomeLocations |
| 2 | Generation | QuestGenerator, QuestManager (simple quests) |
| 3 | Integration | FactionDatabase, FactionManager integration |
| 4 | UI | QuestPanel, FarmView integration |
| 5 | Testing | Test suite, manual playtesting, balancing |
| 6 | Expansion | Compound verbs, narrative arcs (basic) |
| 7-10 | Unlimited | Expand vocabulary 159→400 atoms incrementally |
| 11-12 | Polish | Filtering, emoji-only mode, caching, optimization |

---

## Success Metrics

**Minimum Viable (Week 5)**:
- ✅ 18 verbs working
- ✅ All 32 factions generate unique quests
- ✅ Quest lifecycle (offer → accept → complete/fail) works
- ✅ UI shows quests clearly
- ✅ 70%+ quest completion rate in playtesting

**Unlimited Target (Week 12)**:
- ✅ 36+ verbs working
- ✅ Compound quests functional
- ✅ 3+ narrative arc types implemented
- ✅ Emoji-only mode functional
- ✅ 2T+ unique quest combinations possible
- ✅ Zero LLM calls required

---

## Risk Mitigation

**Risk 1**: Quest text feels repetitive
- **Mitigation**: Expand vocabulary incrementally, add randomness to modifier selection

**Risk 2**: Quests don't match faction personality
- **Mitigation**: Extensive bit affinity tuning, faction voice testing

**Risk 3**: Performance issues with quest generation
- **Mitigation**: Pre-generate and cache, batch generation

**Risk 4**: Players don't understand bit-driven quest structure
- **Mitigation**: Hide bit complexity, surface only results (emoji, text, time limit)

---

## Notes

- **Start minimal**: Ship quest_demo.py equivalent first (159 atoms, 24M quests)
- **Expand iteratively**: Add quest_vocabulary_unlimited.py features based on playtesting
- **Emoji-first**: Emoji-only mode is the TRUE minimal viable (zero localization)
- **No LLMs**: This is pure procedural generation - runs locally, no API calls
- **Billions of quests**: With full expansion, 2 trillion+ unique combinations

This is the path from proof-of-concept to production.
