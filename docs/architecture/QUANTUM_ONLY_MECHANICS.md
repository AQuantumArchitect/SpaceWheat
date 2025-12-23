# Quantum-Only Mechanics (No Classical Growth!)

## Summary

**Removed all classical factory-farm mechanics.** Plants now appear instantly at full size. Gameplay is purely about manipulating quantum probability ratios through entanglement.

## Core Changes

### 1. **NO Time-Based Growth** ❌🕐
- Deleted `growth_progress` variable entirely
- Deleted `is_mature` flag
- Deleted all energy accumulation logic
- Plants appear **instantly at full size** when planted

###2. **Instant Quantum State** ⚛️✨
- Plant → appears immediately
- Starts at θ = π/2 (50/50 superposition)
- NO waiting, NO maturity threshold
- Pure quantum probability manipulation

### 3. **Measurement Effects** 👁️
When you measure a plot:

1. **Samples probability distribution**
   - P(🌾) = cos²(θ/2)
   - P(👥) = sin²(θ/2)
   - Random outcome based on current theta

2. **FREEZES theta drift** ❄️
   - `theta_frozen = true`
   - Theta stops evolving (locked in)
   - Phi (azimuthal) still precesses

3. **DETANGLES from quantum network** 🔓
   - Breaks all entanglements
   - Removes from quantum superposition space
   - Pulls out into classical observation

4. **Creates conspiracy bond** 🔗
   - `conspiracy_bond_strength += 1.0`
   - Classical correlation persists
   - Plot becomes "known" to network

### 4. **Harvest Mechanics** ✂️
- **MUST measure before harvest**
- If measured as 🌾 wheat → get wheat yield
- If measured as 👥 labor → return people (investment back)
- No time gate, can harvest immediately after measuring

## Gameplay Loop

```
1. Plant → instant full size, θ = π/2
   ↓
2. Manipulate theta via entanglement
   - Entangled plots: θ → π/2 (uncertain)
   - Isolated plots: θ → 0 (certain wheat)
   ↓
3. Measure when happy with probability
   - Samples P(🌾) vs P(👥)
   - Freezes theta
   - Detangles
   ↓
4. Harvest
   - Wheat: get yield
   - Labor: get people back
```

## Theta Manipulation

**How to control probabilities:**

| Action | Effect on θ | P(🌾 wheat) | Strategy |
|--------|-------------|-------------|----------|
| Isolate plot | θ → 0 | ~100% | Certain wheat |
| Entangle plot | θ → π/2 | ~50% | Risky/uncertain |
| Chaos bonus | θ - π/4 | Increases | Lucky shift |
| Chaos disaster | θ + π/3 | Decreases | Unlucky shift |
| Icons | Various | Varies | TBD |

**Theta values:**
- θ = 0: 100% wheat, 0% labor
- θ = π/4: ~85% wheat, ~15% labor
- θ = π/2: 50% wheat, 50% labor
- θ = 3π/4: ~15% wheat, ~85% labor
- θ = π: 0% wheat, 100% labor

## Implementation Status

### ✅ Completed
- [x] Removed growth_progress and all energy accumulation
- [x] Removed maturity threshold
- [x] Plants instant full size
- [x] Measurement freezes theta drift
- [x] Measurement detangles entanglements
- [x] Harvest requires measurement
- [x] Harvest returns people if labor outcome
- [x] Chaos events manipulate theta (not energy)
- [x] Status displays show probability instead of growth

### ✅ All Core Features Complete
- [x] QuantumNode.gd visualization (FIXED - uses constant MAX_RADIUS)
- [x] PlotTile.gd visualization (FIXED - always shows mature state when planted)
- [x] Force graph visual pull for measured nodes (COMPLETE - 20x stronger tether)
- [x] GameController harvest_all (FIXED - checks is_planted instead of is_mature)
- [x] FarmGrid harvest functions (FIXED - all is_mature → is_planted)
- [x] FarmView bubble click logic (FIXED - instant harvest after measure)
- [x] Save/Load system (FIXED - removed growth_progress and is_mature)

### ⚠️ Remaining Enhancements
- [ ] Theta visualization improvements (color/glow based on probability)
- [ ] Test files need updating (references old growth/maturity)

## Visualization TODOs

Since size no longer scales with growth, visual representation needs to change:

1. **All plants same size** - instant full size
2. **Theta visualized through:**
   - Color gradient (wheat color vs labor color)
   - Glow/shimmer for superposition
   - Certainty indicator
3. **Measurement visual:**
   - Distinct appearance when measured
   - Show frozen state
   - Pull stronger in force graph

## Benefits

1. **Pure Quantum Gameplay** - No factory mechanics
2. **No Waiting** - Instant action, manipulate probabilities
3. **Strategic Entanglement** - Control theta through network topology
4. **Measurement Matters** - Irreversible observation with consequences
5. **Risk/Reward** - Entanglement = uncertain but interesting

## Breaking Changes

**Old way:**
- Plant → wait for growth → measure when mature → harvest
- Time-based progression
- Factory-style optimization

**New way:**
- Plant (instant) → manipulate theta → measure → harvest
- Probability-based strategy
- Quantum state engineering

**Migration:**
- No save compatibility (growth_progress removed)
- UI needs updating (show theta, not growth)
- Visualization needs updating (size, not time)

## Next Steps

1. ✅ ~~Fix visualization errors (QuantumNode, PlotTile)~~ COMPLETE
2. ✅ ~~Add force graph measured node visual (stronger pull)~~ COMPLETE
3. Implement theta visualization (color/glow based on probability ratio)
4. Playtest quantum-only mechanics!
5. Update documentation with gameplay strategies

This is a **radical simplification** that makes the game fully quantum-focused! 🎮⚛️
