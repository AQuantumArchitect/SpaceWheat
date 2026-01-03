# Quest System Integration Plan - FINAL
## Replace Contracts with Procedural Quest System via PlayerShell

**Date:** 2025-12-30
**Strategy:** Remove QuantumQuest, hook QuestManager through PlayerShell (not Farm)

---

## Executive Summary

### Current State
1. **OLD**: FactionManager + FactionContract (5 factions, manual contracts) ❌
2. **NEW**: QuestManager + QuestGenerator (32 factions, procedural) ✅ Ready
3. **QuantumQuest**: Quantum objectives system ❌ Remove
4. **C Key**: Currently opens ContractPanel (old system)
5. **PlayerShell**: Manages overlays, resources, UI layer

### Strategy
- **Remove**: QuantumQuest system (wrong system)
- **Replace**: ContractPanel → QuestPanel
- **Replace**: FactionContract → QuestManager
- **Hook**: QuestManager through PlayerShell (NOT Farm)
- **Keep**: C key for quests (user preference)

---

## Why PlayerShell (Not Farm)?

**PlayerShell is the correct location because:**
1. ✅ Already manages overlays (ESC, V, K, C menus)
2. ✅ Player-level persistence (stays when farm changes)
3. ✅ Has access to economy through farm reference
4. ✅ Handles resource display
5. ✅ Controls all UI interactions

**Farm is the wrong location because:**
1. ❌ Farm is game world logic, not UI
2. ❌ Quests are player-level, not farm-level
3. ❌ User explicitly requested PlayerShell integration
4. ❌ Farm could be swapped/reloaded, quests should persist

---

## Phase 1: Remove QuantumQuest System

### Files to DELETE
```
Core/Quests/QuantumQuest.gd
Core/Quests/QuantumQuestGenerator.gd
Core/Quests/QuantumQuestEvaluator.gd
Core/Quests/QuantumObjective.gd
Core/Quests/QuantumCondition.gd
Core/Quests/QuantumObservable.gd
Core/Quests/ObjectiveType.gd
Core/Quests/ComparisonOp.gd
```

### References to REMOVE
```bash
# Search for QuantumQuest references:
grep -r "QuantumQuest" --include="*.gd" /home/tehcr33d/ws/SpaceWheat/

# Expected locations:
- Tests/claude_plays_manual.gd (line 7-10)
- Tests/test_keyboard_gameplay.gd
- Tests/other test files

# Action: Remove imports and replace with QuestManager
```

### Test Files to UPDATE
- `Tests/claude_plays_manual.gd` - Replace QuantumQuestEvaluator with QuestManager
- Any other test using QuantumQuest

**Estimated Impact:** ~8 files deleted, ~5 test files updated

---

## Phase 2: Hook QuestManager to PlayerShell

### 2.1 Add QuestManager to PlayerShell
**File:** `UI/PlayerShell.gd`

**Changes:**
```gdscript
# Add after overlay_manager declaration (line 16)
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabase.gd")

var quest_manager: QuestManager = null

# In _ready() after overlay_manager setup (line 58):
func _ready() -> void:
    # ... existing code ...

    # Create quest manager (before overlays)
    quest_manager = QuestManager.new()
    add_child(quest_manager)
    print("   ✅ Quest manager created")

    # Setup overlay manager with quest_manager
    overlay_manager.setup(layout_manager, null, null, null, quest_manager)

    # Initialize overlays
    overlay_manager.create_overlays(overlay_layer)

# In load_farm() after farm reference is set (line 71):
func load_farm(farm_ref: Node) -> void:
    # ... existing code ...

    farm = farm_ref

    # Connect quest manager to farm economy
    if quest_manager and farm.economy:
        quest_manager.connect_to_economy(farm.economy)
        print("   ✅ Quest manager connected to economy")

        # Offer initial quest
        _offer_initial_quest()

func _offer_initial_quest() -> void:
    """Offer first quest to player"""
    if not quest_manager or not farm:
        return

    # Get random faction from database
    var all_factions = FactionDatabase.get_all_factions()
    var faction = all_factions[randi() % all_factions.size()]

    # Get resources from current biome
    var resources = []
    if farm.biotic_flux_biome:
        resources = farm.biotic_flux_biome.get_available_emojis()

    if resources.is_empty():
        resources = ["🌾", "👥"]  # Fallback

    # Generate and offer quest
    var quest = quest_manager.offer_quest(faction, "BioticFlux", resources)
    if not quest.is_empty():
        # Auto-accept first quest for tutorial
        quest_manager.accept_quest(quest)
        print("   📜 Initial quest offered and accepted: %s" % quest["faction"])
```

