# Quest Vocabulary Rewards - Implementation Plan

## Overview

When players complete faction quests, they learn new vocabulary from that faction's signature list. This creates a **discovery loop**:

```
Complete Quest → Learn Vocabulary → Unlock New Factions → Receive New Quests
```

This also sets up the future **Icon planting system**: learned emojis will eventually become Icons that can be planted in biomes to discover quantum interactions.

---

## Core Concept

### The Learning Loop

```
Player accepts quest from Millwright's Union (⚙🏭🔩)
  ↓
Quest: "Deliver 8 🌾"
  ↓
Player completes quest
  ↓
Reward: 💰 gold + 📖 Learn "🔩" (bolt)
  ↓
Player's vocabulary: [🌾, 🍄] → [🌾, 🍄, 🔩]
  ↓
New factions unlocked! (Those with 🔩 in vocabulary)
  ↓
Quest variety expands (🔩 can now appear in quests)
```

### Vocabulary Teaching Strategy

**From which pool?**
- Teach emojis from faction's **signature vocabulary** (NOT axial)
- Signature is the faction's unique thematic cluster
- This makes quests feel thematic: "Millwrights teach you about machinery"

**Which emoji to teach?**
- Teach emojis the player **doesn't already know**
- Prioritize emojis with **high probability** in current biome bath
- This creates connection: "You've shaped your biome to resonate with this vocabulary"

**How many to teach?**
- Start simple: **1 emoji per quest completion**
- Could scale with quest difficulty/alignment in the future

---

## Vocabulary Selection Algorithm

### Smart Selection (Quantum-Informed)

```gdscript
func select_vocabulary_reward(faction: Dictionary, bath, player_vocab: Array) -> String:
    """Choose which emoji from faction signature to teach

    Strategy:
    1. Get faction signature vocabulary
    2. Filter to emojis player doesn't know
    3. Get bath probabilities for unknown emojis
    4. Sample weighted by probability (quantum-informed!)
    5. Fallback to random if no probabilities
    """

    var signature = faction.get("signature", [])

    # Filter to unknown vocabulary
    var unknown = []
    for emoji in signature:
        if emoji not in player_vocab:
            unknown.append(emoji)

    # Already know everything?
    if unknown.is_empty():
        return ""  # No vocabulary to teach

    # Get bath probabilities for unknown emojis
    if bath and bath._density_matrix:
        var emoji_list = bath._density_matrix.emoji_list
        var probs = []
        var indices = []

        for i in range(unknown.size()):
            var emoji = unknown[i]
            var idx = emoji_list.find(emoji)

            if idx >= 0:
                var prob = bath._density_matrix.get_probability_by_index(idx)
                probs.append(prob)
                indices.append(i)

        # Sample weighted by probability
        if probs.size() > 0:
            var total = 0.0
            for p in probs:
                total += p

            if total > 0.001:
                # Renormalize and sample
                var roll = randf() * total
                var cumulative = 0.0
                for i in range(probs.size()):
                    cumulative += probs[i]
                    if roll <= cumulative:
                        return unknown[indices[i]]

    # Fallback: random from unknown
    return unknown[randi() % unknown.size()]
```

**Why this is good**:
- Teaches vocabulary that **resonates with current biome state**
- Player shaped the bath through farming → bath shaped reward vocabulary
- Creates feedback loop: "Your wheat-heavy farm attracted Millwrights, and they taught you about gears because gears resonate with wheat"

---

## Implementation Steps

### Phase 1: Quest Reward Structure

**File**: `Core/Quests/QuestTypes.gd` (or create `QuestRewards.gd`)

Add reward data structure:

```gdscript
class QuestReward:
    """Rewards for completing a quest"""
    var gold: int = 0
    var learned_vocabulary: Array[String] = []  # Emojis player learned
    var reputation_gain: int = 0  # Future: faction reputation
    var bonus_multiplier: float = 1.0  # From alignment

static func generate_reward(quest: Dictionary, bath, player_vocab: Array) -> QuestReward:
    """Generate rewards for quest completion"""
    var reward = QuestReward.new()

    # Base gold from quest
    var base_gold = quest.get("quantity", 5) * 10
    var multiplier = quest.get("reward_multiplier", 1.0)
    reward.gold = int(base_gold * multiplier)

    # Vocabulary reward
    var faction_dict = _get_faction_by_name(quest.get("faction", ""))
    if faction_dict:
        var vocab = select_vocabulary_reward(faction_dict, bath, player_vocab)
        if vocab != "":
            reward.learned_vocabulary.append(vocab)

    return reward
```

### Phase 2: QuestManager Integration

**File**: `Core/Quests/QuestManager.gd`

Update `complete_quest()` to handle vocabulary rewards:

