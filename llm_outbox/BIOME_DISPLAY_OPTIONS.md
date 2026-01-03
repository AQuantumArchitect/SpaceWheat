# Biome Display UI Options

**Challenge:** Display biome information that scales from 3-30 emojis/icons with deep quantum state data

---

## Information Architecture Analysis

### Data to Display (Per Biome)

**Tier 1: Critical (Always Visible)**
- Biome name + emoji identifier
- Current temperature
- Total energy in bath
- Number of active projections (planted plots)

**Tier 2: Important (1-click access)**
- All producible emojis (3-30 items)
- Sun angle / day-night state (for BioticFlux)
- Icon count breakdown
- Bath mode (Hamiltonian/Lindblad/Hybrid)

**Tier 3: Detailed (2-click / specialist access)**
- Per-icon quantum operators
  - Hamiltonian terms (energy landscape)
  - Lindblad transfer rates (emoji → emoji flow)
- Bath quantum state
  - Basis state amplitudes (exponentially many!)
  - Phase angles
  - Energy distribution histogram
- Active projection details
  - Which plots (x,y positions)
  - North/south emoji assignments
- Bell gates (entangled pairs)

**Tier 4: Debug/Advanced**
- Full Hamiltonian matrix
- Full Lindblad superoperator
- Density matrix visualization
- Quantum trajectory data

---

## Option 1: Hierarchical Side Panel (Recommended for Desktop)

```
┌─────────────────────────────────────────┐
│ BIOMES                          [🌍 6]  │
├─────────────────────────────────────────┤
│                                         │
│ ▶ 🌾 BioticFlux        300K  ⚡0.42    │  ← Click to expand
│                                         │
│ ▼ 🏪 Market           295K  ⚡1.85    │  ← Expanded
│   ├─ Emojis (6): 👥💰👑🌾💨🌻        │
│   ├─ Icons: 6 configured               │
│   ├─ Active plots: 3                   │
│   └─ [View Details →]                  │
│                                         │
│ ▶ 🌲 Forest           298K  ⚡3.21    │
│                                         │
│ ▶ 🍳 Kitchen          310K  ⚡0.15    │
│                                         │
└─────────────────────────────────────────┘
```

**Click "View Details →" opens modal:**

```
┌───────────────────────────────────────────────────────┐
│ 🏪 Market Biome                        [Tabs] [Close]│
├───────────────────────────────────────────────────────┤
│ [Overview] [Icons] [Bath State] [Projections]        │
├───────────────────────────────────────────────────────┤
│                                                       │
│ OVERVIEW                                              │
│ ─────────────────────────────────────────────────     │
│ Temperature: 295K                                     │
│ Total Energy: 1.85 ⚡                                 │
│ Mode: Bath-first (Lindblad)                          │
│                                                       │
│ PRODUCIBLE EMOJIS (6)                                │
│ ┌───┬───┬───┬───┬───┬───┐                           │
│ │👥 │💰 │👑 │🌾 │💨 │🌻 │                           │
│ └───┴───┴───┴───┴───┴───┘                           │
│                                                       │
│ ACTIVE PLOTS (3)                                     │
│ • Plot (0,0): 🌾↔👥 | Energy: 0.42                  │
│ • Plot (2,0): 💰↔👑 | Energy: 0.89                  │
│ • Plot (4,1): 💨↔🌻 | Energy: 0.54                  │
│                                                       │
│ [Switch to Icons Tab for Operator Details]          │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**Pros:**
- Clean progressive disclosure (3 tiers)
- Compact when collapsed
- Scales to many biomes
- Modal provides space for complex data

**Cons:**
- Requires panel real estate
- Hidden information when collapsed
- Modal obscures game view

**Best For:** Desktop with >1024px width, information-dense gameplay

---

## Option 2: Hoverable Biome Bubbles (Visual-First)

```
┌─────────────────────────────────────────────────────┐
│                  [Game View Area]                   │
│                                                     │
│        🌾                    🏪                     │
│      ╱BioticFlux╲          ╱Market╲                │
│     (    6       )        (    6    )               │
│      ╲ 0.42⚡  ╱          ╲ 1.85⚡╱                │
│                                                     │
│   🌲                              🍳                │
│  ╱Forest╲                       ╱Kitchen╲          │
│ (   22   )                     (    4    )          │
│  ╲3.21⚡╱                       ╲0.15⚡╱           │
│                                                     │
└─────────────────────────────────────────────────────┘

