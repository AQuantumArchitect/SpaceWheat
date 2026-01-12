# Catalogues User Guide

How to use the three catalogues to understand what SpaceWheat quantum machinery can do and how to access it.

---

## The Three Catalogues

### 1. QUANTUM_MACHINERY_CATALOGUE.md
**What it contains:** Detailed inventory of ALL quantum features available in the system

**Sections:**
- State Management & Representation (registers, density matrices, component tracking)
- Quantum Dynamics & Evolution (Hamiltonian, Lindblad, integration methods)
- Quantum Gates (9 gates: 6 single-qubit, 3 two-qubit)
- Measurement & Collapse (3 measurement types)
- Entanglement & Correlations (Bell states, decoherence)
- Operator Construction (Hamiltonian and Lindblad builders)
- State Properties & Analysis (purity, entropy, precision, flexibility)
- Quantum Algorithms (Deutsch-Jozsa, Grover, Phase Estimation)
- Entanglement Pattern Detection (5 patterns)
- Semantic/Topological Analysis (octants, attractors, topology)
- Conservation & Validation (6 properties)
- Observable Extraction
- Spark System (energy extraction)

**Use this when:** You want to understand what quantum operations exist in the system

**Example:** "What quantum gates are available?" → Look at section 3 (Quantum Gates)

---

### 2. TOOLS_INTERFACES_CATALOGUE.md
**What it contains:** Complete inventory of in-game tools, UI panels, and interfaces

**Sections:**
- Tool 1: GROWER 🌱 (plant, entangle, measure)
- Tool 2: QUANTUM ⚛️ (build clusters, set triggers, batch measure)
- Tool 3: INDUSTRY 🏭 (build markets/kitchens)
- Tool 4: BIOME CONTROL ⚡ (energy tap, pump/reset, tune decoherence)
- Tool 5: GATES 🔄 (apply quantum gates)
- Tool 6: BIOME 🌍 (assign biomes, inspect)
- UI Panels (Quantum state visualization, game state, configuration)
- Keyboard Input Mapping (how to activate tools)
- Submenu System (dynamic menus)
- Summary Statistics

**Use this when:** You want to know what player-facing tools and UI exist

**Example:** "What can I do with the GATES tool?" → Look at Tool 5 section

---

### 3. FEATURE_TOOL_CROSSREFERENCE.md
**What it contains:** Matrix showing which tools access which quantum features

**Sections:**
- Quick Reference: Tools vs Quantum Features (by tool)
- Capability Matrix (what each tool can do)
- Feature Availability by Tool (features vs tools grid)
- Semantic Topology Features mapping
- UI Panels mapped to Tools
- Accessing Quantum Machinery Features (goal-based lookup)
- Quick Start Guides (by quantum goal)
- Constraints & Rules
- Reference: Feature to Tool Lookup

**Use this when:** You want to find HOW to access a feature (which tool does it)

**Example:** "I want to measure a quantum state. Which tool do I use?" → Look at "Accessing Quantum Machinery Features" → Use Tool 1 (R) or Tool 2 (R)

---

## HOW TO USE THE CATALOGUES TOGETHER

### Scenario 1: "I discovered a new quantum feature. How does it fit into the game?"

1. **Start with:** QUANTUM_MACHINERY_CATALOGUE
   - Find your feature in the appropriate section
   - Understand its parameters and behavior
   - See what files implement it

2. **Then check:** FEATURE_TOOL_CROSSREFERENCE
   - Search "Reference: Feature to Tool Lookup" table
   - Find which tools access this feature
   - See which UI panels display it

3. **Finally:** TOOLS_INTERFACES_CATALOGUE
   - Look up each tool that accesses it
   - Understand the user-facing action
   - See keyboard shortcuts and UI integration

**Example: You've added a new state property "Color Balance"**
1. QUANTUM_MACHINERY → Doesn't exist yet, so you'll document it in section 7
2. FEATURE_TOOL_CROSSREFERENCE → Add to relevant tool rows
3. TOOLS_INTERFACES_CATALOGUE → Update tool description to mention it

---

### Scenario 2: "A player wants to do X. Which tool and quantum features do they need?"

**Method: Goal-Based Lookup**

1. **Check:** FEATURE_TOOL_CROSSREFERENCE section "Accessing Quantum Machinery Features"
   - Find row matching the player's goal
   - See which tool(s) to use
   - See which quantum features are accessed

2. **Then:** TOOLS_INTERFACES_CATALOGUE
   - Look up the tool
   - Find the specific action (Q/E/R)
   - See keyboard shortcut
   - Check which submenu (if any)

3. **Optionally:** QUANTUM_MACHINERY_CATALOGUE
   - Deep dive on the quantum features involved
   - Understand limitations and constraints

