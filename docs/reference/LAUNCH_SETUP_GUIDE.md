# Godot Launch Setup Guide

## Current Status

**Current Main Scene**: `res://scenes/FarmView.tscn`

When you run `godot`, it loads FarmView which:
- ✅ Creates a fresh Farm simulation (clean every launch)
- ✅ Initializes all game systems (grid, economy, goals, factions)
- ✅ Sets up UILayoutManager for parametric layout
- ✅ Loads VocabularyEvolution system
- ✅ Ready for gameplay

## Setup for New Layout

### **Step 1: Provide Scene Path**

Tell me the exact path to your new layout scene. For example:
- `res://scenes/MainLayout.tscn`
- `res://UI/NewMainUI.tscn`
- `res://scenes/GameBoard.tscn`

### **Step 2: Choose Integration Approach**

#### **Option A: Replace FarmView (Recommended if new layout is complete)**
Your new scene becomes the main scene. It should:
1. Extend `Control` (or Node)
2. Create/reference a Farm instance:
   ```gdscript
   var farm = Farm.new()
   add_child(farm)
   ```
3. Set up your UI layout around it
4. Connect to the farm systems (grid, biome, economy)

**How to set it up:**
```bash
./SET_MAIN_SCENE.sh res://scenes/YourNewLayout.tscn
```

Then launch:
```bash
godot
```

#### **Option B: Wrapper Scene (Best for gradual migration)**
Keep FarmView.tscn as-is, create a new wrapper that contains it:
1. Create new scene: `res://scenes/GameBoard.tscn`
2. Structure:
   ```
   GameBoard (Control)
   ├── YourNewUILayout (custom layout)
   └── FarmViewInstance (FarmView.tscn)
   ```
3. Set GameBoard as main scene

#### **Option C: Modify FarmView.tscn (Simplest if UI is just a layout change)**
If your new layout is just a rearrangement of the existing UI:
1. Open `res://scenes/FarmView.tscn` in editor
2. Rearrange the nodes to match your layout
3. Save
4. Launch with `godot`

## Quick Start Commands

### **Set Your New Scene as Main**
```bash
cd /home/tehcr33d/ws/SpaceWheat
./SET_MAIN_SCENE.sh res://scenes/YOUR_SCENE_NAME.tscn
godot
```

### **Revert to FarmView (if needed)**
```bash
./SET_MAIN_SCENE.sh res://scenes/FarmView.tscn
```

### **Check Current Main Scene**
```bash
grep "run/main_scene" project.godot
```

## FarmView Architecture

FarmView initializes systems in this order:

1. **UILayoutManager** (line 131) - Parametric layout system
2. **Farm** (line 137) - Core simulation
   - Creates Biome (quantum substrate)
   - Creates FarmGrid (6x1 grid of plots)
   - Creates FarmEconomy
   - Creates GoalsSystem
   - Creates FactionManager
3. **GameController** (line 157) - Game logic
4. **VocabularyEvolution** (line 188) - Procedural vocabulary
5. **Icon Fields** (if enabled) - Visual particle systems
6. **UI Panels** (line 230+) - Info, resources, goals, actions

All these are accessible as properties:
```gdscript
# In your layout script
var farm = $FarmView.farm  # Or however you reference it
var grid = farm.grid
var biome = farm.biome
var economy = farm.economy
```

## If You Created a New Scene in the Editor

If you created a `.tscn` file in the Godot editor:

1. **Find the file path** - Open file system and note the path
2. **Tell me the path** - Copy the path from the editor
3. **I'll set it up** - I'll configure it as the main scene

Or manually:
1. Open `project.godot`
2. Find the line: `run/main_scene="..."`
3. Replace with your scene path
4. Save and launch `godot`

## Testing Your Setup

After setting up your new scene, verify it works:

```bash
# Method 1: Launch Godot
godot

# Method 2: Headless verification (just check it loads)
godot --headless -s verify_scenario_loads.gd

# Method 3: Run with tests
timeout 30 godot --headless -s verify_saves_simple.gd
```

## Common Issues

### **Scene Doesn't Load**
- Check the path is correct (case-sensitive on Linux)
- Verify the scene file exists: `ls -la res://scenes/YOUR_SCENE_NAME.tscn`
- Check for compile errors in the script

### **No Farm/Simulation**
- Ensure your scene creates/references a Farm instance
- Check FarmView.gd line 137 for the pattern: `farm = Farm.new()`

### **UI Doesn't Show**
- Make sure you add UI elements as children to Control nodes
- Check that layout nodes have proper anchors/layout settings
- Use UILayoutManager if you want parametric positioning

### **Save/Load Not Working**
- Verify GameStateManager is auto-loaded: `grep GameStateManager project.godot`
- Check that farm/biome/grid are properly initialized
- Review SAVE_VALIDATION_SUMMARY.md for format requirements

## Next: Tell Me Your Scene Details

Please provide:
1. **Scene file path**: (e.g., `res://scenes/MainLayout.tscn`)
2. **What does it contain**: (UI layout description)
3. **Should it replace FarmView?** (yes/no/partial)

Then I can:
- Set it as the main scene
- Ensure it properly initializes the simulation
- Verify it boots correctly with `godot`