**Lines Added:** ~35
**Files Modified:** 1

---

### 2.2 Update OverlayManager to Support QuestManager
**File:** `UI/Managers/OverlayManager.gd`

**Changes:**
```gdscript
# Replace ContractPanel with QuestPanel
# Line 8: Remove
# const ContractPanel = preload("res://UI/ContractPanel.gd")

# Line 8: Add
const QuestPanel = preload("res://UI/Panels/QuestPanel.gd")

# Line 16: Replace
# var contract_panel: ContractPanel
var quest_panel: QuestPanel

# Add quest_manager reference
var quest_manager: Node = null

# Line 52: Update setup signature
func setup(layout_mgr, vocab_sys, faction_mgr, conspiracy_net, quest_mgr = null) -> void:
    """Initialize OverlayManager with required dependencies"""
    layout_manager = layout_mgr
    vocabulary_evolution = vocab_sys
    faction_manager = faction_mgr
    conspiracy_network = conspiracy_net
    quest_manager = quest_mgr  # NEW
    print("📋 OverlayManager initialized")

# Line 73-79: Replace contract panel creation
# REMOVE:
# contract_panel = ContractPanel.new()
# contract_panel.set_faction_manager(faction_manager)
# contract_panel.visible = false
# contract_panel.z_index = 1001
# parent.add_child(contract_panel)
# print("📜 Contract panel created (press C to toggle)")

# ADD:
quest_panel = QuestPanel.new()
if layout_manager:
    quest_panel.set_layout_manager(layout_manager)
if quest_manager:
    quest_panel.connect_to_quest_manager(quest_manager)
quest_panel.visible = false
quest_panel.z_index = 1001
parent.add_child(quest_panel)
print("📜 Quest panel created (press C to toggle)")

# Line 32: Update overlay_states
var overlay_states: Dictionary = {
    "quests": false,  # CHANGED from "contracts"
    "vocabulary": false,
    "network": false,
    "escape_menu": false,
    "save_load": false
}

# Line 150-151: Update toggle_overlay
"quests":  # CHANGED from "contracts"
    toggle_quest_panel()  # CHANGED from toggle_contract_panel()

# Line 166-221: Replace contract panel logic with quest panel
func toggle_quest_panel() -> void:
    """Toggle quest panel visibility"""
    print("🔄 toggle_quest_panel() called")
    if quest_panel:
        if quest_panel.visible:
            hide_overlay("quests")
        else:
            show_overlay("quests")

# Update show_overlay case:
"quests":
    if quest_panel:
        quest_panel.visible = true
        overlay_states["quests"] = true
        overlay_toggled.emit("quests", true)

# Update hide_overlay case:
"quests":
    if quest_panel:
        quest_panel.visible = false
        overlay_states["quests"] = false
        overlay_toggled.emit("quests", false)

# Line 267: Update position logic
if quest_panel:
    quest_panel.position = layout_manager.anchor_to_corner("top_left", Vector2(10, 10))
```

**Lines Modified:** ~50
**Lines Removed:** ~40
**Net Change:** +10 lines
**Files Modified:** 1

---

### 2.3 Update InputController Signal
**File:** `UI/Controllers/InputController.gd`

**Changes:**
```gdscript
# Line 16: Update comment
## - Overlay toggles (K=keyboard help, V=vocabulary, N=network, C=quests)

# Line 35: Update signal name (or keep as-is)
# Option A: Rename signal
signal quests_toggled()  # C: Toggle quest panel (CHANGED from contracts_toggled)

# Option B: Keep contracts_toggled (less breaking)
# signal contracts_toggled()  # C: Toggle quest panel (quests replace contracts)

# Line 187-188: Update emit (if renamed)
KEY_C:
    quests_toggled.emit()  # CHANGED if using Option A
```

**Decision:** Keep `contracts_toggled` signal name for backwards compatibility, just change what it does

**Lines Modified:** 1 (comment only)
**Files Modified:** 1

---

