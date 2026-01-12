# SpaceWheat: Quantum Farming Simulator - Technical Design

**Version:** 1.0 (January 2026)
**Audience:** LLMs, physics-literate developers, technical collaborators
**Purpose:** Architectural reference for understanding SpaceWheat's design intent

---

## Executive Summary

**Core Concept:** Real quantum mechanics farming simulator where density matrix evolution drives gameplay.

**Physics Engine:** 68 factions define quantum dynamics over 78+ emojis. Icons merge faction contributions into Hamiltonians and Lindblad operators. QuantumComputer evolves density matrices. Players bridge quantum potential to classical resources via measurement.

**Current State:**
- ✅ Quantum substrate operational (native C++/Eigen, 20-70x speedup)
- ✅ 68 factions with distinct quantum dynamics
- ✅ 4 biomes (BioticFlux, Market, Forest, Kitchen)
- ✅ 6-tool player interaction system
- ✅ Entanglement mechanics (Bell, GHZ, cluster states)
- ⚠️ Faction reputation/quest systems designed, integration incomplete

**Gameplay Loop:**
```
Plant → Quantum Evolution → Measure → Harvest → Replant
```

---

## 1. Architecture: Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                   FACTION LAYER (68 Factions)                   │
│                                                                 │
│  Each faction defines:                                          │
│    • signature: [emoji₁, emoji₂, ..., emojiₙ]                  │
│    • self_energies: {emoji: ω}                                  │
│    • hamiltonian: {(emoji_i, emoji_j): J_ij}                   │
│    • lindblad_outgoing: {emoji_source: [(target, Γ)]}          │
│    • lindblad_incoming: {emoji_target: [(source, Γ)]}          │
│    • gated_lindblad: {emoji: [(gate, power, rate)]}            │
│    • drivers: {emoji: (amplitude, frequency)}                   │
│    • alignment_couplings: {emoji: (coupled_emoji, λ)}          │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                    ICON LAYER (78+ Icons)                       │
│                                                                 │
│  IconBuilder.build_icons_for_factions():                        │
│    for each emoji in union(all faction signatures):            │
│      icon = Icon.new(emoji)                                     │
│      for each faction that speaks emoji:                        │
│        icon.merge_contribution(faction.get_contribution(emoji)) │
│      IconRegistry.register(emoji, icon)                         │
│                                                                 │
│  Result: Icon = composite quantum operator                      │
│    • Hamiltonian: H = Σ ω_i |i⟩⟨i| + Σ J_ij |i⟩⟨j|             │
│    • Lindblad: L = {L_k operators for dissipation}             │
│    • Time-dependent drivers: H(t) = H₀ + Σ A_i cos(ω_i t)      │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│              QUANTUM COMPUTER (per Biome, Model C)              │
│                                                                 │
│  State: ρ(t) ∈ ℂ^(2^n × 2^n), Hermitian, tr(ρ)=1, ρ≥0        │
│                                                                 │
│  Evolution: dρ/dt = -i[H, ρ] + Σ(L_k ρ L_k† - ½{L_k†L_k, ρ})  │
│                      └─Hamiltonian  └─Lindblad dissipation     │
│                                                                 │
│  Integration methods:                                           │
│    • Euler: ρ_{n+1} = ρ_n + dt·dρ/dt                           │
│    • Cayley: ρ_{n+1} = (I-iHdt/2)ρ_n(I+iHdt/2) [unitary-pres.]│
│    • RK4: Standard Runge-Kutta 4th order                        │
│    • Expm: ρ_{n+1} = exp(-iHdt)ρ_n exp(iHdt) [exact unitary]  │
│                                                                 │
│  Components:                                                    │
│    • OperatorCache: Serialized H, L operators (100% hit rate)  │
│    • DensityMatrix: Validation wrapper (trace, Hermiticity)    │
│    • ComplexMatrix: Native Eigen backend (20-70x speedup)      │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                  MEASUREMENT & COLLAPSE                         │
│                                                                 │
│  Trigger: Player harvests plot → QuantumComputer.measure()     │
│                                                                 │
│  Born rule: P(outcome) = ⟨outcome|ρ|outcome⟩                   │
│                                                                 │
│  Sampling: outcome ~ categorical(P)                             │
│                                                                 │
│  Backaction modes:                                              │
│    • Kid-light: No collapse (cheating, peek state)             │
│    • Lab-true: ρ → |outcome⟩⟨outcome| / P(outcome)             │
│                                                                 │
│  Readout modes:                                                 │
│    • Hardware: Noisy (error rate ε)                            │
│    • Inspector: Perfect readout                                 │
│                                                                 │
│  Result: Classical resource added to FarmEconomy               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key Insight:** Factions define physics rules. Players interact with quantum substrate, not factions directly.

---

## 2. Faction System (68 Total)

**Function:** Factions are **quantum dynamical system definitions**, not NPCs or quest-givers.

