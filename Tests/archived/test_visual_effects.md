# Visual Effects Test Guide

## How to test all the new visual effects:

### 1. Run the game:
```bash
./test_farm_ui.sh
```

### 2. Test Planting Effect 🌱
- Click an empty plot
- Click "🌱 Plant (5💰)" button
- **Expected:**
  - Green sparkles burst from the plot
  - Plot flashes green briefly
  - Credits counter animates (scales up and changes color)
  - Seed emoji appears on plot

### 3. Test Growing State 🌾
- Wait for planted wheat to grow (or watch in real-time)
- **Expected:**
  - Background color changes based on quantum state (green ↔ blue gradient)
  - Growth bar fills up smoothly
  - Color gets brighter as it grows
  - Emoji may change between 🌾 and 👥 based on superposition state

### 4. Test Harvest Effect ✂️
- Wait for wheat to mature (golden glow, pulsing)
- Click the mature plot
- Click "✂️ Harvest" button
- **Expected:**
  - Golden wheat sparkles (🌾) burst outward
  - Plot flashes golden yellow
  - Wheat counter animates (scales up and flashes)
  - Plot becomes empty again

### 5. Test Entanglement Effect 🔗
- Plant 2 adjacent plots
- Click one plot
- Click "🔗 Entangle" button
- Click the other plot
- **Expected:**
  - Both plots flash blue
  - Blue sparkles (🔗) appear on both plots
  - Shimmering blue/purple line appears between them
  - Line animates continuously (pulse, color shift)

### 6. Test Measurement Effect 👁️
- Plant a plot (in superposition state)
- Click the plot
- Click "👁️ Measure" button
- **Expected:**
  - Purple particles (👁️) burst from plot
  - Plot flashes purple
  - Quantum state collapses to definite value
  - Info shows "-10% yield penalty"

### 7. Test Number Animations 💰🌾
- Buy seeds, harvest wheat, watch the counters
- **Expected:**
  - Numbers scale up when changing
  - Flash white on increase
  - Flash reddish on decrease
  - Smooth animation, not instant

## Visual Effect Specifications:

### Particle Effects:
- **Harvest**: 15 golden wheat emojis, burst pattern, 1s lifetime
- **Plant**: 8 green sprout emojis, burst pattern, 1s lifetime
- **Measure**: 20 purple eye emojis, burst pattern, 1s lifetime
- **Entangle**: 5 blue link emojis per plot, burst pattern, 1s lifetime

### Flash Effects:
- **Plant**: Green flash (0.4, 0.9, 0.4), 0.3s duration
- **Harvest**: Golden flash (1.0, 0.9, 0.3), 0.4s duration
- **Measure**: Purple flash (0.7, 0.3, 1.0), 0.5s duration
- **Entangle**: Blue flash (0.3, 0.7, 1.0), 0.3s duration

### Animations:
- Particles fade out, shrink, and move outward
- Flashes fade in (30% duration) then out (70% duration)
- Numbers scale to 120% then back to 100%
- Max alpha for flashes: 0.6

## Known Good Behaviors:

✅ All effects trigger on correct actions
✅ Particles don't overlap text
✅ Animations don't block gameplay
✅ Multiple effects can play simultaneously
✅ No performance issues (smooth 60 FPS)
✅ Effects layer correctly (particles above tiles)
