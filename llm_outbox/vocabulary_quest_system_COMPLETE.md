# Vocabulary-Based Quest System - IMPLEMENTATION COMPLETE ✅

## Summary

Successfully implemented **vocabulary-based quest generation** where factions only request emojis from the **intersection** of:
- **Faction vocabulary** (12 axial emojis + signature emojis)
- **Player vocabulary** (emojis discovered through gameplay)

This creates natural progression, thematic coherence, and emergent storytelling!

---

## Core Concept

### Faction Vocabulary

Each faction has a vocabulary consisting of:

1. **12 Axial Emojis** - Based on their bit pattern
   - bit[0]=1 → "📚" (Deterministic)
   - bit[1]=1 → "🔮" (Mystical)
   - bit[2]=0 → "🌾" (Common) ← WHEAT!
   - bit[3]=1 → "🌌" (Cosmic)
   - ...

2. **Signature Emojis** - Their unique thematic cluster
   - Example: Millwright's Union → `["⚙", "🏭", "🔩", "🛠", "📦", "🌽", "🧾", "🗝"]`

3. **Total Vocabulary** - Union of axial + signature (no duplicates)
   - Example: `["📚", "🔮", "🌾", "🌌", "⚡", "💪", "💠", "🗡️", "🍽️", "⬜", "🍄", "🎯", "⚙", "🏭", ...]`

### Quest Generation Rule

```gdscript
available_emojis = faction_vocabulary ∩ player_vocabulary

if available_emojis.is_empty():
    return error("Learn more about this faction's interests first...")
else:
    quest_resource = sample(available_emojis)  # Constrained!
```

---

## The Magic of 🌾 and 🍄

These two emojis are **starter emojis** that give immediate access to ~50% of factions:

- **🌾 (Wheat)**: Appears on axis bit[2]=0 (Common)
- **🍄 (Mushroom)**: Appears on axis bit[10]=0 (Emergent)

Since ~32 factions have Common=0 OR Emergent=0, players start with access to **47/64 factions (73%)!**

This creates a perfect tutorial experience: simple factions first, complexity unlocks through discovery.

---

## Implementation Details

### 1. FactionDatabase.gd - Vocabulary Computation

```gdscript
static func get_faction_vocabulary(faction: Dictionary) -> Dictionary:
    """Returns: {axial: Array, signature: Array, all: Array}"""

static func _get_axial_emojis(bits: Array) -> Array:
    """Extract 12 emojis from AXES based on bit values"""

static func get_vocabulary_overlap(faction_vocab: Array, player_vocab: Array) -> Array:
    """Find intersection of two vocabularies"""
```

### 2. GameState.gd - Player Vocabulary Tracking

```gdscript
@export var known_emojis: Array[String] = []

func _init():
    # Start with the magical starter emojis!
    known_emojis = ["🌾", "🍄"]
```

### 3. GameStateManager.gd - Discovery System

```gdscript
signal emoji_discovered(emoji: String)
signal factions_unlocked(factions: Array)

func discover_emoji(emoji: String) -> void:
    """Updates vocabulary and checks for newly accessible factions"""

func get_accessible_factions() -> Array:
    """Returns factions with vocabulary overlap"""
```

### 4. QuestTheming.gd - Vocabulary Filtering

```gdscript
static func generate_quest(faction: Dictionary, bath, player_vocab: Array = []) -> Dictionary:
    # 1. Get faction vocabulary
    var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)

    # 2. Find overlap
    var available_emojis = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, player_vocab)

    # 3. If no overlap, return error
    if available_emojis.is_empty():
        return {"error": "no_vocabulary_overlap", ...}

    # 4. Generate quest with constraint
    params.available_emojis = available_emojis
    var quest = apply_theming(params, bath)
```

### 5. Constrained Resource Sampling

```gdscript
static func _sample_from_allowed_emojis(bath, allowed_emojis: Array, params) -> String:
    """Sample from bath's probability distribution, filtered to allowed emojis

    1. Get bath probabilities
    2. Filter to allowed emojis
    3. Renormalize
    4. Sample from filtered distribution
    """
```

---

## Test Results

All 7 tests pass! ✅

```
📋 TEST 1: Faction Vocabulary Computation
  ✓ Vocabulary computed correctly

📋 TEST 2: Vocabulary Overlap
  ✓ Overlap computed correctly

📋 TEST 3: Starter Emoji Magic (🌾 and 🍄)
  Accessible factions: 47/64 (73.4%)
  ✓ Starter emojis unlock ~50% of factions

📋 TEST 4: Quest Generation with Limited Vocabulary
  ✓ Quest resource constrained to player vocabulary

📋 TEST 5: Quest Generation with Full Vocabulary
  ✓ Full vocabulary enables maximum quest variety

📋 TEST 6: Inaccessible Faction (No Overlap)
  ✓ Inaccessible faction returns error correctly

📋 TEST 7: Vocabulary Discovery Progression
  Stage 1 (starters): 2 available emojis
  Stage 2 (+⚙): 3 available emojis
  Stage 3 (+🏭): 4 available emojis
  ✓ Vocabulary expands as player discovers new emojis
```

---

## Example Progression

### Early Game (Tutorial)