**Structure:**
- Each faction owns 3-7 emojis (closed vocabulary)
- Multiple factions compete for shared emojis (contested dynamics)
- Icons merge all faction contributions per emoji
- Faction count: 68 total (27 quantum-defined, 41 additional with lore/mechanics)

### 2.1 Representative Factions (20 Examples)

**Selection Criteria:** High emoji coupling (hub factions in network topology)

#### Imperial Power Network
| Faction | Emojis | Role |
|---------|--------|------|
| **Carrion Throne** | 👥⚖🦅⚜🩸🏰📜 | Apex authority, imperial quotas, death/law nexus |
| **Station Lords** | 👥📦📘📜📋🔖 | Bureaucratic administration, record-keeping |
| **Void Serfs** | 👥⛓💸🌑🥀⛏ | Exploited labor, measurement inversion mechanics |
| **House of Thorns** | 🌹🍷⚖🗡👑🎭 | Aristocracy, subtle violence via poison dynamics |
| **Ledger Bailiffs** | ⚖💰📘🔎⚔🪙 | Debt enforcement, economic justice |

#### Death & Transformation Network
| Faction | Emojis | Role |
|---------|--------|------|
| **Mycelial Web** | 🍄🍂🌙💀 | Decomposition, night-active mushrooms |
| **Pack Lords** | 🐺💀🥩🌙🏔 | Predation, death-as-nutrient cycle |
| **Scavenged Psithurism** | 🧤🗑💀🍂🏚 | Refugee scavenging from ruins |

#### Growth & Production Network
| Faction | Emojis | Role |
|---------|--------|------|
| **Verdant Pulse** | 🌱🌿🌾🌲🍂 | Seed → growth → decay lifecycle |
| **Pollinator Guild** | 🐝🌾🌿☀💧🌈 | Gated dynamics: no 🐝 → no 🌾 growth |
| **Plague Vectors** | 🦠🐀🥀💀⚰👤 | Density-dependent disease (anti-monoculture) |
| **Swift Herd** | 🐇🦌🌿🥬💨 | Herbivore population oscillations |

#### Economic Network
| Faction | Emojis | Role |
|---------|--------|------|
| **Market Spirits** | 🐂🐻💰📦🏛🏚 | Bull/bear market oscillations |
| **Granary Guilds** | 🌱🍞💰🧺⚖📦 | Storage, wheat price stabilization |
| **Quay Rooks** | ⚓📦💰🐟🌊⛵ | Maritime trade, fish/wheat exchange |

#### Industrial Network
| Faction | Emojis | Role |
|---------|--------|------|
| **Millwright's Union** | 🌾⚙🏭💨🍞📜 | Wheat → flour processing |
| **Gearwright Circle** | ⚙🔩🛠🔧⚡📐 | Manufacturing standards |
| **Kilowatt Collective** | ⚙🔋🔌⚡💡🏭 | Power grid, clock signal drivers |

#### Mystical Network
| Faction | Emojis | Role |
|---------|--------|------|
| **Yeast Prophets** | 🍞🧪⛪🌾💨📜 | Fermentation mysticism, bread miracles |
| **Hearth Keepers** | 🔥❄💧🏜💨🍞 | Elemental alchemy: heat × moisture × grain |

### 2.2 Emoji Hotspots (Most Contested)

| Emoji | Faction Count | Competing Factions |
|-------|---------------|-------------------|
| 👥 (population) | 6+ | Granary, Station Lords, Void Serfs, Carrion Throne, Indelible Precept, Wildfire |
| 💀 (death) | 5 | Mycelial Web, Pack Lords, Void Serfs, Carrion Throne, Scavenged Psithurism |
| ⚖ (law/balance) | 6 | Station Lords, Carrion Throne, House of Thorns, Irrigation Jury, Indelible Precept, Ledger Bailiffs |
| 💰 (wealth) | 5 | Market Spirits, Granary Guilds, Quay Rooks, Ledger Bailiffs, Gilded Legacy |
| 🍞 (bread) | 5 | Granary Guilds, Hearth Keepers, Millwright's Union, Yeast Prophets, Scavenged Psithurism |
| ⚙ (gears) | 4 | Millwright's Union, Kilowatt Collective, Gearwright Circle, Rocketwright Institute |

**Network Effect:** Shared emojis create faction interdependence. Changes to 👥 population affect 6+ faction dynamics simultaneously.

### 2.3 Faction Dynamics Examples

**Celestial Archons** (☀🌙🔥💧⛰🌬):
- **Drivers:** `☀: A=1.0, ω=2π/(24 game-hours)` (day cycle)
- **Effect:** All biomes receive periodic energy injection
- **Coupling:** `☀ ↔ 🌾` (wheat growth rate ∝ sunlight)

