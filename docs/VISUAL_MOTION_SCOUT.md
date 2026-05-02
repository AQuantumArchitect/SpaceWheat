# Visual Motion Scout

**Date:** 2026-04-19
**Purpose:** Identify visual motion channels that compete with the continuous graph dynamics.

## Working Rule

Do not express self-energy, berry phase, or status by breathing the object body. Bubble radius should be stable except when the underlying quantum state genuinely changes the node radius. Bloch `phi` owns angular phase expression, so any future "twist" should be a projection-lens contour/basis deformation rather than another phase rotation on the bubble.

The enforceable version of this rule now lives in `Core/Visualization/QuantumVisualGrammar.gd`: every channel gets one owner, one data source, and one motion policy.

## Current Findings

### Bubble Body

- `Core/Visualization/BatchedBubbleRenderer.gd` previously computed a sinusoidal `pulse_phase` from `node.get_pulse_rate()`.
- `Core/Visualization/BubbleAtlasBatcher.gd` previously multiplied bubble radius by `1.0 + pulse_phase * 0.08`.
- The old `QuantumBubbleRenderer.gd` fallback path had the same measured-bubble pulsing and has been removed from the live renderer surface.
- This made berry-phase-derived pulse rate visible as continuous object-size breathing.
- Current status: removed from atlas rendering; native/GDScript fallback bubble paths have been deleted. Phase wedges and data rings remain.

### Measured Bubble Status

- `Core/Visualization/BubbleAtlasBatcher.gd` also pulsed measured-bubble glow radius and outline alpha with `sin(time * 4.0)`.
- Current status: measured glow and outline are fixed-size/fixed-alpha status marks.

### Infrastructure Lines

- `Core/Visualization/QuantumInfraRenderer.gd` pulses Bell/cluster gate line width, alpha, and connector size.
- `UI/PlotGridDisplay.gd` has older infrastructure drawing with similar pulsing line widths.
- Recommendation: convert these to stable width/color, with state represented by topology, dash pattern, contour band, or actual data intensity.

### Plot UI

- `UI/PlotTile.gd` lightens planted tile backgrounds using a shared sine wave.
- `UI/PlotTile.gd` also pulses entanglement indicator color.
- Recommendation: handle as a separate UI pass. The gameplay graph fix should not casually redesign plot tile states.

### Rejection Feedback

- `UI/PlotGridDisplay.gd` draws expanding rejection rings.
- This is transient feedback rather than ambient breathing. It is less risky, but it should remain short-lived and event-bound.

## Self-Energy Projection Direction

Good 2D mappings:

- stable shell/contour membership around any selected anchor emoji;
- signed energy color or line style for above/below anchor;
- shell thickness from local density of nearby self-energy values;
- Hamiltonian coupling as strands between shells;
- driven self-energy as recomputed contour position or tick/marker offset.

Avoid:

- object-size pulsing;
- alpha breathing;
- assigning self-energy to the same angular channel already used by Bloch `phi`;
- adding ambient motion not traceable to graph mechanics or player action.
