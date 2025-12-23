# 🌍 Biome Setup Guide

## Quick Summary

| Biome | Use Case | Quantum Evolution | Energy Transfer | Performance |
|-------|----------|-------------------|-----------------|-------------|
| **NullBiome** | UI Development | ❌ None | ❌ None | ⚡ Instant |
| **Biome** (normal) | Gameplay | ✅ Full | ✅ Full | ⚙️ Normal |
| **Biome** (is_static=true) | Debugging/Pause | ⏸️ Paused | ⏸️ Paused | ⚙️ Normal |

---

## 🎯 How to Use Each Biome

### Option 1: NullBiome (UI Testing) - RECOMMENDED FOR UI TEAM

**Use when**: Building UI components and you want zero quantum interference.

```gdscript
# In Farm.gd or your test file
var NullBiome = preload("res://Core/Environment/NullBiome.gd")

var biome = NullBiome.new()
biome._ready()

# Now use with FarmGrid
grid.biome = biome

# NullBiome will:
# ✓ Not evolve quantum states
# ✓ Not transfer energy
# ✓ Not change temperature
# ✓ Stay completely inert
```

**Pros**:
- Zero quantum interference
- Extremely lightweight
- UI renders at max speed
- Perfect for UI layout/styling experiments

**Cons**:
- No quantum mechanics
- Not representative of real gameplay

---

### Option 2: Normal Biome with is_static Flag (For Debugging)

**Use when**: You want quantum mechanics available but paused for inspection.

```gdscript
var Biome = preload("res://Core/Environment/Biome.gd")

var biome = Biome.new()
biome.is_static = true  # ← Pause all evolution
biome._ready()

# Quantum states exist but don't evolve
```

**Pros**:
- Full quantum interface available
- Can inspect quantum states
- Can toggle evolution on/off easily
- Good for debugging

**Cons**:
- Still heavier than NullBiome
- Not good for UI rendering performance

---

### Option 3: Normal Biome (Full Gameplay)

**Use when**: Running real game scenarios with full quantum mechanics.

```gdscript
var Biome = preload("res://Core/Environment/Biome.gd")

var biome = Biome.new()
biome.grid = grid
biome._ready()

# No is_static flag - full evolution!
# Quantum states will evolve
# Energy will transfer
# Temperature will vary with day/night cycle
```

**Pros**:
- Full quantum mechanics
- Realistic gameplay
- All features work (energy taps, growth, etc.)

**Cons**:
- More computationally expensive
- Quantum evolution might interfere with UI work

---

## 🔄 Switching Between Biomes

All three biomes implement a compatible interface, so you can swap them:

```gdscript
# Easy swap for different scenarios
func create_biome_for_scenario(scenario_type: String):
    match scenario_type:
        "ui_testing":
            return NullBiome.new()

        "debug_paused":
            var biome = Biome.new()
            biome.is_static = true
            return biome

        "full_gameplay":
            return Biome.new()
```

---

## ✅ Current Status

- ✅ **NullBiome** created and tested
- ✅ **Normal Biome** working with full evolution
- ✅ **Static Mode** tested and working
- ✅ All three modes compatible

---

## 📝 Recommendations

### For UI Team:
```
Use: NullBiome
Why: Zero quantum interference, max rendering speed
```

### For Gameplay Team:
```
Use: Normal Biome (is_static=false)
Why: Full quantum mechanics needed for gameplay
```

### For Debugging:
```
Use: Normal Biome (is_static=true)
Why: Can inspect states without evolution
```

---

## 🧪 Testing Biomes

Run the test suite:
```bash
godot --headless -s test_biome_modes.gd
```

This verifies:
- NullBiome works (nothing happens)
- Normal Biome works (evolution occurs)
- Static mode works (evolution paused)
- Interfaces are compatible

---

## Files

| File | Purpose |
|------|---------|
| `Core/Environment/NullBiome.gd` | Inert test biome |
| `Core/Environment/Biome.gd` | Full quantum biome |
| `test_biome_modes.gd` | Verification tests |
| `BIOME_SETUP_GUIDE.md` | This guide |

---

## ❓ FAQ

**Q: Can I use NullBiome in production?**
A: Yes, if you want a mode where nothing quantum happens. Good for menus, UI screens.

**Q: How do I enable evolution again if I used is_static?**
A: `biome.is_static = false`

**Q: Does NullBiome break anything?**
A: No, it's a stub that does nothing. All methods return safely.

**Q: Performance impact?**
A: NullBiome is fastest, Normal Biome with evolution is slowest. Choose based on needs.

**Q: Can I mix biome modes?**
A: Not recommended - pick one per farm/game session.

---

**Status**: ✅ All biome modes ready for use!