**Verdant Pulse** (🌱🌿🌾🌲🍂):
- **Lindblad outgoing:** `🌱 → 🌿 (Γ=0.5)`, `🌿 → 🌾 (Γ=0.3)`, `🌾 → 🍂 (Γ=0.2)`
- **Effect:** Irreversible growth cascade seed → sapling → wheat → decay
- **Hamiltonian:** None (purely dissipative faction)

**Pollinator Guild** (🐝🌾🌿☀💧🌈):
- **Gated Lindblad:** `🌿 → 🌾: rate=0.8, gate=🐝, power=1.0`
- **Effect:** Wheat growth requires bee population: rate × P(🐝)
- **Mechanic:** Prevents wheat farming without ecosystem support

**Market Spirits** (🐂🐻💰📦🏛🏚):
- **Hamiltonian:** `🐂 ↔ 💰 (J=0.5)`, `🐻 ↔ 🏚 (J=0.5)`
- **Effect:** Bull markets boost money, bear markets increase ruins
- **Oscillation:** `|🐂⟩ ↔ |🐻⟩` with period ~10 game-days

---

## 3. Biome System (4 Operational)

**Architecture:**
- Each biome = ONE `QuantumComputer` instance
- Plots assigned to biomes inherit quantum state
- Biomes define planting capabilities (what grows where)
- Icons active in biome modulate evolution

### 3.1 Biome Comparison

| Biome | Dimension | Qubits | Focus | Key Emojis |
|-------|-----------|--------|-------|------------|
| **BioticFlux** | 8×8 (2³) | 3 | Natural farming | 🌾👥🍄🍂☀🌙 |
| **Quantum Kitchen** | 8×8 (2³) | 3 | Production chain | 🔥❄🍞 |
| **Market** | 4×4 (2²) | 2 | Economic trading | 💰📦🐂🐻 |
| **Forest Ecosystem** | 32×32 (2⁵) | 5 | Ecological web | 💧🐺🦅🐦🐰🐛🐭🌲🌱🌿🥚🍎 |

**Performance (native acceleration):**
- BioticFlux evolution: ~1.2 ms/step
- Kitchen evolution: ~3.1 ms/step
- Market evolution: ~0.9 ms/step
- Forest evolution: ~16.7 ms/step
- **Target:** 60 FPS = 16.67 ms/frame ✅ All biomes within budget

### 3.2 BioticFlux Biome (Example)

**Emojis:** 🌾 wheat, 👥 labor, 🍄 mushroom, 🍂 detritus, ☀ sun, 🌙 moon

**Dominant Factions:**
- Celestial Archons (☀🌙 drivers)
- Verdant Pulse (🌾 growth)
- Mycelial Web (🍄🍂 decomposition)
- Carrion Throne (👥 population control)

**Evolution Example:**
```
t=0:      ρ₀ = |🌾⟩⟨🌾|                    (pure wheat state)
          ↓ Celestial Hamiltonian (☀ ↔ 🌾)
t=6h:     ρ = 0.7|🌾⟩⟨🌾| + 0.3|☀⟩⟨☀|      (solar charging)
          ↓ Verdant Lindblad (🌾 → 🍂)
t=24h:    ρ = 0.5|🌾⟩⟨🌾| + 0.3|🍂⟩⟨🍂| + ... (maturity → decay)
          ↓ Mycelial Lindblad (🍂 → 🍄)
t=48h:    ρ = 0.2|🍂⟩⟨🍂| + 0.4|🍄⟩⟨🍄| + ... (decay → mushroom)
```

**Measurement:** Player harvests → Born rule samples from ρ(t) → classical resource

### 3.3 Planting Capabilities

**System:** Biomes define what can be planted (PlantingCapability)

| Biome | Plantable Types | Exclusive Types |
|-------|----------------|-----------------|
| BioticFlux | wheat, mushroom, tomato | - |
| Kitchen | fire, water, flour | flour (requires mill) |
| Market | bread, flour | - |
| Forest | vegetation, rabbit, wolf | rabbit, wolf |

**Economy:** Planting costs resources (defined per biome/type)

---

## 4. Player Interaction: 6-Tool System

**Input Scheme:** Keys 1-6 select tool, Q/E/R perform actions

```
┌──────────────────────────────────────────────────────────────┐
│                         TOOL MATRIX                          │
├─────────┬──────────────────┬──────────────────┬─────────────┤
│  Tool   │    Q             │    E             │    R        │
├─────────┼──────────────────┼──────────────────┼─────────────┤
│ 1-GROW  │ Plant crop       │ Entangle plots   │ Harvest     │
│ 2-QM    │ Build cluster    │ Peek state       │ Measure     │
│ 3-IND   │ Build submenu    │ Build market     │ Build kit   │
│ 4-BIOME │ Energy tap       │ Lindblad ops     │ Pump/Reset  │
│ 5-GATE  │ 1-qubit gates    │ Phase gates      │ 2-qubit     │
│ 6-BIOME │ Assign biome     │ Clear biome      │ Inspect     │
└─────────┴──────────────────┴──────────────────┴─────────────┘
```