**Example: "I want to create quantum entanglement"**
1. FEATURE_TOOL_CROSSREFERENCE → "Accessing Features" → "Create Entanglement"
   - Tools: Grower (1) or Quantum (2)
   - Method 1: Tool 1 → E
   - Method 2: Tool 2 → Q
2. TOOLS_INTERFACES_CATALOGUE → Tool 1 E action: "Entangle Plots"
   - Creates Bell φ+ state
   - Requires 2+ plots in same biome
   - Merges components
3. QUANTUM_MACHINERY_CATALOGUE → Section 5: Entanglement
   - Understand Bell states
   - Decoherence parameters
   - Cross-biome blocking

---

### Scenario 3: "I need to optimize tool layout/UI. Which tools are most used?"

1. **Start with:** TOOLS_INTERFACES_CATALOGUE
   - Section "UI Panels Mapped to Tools"
   - Count how many UI panels each tool uses
   - Identify which tools have most visual feedback

2. **Cross-check:** FEATURE_TOOL_CROSSREFERENCE
   - Capability Matrix: more ✓'s = more central
   - Feature Availability grids: broader coverage = more important

3. **Result:** Priority ranking for UI real estate

**Example Output:**
- Tool 1 (Grower): Uses 6 UI panels → 80% gameplay → Priority 1
- Tool 2 (Quantum): Uses 3 UI panels → 10% gameplay → Priority 2
- Tool 5 (Gates): Uses 2 UI panels → 5% gameplay → Priority 3
- Tool 4 (Control): Uses 4 UI panels → Research → Priority 2
- Tool 3 (Industry): Minimal UI → Economy only → Priority 5
- Tool 6 (Biome): Uses 2 UI panels → System → Priority 4

---

### Scenario 4: "A quantum feature isn't accessible. How do I add tool support?"

1. **Understand the feature:** QUANTUM_MACHINERY_CATALOGUE
   - Find your feature
   - Understand parameters, outputs, constraints
   - Identify which file implements it

2. **Find best tool:** TOOLS_INTERFACES_CATALOGUE
   - Look at tool purposes
   - Identify which tool makes sense for this feature
   - Check existing Q/E/R actions to find free slot

3. **Update catalogues:** FEATURE_TOOL_CROSSREFERENCE
   - Add ✓ to appropriate cell in capability matrix
   - Add to feature availability grid
   - Update "Accessing Quantum Machinery Features"
   - Add to UI panels mapping if needed

4. **Implement:**
   - Add action to Tool (ToolConfig.gd)
   - Add input handling (FarmInputHandler.gd)
   - Add UI feedback if needed
   - Create/update test

**Example: You want to add "Gate History Inspection" to Tool 1**
1. Feature: Gate history tracking (already exists)
2. Tool: Grower (1) might already have 3 actions (Q, E, R)
3. Better: Biome (6) has less usage → Tool 6 R (Inspect) already does this
4. Conclusion: Feature already accessible via Tool 6

---

### Scenario 5: "Create a quick reference card for players"

**Use:** FEATURE_TOOL_CROSSREFERENCE sections
- "Quick Reference: Tools vs Quantum Features" (by tool)
- "Capability Matrix" (visual grid)
- "Accessing Quantum Machinery Features" (goal-based)
- "Quick Start Guides" (by quantum goal)

**Print-friendly:** These are already formatted for easy copying to reference card

---

## CROSS-REFERENCE PATTERNS

### Most Connected Tool
**Tool 1 (Grower) 🌱**
- Accesses: State management, evolution, measurement, entanglement, semantic analysis
- UI Panels: 6
- Accessibility: Easiest for new players
- Frequency: ~80% of gameplay

### Most Specialized Tool
**Tool 5 (Gates) 🔄**
- Accesses: Quantum gates (primary)
- UI Panels: 2
- Accessibility: Advanced players only
- Frequency: ~5% of gameplay

### Most Research-Focused Tool
**Tool 4 (Control) ⚡**
- Accesses: Energy extraction, parameter tuning, semantic analysis
- UI Panels: 4
- Accessibility: Intermediate to advanced
- Frequency: ~10-15% (oscillates)

### Least Used Tool
**Tool 3 (Industry) 🏭**
- Accesses: Only economy (population transfer)
- UI Panels: 0 dedicated
- Accessibility: Infrastructure only
- Frequency: ~1% (occasional)

---

## QUICK LOOKUP TABLES

### By Quantum Feature (What tool uses it?)

```
FEATURE                          → TOOLS
─────────────────────────────────────────
State Initialization             → 1, 4, 6
Hamiltonian Evolution            → 1, 6
Lindblad Evolution               → 1, 4, 6
Population Transfer              → 1, 3, 4
Measurement                      → 1, 2
Quantum Gates                    → 5
Entanglement                     → 1, 2
Energy Extraction                → 4
Semantic Octant                  → 1, 4, 6
Attractor Analysis               → 1, 6
```

### By Tool (What features does it use?)