```gdscript
const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")

signal vocabulary_learned(emoji: String, faction: String)

func complete_quest(quest_id: int) -> Dictionary:
    """Mark quest as complete and grant rewards"""

    var quest = active_quests.get(quest_id)
    if not quest:
        return {}

    # Get current biome bath
    var biome = _get_active_biome()
    var bath = biome.bath if biome else null

    # Get player vocabulary
    var player_vocab = GameStateManager.current_state.known_emojis if GameStateManager.current_state else []

    # Generate rewards
    var reward = QuestRewards.generate_reward(quest, bath, player_vocab)

    # Apply rewards
    _apply_gold_reward(reward.gold)

    for emoji in reward.learned_vocabulary:
        GameStateManager.discover_emoji(emoji)
        emit_signal("vocabulary_learned", emoji, quest.get("faction", "Unknown"))
        print("📖 %s taught you: %s" % [quest.get("faction", "Unknown"), emoji])

    # Update quest status
    quest["status"] = "completed"
    quest["completed_at"] = Time.get_ticks_msec()
    quest["reward"] = reward

    emit_signal("quest_completed", quest)
    active_quests.erase(quest_id)
    completed_quests.append(quest)

    return reward
```

### Phase 3: UI Display

**File**: `UI/Panels/QuestPanel.gd`

Show vocabulary rewards in quest display:

```gdscript
func _display_quest_rewards(quest: Dictionary):
    """Show potential rewards for quest"""

    var reward_text = ""

    # Gold reward
    var base_gold = quest.get("quantity", 5) * 10
    var multiplier = quest.get("reward_multiplier", 1.0)
    var gold = int(base_gold * multiplier)
    reward_text += "💰 %d gold\n" % gold

    # Vocabulary preview
    var faction_vocab = quest.get("faction_vocabulary", [])
    var available_vocab = quest.get("available_emojis", [])
    var unknown_vocab = []

    for emoji in faction_vocab:
        if emoji not in GameStateManager.current_state.known_emojis:
            unknown_vocab.append(emoji)

    if unknown_vocab.size() > 0:
        # Show preview of possible vocabulary
        var preview = unknown_vocab.slice(0, 3)  # First 3
        reward_text += "📖 Learn: %s" % " or ".join(preview)
        if unknown_vocab.size() > 3:
            reward_text += " (+%d more)" % (unknown_vocab.size() - 3)
    else:
        reward_text += "📖 (No new vocabulary)"

    reward_label.text = reward_text
```

**Completion notification**:

```gdscript
func _on_quest_completed(quest: Dictionary):
    """Show completion notification"""

    var reward = quest.get("reward")
    if not reward:
        return

    var message = "Quest Complete!\n"
    message += "💰 +%d gold\n" % reward.gold

    for emoji in reward.learned_vocabulary:
        message += "📖 Learned: %s\n" % emoji

    _show_notification(message)
```

### Phase 4: Vocabulary Panel (New UI)

**New File**: `UI/Panels/VocabularyPanel.gd`

Create a panel to view learned vocabulary:

```gdscript
extends PanelContainer

@onready var vocab_grid = $VocabularyGrid
@onready var faction_filter = $FactionFilter
@onready var stats_label = $StatsLabel

func _ready():
    GameStateManager.emoji_discovered.connect(_on_emoji_discovered)
    _refresh_vocabulary_display()

func _refresh_vocabulary_display():
    """Display all learned vocabulary"""

    var known = GameStateManager.current_state.known_emojis if GameStateManager.current_state else []

    # Clear grid
    for child in vocab_grid.get_children():
        child.queue_free()

    # Display each emoji
    for emoji in known:
        var emoji_label = Label.new()
        emoji_label.text = emoji
        emoji_label.add_theme_font_size_override("font_size", 32)
        emoji_label.tooltip_text = _get_emoji_sources(emoji)
        vocab_grid.add_child(emoji_label)

    # Update stats
    var total_factions = FactionDatabase.ALL_FACTIONS.size()
    var accessible = GameStateManager.get_accessible_factions().size()

    stats_label.text = "Vocabulary: %d emojis | Factions: %d/%d (%.0f%%)" % [
        known.size(),
        accessible,
        total_factions,
        float(accessible) / total_factions * 100
    ]

func _get_emoji_sources(emoji: String) -> String:
    """Find which factions have this emoji in their vocabulary"""

    var sources = []
    for faction in FactionDatabase.ALL_FACTIONS:
        var vocab = FactionDatabase.get_faction_vocabulary(faction)
        if emoji in vocab.all:
            sources.append(faction.name)

    if sources.is_empty():
        return "Unknown origin"

    return "Found in: " + ", ".join(sources.slice(0, 3))
```

---

## Future: Icon Integration

This vocabulary system sets up the **Icon planting feature**:

```gdscript
# Future in Core/Icons/IconRegistry.gd

func can_plant_icon(emoji: String) -> bool:
    """Check if player knows this emoji and can plant it"""
    if not GameStateManager.current_state:
        return false

    return emoji in GameStateManager.current_state.known_emojis

func plant_icon(emoji: String, plot_position: Vector2i):
    """Plant an Icon in a biome plot (future feature)"""

    if not can_plant_icon(emoji):
        print("📖 You don't know how to use %s yet!" % emoji)
        return

    # Create Icon from emoji
    var icon = Icon.new(emoji)

    # Plant at location
    # ... quantum substrate integration ...

    print("🌱 Planted %s Icon" % emoji)
```