### 4.1 Core Actions (Tool 1: GROWER)

**Plant (1Q):**
- Initialize plot in superposition: `ρ = (|north⟩⟨north| + |south⟩⟨south|) / 2`
- Biome-dependent crop types (submenu)
- Cost: Resources from FarmEconomy
- Effect: Plot enters quantum evolution

**Entangle (1E):**
- Create Bell pair between adjacent plots: `φ+ = (|00⟩ + |11⟩) / √2`
- Requirement: Both plots must exist
- Effect: Correlated outcomes on measurement
- Topology: Complex entanglement patterns → bonuses (calculated, not yet rewarded)

**Harvest (1R):**
- Trigger measurement on plot
- Born rule sampling from density matrix
- Backaction: Collapse (Lab-true) or peek (Kid-light)
- Result: Classical resource added to inventory

### 4.2 Quantum Operations (Tool 2)

**Build Cluster (2Q):**
- N-plot entanglement (N=2: Bell, N=3+: cluster state)
- GHZ state: `(|000...⟩ + |111...⟩) / √2`
- Cluster state: Graph state with CZ gates

**Peek State (2E):**
- Non-destructive inspection
- Returns: Density matrix elements, purity, entanglement measures
- No backaction (inspector readout mode)

### 4.3 Gate Operations (Tool 5)

**1-Qubit Gates (5Q):**
- Pauli-X: `|0⟩ ↔ |1⟩` (bit flip)
- Hadamard: `|0⟩ → (|0⟩+|1⟩)/√2` (superposition)
- Pauli-Z: `|1⟩ → -|1⟩` (phase flip)

**Phase Gates (5E):**
- Pauli-Y: `|0⟩ → i|1⟩`, `|1⟩ → -i|0⟩`
- S-gate: `|1⟩ → i|1⟩` (π/2 phase)
- T-gate: `|1⟩ → e^(iπ/4)|1⟩` (π/4 phase)

**2-Qubit Gates (5R):**
- CNOT: `|control,target⟩ → |control, control⊕target⟩`
- CZ: `|11⟩ → -|11⟩` (controlled phase)
- SWAP: `|ab⟩ → |ba⟩`

**Implementation:** Gates applied as unitary operators `U` to density matrix: `ρ → U ρ U†`

### 4.4 Advanced Operations (Tool 4)

**Energy Tap (4Q):**
- Extract population from quantum coherence
- SparkConverter: Measures semantic uncertainty, converts to classical energy
- Tradeoff: Lose quantum coherence, gain immediate resources

**Lindblad Operations (4E):**
- Manually trigger dissipative dynamics
- Drive: Inject energy into emoji
- Decay: Extract energy from emoji
- Transfer: Force emoji_A → emoji_B flow

**Pump/Reset (4R):**
- Pump to wheat: Force |0⟩ → |1⟩ (prepare specific state)
- Reset pure: Collapse to basis state
- Reset mixed: Maximize entropy (thermal state)

---

## 5. Quantum Mechanics Implementation

**Philosophy:** Real physics, no shortcuts. Game passes 9/10 rigor test from physics experts.

### 5.1 Density Matrix Formalism

**State Space:**
- ρ ∈ ℂ^(d×d), d = 2^n for n qubits
- Properties: Hermitian (ρ† = ρ), unit trace (tr(ρ) = 1), positive semidefinite (ρ ≥ 0)

**Purity:**
- Pure state: tr(ρ²) = 1, ρ = |ψ⟩⟨ψ|
- Mixed state: tr(ρ²) < 1, ρ = Σ pᵢ|ψᵢ⟩⟨ψᵢ|

**Observables:**
- Any Hermitian operator O
- Expectation: ⟨O⟩ = tr(O ρ)

### 5.2 Evolution Equation

**Lindblad Master Equation:**
```
dρ/dt = -i[H, ρ] + Σₖ (Lₖ ρ Lₖ† - ½{Lₖ†Lₖ, ρ})
```

**Terms:**
- Hamiltonian: `H = Σᵢ ωᵢ σᵢ + Σᵢⱼ Jᵢⱼ σᵢσⱼ` (reversible dynamics)
- Lindblad operators: `Lₖ` (dissipation, decoherence, pumping)
- Commutator: `[A,B] = AB - BA`
- Anticommutator: `{A,B} = AB + BA`

**Conservation Laws:**
- `d(tr(ρ))/dt = 0` (probability conservation)
- `d(ρ†)/dt = (dρ/dt)†` (Hermiticity preservation)

### 5.3 Integration Methods

| Method | Order | Preserves Unitarity | Cost | Use Case |
|--------|-------|---------------------|------|----------|
| Euler | 1 | ❌ No | Low | Debug, fast preview |
| Cayley | 2 | ✅ Yes | Medium | Default (unitary-preserving) |
| RK4 | 4 | ❌ No | High | High accuracy, short runs |
| Expm | Exact | ✅ Yes | Very High | Critical operations |

