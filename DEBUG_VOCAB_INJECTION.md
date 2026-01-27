# Vocab Injection Debug - Testing Guide

## The Issue (Now Fixed!)

The submenu code was added to **FarmInputHandler**, but the active input system uses **QuantumInstrumentInput**. This caused the Q key to execute the old vocab injection behavior instead of opening the submenu.

## The Fix

Updated **QuantumInstrumentInput** to:
1. Check for "submenu" field in action_info
2. Open VocabInjectionSubmenu dynamically
3. Route Q/E/R to submenu actions when in submenu
4. Handle F-cycling for submenu pagination

## Testing Instructions

### Test 1: Submenu Opens
```
1. Start game
2. Select a plot
3. Press 4 (Meta tool) - verify "Tool: Meta" shown
4. Press Q (Inject Vocabulary)
5. EXPECTED: Submenu appears with 3 vocab options
   - Should show Q/E/R with vocab pairs
   - Each should have an affinity value
6. OBSERVED: Check console for logs like:
   - "Opened vocab injection submenu"
   - "Submenu page 1/X"
```

### Test 2: F-Cycling Works
```
1. In vocab submenu (after Test 1)
2. Press F repeatedly
3. EXPECTED:
   - Submenu cycles to next page if multiple pages exist
   - Shows different vocab options
   - Console shows "Submenu page N/X"
4. If only 1 page: console shows "Only 1 page in submenu"
```

### Test 3: Vocab Injection Works
```
1. In vocab submenu
2. Look at 3 options and note the vocab pairs
3. Press E (middle option) or Q/R
4. EXPECTED:
   - Submenu closes
   - Vocab is injected into biome
   - Economy cost deducted
   - Console shows: "Injected vocab X/Y into [BiomeName]"
5. Check biome quantum computer for new emoji pair
```

### Test 4: Error Handling
```
1. Try vocab injection without enough energy
2. EXPECTED: "Insufficient funds for vocab injection" in console
3. Try vocab injection on vocab already in biome
4. EXPECTED: "[emoji] already in biome" in console
```

## Console Logging

All vocab injection operations log to console with "input" and "+" or "📋" prefix.

**Submenu opening:**
```
[input] 📋 Opening submenu: vocab_injection
[input] 📋 Opened vocab injection submenu
[input] 📋 Submenu page 1/X
```

**Successful injection:**
```
[input] + Injected vocab 🌻/🌿 into [BiomeName]
[input] ✓ inject_vocabulary succeeded: {...}
```

**Errors:**
```
[input] ✗ Vocab injection failed: expansion_failed
[input] + No biome for vocab injection
[input] + Insufficient funds for vocab injection (need 50 energy)
```

## Key Changes Made

**File: `UI/Core/QuantumInstrumentInput.gd`**
- Added submenu state tracking (_in_submenu, _current_submenu, _submenu_page)
- Modified _perform_action() to check for "submenu" field
- Added _open_submenu_for_action() to open submenus
- Added _generate_vocab_injection_submenu() to create dynamic menu
- Added _handle_submenu_action() to route Q/E/R to submenu actions
- Added _execute_inject_vocabulary() to perform vocab injection
- Added _cycle_submenu_page() to handle F-cycling
- Modified key input handling to route to submenu when active

## Remaining Code

The following code is still there but NOT used (kept for reference):
- `UI/FarmInputHandler.gd` - Submenu code here (not active)
- `UI/Core/SubmenuManager.gd` - Submenu pagination code (not active)

These aren't being called since QuantumInstrumentInput is the active system. If you want to remove them, they can be safely deleted, but keeping them doesn't hurt.

## If Still Not Working

Check console for errors like:
- "No action for Q in group 4" → Tool 4 not selected
- "GameStateManager not found" → GSM autoload issue
- "No current biome" → Biome not selected properly
- Any GDScript parse errors

Enable verbose logging by checking `Core/Config/VerboseConfig.gd` if needed.