```
TOOL     NAME                 PRIMARY FEATURES
────────────────────────────────────────────────────
1        Grower              State, Evolution, Measurement
2        Quantum             Entanglement, Measurement
3        Industry            Population Transfer (eco only)
4        Control             Energy, Parameters, Analysis
5        Gates               Quantum Gates
6        Biome               State management, Analysis
```

### By Goal (Which tool to use?)

```
GOAL                           → TOOL(S) → ACTION
──────────────────────────────────────────────────
Plant crops                    → 1        → Q
Create entanglement            → 1 or 2   → E or Q
Measure state                  → 1 or 2   → R or R
Apply quantum gate             → 5        → Q or E
Extract energy                 → 4        → Q
Inspect quantum state          → 6        → R
Adjust decoherence             → 4        → R
Assign to biome                → 6        → Q
```

---

## MAINTENANCE: Keeping Catalogues Updated

### When you add a new quantum feature:
1. Add entry to QUANTUM_MACHINERY_CATALOGUE
2. If it has player interface: add to TOOLS_INTERFACES_CATALOGUE
3. Update FEATURE_TOOL_CROSSREFERENCE grids

### When you add a new tool action:
1. Add description to TOOLS_INTERFACES_CATALOGUE
2. Add feature accesses to FEATURE_TOOL_CROSSREFERENCE
3. Update capability matrix and feature grids

### When you change tool behavior:
1. Update TOOLS_INTERFACES_CATALOGUE (parameters, effects)
2. Update FEATURE_TOOL_CROSSREFERENCE (capabilities)
3. Test cross-reference consistency

### When you add a new UI panel:
1. Add to TOOLS_INTERFACES_CATALOGUE "Quantum State Visualization" or "Game State Display"
2. Update "UI Panels Mapped to Tools" in FEATURE_TOOL_CROSSREFERENCE
3. Link from appropriate tool description

---

## FILE LOCATIONS

```
llm_outbox/
├── QUANTUM_MACHINERY_CATALOGUE.md        ← What quantum features exist
├── TOOLS_INTERFACES_CATALOGUE.md         ← What tools & UI exist
├── FEATURE_TOOL_CROSSREFERENCE.md        ← How they connect
└── CATALOGUES_USER_GUIDE.md              ← This file
```

All files are in `llm_outbox/` for easy access and sharing.

---

## EXAMPLE WORKFLOWS

### Workflow 1: Debug "Why doesn't tool X do feature Y?"

```
User reports: "Grower tool won't let me inspect coherence"

1. TOOLS_INTERFACES_CATALOGUE → Tool 1 (Grower)
   Actions: Q (Plant), E (Entangle), R (Measure)
   → R doesn't say it inspects, just measures

2. FEATURE_TOOL_CROSSREFERENCE → Capability matrix
   Tool 1 → State Properties = ✓, Coherence = ✓
   But how to ACCESS?

3. FEATURE_TOOL_CROSSREFERENCE → "Accessing Features"
   To inspect: Use Tool 6 (Biome) → R

Conclusion: User needs Tool 6, not Tool 1
```

### Workflow 2: Plan new feature "Quantum Error Correction"

```
1. QUANTUM_MACHINERY_CATALOGUE
   Where does error correction fit?
   → New section 14: Quantum Error Correction
   → Describes syndrome measurement, recovery

2. TOOLS_INTERFACES_CATALOGUE
   Which tool should expose it?
   → Could be Tool 4 (Control) E submenu
   → Or new Tool 7?

3. FEATURE_TOOL_CROSSREFERENCE
   Add rows for error correction features
   Update affected tool capability matrices
   Add to "Accessing Features" table

4. Update catalogues
   → All three files updated consistently
```

### Workflow 3: Create learning path for new player

```
1. FEATURE_TOOL_CROSSREFERENCE → "Quick Start Guides"
   Start with: "Goal: Plant crops" → Use Tool 1 → Q

2. TOOLS_INTERFACES_CATALOGUE → Tool 1 section
   Read Q action: Plant Crops

3. QUANTUM_MACHINERY_CATALOGUE → State Initialization
   Understand what happens in background

Progression:
Day 1: Plant (Tool 1 Q) → Harvest (Tool 1 R)
Day 2: Entangle (Tool 1 E) → Measure (Tool 2 R)
Day 3: Energy Tap (Tool 4 Q) → Control (Tool 4 R)
Day 4: Gates (Tool 5 Q/E) for advanced play
```

---

## SUMMARY

Use these three catalogues as your **unified knowledge base** for SpaceWheat quantum machinery:

- **QUANTUM_MACHINERY_CATALOGUE** = "What exists?"
- **TOOLS_INTERFACES_CATALOGUE** = "How do players access it?"
- **FEATURE_TOOL_CROSSREFERENCE** = "How are they connected?"

**The cross-reference is the bridge** between what the system CAN do and what players CAN DO.

Every feature should appear in all three documents for complete visibility.