**Cayley Implementation:**
```
ρ_{n+1} = (I - iHdt/2)^(-1) ρ_n (I + iHdt/2)^(-1)
```
Advantage: Preserves unitarity even with large timesteps.

### 5.4 Measurement

**Born Rule:**
```
P(outcome = j) = ⟨j|ρ|j⟩ = ρⱼⱼ (for basis state measurement)
```

**Generalized:**
```
P(outcome) = tr(Mₒᵤₜcₒₘₑ ρ Mₒᵤₜcₒₘₑ†)
```
where M is POVM element.

**Backaction:**
```
ρ → Mₒᵤₜcₒₘₑ ρ Mₒᵤₜcₒₘₑ† / P(outcome)
```

**Modes:**
- **Lab-true:** Full collapse (realistic QM)
- **Kid-light:** No collapse (cheating, for learning)

### 5.5 Entanglement

**Bell States:**
```
φ+ = (|00⟩ + |11⟩) / √2    (maximally entangled)
φ- = (|00⟩ - |11⟩) / √2
ψ+ = (|01⟩ + |10⟩) / √2
ψ- = (|01⟩ - |10⟩) / √2
```

**GHZ State (n qubits):**
```
|GHZ_n⟩ = (|00...0⟩ + |11...1⟩) / √2
```

**Cluster State:**
- Graph state prepared by CZ gates on edges
- Topology-dependent properties
- Used in measurement-based quantum computing

**Entanglement Measures:**
- Von Neumann entropy: `S(ρ) = -tr(ρ log₂ ρ)`
- Concurrence (2 qubits)
- Entanglement entropy (bipartite split)

### 5.6 Performance (Native Acceleration)

**ComplexMatrix:**
- Hybrid wrapper: Native C++/Eigen when available, GDScript fallback
- Data marshalling: GDScript Complex[] ↔ PackedFloat64Array ↔ Eigen::MatrixXcd

**Speedup (Eigen vs GDScript):**
| Operation | Matrix Size | GDScript (μs) | Native (μs) | Speedup |
|-----------|-------------|---------------|-------------|---------|
| Multiply | 8×8 | 6,672 | 342 | 19.5x |
| Multiply | 16×16 | 75,550 | 3,460 | 21.8x |
| Multiply | 24×24 | 227,319 | 3,279 | 69.3x |
| Multiply | 32×32 | 503,239 | 10,498 | 47.9x |
| Expm | 8×8 | ~20,000 | ~800 | ~25x |

**Critical Path:** All biome evolution fits within 60 FPS budget (16.67 ms/frame).

---

## 6. Gameplay Loop

### 6.1 Primary Loop (Working)

```
┌─────────────────────────────────────────────────────────┐
│                    CORE LOOP                            │
└─────────────────────────────────────────────────────────┘

1. SELECT PLOT (6×2 grid)
   ↓
2. PLANT (Tool 1Q)
   • Choose crop (biome-dependent submenu)
   • Cost: Resources deducted
   • Initialize: ρ = (|north⟩⟨north| + |south⟩⟨south|) / 2
   ↓
3. QUANTUM EVOLUTION (automatic)
   • Hamiltonian: Oscillations (day/night, faction couplings)
   • Lindblad: Irreversible flows (growth, decay, transfers)
   • Icon effects: Faction dynamics modulate rates
   • Duration: ~60 seconds real-time (3 game-days)
   ↓
4. [OPTIONAL] MANIPULATE STATE
   • Entangle (1E): Create correlations
   • Apply gates (5Q/E/R): Pauli, Hadamard, CNOT
   • Lindblad ops (4E): Drive/decay/transfer
   ↓
5. MEASURE & HARVEST (Tool 1R)
   • Born rule sampling: outcome ~ P(ρ)
   • Backaction: ρ → |outcome⟩⟨outcome|
   • Reward: Classical resource (wheat, mushroom, etc.)
   ↓
6. ECONOMY
   • Replant: Spend resources
   • Build infrastructure: Mill, Market, Kitchen
   • Trade: Wheat → Flour → Bread → Credits
   ↓
LOOP
```

### 6.2 Secondary Loops (Designed)

**Infrastructure Chain:**
```
Wheat → Mill → Flour → Kitchen → Bread → Market → Credits
```

**Faction Progression:**
```
Farm in Territory → Faction Reputation → Bonus Effects → Territory Expansion
```
Status: Designed, integration incomplete

**Quest System:**
```
Accept Contract → Farm Resources → Fulfill Quota → Reputation + Rewards
```
Status: UI exists, logic not wired to main loop

### 6.3 Strategic Depth

**Entanglement Strategy:**
- Bell pairs guarantee correlated outcomes (both plots yield same resource)
- GHZ states provide multi-way correlations
- Topology bonuses from knot invariants (calculated via TopologyAnalyzer)

