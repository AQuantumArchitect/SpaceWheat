# Vocab Injection Testing Guide

## Status: ✅ WORKING (console-based for now)

The vocab injection submenu **is working**! The data is being generated correctly. However, there's **no visible UI overlay** yet showing the options, so all feedback is in the **console**.

## How to Test

### Step 1: Open the Vocab Injection Submenu
```
1. Start the game
2. Select a plot (press J/K/L or ; to select one of the 4 plots)
3. Press 4 → "Tool: Meta"
4. Press Q → Opens vocab injection submenu
```

**Console output you should see:**
```
[INFO][INPUT] 📋 Opened vocab injection submenu
[INFO][INPUT] 📋 Submenu has 3 actions (Q/E/R)
[INFO][INPUT] 📋   Q: 🌻/🌿 (affinity: 12.45)
[INFO][INPUT] 📋   E: 🍄/🍂 (affinity: 8.32)
[INFO][INPUT] 📋   R: 🌾/👥 (affinity: 5.17)
```

### Step 2: Select an Option

From the options above, you can now press:
- **Q** → Inject the first option (🌻/🌿)
- **E** → Inject the second option (🍄/🍂)
- **R** → Inject the third option (🌾/👥)

**Press E:**
```
[INFO][INPUT] 📋 You selected: 🍄/🍂 - injecting...
[INFO][INPUT] + Injected vocab 🍄/🍂 into VolcanicWorlds
[INFO][INPUT] ✓ inject_vocabulary succeeded: {...}
```

### Step 3: Try F-Cycling (if multiple pages)

Press F to see next set of options:
```
[INFO][INPUT] 📋 Submenu page 2/3
[INFO][INPUT] 📋 Submenu has 3 actions (Q/E/R)
[INFO][INPUT] 📋   Q: 🌹/🔥 (affinity: 6.21)
...
```

## Troubleshooting

### "Opened vocab injection submenu" but no options listed
- Your biome might have all vocabulary already
- Or there's an error loading vocab pairs
- Check for warnings in console

### "Menu opened - Game PAUSED" appears
- You probably pressed Escape by mistake after opening the submenu
- Click the menu button or press Escape again to close it
- Then continue testing: press Q/E/R to inject

### Nothing happens when you press Q/E/R in submenu
- Check if console shows the Q/E/R options in "Submenu has X actions"
- Make sure you're NOT pressing Escape (it closes the submenu)
- Try pressing E (the "middle" option is usually safe to test)

### "Insufficient funds for vocab injection" error
- Your economy is low on energy
- Grow some wheat or do other farming to build up resources
- Try again after you have enough energy

## Console Output Reference

### Success Messages
```
[INFO][INPUT] 📋 Opened vocab injection submenu         ← Submenu opened
[INFO][INPUT] 📋 Submenu has 3 actions (Q/E/R)        ← Options loaded
[INFO][INPUT] 📋   Q: 🌻/🌿 (affinity: 12.45)         ← Option Q available
[INFO][INPUT] 📋 You selected: 🌻/🌿 - injecting...   ← You pressed Q
[INFO][INPUT] + Injected vocab 🌻/🌿 into [Biome]     ← SUCCESS
```

### Error Messages
```
[WARNING] BiomeAffinityCalculator: Could not find IconRegistry...   ← Minor (using fallback)
[INFO][INPUT] 📋 Submenu is empty!                      ← No vocab available
[INFO][INPUT] 📋 You pressed Q - no option in slot      ← Slot is empty
[INFO][INPUT] + Insufficient funds for vocab injection  ← Not enough energy
[INFO][INPUT] + [emoji] already in biome               ← Vocab already there
```

## What's Working vs What Needs UI

### ✅ Working:
- Submenu generation (dynamic based on biome affinity)
- Q/E/R selection (injects vocab into biome)
- F-cycling (pagination through vocab options)
- Economy cost calculation and deduction
- Error handling (insufficient funds, vocab already exists, etc.)
- Console logging (all feedback visible in console)

### 🚧 Not Yet Implemented (UI Layer):
- Visual overlay showing submenu options
- Affinity values displayed as bars/colors
- Page indicator (X/Y)
- Keyboard hints

## Next Steps

Once console-based testing confirms everything works:
1. Create an overlay panel to display submenu options visually
2. Show affinity as a progress bar or color gradient
3. Add page indicator
4. Add keyboard hints (press Q/E/R to select, F to cycle, Esc to cancel)

For now, the system is **fully functional** - just console-based!
