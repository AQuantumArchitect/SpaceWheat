# SpaceWheat UI Proposal - Simplified for Quantum Farm

**Date**: 2025-12-13
**Based on**: SpaceWheat UI Design Vision (simplified for kids' game)

## Core Philosophy

Take the **emoji lattice** concept and **quantum visualization** from the complex design, but make it **touchscreen-friendly** and **accessible to 10-year-olds**.

---

## Visual Layout

```
┌──────────────────────────────────────────────────────┐
│  [💰 125]  [🌾 47]  [⏱️ 2:34]  [📊 Stats] [❓ Help]  │  ← Top Bar
├──────────────────────────────────────────────────────┤
│                                                      │
│              ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗          │
│              ║   ║ ║ 🌾║ ║   ║ ║   ║ ║   ║          │  ← Farm Grid
│              ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝          │    (5x5 emoji lattice)
│                                                      │
│              ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗          │    Click = Select
│              ║   ║ ║🍅M║ ║ g ║ ║   ║ ║ 🌾║          │    Hold = Inspect
│              ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝          │    Drag = Entangle
│                                                      │
│              ... (3 more rows) ...                   │
│                                                      │
│  ┌────────────────────────────────────────────┐     │
│  │ Selected: Plot (2,1)                       │     │  ← Info Panel
│  │ 🌾 Growing - 67%  [🔗 x2]  [📊 θ=1.2]    │     │    (when plot selected)
│  │ Berry Phase: 3 cycles  Quality: 115%      │     │
│  └────────────────────────────────────────────┘     │
│                                                      │
├──────────────────────────────────────────────────────┤
│  [🌱 Plant] [✂️ Harvest] [🔗 Entangle] [👁️ Measure] │  ← Action Bar
└──────────────────────────────────────────────────────┘
```

---

## The Emoji Lattice (Farm Grid)

### Visual States

**Empty Plot**: `[ ]`
- Light gray square
- Faint grid lines
- Subtle glow when hovered

**Wheat Seedling**: `[🌱]`
- Small green sprout emoji
- Gentle upward growth animation
- Pale green glow

**Growing Wheat**: `[g]`
- Medium wheat emoji (or "g" text)
- Size increases with growth (50% → 100%)
- Warm yellow-green glow
- Pulse speed = growth rate

**Mature Wheat**: `[🌾]`
- Full golden wheat emoji
- Bright golden glow (ready to harvest!)
- Gentle swaying animation

**Tomato (Chaotic)**: `[🍅M]`
- Tomato emoji + conspiracy indicator
- Flickering multi-color glow
- "M" = Meta conspiracy active
- Erratic pulse pattern

**Entanglement Lines**:
- Shimmering blue/purple lines between connected plots
- Animated particles flowing along connections
- Thickness = entanglement strength
- Glow intensity = energy transfer rate

### Quantum State Visualization

**Colors Based on Quantum State**:
- **Green** (θ ≈ 0): Natural growth mode (🌾)
- **Blue** (θ ≈ π): Labor mode (👥)
- **Purple** (θ ≈ π/2): Superposition (both!)
- **Golden**: High energy / mature
- **Red/Orange**: Contaminated by tomato conspiracy

**Glow Intensity** = Energy level
**Pulse Speed** = Growth rate
**Flicker** = Chaos/decoherence

---

## Input System (Simplified from Vision Doc)

### Touch/Mouse Controls

**Tap Empty Plot**:
- Select plot
- Show info panel
- Action bar highlights available actions

**Tap Selected Plot Again**:
- Plant wheat (if empty + have credits)
- Harvest (if mature)

**Drag Between Plots**:
- Create entanglement connection
- Visual line follows finger/mouse
- Snaps into place on release
- Shows "Max 3 connections!" if limit reached

**Long Press Plot**:
- Open detailed inspector
- Shows full quantum state (θ, φ visualization as circle)
- Energy graph
- Entanglement list
- Berry phase history

**Pinch/Scroll**:
- Zoom in/out on grid
- See more plots or focus on one

### Keyboard Shortcuts (Optional, for Power Users)

- **1-9**: Quick select plot (row-major order)
- **P**: Plant at selected plot
- **H**: Harvest selected plot
- **M**: Measure (observer effect)
- **Space**: Pause/unpause time
- **+/-**: Speed up/slow down time
- **Tab**: Toggle quantum overlay (show Bloch vectors)

---

## Action Bar (Bottom of Screen)

### 🌱 Plant
- **Cost**: 5 credits
- **Effect**: Plant wheat in selected plot
- **Disabled** if: plot occupied, not enough credits
- **Visual**: Button pulses when affordable and plot selected

### ✂️ Harvest
- **Effect**: Collect wheat from mature plot
- **Disabled** if: plot not mature
- **Visual**: Golden glow when available

### 🔗 Entangle
- **Mode**: Enter "entangle mode"
- **Effect**: Drag between two plots to connect
- **Visual**: Valid targets glow blue
- **Limit**: Max 3 connections per plot

### 👁️ Measure
- **Effect**: Observer effect - collapse superposition
- **Preview**: Shows what state will collapse to (70% 🌾 / 30% 👥)
- **Warning**: Reduces final yield by 10%
- **Visual**: Confirmation dialog with prediction

---

## Top Bar (Status Display)

### Left Side: Resources
- **💰 125**: Current credits (green when increasing, red when spending)
- **🌾 47**: Wheat in inventory
- **⏱️ 2:34**: Time until next Carrion Throne quota (when added)

### Right Side: Info
- **📊 Stats**: Open statistics panel
  - Total wheat harvested
  - Average growth rate
  - Entanglement efficiency
  - Berry phase progress
- **❓ Help**: Tutorial messages & quantum concept explanations

---

## Inspector Panel (Detailed View)

**Triggered by**: Long press on plot

**Contains**:
```
┌─────────────────────────────────────────┐
│ Plot (2, 3) - Growing 67%               │
│                                         │
│  Quantum State:                         │
│    ╭───────╮                           │
│    │   •   │  ← Bloch sphere (top view) │
│    │  ↗    │     Dot = current state    │
│    ╰───────╯     🌾 = north, 👥 = south │
│                                         │
│  Energy: ████████░░ 0.8                │
│  Growth: ████████████████████░░░ 67%    │
│                                         │
│  Entangled to:                          │
│    🔗 Plot (1,3) - strength 0.8        │
│    🔗 Plot (2,2) - strength 0.9        │
│                                         │
│  Berry Phase: 3 cycles                  │
│  Quality Bonus: +15%                    │
│                                         │
│  [Measure] [Break Entanglement]        │
└─────────────────────────────────────────┘
```

---

## Quantum Visualization Features

### From Vision Doc - Adapted

**1. Quantum Sprites** (Background beauty)
- Faint particle systems showing quantum field
- Colors shift with overall farm coherence
- Not interactive, just atmospheric

**2. Emoji Lattice** (Interactive gameplay)
- Our 5x5 farm grid
- Click-based interaction
- Clear visual feedback

**3. Measurement Preview** (Before committing)
- Tap "👁️ Measure" → Shows probability
- "70% chance: 🌾 Natural (+12 wheat)"
- "30% chance: 👥 Labor (+8 wheat)"
- Confirm or cancel

**4. Temporal Feedback** (Growth visualization)
- Time flows continuously (can pause/speed up)
- Growth bars fill in real-time
- Entanglement effects visible immediately
- No complex timeline scrubbing (too complex for kids)

---

## Visual Feedback Systems

### Harvesting Animation
1. Click harvest on mature wheat
2. Wheat glows bright golden
3. Wheat emoji shoots upward and splits into individual units
4. Numbers fly to inventory counter "+12 🌾"
5. Plot returns to empty with brief sparkle
6. Quiet "ding" sound

### Entanglement Creation
1. Drag from plot A to plot B
2. Line follows finger/cursor (shimmering blue)
3. On release, line snaps into place
4. Both plots glow briefly
5. Energy particles start flowing along connection
6. Soft "whoosh" sound

### Conspiracy Activation (Tomatoes - Later)
1. Tomato node energy crosses threshold
2. Tomato starts flickering red/orange
3. Expanding ripple effect
4. Nearby wheat plots show contamination (color shift)
5. Message: "🔴 CONSPIRACY ACTIVATED: growth_acceleration"
6. Ominous hum sound

---

## Accessibility Features

### For Kids (10-year-olds)
- **Large touch targets**: Minimum 60px squares
- **Clear icons**: Emoji + text labels
- **Immediate feedback**: Every action has sound + visual
- **Undo option**: "Oops" button for recent actions
- **Helpful tooltips**: Tap "?" on anything for explanation

### Color Blind Support
- **Patterns + Colors**: Not just color coding
- **Text labels**: Always available
- **High contrast mode**: Optional
- **Shape differences**: Empty/growing/mature have different shapes

### Tutorial Integration
- **Contextual hints**: Arrow pointing to next action
- **Progressive disclosure**: Features unlock gradually
- **Practice mode**: Sandbox with no consequences
- **Quantum concept cards**: Simple explanations when new concepts appear

---

## Comparison to Vision Doc

### What We Kept ✅
- Emoji lattice core concept
- Quantum state visualization (colors, glow)
- Click-to-select pattern
- Measurement preview system
- Beautiful visual feedback
- Keyboard shortcuts (optional)
- Inspector panel for details

### What We Simplified 🔧
- **No 3-layer architecture**: Just one farm view
- **No timeline scrubbing**: Continuous time only (pause/speed up)
- **No agent hotkeys**: Direct plot interaction
- **No away teams**: All actions immediate
- **No Socialite layer**: Focus on core farming

### What We Adapted 🔄
- **"Nodes"** → **Farm plots**
- **"Quantum tunnels"** → **Entanglement lines**
- **"Measurement synchronization"** → **Observer effect preview**
- **"Strategic empire view"** → **Simple stats panel**
- **"Temporal manipulation"** → **Growth over time**

---

## Implementation Priority

### Phase 1: Core Grid (MVP)
- [ ] 5x5 emoji grid display
- [ ] Click to select plots
- [ ] Plant/harvest buttons
- [ ] Credits display
- [ ] Basic growth animation

### Phase 2: Quantum Visuals
- [ ] Glow effects (energy-based color)
- [ ] Entanglement lines
- [ ] Growth pulse animation
- [ ] Harvest particle effects

### Phase 3: Inspector & Details
- [ ] Long-press inspector panel
- [ ] Bloch sphere visualization
- [ ] Detailed stats
- [ ] Quantum state info

### Phase 4: Polish
- [ ] Sound effects
- [ ] Tutorial overlays
- [ ] Help system
- [ ] Keyboard shortcuts

---

## Technical Implementation Notes

### Godot Scene Structure
```
FarmView (Node2D)
├── BackgroundLayer (CanvasLayer -1)
│   └── QuantumParticles (GPUParticles2D)
├── GridContainer (GridContainer)
│   ├── PlotTile x25 (Custom Control)
│   │   ├── Background (ColorRect)
│   │   ├── Emoji (Label)
│   │   ├── GrowthBar (ProgressBar)
│   │   └── GlowEffect (Sprite2D + Shader)
├── EntanglementLines (Node2D)
│   └── Line x N (Line2D + particles)
├── UILayer (CanvasLayer 1)
│   ├── TopBar (HBoxContainer)
│   ├── InfoPanel (PanelContainer)
│   └── ActionBar (HBoxContainer)
└── InspectorPanel (Popup)
```

### Shader for Quantum Glow
```glsl
// Energy-based glow
uniform float energy: hint_range(0.0, 10.0) = 1.0;
uniform float theta: hint_range(0.0, 3.14159) = 1.57;

// Color based on quantum state
vec3 natural_color = vec3(0.2, 0.8, 0.2);  // Green
vec3 labor_color = vec3(0.2, 0.4, 0.8);    // Blue
vec3 blend = mix(labor_color, natural_color, cos(theta/2.0));

// Glow intensity based on energy
float glow = energy * 0.5;
COLOR.rgb = blend + vec3(glow);
```

---

## Questions for Review

1. **Grid Size**: 5x5 (25 plots) good? Or start smaller (3x3)?
2. **Visual Style**: Pixel art emojis or vector emojis?
3. **Time Control**: Continuous real-time or turn-based?
4. **Tutorial Approach**: Guided tour or discovery-based?
5. **Tomato Integration**: When to introduce chaos? (Level 6+ per design doc)

---

## Summary

This UI takes the **best concepts** from the complex vision (emoji lattice, quantum visualization, measurement preview) and **simplifies** them into a **touchscreen-friendly** farming game that can still teach real quantum mechanics.

**Core Loop**:
1. Tap to select plot
2. Tap button to plant
3. Watch wheat grow (with quantum glow!)
4. Drag to entangle (faster growth)
5. Tap to harvest
6. Repeat with berry phase bonuses

**Quantum Depth**:
- Superposition visible in color blend
- Entanglement creates real mechanical benefits
- Measurement has observable consequences
- Energy flows visualized beautifully

**Kid-Friendly**:
- Immediate feedback
- Clear visual language
- Optional complexity (inspector panel)
- Help always available

This should be buildable in 1-2 days and fun to play!