**The loop becomes**:
1. Farm → Shape quantum state
2. Accept quest from aligned faction
3. Complete quest → Learn vocabulary
4. Plant learned vocabulary as Icons
5. Icons interact → Discover quantum effects
6. New quantum states → New faction alignments
7. Loop continues!

---

## Edge Cases

### Player Already Knows All Faction Vocabulary

```gdscript
if unknown_vocab.is_empty():
    # Still give gold, just no vocabulary
    print("📖 %s has nothing new to teach you" % faction_name)
    return ""  # No vocab reward
```

### Faction Has No Signature Vocabulary

```gdscript
if signature.is_empty():
    # Shouldn't happen with current data, but handle gracefully
    return ""
```

### Bath Doesn't Contain Faction Vocabulary

```gdscript
# Fallback to random selection from unknown vocabulary
# Still meaningful: player learns something new
return unknown[randi() % unknown.size()]
```

---

## Testing Plan

### Test 1: Basic Vocabulary Reward

```gdscript
# Create test quest
var quest = {
    "faction": "Millwright's Union",
    "quantity": 5,
    "resource": "🌾",
    "reward_multiplier": 2.0
}

# Player knows only starters
GameStateManager.current_state.known_emojis = ["🌾", "🍄"]

# Complete quest
var reward = QuestManager.complete_quest(quest_id)

# Verify
assert(reward.learned_vocabulary.size() == 1)
assert(reward.learned_vocabulary[0] in ["⚙", "🏭", "🔩", "🛠", "📦", "🌽", "🧾", "🗝"])
assert(GameStateManager.current_state.known_emojis.size() == 3)
```

### Test 2: Quantum-Weighted Selection

```gdscript
# Create bath with high ⚙ probability
var bath = QuantumBath.new()
bath.initialize_with_emojis(["🌾", "⚙", "🏭"])
bath.inject("⚙", 0.7)  # High probability for ⚙

# Complete quest 100 times
var results = {}
for i in range(100):
    var emoji = select_vocabulary_reward(faction, bath, ["🌾", "🍄"])
    results[emoji] = results.get(emoji, 0) + 1

# Verify ⚙ appears most often (quantum-weighted)
assert(results["⚙"] > results.get("🏭", 0))
```

### Test 3: All Vocabulary Known

```gdscript
# Player knows entire signature
var faction = FactionDatabase.MILLWRIGHTS_UNION
var vocab = FactionDatabase.get_faction_vocabulary(faction)
GameStateManager.current_state.known_emojis = vocab.all.duplicate()

# Complete quest
var reward = QuestManager.complete_quest(quest_id)

# Verify no vocabulary reward
assert(reward.learned_vocabulary.is_empty())
assert(reward.gold > 0)  # Still get gold
```

---

## Files to Create/Modify

### New Files
- `Core/Quests/QuestRewards.gd` - Reward generation and vocabulary selection
- `UI/Panels/VocabularyPanel.gd` - UI to view learned vocabulary
- `Tests/test_vocabulary_rewards.gd` - Comprehensive test suite

### Modified Files
- `Core/Quests/QuestManager.gd` - Add `vocabulary_learned` signal, update `complete_quest()`
- `Core/Quests/QuestTypes.gd` - Add `QuestReward` class (or use QuestRewards.gd)
- `UI/Panels/QuestPanel.gd` - Display vocabulary rewards in quest UI
- `Core/GameState/GameState.gd` - Already has `known_emojis` (ready!)
- `Core/GameState/GameStateManager.gd` - Already has `discover_emoji()` (ready!)

---

## Benefits

✅ **Natural Progression**: Vocabulary expands through gameplay, not grinding
✅ **Thematic Coherence**: Learn machinery from Millwrights, poison from Assassins
✅ **Quantum Feedback**: Rewards shaped by biome state (farm → bath → reward)
✅ **Discovery Loop**: Complete quests → unlock factions → more quests
✅ **Future-Proof**: Sets up Icon planting system
✅ **Educational**: Teaches quantum observables through rewards
✅ **Emergent**: No hardcoded progression, all parametric

---

## Implementation Priority

1. **Phase 1** (Core): QuestReward structure and vocabulary selection algorithm
2. **Phase 2** (Integration): QuestManager completion handling
3. **Phase 3** (UI): Quest panel reward display
4. **Phase 4** (Polish): Vocabulary panel for viewing collection
5. **Testing**: Comprehensive test suite

---

## Status: READY TO IMPLEMENT

All prerequisites are in place:
- ✅ Vocabulary system implemented (faction + player vocabulary)
- ✅ Discovery system implemented (GameStateManager.discover_emoji)
- ✅ Quest generation implemented (alignment-based)
- ✅ Faction database ready (64 factions with signatures)

Next step: Implement Phase 1 (QuestReward structure and selection algorithm)
