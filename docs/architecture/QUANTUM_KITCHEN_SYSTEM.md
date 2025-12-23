# 🍳 Quantum Kitchen: Triple Bell State to Bread

## Overview

The **Quantum Kitchen** is a specialized biome that converts quantum superpositions into bread through **triple Bell state measurement**.

Unlike classical recipes where ingredients are mixed, the kitchen requires inputs to be in a maximally **entangled quantum state**. The plot arrangement itself acts as a "quantum gate" that defines the entanglement pattern.

### Core Concept

```
Three Separate Qubits              Arranged in Space              Bell State Detected
🌾 Wheat, 💧 Water, 🌾 Flour  →  Plot positions (gate)  →  Triplet measurement ready
```

**Key Insight:** The kitchen doesn't "combine" resources classically. It **measures an entangled triplet** and collapses them into bread while consuming the original qubits.

---

## System Architecture

### Files

```
Core/QuantumSubstrate/
├── BellStateDetector.gd          # Detects Bell states from plot positions

Core/Environment/
├── QuantumKitchen_Biome.gd       # Kitchen measurement and bread production

Tests/
└── test_quantum_kitchen.gd       # Tests: GHZ horizontal/vertical, W state
```

---

## Bell State System

### What is a Triple Bell State?

A **Bell state** is a maximally entangled quantum state. In the kitchen, three qubits must be entangled to produce bread.

**Common 3-qubit Bell States:**

| Name | Pattern | Description |
|------|---------|-------------|
| **GHZ (Horizontal)** | `--- (line)` | Three plots in a row: (0,0), (1,0), (2,0) |
| **GHZ (Vertical)** | `\| (line)` | Three plots in a column: (0,0), (0,1), (0,2) |
| **GHZ (Diagonal)** | `\ (line)` | Three plots diagonal: (0,0), (1,1), (2,2) |
| **W State** | `L (corner)` | L-shaped arrangement (robust to loss) |
| **Cluster State** | `T (tee)` | T-shaped (one-way computation ready) |

### Plot Arrangement as Gate Action

The **spatial arrangement of plots defines the quantum gate**:

```
GHZ Horizontal (0,0)-(1,0)-(2,0):
   Wheat Water Flour
   |_________|_________|

Produces: |000⟩ + |111⟩ entanglement
Meaning: All qubits perfectly correlated
Property: Pure bread state (theta = 0°)
```

```
GHZ Vertical (0,0)-(0,1)-(0,2):
   Wheat
   |
   Water
   |
   Flour

Produces: |000⟩ + |111⟩ entanglement
Meaning: All qubits correlated in sequence
Property: Lean toward bread (theta = 45°)
```

```
W State L-shape (0,0)-(0,1)-(1,1):
   Wheat  Flour
   |      /
   Water-

Produces: |001⟩ + |010⟩ + |100⟩
Meaning: Any one qubit can be different
Property: Robust (theta = 270°) - emphasizes inputs
```

---

## Kitchen Mechanics

### Flow Diagram

```
┌────────────────────────────────────────┐
│ 1. PLOT ARRANGEMENT                    │
│    Player arranges three plots in      │
│    physical space (defines gate)       │
└────────────┬─────────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ 2. BELL STATE DETECTION                │
│    BellStateDetector analyzes          │
│    positions and identifies state      │
└────────────┬─────────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ 3. VERIFICATION                        │
│    Check Bell state is valid           │
│    Check input qubits have energy      │
└────────────┬─────────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ 4. MEASUREMENT                         │
│    Measure each input qubit            │
│    Collapse triplet to classical       │
│    Calculate bread energy              │
└────────────┬─────────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ 5. CONSUMPTION                         │
│    Consume input qubits                │
│    Create bread qubit                  │
│    Store entanglement pattern          │
└────────────┬─────────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ 6. PRODUCTION                          │
│    Bread qubit ready for guild         │
│    consumption or storage              │
└────────────────────────────────────────┘
```

### Step-by-Step: Bread Production

#### 1. Set Input Qubits

```gdscript
var wheat = DualEmojiQubit.new("🌾", "💼", PI/2)
wheat.radius = 0.8

var water = DualEmojiQubit.new("💧", "☀️", PI/2)
water.radius = 0.6

var flour = DualEmojiQubit.new("🌾", "💼", PI/3)
flour.radius = 0.7

kitchen.set_input_qubits(wheat, water, flour)
```

#### 2. Configure Bell State from Plot Positions

```gdscript
# Plot arrangement acts as quantum gate
var positions = [
    Vector2i(0, 0),  # Wheat position
    Vector2i(1, 0),  # Water position
    Vector2i(2, 0)   # Flour position (horizontal line)
]

var is_valid = kitchen.configure_bell_state(positions)
# Returns: true (valid GHZ horizontal state)
```

