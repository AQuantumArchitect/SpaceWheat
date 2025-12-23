# Manual Test: Entanglement Line Visualization

## How to test the entanglement lines:

1. **Run the game:**
   ```bash
   ./test_farm_ui.sh
   ```

2. **Plant some wheat:**
   - Click an empty plot (it will become selected with a border)
   - Click the "🌱 Plant (5💰)" button
   - Repeat for 3-4 adjacent plots

3. **Create entanglements:**
   - Click one of your planted plots
   - Click the "🔗 Entangle" button
   - Click another planted plot
   - You should see a **shimmering blue/purple line** appear between them!

4. **What to look for:**
   - Animated lines connecting entangled plots
   - Lines pulse/shimmer with changing alpha
   - Colors shift between blue and purple
   - Lines have a gradient effect
   - Strength affects line opacity (stronger = more opaque)

5. **Test edge cases:**
   - Create multiple entanglements (max 3 per plot)
   - Harvest a plot - lines should disappear
   - Entangle plots in different patterns (square, diagonal, chain)

## Expected behavior:

- Lines appear immediately when entanglement is created
- Lines animate continuously (pulsing, color shifting)
- Lines are drawn behind the tiles but above the background
- Lines disappear when plots are harvested
- Maximum 3 entanglements per plot (entangle button disabled after limit)

## Visual specs:

- Line width: 3 pixels
- Base colors: Blue (0.4, 0.6, 1.0) → Purple (0.8, 0.4, 1.0)
- Alpha range: 0.6 - 0.9 (pulsing)
- Animation speed: ~2-3 Hz pulse
- Gradient: Start and end colors shift over time