[Hover over bubble:]

┌───────────────────────────┐
│ 🏪 Market                 │
│ ───────────────────────── │
│ Temp: 295K  Energy: 1.85⚡│
│                           │
│ Emojis: 👥💰👑🌾💨🌻     │
│                           │
│ Active plots: 3           │
│                           │
│ [Click for details]       │
└───────────────────────────┘
```

**Click opens same tabbed modal as Option 1**

**Pros:**
- Visual representation of biome relationships
- No permanent UI clutter
- Natural integration with existing force graph
- Spatial memory (biomes in consistent positions)

**Cons:**
- Limited space for hover tooltip
- Hard to compare multiple biomes
- Large biomes (22 emojis) need scrolling in tooltip

**Best For:** Visual/spatial thinkers, immersive gameplay

---

## Option 3: Compact Emoji Grid with Detail-on-Demand

```
┌─────────────────────────────────────────────────────┐
│ BIOME BROWSER                        [Grid] [List]  │
├─────────────────────────────────────────────────────┤
│                                                     │
│ 🌾 BioticFlux (6)     300K  0.42⚡  3 plots       │
│ ┌─┬─┬─┬─┬─┬─┐                                      │
│ │☀│🌾│👥│🍄│💨│🌿│  ← Click emoji to see icon    │
│ └─┴─┴─┴─┴─┴─┘      operators                      │
│                                                     │
│ 🏪 Market (6)        295K  1.85⚡  3 plots        │
│ ┌─┬─┬─┬─┬─┬─┐                                      │
│ │👥│💰│👑│🌾│💨│🌻│                                 │
│ └─┴─┴─┴─┴─┴─┘                                      │
│                                                     │
│ 🌲 Forest (22)       298K  3.21⚡  2 plots        │
│ ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐                         │
│ │🌿│🐺│🦅│🐇│🦌│🐦│🐜│🍂│☀│💧│🌲│🦊│ [+10 more]   │
│ └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘                         │
│                                                     │
│ 🍳 Kitchen (4)       310K  0.15⚡  0 plots        │
│ ┌─┬─┬─┬─┐                                          │
│ │🌾│🍞│🔥│💧│                                        │
│ └─┴─┴─┴─┘                                          │
│                                                     │
│ [Click biome name for bath state visualization]   │
└─────────────────────────────────────────────────────┘
```

**Click emoji (e.g., 🌾):**

```
┌─────────────────────────────────────┐
│ 🌾 Wheat Icon (BioticFlux)          │
├─────────────────────────────────────┤
│ HAMILTONIAN                         │
│ • Self-energy: 0.50                 │
│ • ☀ → 🌾: +0.10 (photosynthesis)   │
│                                     │
│ LINDBLAD (Decay/Transfer)           │
│ • 🌾 → 👥: 0.017 (harvest)          │
│ • 🌾 → 🍄: 0.003 (composting)       │
│                                     │
│ Currently in 3 plot projections     │
└─────────────────────────────────────┘
```

**Pros:**
- Scannable overview of all emojis
- Direct access to icon operators
- Compact for small biomes
- Expandable "+N more" for large biomes

**Cons:**
- Large biomes need horizontal scroll or wrapping
- No immediate quantum state visibility
- Less spatial/visual than force graph

**Best For:** Players who think in terms of emoji relationships

---

## Option 4: Split-View with Live Bath Visualization

```
┌───────────────────┬─────────────────────────────────┐
│ BIOMES (Selector) │ BATH STATE VISUALIZATION        │
│                   │                                 │
│ [🌾 BioticFlux]  │     Energy Distribution         │
│  🏪 Market       │   ┌─────────────────────────┐   │
│  🌲 Forest       │ 1 │████████░░░░░░░░░░░░░░░░│   │
│  🍳 Kitchen      │   │                         │   │
│                   │ 0 ├─────────────────────────┤   │
│ OVERVIEW          │   │☀│🌾│👥│🍄│💨│🌿│      │   │
│ ────────────────  │   └─────────────────────────┘   │
│ Temp: 300K        │                                 │
│ Energy: 0.42⚡    │   Phase Angles (Bloch Sphere)  │
│ Mode: Hybrid      │         ▲ |0⟩                  │
│                   │        ╱│╲                     │
│ EMOJIS (6)        │       ╱ │ ╲                    │
│ ┌──┬──┬──┐        │      ╱  ●  ╲ ← 🌾 state       │
│ │☀ │🌾│👥│        │     ╱   │   ╲                  │
│ │🍄│💨│🌿│        │    ◀────┼────▶                 │
│ └──┴──┴──┘        │         │                      │
│                   │         ▼ |1⟩                  │
│ PLOTS (3)         │                                 │
│ • (0,0): 🌾↔👥   │   Transfer Rates (Lindblad)    │
│ • (1,0): 🍄↔🌿   │   🌾 ──0.017──→ 👥             │
│ • (2,1): ☀↔🌾   │   🍄 ──0.40───→ 💨             │
│                   │                                 │
│ [Icon Details]    │   [Switch to Density Matrix]   │
└───────────────────┴─────────────────────────────────┘
```

**Pros:**
- **Live visualization** of quantum state
- Side-by-side comparison enabled
- Dedicated space for complex visualizations
- Physics-focused interface

**Cons:**
- Requires significant screen space (>1280px width)
- Complex for casual players
- High cognitive load

**Best For:** Advanced players, quantum mechanics enthusiasts, debugging

---

## Option 5: Overlay Panels (Keyboard-Activated)

```
Press 'B' → Toggle biome overlay

