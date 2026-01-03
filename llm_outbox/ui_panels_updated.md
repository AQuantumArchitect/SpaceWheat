# UI Panels Updated for Vocabulary System ✅

## Summary

Both the **Vocabulary Panel (V key)** and **Quest Panel (C key)** have been updated to integrate with the new vocabulary reward system!

---

## Vocabulary Panel (V Key) - Completely Redesigned

### Before
- **Static content** hardcoded in overlay creation
- Showed ~10 example emojis with descriptions
- Never changed based on player progress

### After
- **Dynamic content** pulled from `GameStateManager.current_state.known_emojis`
- Shows **all discovered emojis** in an 8-column grid
- Displays **faction accessibility stats**
- Refreshes every time panel is opened

### New Features

**Stats Display**:
```
Vocabulary: 12 emojis | Accessible Factions: 49/64 (76%)
```

**Emoji Grid**:
- 8 columns × dynamic rows
- Large emoji display (32pt font)
- Scrollable for large vocabularies
- Shows actual player progress

**Visual Layout**:
```
┌──────────────────────────────────────────┐
│ 📖 Vocabulary                        [✖] │
├──────────────────────────────────────────┤
│ Vocabulary: 12 emojis                    │
│ Accessible Factions: 49/64 (76%)         │
├──────────────────────────────────────────┤
│ ┌────────────────────────────────────┐   │
│ │ 🌾  🍄  ⚙  🏭  🔩  🛠  📦  🌽    │   │
│ │ 🧾  🗝  💨  🍂                     │   │
│ │                                    │   │
│ └────────────────────────────────────┘   │
├──────────────────────────────────────────┤
│              [Close [V]]                 │
└──────────────────────────────────────────┘
```

### Implementation Details

**File**: `UI/Managers/OverlayManager.gd`

**New function**: `_refresh_vocabulary_overlay()`
```gdscript
func _refresh_vocabulary_overlay() -> void:
    # Get player's known emojis
    var known_emojis = GameStateManager.current_state.known_emojis

    # Get accessible factions count
    var accessible = GameStateManager.get_accessible_factions().size()

    # Update stats label
    stats_label.text = "Vocabulary: %d emojis | Accessible Factions: %d/%d"

    # Populate emoji grid
    for emoji in known_emojis:
        var label = Label.new()
        label.text = emoji
        emoji_grid.add_child(label)
```

**Updated**: `toggle_vocabulary_overlay()`
- Now calls `_refresh_vocabulary_overlay()` before showing
- Always shows current state

**Updated**: `_create_vocabulary_overlay()`
- Creates grid layout instead of static text
- Named children for easy updating: "StatsLabel", "EmojiGrid"
- Larger panel (500×600 instead of 400×300)

---

## Quest Panel (C Key) - Vocabulary Preview Added

### Before
- Showed: Resource, Quantity, Time, Reward multiplier
- No indication of vocabulary rewards

### After
- **Added vocabulary preview** for each quest offer
- Shows which emojis player could learn
- Indicates when faction has no new vocabulary to teach

### New Feature: Vocabulary Preview

**In each quest card**:
```
┌──────────────────────────────────────────────────┐
│ ⚙🏭🔩 Millwright's Union    Alignment: 87%      │
├──────────────────────────────────────────────────┤
│ 🌾 × 5                                           │
│ ⏰ 120s | Reward: 2.0x | 📖 Learn: ⚙ or 🏭 (+6) │
│                                    [✅ Accept]   │
└──────────────────────────────────────────────────┘
```

**Shows**:
- `📖 Learn: ⚙ or 🏭 or 🔩` - First 3 unknown emojis from faction
- `(+6)` - Number of additional learnable emojis
- `📖 (No new vocab)` - When player knows all faction vocabulary

### Implementation Details

**File**: `UI/Panels/FactionQuestOffersPanel.gd`

**Updated**: `QuestOfferItem._create_ui()`
```gdscript
# Vocabulary preview
var vocab_label = Label.new()
var faction_vocab = quest_data.get("faction_vocabulary", [])
var player_vocab = GameStateManager.current_state.known_emojis

# Find unknown emojis
var unknown_vocab = []
for emoji in faction_vocab:
    if emoji not in player_vocab:
        unknown_vocab.append(emoji)

if unknown_vocab.size() > 0:
    var preview = unknown_vocab.slice(0, 3)
    vocab_label.text = "📖 Learn: %s" % " or ".join(preview)
    if unknown_vocab.size() > 3:
        vocab_label.text += " (+%d)" % (unknown_vocab.size() - 3)
else:
    vocab_label.text = "📖 (No new vocab)"
```

**Styling**:
- Light blue color (matches biome state text)
- Detail font size (consistent with other quest info)
- Positioned between reward and accept button

---

## User Experience Flow

### Opening Vocabulary Panel (V key)

**Before quest completion**:
```
Press V
  ↓
Shows: [🌾, 🍄]  (starter emojis)
Stats: "Accessible Factions: 47/64 (73%)"
```

**After completing Millwright quest**:
```
Press V
  ↓
Shows: [🌾, 🍄, ⚙]  (learned gear!)
Stats: "Accessible Factions: 49/64 (76%)"
       ^^ 2 new factions unlocked!
```

### Opening Quest Panel (C key)

**Shows quest offers with vocabulary info**:
```
High Alignment Quest:
  ⚙🏭🔩 Millwright's Union - 87% alignment
  Deliver 5 🌾
  📖 Learn: 🏭 or 🔩 or 🛠 (+5)
  ↑ Player can see what they'll learn!

Low Alignment Quest:
  🍄🌙🔮 Fungal Network - 34% alignment
  Collect 8 🍄
  📖 Learn: 🌙 or 🌲 or 🌿 (+8)
```

