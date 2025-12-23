# 🌾💰 Dual-Farm Complete System

## Overview

A fully integrated farm system with **one grid, two biomes, six plots**, demonstrating the complete resource flow from classical inputs to quantum evolution and back to classical outputs.

## Farm Layout (3×2 Grid)

```
┌─────────────────────────────────────┐
│ FARMING BIOME          │ FARMING     │
├──────────┬──────────┬──────────┤
│ U (🌾)   │ I (🍄)   │ O (⌛)    │  Wheat, Mushroom, Imperial Noon
├──────────┼──────────┼──────────┤
│ P (⌛)    │ T (📈)   │ Y (🏭)   │  Imperial Midnight, Market, Mill
└──────────┴──────────┴──────────┘
  FARMING              MARKET BIOME
```

### Plot Details

| Plot | Position | Type | Biome | Properties |
|------|----------|------|-------|-----------|
| **U** | (0,0) | Wheat | FarmingBiome | Standard crop, 50/50 superposition |
| **I** | (1,0) | Mushroom | FarmingBiome | Special growth profile |
| **O** | (2,0) | Imperial Noon | FarmingBiome | θ locked at 3π/4 (high wheat bias) |
| **P** | (0,1) | Imperial Midnight | FarmingBiome | θ locked at π/4 (high labor bias) |
| **T** | (1,1) | Market | MarketBiome | Trading hub, coin energy → credits |
| **Y** | (2,1) | Mill | MarketBiome | Production, coin energy → credits |

## Resource Flow

### Input Layer (Classical)
```
Player Resources (per plot):
├─ Wheat: 0.22🌾
└─ Labor: 0.08👥
```

### Processing Layer (Quantum/Biomes)

**Farming Biome (UIOP):**
- Creates quantum superposition qubits
- Energy = wheat × 100 + labor × 50 = 26.0 per plot
- Evolves via Bloch sphere dynamics
- Supports constraints (Imperial plots)

**Market Biome (TY):**
- Creates coin energy qubits
- Base energy (T): 0.22 × 100 × (1 + 0.08 × 5) = 30.8 coin energy
- Base energy (Y): 0.15 × 100 × (1 + 0.10 × 5) = 22.5 coin energy
- No evolution—immediate convertibility

### Output Layer (Classical)

**From Farming (Measurement/Collapse):**
```
U: 0.13🌾 + 0.13👥  (balanced at θ=π/2)
I: 0.13🌾 + 0.13👥  (balanced at θ=π/2)
O: 0.04🌾 + 0.22👥  (labor-heavy, θ=3π/4)
P: 0.22🌾 + 0.04👥  (wheat-heavy, θ=π/4)
─────────────────────
Total: 0.52🌾 + 0.52👥
```

**From Market (Coin Harvest):**
```
T: 30.8 coin energy → 308 credits
Y: 22.5 coin energy → 225 credits
─────────────────────
Total: 533 credits
```

### Economy Summary
```
Starting:     50 credits
+ Wheat:      100 units
+ Farming:    0.52🌾 + 0.52👥
+ Market:     533 credits
= Final:      583 credits + 100 wheat
```

## Persistence

The entire state is saved to **GameStateManager** as a GameState resource:

**File:** `user://saves/dual_farm_complete.tres`

**Contents:**
- Scenario ID: "dual_farm_complete"
- Grid dimensions: 3×2
- 6 plot states (planted status, theta, phi, measurement state)
- Economy: 583 credits, 100 wheat, 0 flour
- Timestamp: System save time

**Verification:** State loads correctly with all properties preserved

## Architecture Benefits

### 1. **Unified Resource Interface**
- All plots accept same input (0.22🌾 + 0.08👥)
- Biomes determine output conversion
- No coupling between plot types and biome logic

### 2. **Optional Economy**
- Farming biome is self-contained (quantum evolution only)
- Market biome is self-contained (coin energy conversion)
- Players can choose farming focus, market focus, or hybrid

### 3. **Meaningful Constraints**
- Imperial plots demonstrate Bloch-lock with phase constraints
- O plot: constrained high wheat (θ=3π/4)
- P plot: constrained high labor (θ=π/4)
- Measurement respects constraints during collapse

### 4. **Complete Integration**
- Single Farm class manages both biomes
- FarmGrid stores all 6 plots uniformly
- FarmEconomy tracks classical resources
- GameState persists entire configuration

## Test Execution

### Run the Test
```bash
godot --headless -s test_dual_farm_complete.gd
```

### Output Stages
1. **SETUP** - Initialize grid, biomes, economy
2. **PLANTING** - Inject resources into both biomes
3. **MEASUREMENT** - Collapse qubits and harvest
4. **SAVE** - Persist state to disk
5. **LOAD** - Verify state reloads correctly

### Success Criteria
- ✅ All 6 plots planted successfully
- ✅ Farming biome produces 0.52🌾 + 0.52👥
- ✅ Market biome produces 533 credits
- ✅ State saved with all data intact
- ✅ State loads and matches save

## Next Steps

### UI Integration
- Use `GameState.grid_width/height` for layout
- Display 6 plots in 3×2 arrangement
- Show theta/phi for each plot (Bloch visualization)
- Render resources: wheat, labor, credits

### Extended Features
- (🌾,💰) Hybrid crop: starts in farming, harvests to both wheat AND flour
- Biome entanglement: adjacent plots can couple quantum states
- Tribute system: drain credits to affect market/farming behavior
- Multiple save slots with scenario progression

## Files Modified/Created

| File | Status | Purpose |
|------|--------|---------|
| `test_dual_farm_complete.gd` | NEW | Complete integration test |
| `Biome.gd` | MODIFIED | Added `inject_planting()` + `harvest_quantum_planting()` |
| `MarketBiome.gd` | MODIFIED | Fixed `get_coin_energy()` type checking |
| `WheatPlot.gd` | MODIFIED | Unified plant() signature for backward compatibility |
| `DUAL_FARM_COMPLETE.md` | NEW | This documentation |

## Verification Checklist

- [x] One Farm with 3×2 grid
- [x] Two independent biomes (Farming + Market)
- [x] Six plots using all major types (wheat, mushroom, imperial, market, mill)
- [x] Classical resource input interface (0.22🌾 + 0.08👥)
- [x] Quantum evolution in farming biome
- [x] Coin energy conversion in market biome
- [x] Measurement collapses superposition correctly
- [x] Constrained plots respect Bloch-lock
- [x] Economy tracks classical resources
- [x] Full save/load cycle verified
- [x] GameState persistence working

---

**Status:** ✅ Complete - Ready for UI team integration