┌─────────────────────────────────────────────────────┐
│                 [Translucent Overlay]                │
│ ╔═══════════════════════════════════════════════╗   │
│ ║ BIOMES                            [B to close]║   │
│ ╠═══════════════════════════════════════════════╣   │
│ ║                                               ║   │
│ ║ 1️⃣ 🌾 BioticFlux    300K  0.42⚡  6 emojis  ║   │
│ ║    ☀🌾👥🍄💨🌿                             ║   │
│ ║    [Press 1 for details]                      ║   │
│ ║                                               ║   │
│ ║ 2️⃣ 🏪 Market        295K  1.85⚡  6 emojis  ║   │
│ ║    👥💰👑🌾💨🌻                             ║   │
│ ║    [Press 2 for details]                      ║   │
│ ║                                               ║   │
│ ║ 3️⃣ 🌲 Forest        298K  3.21⚡  22 emojis ║   │
│ ║    🌿🐺🦅🐇🦌🐦🐜🍂 [+14 more]             ║   │
│ ║    [Press 3 for details]                      ║   │
│ ║                                               ║   │
│ ║ 4️⃣ 🍳 Kitchen       310K  0.15⚡  4 emojis  ║   │
│ ║    🌾🍞🔥💧                                  ║   │
│ ║    [Press 4 for details]                      ║   │
│ ╚═══════════════════════════════════════════════╝   │
└─────────────────────────────────────────────────────┘

Press '1' → BioticFlux details

