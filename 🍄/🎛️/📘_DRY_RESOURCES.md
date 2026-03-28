# 📘 DRY Resource Management Guide

## 🎯 Problem Solved

**Before (WET - Write Everything Twice):**
- Resources defined in `Scenarios/default.tres` ❌
- Resources defined in `Scenarios/new_game_easy.tres` ❌
- Resources defined in duplicated 🍄 profile loaders ❌
- Resources hardcoded in test scripts ❌
- **Result**: Update resources in 4+ places, easy to get out of sync!

**After (DRY - Don't Repeat Yourself):**
- Resources defined **ONCE** in `config/starter_resources.json` ✅
- Generate template: `🎛️/create_starter_template.sh` ✅
- **All systems auto-load from template** ✅
- **Result**: Update 1 file → regenerate → everything syncs!

---

## 🏗️ Architecture

### **Single Source of Truth: `config/starter_resources.json`**

```json
{
  "resources": {
    "👥": 220,  // Define ONCE
    "🌱": 50,   // Define ONCE
    "❄️": 60,   // Define ONCE
    // ...
  }
}
```

### **Template Generation Flow**

```
config/starter_resources.json
    ↓
🎛️/create_starter_template.sh
    ↓
user://saves/new_game_easy.tres  ← CANONICAL TEMPLATE
    ↓
    ├─→ New Games (auto-load)
    ├─→ Test Scenarios (load_new_game_template)
    ├─→ Milk Hunt Profiles (seed from template)
    └─→ Manual Tests (rig listener loads template)
```

### **Save System Priority (from SaveStore.gd:112-124)**

```gdscript
1. user://saves/new_game_easy.tres  ← USER OVERRIDE (DRY point!)
2. res://Scenarios/new_game_easy.tres  ← Project template
3. res://Scenarios/default.tres        ← Fallback
```

**Key Insight**: The save system already has a user override mechanism! We just needed to populate it.

---

## 📋 Usage

### **1. Update Resources (Edit ONCE)**

```bash
# Edit the single source of truth
code 🎛️/config/starter_resources.json

# Example change:
# "👥": 220  →  "👥": 300
```

### **2. Regenerate Template**

```bash
# Generate new template from config
🎛️/create_starter_template.sh

# Output:
# ✅ DRY Starter Template Created
# Template: user://saves/new_game_easy.tres
```

### **3. All Systems Updated!**

```bash
# New game - auto-loads updated resources
godot --path . --script Tests/test_game_loop.gd

# Milk hunt - uses updated template
🧪/🥛🖥️⚡.sh

# Rig listener - loads updated template
🎛️/🟢.sh

# Profile seeding - seeds from updated template
python3 🎛️/milk_hunt_seed_save.py --slot 2 --profile balanced_survival
```

**No code changes needed!** Just regenerate the template.

---

## 🔍 Verification

### **Check Existing Template**

```bash
🎛️/create_starter_template.sh --verify

# Output:
# ✅ Template exists: user://saves/new_game_easy.tres
# Modified: 2026-02-14 15:30:00
# Size: 4096 bytes
```

### **Dry Run (Preview Changes)**

```bash
🎛️/create_starter_template.sh --dry-run

# Output:
# [dry-run] Would create template with:
#   Resources: 20 items
#   Pairs: 1 items
#   Biomes: 2 + active: Village
```

### **Verify Template is Loaded**

```bash
# Start rig and check resource snapshot
🎛️/🟢.sh &
sleep 5
🎛️/✍️.sh '{"turn":1,"action":"resource_snapshot"}'
tail -1 .godot/godot/app_userdata/SpaceWheat\ -\ Quantum\ Farm/rig/results.jsonl
```

---

## 📊 Resource Economy Notes

### **Current Baseline (config/starter_resources.json)**

| Resource | Amount | Usage |
|----------|--------|-------|
| 👥 | 220 | 2.2 vocab injections with 👥-south (100 each) |
| 🌱 | 50 | 5 vocab injections (10 sprouts each) |
| ❄️ | 60 | 60 measure operations (CRITICAL FIX!) |
| 🍞 | 60 | 60 explore operations (economy pressure) |
| 🔥 | 30 | 30 Hadamard gates |
| 🦅 | 20 | 1 biome unlock (20 eagles per) |
| 🍼 | 2 | 2 harvest-all operations |

### **Action Costs (from EconomyConstants.gd)**

```gdscript
explore: 1 🍞
measure: 1 ❄️
reap: 1 👥
harvest_all: 1 🍼
discover_biome: 20 🦅
vocab_injection: 100 [south_emoji] + 10 🌱
```

### **Why 220 👥?**

Starter pair is `🌾/👥` (wheat north, people south).
Many quest rewards give pairs with `👥` as south pole.

```
Inject 🌾/👥: Costs 100 👥 + 10 🌱
Inject 📜/👥: Costs 100 👥 + 10 🌱
Inject 🧂/👥: Costs 100 👥 + 10 🌱
                    --------
Total for 2.2 injections: 220 👥
```

---

## 🔧 Integration with Existing Systems

### **Milk Hunt Profiles**

Profiles now **reference** the template instead of hardcoding:

```python
# OLD (WET):
"balanced_survival": {
    "resources": {
        "👥": 300,  # Hardcoded!
        "🌾": 300,  # Hardcoded!
        # ...
    }
}

# NEW (DRY):
"balanced_survival": {
    "description": "Loads from canonical template",
    "load_from_template": True,  # Uses new_game_easy.tres
    # Resources come from template automatically!
}
```

### **Test Scenarios**

Tests already use `load_new_game_template()`:

```gdscript
# Automatically loads from DRY template!
var state = SaveStore.load_new_game_template()
```

### **Rig Listener**

Already uses template via BootManager:

```gdscript
# Loads template by default
_farm = await boot_manager.boot_core(-1, "default", is_headless)
```

---

## 🚀 Migration Guide

### **Before Running First Time**

```bash
# 1. Create initial template from current best-practice resources
🎛️/create_starter_template.sh

# 2. Verify template was created
🎛️/create_starter_template.sh --verify

# 3. Test with a quick milk run
MAX_LOOPS=5 🧪/🥛🖥️⚡.sh
```

### **After Migration**

```bash
# Update resources system-wide:
# 1. Edit config/starter_resources.json
# 2. Regenerate template
🎛️/create_starter_template.sh
# 3. Done! All systems updated.
```

---

## 💡 Benefits

✅ **Single Source of Truth**: Resources defined in ONE place
✅ **No Code Changes**: Update config → regenerate → done
✅ **No Drift**: Impossible to have mismatched resources
✅ **Version Control Friendly**: JSON config is human-readable
✅ **Self-Documenting**: Config includes economy notes
✅ **Fast Iteration**: Change resources in seconds
✅ **Test Consistency**: All tests use same baseline

---

## 📝 Future Enhancements

### **Profile Variants**

```json
// config/profile_adjustments.json
{
  "probe_heavy": {
    "base_template": "starter_resources.json",
    "adjustments": {
      "🍞": "+50",  // More explores
      "❄️": "+50"   // More measures
    }
  }
}
```

### **Environment-Specific Templates**

```bash
# Development (generous resources)
ENV=dev 🎛️/create_starter_template.sh

# QA (balanced)
ENV=qa 🎛️/create_starter_template.sh

# Production (tight economy)
ENV=prod 🎛️/create_starter_template.sh
```

---

## ⚠️ Important Notes

1. **Template is User-Scoped**: Lives in `user://saves/` (per-user, not project)
2. **Regenerate After Changes**: Template won't update automatically
3. **Backup Before Regenerating**: Old template is overwritten
4. **Test After Changes**: Run quick smoke test after regeneration

---

## 🎓 Summary

**DRY Principle in Action:**
- ❌ Before: 4+ files defining resources
- ✅ After: 1 config → 1 template → all systems

**Workflow:**
```
Edit config/starter_resources.json
    ↓
Run 🎛️/create_starter_template.sh
    ↓
All systems automatically use new resources!
```

**This is how resource management should be done!** 🎉