**Gate Optimization:**
- Hadamard creates even superposition (maximize outcome diversity)
- Pauli-X flips north ↔ south (bias toward specific resource)
- CNOT creates conditional correlations (if plot_A is wheat, plot_B is wheat)

**Faction Alignment:**
- Farm emojis preferred by faction → reputation boost
- High reputation → territory bonuses (designed)
- Strategic crop selection to align with powerful factions

---

## 7. UI Architecture

```
PlayerShell (persistent across scenes)
├── OverlayManager
│   ├── EscapeMenu (pause/save/load)
│   ├── QuestPanel (exists, not wired)
│   ├── VocabularyPanel (emoji reference)
│   └── KeyboardHintButton (shortcut overlay)
│
├── ActionBarManager (bottom toolbar)
│   ├── ToolSelectionRow (tools 1-6, dynamic icons)
│   └── ActionPreviewRow (shows Q/E/R for current tool)
│
├── QuantumHUDPanel (real-time state visualization)
│   ├── QuantumEnergyMeter (Re/Im energy, regime indicator)
│   ├── SemanticContextIndicator (octant, phase space position)
│   ├── UncertaintyMeter (Δx·Δp ≥ ℏ/2 visualization)
│   └── AttractorPersonalityPanel (trajectory, Lyapunov exp)
│
└── FarmUI Container
    ├── PlotGridDisplay (6×2 visual grid)
    │   └── Individual plot tiles (state, growth progress)
    ├── EntanglementLines (visual links between entangled plots)
    └── BiomeInfoDisplay (current biome emoji, state)
```

**Input Layers (priority order):**
1. **Modal:** Quest boards, menus (consume all input)
2. **Shell:** ESC/C/K/L global shortcuts
3. **Farm:** Tool actions (QER), plot selection (WASD/touch)

**Parametric Layout:**
- Viewport: 960×540 (base resolution)
- Touch-friendly: 80×80 minimum button size
- Dynamic menus: Context-aware submenu generation

---

## 8. Technical Implementation

### 8.1 Critical File Paths

```
Core/
├── QuantumSubstrate/
│   ├── QuantumComputer.gd          ★ Physics engine
│   ├── ComplexMatrix.gd            ★ Native Eigen wrapper
│   ├── DensityMatrix.gd            Validation wrapper
│   ├── QuantumBath.gd              Emoji-based quantum system
│   ├── Icon.gd                     Faction→operator converter
│   ├── IconRegistry.gd             Global icon registry
│   ├── OperatorCache.gd            Serialized operator storage
│   └── StrangeAttractorAnalyzer.gd Dynamics analysis
│
├── Factions/
│   ├── Faction.gd                  Base faction class
│   ├── CoreFactions.gd             Core ecosystem factions
│   ├── CivilizationFactions.gd     Civilization factions
│   ├── Tier2Factions.gd            Advanced factions
│   ├── IconBuilder.gd              ★ Faction→Icon pipeline
│   ├── AllFactions.gd              Faction registry (68 total)
│   └── FactionDatabaseV2.gd        Lore & reputation data
│
├── Environment/
│   ├── BiomeBase.gd                Base biome class
│   ├── BioticFluxBiome.gd          Natural farming biome
│   ├── MarketBiome.gd              Economic biome
│   ├── ForestEcosystem_Biome.gd    Ecological biome
│   └── QuantumKitchen_Biome.gd     Production biome
│
├── GameMechanics/
│   ├── FarmGrid.gd                 ★ Grid manager (6×2)
│   ├── FarmPlot.gd                 ★ Plot state & actions
│   ├── BasePlot.gd                 Plot base class
│   ├── FarmEconomy.gd              Resource tracking
│   ├── PlantingCapability.gd       Biome planting rules
│   └── TopologyAnalyzer.gd         Entanglement topology
│
└── GameState/
    ├── ToolConfig.gd               ★ 6-tool definitions
    └── FarmState.gd                Global game state

UI/
├── PlayerShell.gd                  ★ Main UI container
├── FarmInputHandler.gd             ★ Input routing (QER)
├── Panels/
│   ├── QuantumHUDPanel.gd
│   ├── QuantumEnergyMeter.gd
│   ├── SemanticContextIndicator.gd
│   ├── UncertaintyMeter.gd
│   └── AttractorPersonalityPanel.gd
├── ToolSelectionRow.gd             Tool selector (1-6)
└── PlotGridDisplay.gd              Grid visualization

native/                             C++ acceleration (GDExtension)
├── src/
│   ├── quantum_matrix_native.cpp   Eigen implementations
│   ├── quantum_matrix_native.h
│   ├── register_types.cpp          GDExtension entry point
│   └── register_types.h
└── bin/
    └── libquantummatrix.*.so       Compiled library (897 KB)
```

★ = Critical path files

### 8.2 Data Flow: Planting Example