┌─────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════╗   │
│ ║ 🌾 BioticFlux Bath            [1-Overview]    ║   │
│ ║                               [2-Icons]       ║   │
│ ║                               [3-Quantum]     ║   │
│ ║                               [B-Close]       ║   │
│ ╠═══════════════════════════════════════════════╣   │
│ ║ EMOJIS (6)                                    ║   │
│ ║ ┌───┬───┬───┬───┬───┬───┐                    ║   │
│ ║ │ ☀ │ 🌾│ 👥│ 🍄│ 💨│ 🌿│                    ║   │
│ ║ │Sun│Wht│Ppl│Msh│Wnd│Veg│                    ║   │
│ ║ └───┴───┴───┴───┴───┴───┘                    ║   │
│ ║                                               ║   │
│ ║ ACTIVE PROJECTIONS (3)                        ║   │
│ ║ Plot (0,0): 🌾 ↔ 👥  | Energy: 0.42          ║   │
│ ║ Plot (1,0): 🍄 ↔ 🌿  | Energy: 0.28          ║   │
│ ║ Plot (2,1): ☀ ↔ 🌾  | Energy: 0.15          ║   │
│ ║                                               ║   │
│ ║ BATH STATE                                    ║   │
│ ║ Temperature: 300K                             ║   │
│ ║ Total Energy: 0.85 ⚡                         ║   │
│ ║ Sun Angle: ☀️ 11.7° (Day)                    ║   │
│ ║                                               ║   │
│ ║ Press 2 for icon operators, 3 for quantum    ║   │
│ ╚═══════════════════════════════════════════════╝   │
└─────────────────────────────────────────────────────┘
```

**Pros:**
- Doesn't compete for permanent screen space
- Keyboard-driven (fast for experienced players)
- Can overlay entire game view when needed
- Progressive disclosure via number keys

**Cons:**
- Requires learning keyboard shortcuts
- Overlay obscures game
- Not mouse-friendly

**Best For:** Keyboard-first players, streamlined for speed

---

## Option 6: Expandable Cards with Emoji Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│ ╔════════════════════════════════════════════════╗  │
│ ║ 🌾 BioticFlux                    [▼ Collapse] ║  │
│ ╠════════════════════════════════════════════════╣  │
│ ║ 300K  │  0.42⚡  │  3 plots  │  6 emojis      ║  │
│ ╠════════════════════════════════════════════════╣  │
│ ║                                                ║  │
│ ║  EMOJI FLOW (Lindblad Transfers)              ║  │
│ ║                                                ║  │
│ ║         ☀ (Sun)                                ║  │
│ ║         │ 0.10                                 ║  │
│ ║         ↓                                      ║  │
│ ║    🌾 (Wheat) ───0.017──→ 👥 (People)        ║  │
│ ║         │                                      ║  │
│ ║         │ 0.003                                ║  │
│ ║         ↓                                      ║  │
│ ║    🍄 (Mushroom) ─0.40──→ 💨 (Wind)          ║  │
│ ║         ↑                                      ║  │
│ ║         │ 0.05                                 ║  │
│ ║    🌿 (Vegetation)                            ║  │
│ ║                                                ║  │
│ ║  PROJECTIONS                                   ║  │
│ ║  • (0,0): 🌾↔👥 | 0.42⚡ | Not measured      ║  │
│ ║  • (1,0): 🍄↔🌿 | 0.28⚡ | Not measured      ║  │
│ ║  • (2,1): ☀↔🌾 | 0.15⚡ | Not measured      ║  │
│ ║                                                ║  │
│ ║  [View Full Hamiltonian] [Bath Visualization] ║  │
│ ╚════════════════════════════════════════════════╝  │
│                                                     │
│ ╔════════════════════════════════════════════════╗  │
│ ║ 🏪 Market                        [▶ Expand]   ║  │
│ ╠════════════════════════════════════════════════╣  │
│ ║ 295K  │  1.85⚡  │  3 plots  │  6 emojis      ║  │
│ ╚════════════════════════════════════════════════╝  │
│                                                     │
│ [Collapsed cards for Forest, Kitchen...]          │
└─────────────────────────────────────────────────────┘
```

