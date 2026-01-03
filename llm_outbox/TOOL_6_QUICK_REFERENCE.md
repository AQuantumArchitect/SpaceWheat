# Tool 6: Biome Management - Quick Reference

**Tool Number:** 6
**Tool Emoji:** 🌍
**Tool Name:** Biome

---

## Quick Actions

```
Press 6 → Select Tool 6 (Biome Management)

Q = Assign Biome ▸     Opens submenu to reassign plots
E = Clear Assignment   Remove biome from selected plots
R = Inspect Plot       Show detailed plot information
```

---

## Q: Assign Biome (Submenu)

**Opens dynamic submenu showing all registered biomes**

```
6-Q → Opens submenu

Example submenu:
  Q = 🌾 BioticFlux
  E = 🏪 Market
  R = 🌲 Forest
```

**What it does:**
- Reassigns selected plots to chosen biome
- Preserves quantum states (energy, north/south)
- Preserves entanglement links
- Future operations use new biome's bath

**Example:**
```
1. Select plots with T/Y/U/I/O/P
2. Press 6 (Biome tool)
3. Press Q (Open submenu)
4. Press E (Assign to Market)

Result: Selected plots now belong to Market biome
```

---

## E: Clear Assignment

**Removes biome assignment from plots**

```
6-E → Clear biome assignment
```

**What it does:**
- Removes plot from biome registry
- Plot becomes "orphaned"
- Future operations will fail until reassigned
- Use case: Reset plots before reassignment

**Warning:** Clearing assignment on a planted plot leaves it in limbo. Reassign before using other tools.

---

## R: Inspect Plot

**Shows comprehensive plot metadata**

```
6-R → Inspect selected plot
```

**Information displayed:**
- 🌍 Current biome assignment
- 🌱 Planted status (YES/NO)
- ⚛️  Quantum state (north emoji, south emoji, energy)
- 🔗 Entanglement links
- 🛁 Bath projection status

**Example output:**
```
🔍 PLOT INSPECTION
─────────────────────────────────────────

📍 Plot (0, 0):
   🌍 Biome: BioticFlux
   🌱 Planted: YES
      Has been measured: NO
      ⚛️  State: 🌾 ↔ 👥 | Energy: 0.785
   🔗 Entangled: NO
   🛁 Bath Projection: Active
      North: 🌾 | South: 👥

─────────────────────────────────────────
```

---

## Common Workflows

### Move Plot to Different Biome
```
1. Press 6 (Biome tool)
2. Select plot with T/Y/U/I/O/P
3. Press Q (Assign Biome submenu)
4. Press Q/E/R (Choose target biome)

✅ Plot reassigned, quantum state preserved
```

### Check Plot Details
```
1. Press 6 (Biome tool)
2. Select plot with T/Y/U/I/O/P
3. Press R (Inspect)

✅ Console shows full plot metadata
```

### Reset Plot Before Reassignment
```
1. Press 6 (Biome tool)
2. Select plot with T/Y/U/I/O/P
3. Press E (Clear assignment)
4. Press Q (Assign Biome submenu)
5. Press Q/E/R (Choose new biome)

✅ Plot cleanly reassigned
```

### Batch Reassign Multiple Plots
```
1. Press T, Y, U (Select plots 0, 1, 2)
2. Press 6 (Biome tool)
3. Press Q (Assign Biome submenu)
4. Press E (Market)

✅ All 3 plots reassigned to Market
```

---

## Tips & Tricks

### Strategic Biome Switching
- Move high-energy plots to Market for economic gains
- Move mushroom plots to Forest for ecosystem synergy
- Experiment with different biome combinations

### Quantum State Monitoring
- Use R (Inspect) to track quantum energy buildup
- Reassign before measurement to change outcome probability
- Check entanglement status before breaking links

### Debugging
- Use R (Inspect) to diagnose plot issues
- Check biome assignment if operations fail
- Verify bath projection is active

---

## FAQ

**Q: What happens to quantum state when I reassign a plot?**
A: Quantum state persists! North/south emojis and energy are preserved. Only the biome reference changes.

**Q: Can I reassign entangled plots?**
A: Yes! Entanglement links persist even across biome changes.

**Q: What if I clear assignment on a planted plot?**
A: Plot becomes orphaned. You can still inspect it, but planting/harvesting will fail until you reassign.

**Q: How many biomes can appear in the submenu?**
A: Currently first 3 registered biomes. Pagination for >3 biomes is a future enhancement.

**Q: Can I create custom biomes?**
A: Not yet from Tool 6, but you can register custom biomes in Farm._ready(). They'll appear in the submenu automatically!

**Q: Does reassignment affect save files?**
A: Yes! Plot assignments are saved and restored correctly.

---

## Keyboard Layout

```
┌─────────────────────────────────────┐
│  Tool 6: Biome Management 🌍        │
├─────────────────────────────────────┤
│                                     │
│   Q = Assign Biome ▸                │
│   E = Clear Assignment              │
│   R = Inspect Plot                  │
│                                     │
│  Plot Selection:                    │
│   T Y U I O P = Plots 1-6           │
│   [ = Deselect all                  │
│                                     │
└─────────────────────────────────────┘
```

---

## See Also

- `TOOL_6_MANUAL_TEST_GUIDE.md` - Comprehensive testing scenarios
- `TOOL_6_BIOME_MANAGEMENT_COMPLETE.md` - Full technical documentation
- `SESSION_SUMMARY_2026-01-02.md` - Implementation summary