**Player thinking**: "I want to learn machinery emojis, so I'll take the Millwright quest even though the reward is similar!"

---

## Integration with Reward System

### Vocabulary Panel Updates
- Refreshes when opened (not real-time)
- Shows current `GameStateManager.current_state.known_emojis`
- Displays faction accessibility calculated by `GameStateManager.get_accessible_factions()`

### Quest Panel Preview
- Pulls from `quest_data["faction_vocabulary"]` (already computed by QuestTheming)
- Filters against current player vocabulary
- Shows exactly what player will learn (within faction's signature)

### After Quest Completion
```
Complete quest
  ↓
QuestManager.complete_quest() calls:
  ↓
GameStateManager.discover_emoji(emoji)
  ↓
Emits: emoji_discovered signal
Emits: factions_unlocked signal (if any)
  ↓
Next time V key pressed → Updated panel!
Next time C key pressed → Different quest offers!
```

---

## Files Modified

### Updated Files
✅ `UI/Managers/OverlayManager.gd`
  - Redesigned `_create_vocabulary_overlay()` - Grid layout
  - Added `_refresh_vocabulary_overlay()` - Dynamic population
  - Updated `toggle_vocabulary_overlay()` - Refresh before show

✅ `UI/Panels/FactionQuestOffersPanel.gd`
  - Updated `QuestOfferItem._create_ui()` - Added vocabulary preview
  - Shows unknown emojis from faction signature
  - Indicates when no new vocabulary available

---

## Visual Examples

### Vocabulary Panel Progression

**Early Game (2 emojis)**:
```
📖 Vocabulary                                    [✖]
Vocabulary: 2 emojis | Accessible Factions: 47/64 (73%)

┌────────────────────────────────────────────────┐
│  🌾  🍄                                        │
│                                                │
└────────────────────────────────────────────────┘
```

**Mid Game (12 emojis)**:
```
📖 Vocabulary                                    [✖]
Vocabulary: 12 emojis | Accessible Factions: 52/64 (81%)

┌────────────────────────────────────────────────┐
│  🌾  🍄  ⚙  🏭  🔩  🛠  📦  🌽                │
│  🧾  🗝  💨  🍂                                │
└────────────────────────────────────────────────┘
```

**Late Game (30+ emojis)**:
```
📖 Vocabulary                                    [✖]
Vocabulary: 32 emojis | Accessible Factions: 64/64 (100%)

┌────────────────────────────────────────────────┐
│  🌾  🍄  ⚙  🏭  🔩  🛠  📦  🌽                │
│  🧾  🗝  💨  🍂  🌹  🗡️  🩸  💉                │
│  ☠️  🎭  🕯️  🌑  🍞  🧪  🦠  🫧                │
│  🌡️  ⏳  🧫  🌙  🌲  🌿  🧬  🔮                │
└────────────────────────────────────────────────┘
                                         [Scroll ↓]
```

### Quest Panel with Vocabulary

**Quest with unknown vocabulary**:
```
┌──────────────────────────────────────────────────────────┐
│ ⚙🏭🔩 Millwright's Union          Alignment: 87%        │
├──────────────────────────────────────────────────────────┤
│ Deliver 5 🌾                                            │
├──────────────────────────────────────────────────────────┤
│ 🌾 × 5 | ⏰ 120s | Reward: 2.0x | 📖 Learn: 🏭 or 🔩   │
│                                              [✅ Accept] │
└──────────────────────────────────────────────────────────┘
```

**Quest with no new vocabulary**:
```
┌──────────────────────────────────────────────────────────┐
│ 🌾🍄 Starter Faction               Alignment: 95%        │
├──────────────────────────────────────────────────────────┤
│ Gather 3 🌾                                             │
├──────────────────────────────────────────────────────────┤
│ 🌾 × 3 | 🕰️ No limit | Reward: 1.5x | 📖 (No new vocab) │
│                                              [✅ Accept] │
└──────────────────────────────────────────────────────────┘
```

---

## Testing Checklist

### Vocabulary Panel (V key)
- [ ] Opens and closes with V key
- [ ] Shows starter emojis [🌾, 🍄] on new game
- [ ] Displays correct faction accessibility percentage
- [ ] Grid displays all emojis in player vocabulary
- [ ] Updates after completing quests (close and reopen)
- [ ] Scrolls correctly with many emojis

### Quest Panel (C key)
- [ ] Shows vocabulary preview for each quest
- [ ] Displays "📖 Learn: X or Y or Z" format
- [ ] Shows "(+N)" for additional learnable emojis
- [ ] Shows "📖 (No new vocab)" when appropriate
- [ ] Preview updates after learning new emojis (refresh panel)
- [ ] Vocabulary text visible and readable (light blue color)

### Integration
- [ ] Complete quest → close and reopen V panel → new emoji appears
- [ ] Complete quest → close and reopen C panel → different vocabulary previews
- [ ] Learn all faction vocab → quest shows "(No new vocab)"
- [ ] Faction accessibility % increases as vocabulary grows

---

## Status: UI UPDATES COMPLETE ✅

**Both panels are now integrated with the vocabulary reward system!**

**Vocabulary Panel (V)**:
- ✅ Dynamic emoji grid
- ✅ Faction accessibility stats
- ✅ Refreshes on open

**Quest Panel (C)**:
- ✅ Vocabulary preview per quest
- ✅ Shows unknown emojis
- ✅ Indicates exhausted vocabulary

**Ready for**:
- In-game testing
- User feedback
- Future enhancements (emoji tooltips, sources, etc.)

The UI now provides full visibility into the vocabulary system! 🎉