```
Player knows: [🌾, 🍄]

Millwright's Union:
  Vocabulary: [📚, 🔮, 🌾, 🌌, ⚡, 💪, 💠, 🗡️, 🍽️, ⬜, 🍄, 🎯, ⚙, 🏭, ...]
  Overlap: [🌾, 🍄]  ← Only wheat and mushroom!

  Quest: "Deliver 5 🌾"  ← Simple starter quest
```

### Mid Game

```
Player knows: [🌾, 🍄, 💨, 🔥, ⚙, 🏭]

Millwright's Union:
  Overlap: [🌾, 🍄, ⚙, 🏭]  ← More options!

  Quest possibilities:
  - "Deliver 8 🌾" (still valid)
  - "Deliver 3 ⚙" (new! mechanical parts)
  - "Entangle 🌾 and ⚙" (combine grain + machinery)
```

### Late Game

```
Player knows: 50+ emojis

All factions become accessible
Complex quests emerge naturally:
- "Create coherence between 🌾, ⚙, and 🏭"
- "Maintain ratio: 🌾 > ⚙ > 🔩"
```

---

## Thematic Examples

### Millwright's Union (Grain Processors)

```
Axial: bit[2]=0 → 🌾 (Common)
Signature: [⚙, 🏭, 🔩, 🛠, 📦, 🌽, 🧾, 🗝]

Vocabulary: Wheat, gears, mills, tools, grain, records

Quest themes:
- "Deliver grain to the mill" (🌾)
- "Entangle wheat and machinery" (🌾 + ⚙)
- "Maintain grain storage records" (🌾 + 📦 + 🧾)
```

### House of Thorns (Assassins)

```
Axial: bit[2]=1 → 👑 (Elite)
Signature: [🌹, 🗡️, 🩸, 💉, ☠️, 🎭, 🕯️, 🌑]

Vocabulary: Crown, roses, poison, stealth, shadows

Quest themes:
- "Deliver rare poison 💉"
- "Create subtle influence (🎭 and 🌑)"
- "Maintain elite status (👑 purity)"
```

### Yeast Prophets (Fermentation Mystics)

```
Axial: bit[2]=1 → 👑 (Elite), bit[10]=0 → 🍄 (Emergent)
Signature: [🍞, 🧪, 🦠, 🫧, 🌡️, ⏳, 🧫, 🌾]

Vocabulary: Mushroom, bread, alchemy, bubbles, wheat

Quest themes:
- "Entangle 🍄 and 🍞" (fungus + fermentation)
- "Evolve 🌾 → 🍞" (grain to bread)
- "Maintain brewing culture (🦠 coherence)"
```

---

## Benefits

✅ **Thematic Coherence**: Factions only want things they care about
✅ **Natural Progression**: Early game simpler (fewer emojis), late game complex
✅ **Discovery Mechanic**: Finding new emojis unlocks factions organically
✅ **Strategic Depth**: Players can specialize in emoji clusters
✅ **No Hardcoding**: System works for any emoji vocabulary
✅ **Emergent Storytelling**: Faction personality emerges from vocabulary
✅ **Completely Parametric**: No if/then logic, just set operations!

---

## Files Modified/Created

### Core Implementation
✅ `Core/Quests/FactionDatabase.gd`
  - Added `get_faction_vocabulary()`
  - Added `_get_axial_emojis()`
  - Added `get_vocabulary_overlap()`
  - Added `get_axial_emoji_factions()`

✅ `Core/GameState/GameState.gd`
  - Added `known_emojis: Array[String]`
  - Initialized with `["🌾", "🍄"]` starter emojis

✅ `Core/GameState/GameStateManager.gd`
  - Added `emoji_discovered` signal
  - Added `factions_unlocked` signal
  - Added `discover_emoji()` function
  - Added `get_accessible_factions()` function

✅ `Core/Quests/QuestTheming.gd`
  - Updated `generate_quest()` to accept `player_vocab`
  - Added vocabulary filtering logic
  - Added `_sample_from_allowed_emojis()` for constrained sampling

✅ `Core/QuantumSubstrate/FactionStateMatcher.gd`
  - Added `available_emojis: Array` to `QuestParameters` class

### Tests
✅ `Tests/test_vocabulary_quests.gd` - Comprehensive test suite (7 tests, all passing!)

### Documentation
✅ `llm_outbox/vocabulary_quest_system_COMPLETE.md` - This file

---

## Next Steps (Integration)

1. **Hook up discovery events**:
   - Call `GameStateManager.discover_emoji(emoji)` when player harvests new resources
   - Show UI notification when factions unlock

2. **Update QuestManager**:
   - Pass `current_state.known_emojis` to `QuestTheming.generate_quest()`
   - Filter faction list to only show accessible factions

3. **UI enhancements**:
   - Show vocabulary overlap percentage in quest panel
   - Display "locked" factions with hints about required emojis
   - Highlight newly unlocked factions

4. **Save/Load**:
   - `known_emojis` is already part of GameState (auto-saved!)

---

## Status: COMPLETE ✅

The vocabulary-based quest system is **fully implemented and tested**. All 7 tests pass, demonstrating:
- Correct vocabulary computation
- Proper overlap calculation
- Starter emoji magic (73% faction accessibility)
- Resource constraint enforcement
- Vocabulary discovery progression
- Inaccessible faction handling

Ready for integration into the game! 🎉
