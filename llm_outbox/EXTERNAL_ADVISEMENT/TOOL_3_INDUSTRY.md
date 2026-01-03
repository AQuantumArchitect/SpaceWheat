# Tool 3: INDUSTRY System Design

## Current Status

**Implementation**: ❌ Not Started
**UI**: ✅ Complete (submenu shows Mill, Market, Kitchen options)
**Backend**: ❌ Missing entirely

```
Q: Build Submenu (Mill/Market/Kitchen)
├─ Q: Place Mill (🏭)
├─ E: Place Market (🏪)
└─ R: Place Kitchen (🍳)
```

---

## Questions for Design

### Question 1: BUILDING PLACEMENT MECHANICS

**What is the spatial model for buildings?**

#### Option A: Grid-Based Overlay
- Buildings occupy farm plot spaces (same 6×2 grid)
- Tradeoff: Buildings compete with crop plots
- Implications:
  - Max 12 buildings total (but 1 plot = 1 building)
  - Player must choose farming vs. industry
  - Simpler implementation

#### Option B: Floating UI Sidebar
- Buildings don't occupy grid space
- Buildings exist as UI elements showing production rates
- Tradeoff: More buildings possible, but no spatial strategy
- Implications:
  - Buildings don't affect plot selection
  - UI becomes more complex
  - Allows unlimited buildings

#### Option C: Separate Scene Nodes
- Buildings are visual scene nodes overlaid on map
- Plots can have associated buildings (1-to-many)
- Tradeoff: Most complex, highest visual potential
- Implications:
  - Can stack buildings on biome regions
  - Requires 3D/visual positioning
  - Most implementation effort

**Recommendation needed**: Which model fits game design intent?

---

### Question 2: BUILDING COSTS & LIMITS

**What resources do buildings cost, and how many can player have?**

#### Option A: Scaling Resource Costs
- Mill: 50 🌾 (grain production facility)
- Market: 100 💰 (trading hub) or 50 👥 (labor to manage)
- Kitchen: 75 🌾 + 50 👥 (ingredient sourcing + staffing)
- Limit: 1 of each type

#### Option B: Unified Economy Cost
- All buildings cost 1 quantum unit equivalent
- Cost: 10 💰 or 10 👥 (standardized)
- Limit: 3 total buildings (no type restrictions)

#### Option C: Progression-Based Unlock
- First building free (tutorial)
- Second building: 50 🌾
- Third building: 100 💰
- Etc. (costs increase)

**Recommendation needed**: Cost model and maximum building counts?

---

### Question 3: BUILDING EFFECTS ON ECONOMY

**How do buildings affect resource generation?**

#### Option A: Production Multipliers
- **Mill** (🏭): +50% wheat production (multiply harvest yields by 1.5x)
- **Market** (🏪): +1 💰 per harvest (bonus credits)
- **Kitchen** (🍳): Generate new emoji ✨ (bread production)

#### Option B: Passive Income
- **Mill**: Generate 5 🌾 per day (passive wheat growth)
- **Market**: Generate 2 💰 per day (passive trading)
- **Kitchen**: Generate 1 ✨ per day (passive food)

#### Option C: Quantum Effects
- **Mill**: Boost Hamiltonian coupling in BioticFlux biome (+20% growth rate)
- **Market**: Reduce measurement cost (cheaper POSTSELECT_COSTED)
- **Kitchen**: Inject new emojis into quantum bath (expand Hilbert space)

#### Option D: No Direct Effects
- Buildings purely aesthetic/organizational
- UI elements for tracking resources
- Effects added in future phases

**Recommendation needed**: Which effect model creates engaging gameplay?

---

### Question 4: BUILDING PLACEMENT INTERACTION WITH BIOMES

**How do buildings interact with the 4 biomes?**

#### Option A: Biome-Specific
- Can only place buildings in certain biomes
- Mill in BioticFlux (wheat grows here)
- Market in Market biome (already thematic!)
- Kitchen in Kitchen biome (food production)

#### Option B: Biome-Agnostic
- Buildings work anywhere on the farm
- Effects apply globally to all crops
- No biome restrictions

#### Option C: Biome Affinity
- Buildings work best in "native" biome (+100% effect)
- Work elsewhere at reduced effect (+50%)
- Allows strategy (place Mill in BioticFlux vs. Forest)

**Recommendation needed**: Should buildings have biome affinity?

---

### Question 5: BUILDING PERSISTENCE & REMOVAL

**Can buildings be modified after placement?**

#### Option A: Permanent
- Once placed, buildings stay forever
- Cannot be removed or relocated
- Makes placement decisions consequential

#### Option B: Removable with Cost
- Can remove buildings (get 50% cost refund)
- Can relocate buildings (costs 10% of original price)
- Allows strategy adjustment

#### Option C: Destructible
- Buildings have durability
- Can break/wear out (need repair)
- Creates ongoing cost/maintenance gameplay

**Recommendation needed**: Should buildings be permanent or modifiable?

---

## Summary of Design Branches

| Aspect | Option | Complexity | Gameplay Impact |
|--------|--------|-----------|-----------------|
| **Placement** | Grid / UI / Nodes | Low / Med / High | Strategic / Flexible / Visual |
| **Cost** | Scaling / Unified / Progression | Med / Low / High | Economy depth / Simplicity / Long-term |
| **Effects** | Multipliers / Passive / Quantum / None | Med / Low / High / Low | Direct / Slow / Complex / Future |
| **Biomes** | Specific / Agnostic / Affinity | Med / Low / High | Restriction / Freedom / Depth |
| **Persistence** | Permanent / Removable / Destructible | Low / Med / High | Commitment / Flexibility / Maintenance |

---

## Current System Context

### Farm Grid
- Size: 6×2 (12 plots total)
- Biomes: BioticFlux, Market, Forest, Kitchen (4 regions)
- Each plot can hold: wheat, mushroom, or tomato

### Economy Resources
- **🌾 Wheat**: 500 credits (farming currency)
- **👥 Labor**: 10 credits (workforce)
- **🍄 Mushroom**: 10 credits (alternative crop)
- **🍅 Tomato**: 0 credits (discovered late)
- **💰 Credits**: 1 credit (general currency)

### Existing Building Mentions in Code
- Mill references exist but unimplemented
- Market biome exists (separate from tool buildings)
- Kitchen biome exists (separate from tool buildings)
- Suggests buildings are distinct from biomes

---

## Questions for External Review

1. **Thematic fit**: Should buildings reinforce the quantum theme, or are they purely economic?
2. **Complexity budget**: Is this system worth implementation complexity, or should it be simpler?
3. **Player fantasy**: What do buildings represent to the player? (Factories? Markets? Infrastructure?)
4. **Progression**: Should building placement be a late-game feature or available from start?
5. **Balance**: How should building benefits compare to pure farming strategy?

---

## Recommendation for Implementation Sequence

Once design decisions are made:
1. Choose placement model (A, B, or C)
2. Choose cost model (A, B, or C)
3. Choose effects model (A, B, C, or D)
4. Implement building data structure
5. Implement placement UI/logic
6. Wire effects into farm simulation
7. Integration testing with crops + harvests
8. Balancing & playtesting

**Estimated effort**: 4-6 hours of coding (after design is set)