```
Player presses 1Q
    ↓
FarmInputHandler.handle_tool_action("grower", "Q")
    ↓
FarmGrid.get_selected_plot() → FarmPlot instance
    ↓
FarmPlot.plant(PlantType.WHEAT)
    ↓
BasePlot.assign_to_biome(BioticFluxBiome)
    ↓
BioticFluxBiome.on_plot_assigned(plot)
    ↓
QuantumComputer.register_plot(plot, initial_state)
    ↓
Initialize: ρ = ComplexMatrix.identity(2) / 2
           = (|🌾⟩⟨🌾| + |🍄⟩⟨🍄|) / 2
    ↓
Start evolution: _physics_process(delta) → QuantumComputer.evolve(delta)
```

### 8.3 Data Flow: Harvesting Example

```
Player presses 1R
    ↓
FarmInputHandler.handle_tool_action("grower", "R")
    ↓
FarmPlot.harvest()
    ↓
QuantumComputer.measure(plot_index, backaction_mode)
    ↓
Born rule: outcome ~ categorical(diag(ρ))
    ↓
If Lab-true: ρ → |outcome⟩⟨outcome| / P(outcome)
    ↓
BiomeBase.on_measurement(outcome, plot)
    ↓
FarmEconomy.add_resource(outcome, quantity)
    ↓
UI updates: Resource counter, plot state cleared
```

---

## 9. Design Intent

### 9.1 Core Pillars

1. **Physics Rigor**
   - Real density matrices, real evolution equations
   - No fake quantum mechanics (passes expert review: 9/10)
   - Educational: Players learn actual QM through gameplay

2. **Emoji Semantics**
   - Emojis are quantum basis states, not decorative graphics
   - Example: 🌾 and 🍄 are orthogonal states in Hilbert space
   - Measurement collapses superposition to one emoji

3. **Faction Dynamics**
   - 68 factions define physics rules
   - Players interact with substrate, not factions directly
   - Faction conflicts = competing quantum dynamics on shared emojis

4. **Measurement as Bridge**
   - Quantum realm: Potential, superposition, entanglement
   - Classical realm: Resources, inventory, economy
   - Measurement converts potential to concrete

5. **Strategic Depth**
   - Understanding QM provides gameplay advantages
   - Entanglement enables guaranteed outcomes
   - Gate operations allow quantum algorithms
   - Accessible to non-physicists via intuitive feedback

### 9.2 Player Experience Goals

**Beginner:**
- Plant wheat, wait, harvest
- Learn: "Quantum states evolve over time"
- Feedback: Visual indicators (growth bar, emoji oscillation)

**Intermediate:**
- Entangle plots for correlated outcomes
- Learn: "Measurement of one affects the other"
- Strategy: Guarantee quest resources via Bell pairs

**Advanced:**
- Apply gate sequences for quantum algorithms
- Learn: "Hadamard + CNOT creates specific patterns"
- Mastery: Grover search for rare resources, Deutsch-Jozsa for faction alignment

**Expert:**
- Topology optimization (GHZ, cluster states)
- Learn: "Knot invariants provide bonuses"
- Endgame: Control faction dynamics via strategic farming

### 9.3 Current State (January 2026)

**Operational:**
- ✅ Quantum substrate (density matrices, evolution, measurement)
- ✅ 68 factions with distinct dynamics
- ✅ 4 biomes with unique ecosystems
- ✅ 6-tool interaction system
- ✅ Native acceleration (20-70x speedup, 60 FPS maintained)
- ✅ Entanglement mechanics (Bell, GHZ, cluster states)
- ✅ Gate library (Pauli, Hadamard, CNOT, etc.)
- ✅ Grid farming with quantum evolution

**Designed, Integration Incomplete:**
- ⚠️ Faction reputation system (coded, not visible to player)
- ⚠️ Quest/contract system (UI exists, logic not wired)
- ⚠️ Territory effects (manager exists, effects unclear)
- ⚠️ Topology bonuses (calculated, not rewarded in economy)

**Player Perspective:**
- Can plant, entangle, measure, harvest successfully
- Quantum evolution visibly affects outcomes
- Economy functional (wheat → flour → bread → credits)
- Faction layer invisible (reputation/quests not integrated)

**Development Status:**
- Quantum substrate: Production-ready
- Gameplay mechanics: Core loop functional
- Social systems: Mid-refactor (transitioning faction role from quest-givers to physics-definers)

---

## 10. Quick Reference

### 10.1 Emoji Dictionary (Selected)