#### 3. Measure and Produce

```gdscript
if kitchen.can_produce_bread():
    var bread = kitchen.produce_bread()
    # Output: Bread qubit (🍞, (🌾🌾💧))
```

### Measurement Process

**Step 1: Verify Bell State**
```
Type: GHZ (Horizontal)
Strength: 100% (perfect entanglement)
Description: |000⟩ + |111⟩ maximally entangled
```

**Step 2: Measure Each Input**
```
🌾 Wheat:  P(state1) = 50% → measured: state 2 (value: 0.50)
💧 Water:  P(state1) = 50% → measured: state 1 (value: 0.50)
🌾 Flour:  P(state1) = 25% → measured: state 1 (value: 0.25)
```

**Step 3: Calculate Bread Energy**
```
Wheat contribution:  0.80 * 0.50 = 0.40
Water contribution:  0.60 * 0.50 = 0.30
Flour contribution:  0.70 * 0.25 = 0.17
                                  ------
Total energy:                      0.88

Efficiency factor:    80%
Bread energy produced: 0.88 * 0.8 = 0.70
```

**Step 4: Collapse Inputs**
```
Wheat remaining: 0.80 * (1 - 0.8*0.5) = 0.48
Water remaining: 0.60 * (1 - 0.8*0.3) = 0.46
Flour remaining: 0.70 * (1 - 0.8*0.5) = 0.42
```

**Step 5: Create Bread Qubit**
```
Qubit: (🍞, (🌾🌾💧))
Energy: 0.70
Theta: 0.0 rad (0°) for GHZ horizontal
       (Different Bell states produce different theta)
```

---

## Bell State Properties

### GHZ States (Horizontal, Vertical, Diagonal)

**Pattern:** Three qubits in a line
**Math:** |000⟩ + |111⟩ (perfectly correlated)
**Property:** All measurements perfectly agree

**Theta Output Mapping:**
- Horizontal: 0° (pure bread state)
- Vertical: 45° (lean toward bread)
- Diagonal: 90° (balanced)

**Interpretation:** Strong coordination between inputs. Bread is "pure" - minimal input linkage.

### W State (L-Shape)

**Pattern:** Two in line, one perpendicular
**Math:** |001⟩ + |010⟩ + |100⟩
**Property:** Any one qubit can differ (robust to measurement error)

**Theta Output:** 270° (lean toward inputs)

**Interpretation:** More flexible arrangement. Bread is "hybrid" - links back to inputs more strongly.

### Cluster State (T-Shape)

**Pattern:** Linear arrangement with perpendicular offset
**Math:** Measurement-based computation pattern
**Property:** Best for sequential measurement-based protocols

**Theta Output:** 180° (pure input state)

**Interpretation:** Maximum entanglement with inputs. Bread remembers exactly what created it.

---

## Integration with Game Systems

### With Farming Biome

```
Farming Biome produces:
  - 🌾 Wheat with energy
  - 💧 Water (requires new biome, deferred)
  - 🌾 Flour from mill

    ↓

Kitchen requires all three in Bell state arrangement
  - Player arranges plots spatially
  - Defines the quantum gate

    ↓

Kitchen measures triplet
  → Collapses to bread
  → Energy consumed from inputs
  → New bread qubit created
```

### With Guild System

```
Bread qubit created by kitchen
  ↓
Linked to economic biome
  ↓
Guilds drain bread energy (constant consumption)
  - Creates demand for kitchen production
  - Motivates player to arrange plots repeatedly
  - Bread scarcity pushes market (guilds apply pressure)
  ↓
Player responds to market conditions
  - Decides when to make bread
  - Chooses which Bell state arrangement
  - Optimizes production timing
```

### With GameStateManager

```gdscript
# Save bread qubit to game state
game_state.bread_qubit = kitchen.get_bread_qubit()
game_state.bread_energy = bread_qubit.radius
game_state.bread_theta = bread_qubit.theta

# Save kitchen statistics
game_state.kitchen_status = kitchen.get_kitchen_status()
# Includes:
# - total_bread_produced (float)
# - measurement_count (int)
# - bell_state_type (string)
# - last_measurement_time (float)

# On load: restore kitchen state and bread qubit
kitchen.set_input_qubits(loaded_wheat, loaded_water, loaded_flour)
bread_qubit = game_state.bread_qubit
```

---

## Testing & Validation

### Test: test_quantum_kitchen.gd

Demonstrates three complete production cycles:

**Test 1: GHZ Horizontal**
- Input: Wheat 0.8, Water 0.6, Flour 0.7
- Arrangement: Three plots in a row
- Result: Bread 0.70, theta = 0° (pure bread)