**Pros:**
- **Shows causal relationships** (emoji flow)
- Expand only biomes of interest
- Integrates quantum operators into visual flow
- Scales well (collapse unused biomes)

**Cons:**
- Complex flow diagrams for large biomes (Forest: 22 emojis!)
- Vertical scrolling needed with 4+ biomes
- Flow layout algorithm needed

**Best For:** Understanding ecosystem dynamics, causal thinkers

---

## Comparison Matrix

| Option | Small Biomes | Large Biomes | Quantum Detail | Space Efficiency | Ease of Use |
|--------|-------------|--------------|----------------|------------------|-------------|
| 1. Hierarchical Panel | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 2. Hoverable Bubbles | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 3. Emoji Grid | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 4. Split-View | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| 5. Overlay Panels | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 6. Flow Diagram Cards | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |

---

## Hybrid Recommendation: Progressive Disclosure System

Combine **Option 2** (Bubbles) + **Option 4** (Split-View) + **Option 3** (Grid):

### Tier 1: Default View (Hoverable Bubbles on Force Graph)
- Visual, spatially consistent, low clutter
- Hover shows: Name, temp, energy, emoji count, plot count

### Tier 2: Click Bubble → Side Panel with Emoji Grid
- Opens side panel (collapsible)
- Shows emoji grid (compact for small, scrollable for large)
- Shows active projections list
- Button: "Open Bath Visualizer"

### Tier 3: Bath Visualizer → Full Modal/Split-View
- Energy distribution histogram
- Lindblad transfer flow diagram
- Hamiltonian heatmap
- Live Bloch sphere (if single qubit)
- Density matrix (if advanced mode enabled)

**Keyboard Shortcuts:**
- `B` → Toggle biome side panel
- `1-4` → Select biome 1-4
- `Shift+B` → Open bath visualizer for selected biome

---

## Technical Implementation Notes

### For Large Biomes (20-30 emojis):

**Emoji Grid with Virtual Scrolling:**
```gdscript
# Only render visible rows
var visible_rows = ceil(panel_height / emoji_cell_height)
var start_idx = scroll_position / emoji_cell_height
var end_idx = min(start_idx + visible_rows, total_emojis)

for i in range(start_idx, end_idx):
    render_emoji_cell(emojis[i], i)
```

**Lindblad Flow Diagram (Forest with 22 emojis):**
- Group emojis by trophic level (producers, herbivores, carnivores)
- Show only active transfers (> 0.01 rate threshold)
- Option to toggle "Show All" vs "Show Active Only"

**Hamiltonian Heatmap:**
- 22×22 matrix for Forest = 484 cells
- Use color gradient (blue=negative, white=0, red=positive)
- Hover cell shows exact value
- Click row/column to highlight related emoji

### Data Update Frequency

```gdscript
# Bath state updates every frame (0.016s @ 60fps)
func _process(delta):
    biome.bath.evolve(delta)

# UI updates less frequently to reduce overhead
var ui_update_timer = 0.0
const UI_UPDATE_INTERVAL = 0.1  # 10fps for UI

func _process(delta):
    ui_update_timer += delta
    if ui_update_timer >= UI_UPDATE_INTERVAL:
        _update_biome_display()
        ui_update_timer = 0.0
```

---

## Accessibility Considerations

- **Color Blindness**: Use patterns + colors for quantum state
- **Text Size**: Scalable UI (already have scale_factor system)
- **Keyboard Navigation**: All actions accessible without mouse
- **Screen Readers**: Label emojis with text names
- **Cognitive Load**: Progressive disclosure (don't show everything at once)

---

## Next Steps

1. **Prototype Option 2 (Bubbles)** - Integrate with existing QuantumForceGraph
2. **Test with Forest biome** (22 emojis) - Verify scaling
3. **Design bath state visualizer** - Energy histogram + transfer diagram
4. **User testing** - Which option feels best during gameplay?

Would you like me to implement any of these options, or combine elements into a hybrid design?