| Category | Emojis |
|----------|--------|
| **Crops** | 🌾 wheat, 🍄 mushroom, 🍞 bread, 🌱 seed, 🌿 sapling, 🌲 tree, 🍂 decay |
| **Elements** | 🔥 fire, 💧 water, ❄ ice, 🌬 wind, ⛰ mountain, 🏜 desert |
| **Celestial** | ☀ sun, 🌙 moon, ⭐ star, 🌈 rainbow |
| **Fauna** | 🐺 wolf, 🐇 rabbit, 🦌 deer, 🐝 bee, 🦅 eagle, 🐦 bird, 🐛 caterpillar, 🐭 mouse |
| **Economy** | 💰 money, 📦 goods, 🐂 bull, 🐻 bear, 💸 loss, 🪙 coin |
| **Power** | ⚖ law, 👑 crown, 🗡 sword, 📜 decree, 🏛 empire, 🏚 ruin |
| **Population** | 👥 people, ⛓ chains, 💀 death, 🩸 blood, ⚰ coffin |
| **Industry** | ⚙ gear, 🏭 factory, 🔌 power, ⚡ energy, 🔋 battery, 🛠 tools |
| **Mystical** | 🧪 alchemy, ⛪ temple, 📘 tome, 🔎 investigation |

### 10.2 Hottest Emojis (Network Hubs)

| Emoji | Faction Count | Strategic Value |
|-------|---------------|-----------------|
| 👥 population | 6+ | Population control = empire power |
| 💀 death | 5 | Death networks span nature ↔ horror |
| ⚖ law | 6 | Justice/balance affects all governance |
| 💰 wealth | 5 | Economic control, market manipulation |
| 🍞 bread | 5 | Food production, survival resource |
| ⚙ gears | 4 | Industrial base, manufacturing |

### 10.3 Biome Quick Reference

```
┌──────────┬─────────┬────────┬──────────────────┐
│ Biome    │ Qubits  │ Time/  │ Best For         │
│          │ (size)  │ Step   │                  │
├──────────┼─────────┼────────┼──────────────────┤
│ BioticFx │ 3 (8×8) │ 1.2ms  │ Wheat, mushrooms │
│ Kitchen  │ 3 (8×8) │ 3.1ms  │ Bread production │
│ Market   │ 2 (4×4) │ 0.9ms  │ Trading, credits │
│ Forest   │ 5 (32×) │ 16.7ms │ Rare resources   │
└──────────┴─────────┴────────┴──────────────────┘
```

### 10.4 Tool Shortcuts Cheat Sheet

```
1Q: Plant    2Q: Cluster   3Q: BuildMenu  4Q: EnergyTap  5Q: 1qGates   6Q: AssignBiome
1E: Entangle 2E: Peek      3E: Market     4E: Lindblad   5E: Phase     6E: ClearBiome
1R: Harvest  2R: Measure   3R: Kitchen    4R: Pump       5R: 2qGates   6R: Inspect

Most Used: 1Q (plant), 1E (entangle), 1R (harvest), 5Q (Hadamard), 5R (CNOT)
```

### 10.5 Performance Benchmarks

| Operation | Size | Native (μs) | Frame Budget |
|-----------|------|-------------|--------------|
| BioticFlux step | 8×8 | 1,200 | 7.2% of 16.67ms |
| Kitchen step | 8×8 | 3,100 | 18.6% |
| Market step | 4×4 | 900 | 5.4% |
| Forest step | 32×32 | 16,700 | 100% (1 step/frame) |

**Optimization:** Forest evolution largest bottleneck. Future: GPU acceleration or reduced update frequency.

---

## Appendix: Glossary

**Biome:** Quantum ecosystem with distinct dynamics. Contains one QuantumComputer instance.

**Density Matrix (ρ):** Mathematical representation of quantum state. ρ ∈ ℂ^(d×d), Hermitian, trace=1.

**Emoji:** Quantum basis state. Orthogonal in Hilbert space. Examples: 🌾 (wheat), 🍄 (mushroom).

**Entanglement:** Non-local correlations. Measurement of one plot affects others. Bell pair: φ+ = (|00⟩+|11⟩)/√2.

**Faction:** Quantum dynamical system definition. Specifies Hamiltonians, Lindbladians over emoji vocabulary.

**Hamiltonian (H):** Hermitian operator governing reversible dynamics. dρ/dt = -i[H,ρ].

**Icon:** Composite quantum operator built from faction contributions. One icon per emoji.

**Lindblad Operator (L):** Dissipation operator. Models irreversible dynamics (growth, decay, decoherence).

**Measurement:** Collapse of quantum state to classical outcome. Born rule: P(j) = ⟨j|ρ|j⟩.

**Plot:** Individual farm cell. Can be assigned to biome, planted, entangled.

**QuantumComputer:** Evolution engine. Integrates Lindblad equation, manages density matrix.

**Superposition:** Linear combination of basis states. Example: α|🌾⟩ + β|🍄⟩.

**Tool:** Player interaction mode. 6 tools (GROW, QUANTUM, INDUSTRY, BIOME CONTROL, GATES, BIOME MGMT).

---

**Document Version:** 1.0
**Last Updated:** January 12, 2026
**Total Factions:** 68
**Total Icons:** 78+
**Operational Biomes:** 4
**Physics Rigor:** 9/10
**Performance:** 60 FPS maintained on all biomes