**Test 2: GHZ Vertical**
- Input: Wheat 0.9, Water 0.7, Flour 0.8
- Arrangement: Three plots in a column
- Result: Bread 0.96, theta = 45° (lean bread)

**Test 3: W State (L-Shape)**
- Input: Wheat 0.75, Water 0.65, Flour 0.85
- Arrangement: L-shaped corner
- Result: Bread 1.05, theta = 180° (input-heavy)

### Key Observations

✓ Different arrangements produce different bread properties
✓ Bread energy depends on input energies and efficiency (80%)
✓ Each measurement consumes inputs (no free production)
✓ Bell state strength determines measurement quality
✓ Theta encodes which arrangement was used

---

## Strategic Gameplay Elements

### 1. **Arrangement Optimization**

Different Bell states suit different goals:

```
Need PURE BREAD (high value to guilds)?
→ Use GHZ Horizontal (theta = 0°)
  Pure bread state, no input linkage

Need HYBRID BREAD (more resource-aware)?
→ Use W State (theta = 270°)
  More entanglement, remembers inputs

Need COMPUTATION-READY BREAD?
→ Use Cluster State (theta = 180°)
  Can be used for measurement-based protocols (future)
```

### 2. **Plot Arrangement as Puzzle**

```
Player must:
1. Plant wheat, water, flour in specific spots
2. Choose arrangement (gate action)
3. Activate kitchen
4. Get bread matching that arrangement

Harder arrangements = Better bread?
→ Cluster state more difficult to arrange but more powerful
→ GHZ easier but simpler bread
```

### 3. **Energy Conversion Trade-offs**

```
Horizontal: 80% efficiency, pure bread
Vertical: 80% efficiency, medium bread
W State: 80% efficiency, hybrid bread
Cluster: 80% efficiency, computation bread

Input costs vary per arrangement
→ Encourages trying different patterns
→ Players learn by experimenting
```

### 4. **Guilds Demand Different Breads**

```
(Future enhancement)

Guilds might prefer certain bread theta values:
- Storage-low guilds want PURE bread (theta=0°)
- Rich guilds want INPUT bread (theta=180°)
- This creates strategic choice for player
```

---

## Future Enhancements

### 1. Water Resource Integration

Current: Assumed water exists
Future: Create Water as new quantum resource

```gdscript
// Water qubit (💧, ☀️)
var water_qubit = DualEmojiQubit.new("💧", "☀️", PI/2)
// Requires new water production biome or special plots
```

### 2. Advanced Recipes

```gdscript
// Recipe system: different inputs for different breads
// (🍞, something_else) qubits possible

// Example: luxury bread
// Input: Wheat + Water + Premium Flour
// Output: (🍞, ✨) - fancy bread!
```

### 3. Measurement-Based Computation

```gdscript
// Cluster state breads can be used in quantum algorithms
// Enables advanced production chains
kitchen.produce_with_measurement_output(cluster_state_bread)
// Returns both bread AND quantum measurement result
```

### 4. Guild Bread Preferences

```gdscript
// Guilds request specific Bell states
guild.request_bread_type(BellStateDetector.BellStateType.GHZ_HORIZONTAL)
// Player gets reward for matching preferences
```

---

## Mathematical Grounding

### Bell States from Quantum Mechanics

The kitchen uses **real quantum mechanics** Bell states:

**GHZ State (3-qubit Greenberger-Horne-Zeilinger):**
```
|GHZ⟩ = (|000⟩ + |111⟩) / √2
```
Properties: Maximally entangled, sensitive to loss

**W State (3-qubit Wilczek):**
```
|W⟩ = (|001⟩ + |010⟩ + |100⟩) / √3
```
Properties: More robust, useful for error correction

**Cluster State:**
```
Graph of entanglement useful for measurement-based computation
```

### Probability from Sin²/Cos²

Just like the market system:
```
P(state1) = sin²(θ/2)
P(state2) = cos²(θ/2)

Kitchen measures each qubit using these probabilities
Result determines bread energy contribution
```

---

## Conclusion

The **Quantum Kitchen** is a unique system where:

1. **Inputs must be entangled** - not just mixed classically
2. **Arrangement defines the gate** - player chooses Bell state via plot positions
3. **Measurement produces bread** - triplet collapses to classical outcome
4. **Theta encodes the type** - different arrangements create different bread properties
5. **Guilds consume the result** - bread becomes demand for the economic system

The kitchen closes the production loop:
```
Farming (🌾, 💧) → Milling (flour) → Kitchen (bread) → Guilds (consumption)
```

All grounded in **quantum mechanics** — not arbitrary game rules. ✨