### 2.4 Update FarmView Signal Connection
**File:** `UI/FarmView.gd`

**Changes:**
```gdscript
# Find where contracts_toggled is connected
# Search for: contracts_toggled.connect

# Update connection target:
# OLD:
# input_controller.contracts_toggled.connect(shell.overlay_manager.toggle_contract_panel)

# NEW:
input_controller.contracts_toggled.connect(shell.overlay_manager.toggle_quest_panel)
```

**Lines Modified:** 1
**Files Modified:** 1

---

## Phase 3: Remove Old Contract System

### 3.1 Deprecate ContractPanel
**File:** `UI/ContractPanel.gd`

**Action:** DELETE (no longer needed)

**Justification:**
- Replaced by QuestPanel
- Old 5-faction system
- No procedural generation
- QuestPanel is superior

---

### 3.2 Keep FactionManager (For Now)
**File:** `Core/GameMechanics/FactionManager.gd`

**Action:** KEEP but MODIFY

**Reason:** FactionManager handles reputation system, which is separate from quests

**Changes:**
```gdscript
# Comment out contract-related code
# Keep reputation system intact

# Mark contract methods as deprecated:
# - _generate_starter_contracts() → stub
# - _refresh_available_contracts() → stub
# - Contract signals → keep for backwards compatibility but don't use
```

**Future:** May integrate QuestManager with FactionManager for reputation rewards

---

### 3.3 Keep FactionContract.gd (Deprecated)
**File:** `Core/GameMechanics/FactionContract.gd`

**Action:** KEEP but mark deprecated

**Reason:** May have dependencies, remove in Phase 4

---

## Phase 4: Testing & Validation

### 4.1 Manual Testing Checklist
```
[ ] C key opens quest panel
[ ] Quest panel displays active quests
[ ] Initial quest is offered on game start
[ ] Quest shows: faction name, emoji, body text, resource, quantity, time limit
[ ] Complete button appears on quest card
[ ] Clicking complete button checks resources
[ ] Completing quest deducts resources and grants rewards
[ ] Quest timer counts down
[ ] Quest expires when timer reaches 0
[ ] New quests are offered periodically
```

### 4.2 Test Script Update
**File:** `Tests/claude_plays_manual.gd`

**Changes:**
```gdscript
# Line 7-8: Replace
# const QuantumQuestGenerator = preload("res://Core/Quests/QuantumQuestGenerator.gd")
# const QuantumQuestEvaluator = preload("res://Core/Quests/QuantumQuestEvaluator.gd")

# With:
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const QuestGenerator = preload("res://Core/Quests/QuestGenerator.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabase.gd")

# Line 12: Replace
# var evaluator: QuantumQuestEvaluator

# With:
var quest_manager: QuestManager

# Update all references from evaluator → quest_manager
```

---

## Phase 5: Quest Generation Triggers

### 5.1 Periodic Quest Offers
**File:** `UI/PlayerShell.gd`

**Add periodic quest generation:**
```gdscript
var quest_offer_timer: float = 0.0
const QUEST_OFFER_INTERVAL: float = 60.0  # Offer new quest every 60s

func _process(delta: float) -> void:
    if not quest_manager or not farm:
        return

    # Periodic quest offers
    quest_offer_timer += delta
    if quest_offer_timer >= QUEST_OFFER_INTERVAL:
        quest_offer_timer = 0.0
        _offer_random_quest()

func _offer_random_quest() -> void:
    """Offer random quest from random faction"""
    if quest_manager.get_active_quest_count() >= QuestManager.MAX_ACTIVE_QUESTS:
        return  # Don't spam player with too many quests

    var all_factions = FactionDatabase.get_all_factions()
    var faction = all_factions[randi() % all_factions.size()]

    var resources = []
    if farm.biotic_flux_biome:
        resources = farm.biotic_flux_biome.get_available_emojis()
    if resources.is_empty():
        resources = ["🌾", "👥", "🍄"]

    var quest = quest_manager.offer_quest(faction, "BioticFlux", resources)
    if not quest.is_empty():
        print("📜 New quest offered: %s - %s" % [quest["faction"], quest["body"]])
```

---

## Implementation Timeline

### Sprint 1: Core Replacement (2-3 hours)
- [ ] Delete QuantumQuest files (8 files)
- [ ] Update PlayerShell with QuestManager (~35 lines)
- [ ] Update OverlayManager (replace ContractPanel → QuestPanel, ~50 lines)
- [ ] Update signal connections (~2 lines)

### Sprint 2: Testing & Polish (1 hour)
- [ ] Update test scripts
- [ ] Manual testing checklist
- [ ] Fix any bugs

### Sprint 3: Quest Generation (1 hour)
- [ ] Add periodic quest offers
- [ ] Add quest notification UI
- [ ] Tune quest generation parameters

**Total Estimated Time:** 4-5 hours

---

## File Change Summary

### Files to DELETE (8)
```
Core/Quests/QuantumQuest.gd
Core/Quests/QuantumQuestGenerator.gd
Core/Quests/QuantumQuestEvaluator.gd
Core/Quests/QuantumObjective.gd
Core/Quests/QuantumCondition.gd
Core/Quests/QuantumObservable.gd
Core/Quests/ObjectiveType.gd
Core/Quests/ComparisonOp.gd
```

### Files to MODIFY (4)
```
UI/PlayerShell.gd          (+40 lines)
UI/Managers/OverlayManager.gd  (+10 net lines)
UI/Controllers/InputController.gd  (comment only)
UI/FarmView.gd  (1 line change)
```

### Files to DEPRECATE (2)
```
UI/ContractPanel.gd  (delete or mark deprecated)
Core/GameMechanics/FactionContract.gd  (keep but stub out)
```

### Test Files to UPDATE (3-5)
```
Tests/claude_plays_manual.gd
Tests/test_keyboard_gameplay.gd
Tests/*quest*.gd  (any using QuantumQuest)
```

**Total Changes:** ~100 lines across 6 files

---

## Verification Checklist

After implementation, verify:

### Structural
- [ ] QuantumQuest files deleted
- [ ] QuestManager instantiated in PlayerShell._ready()
- [ ] QuestPanel instantiated in OverlayManager.create_overlays()
- [ ] C key opens quest panel
- [ ] Quest panel connected to QuestManager

### Functional
- [ ] Initial quest offered on game start
- [ ] Quest displays in panel with all fields
- [ ] Resource requirements shown
- [ ] Timer counts down
- [ ] Complete button works
- [ ] Resources deducted on completion
- [ ] Rewards granted on completion
- [ ] New quests offered periodically

### Integration
- [ ] PlayerShell persists quests across farm changes
- [ ] Quest manager connected to farm economy
- [ ] Quest panel uses FactionDatabase (32 factions)
- [ ] Quest generation uses procedural system
- [ ] Quest panel styled correctly

---

## Rollback Plan

If issues arise:

1. **Keep QuantumQuest deleted** (it's the wrong system)
2. **Revert UI changes** if quest panel doesn't work
3. **Restore ContractPanel temporarily** if needed
4. **Debug in isolation** - test QuestManager separately

---

## Future Enhancements (Phase 6+)

### Quest Notification System
- Toast notification when new quest offered
- Badge on C key icon when unclaimed quests
- Sound effect on quest offer

### Quest Filtering
- Filter by faction
- Filter by time limit
- Filter by resource type

### Quest Reputation Integration
- Link QuestManager to FactionManager reputation
- Reputation affects quest difficulty
- Reputation unlocks special quests

### Quest Variety
- Multiple biomes (Market, Forest, Kitchen)
- Emoji-only quests
- Multi-resource quests
- Chain quests (quest 2 unlocks after quest 1)

---

## Conclusion

**Strategy Summary:**
1. Remove QuantumQuest (wrong system)
2. Hook QuestManager through PlayerShell (not Farm)
3. Replace ContractPanel with QuestPanel
4. Keep C key for quests
5. ~100 lines of code across 6 files

**Benefits:**
- ✅ Procedural quest generation (trillions of quests)
- ✅ 32 factions with unique voices
- ✅ Player-level quest persistence
- ✅ Proper separation: PlayerShell = UI, Farm = game logic
- ✅ Clean architecture: Quest system decoupled from farm

**User Request Satisfied:**
- ✅ QuantumQuest removed
- ✅ QuestManager integrated via PlayerShell
- ✅ C key reserved for quests
- ✅ Not hooked through Farm

---

**Plan Created By:** Claude Code
**Date:** 2025-12-30
**Status:** Ready for implementation
