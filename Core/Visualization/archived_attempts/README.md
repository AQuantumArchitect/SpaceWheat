# Archived Visualization Attempts

This folder contains abandoned force-graph visualization systems that were replaced by the current bath-first quantum visualization.

## Archived Files (Dec 2024)

### Old Glyph-Based System:
- `QuantumVisualizationController.gd` - Main controller for glyph-based visualization
- `QuantumGlyph.gd` - Individual glyph component
- `DetailPanel.gd` - Detail panel for selected glyphs
- `SemanticEdge.gd` - Edge connections between glyphs

### Old Force-Graph System:
- `SimpleQuantumVisualizationController.gd` - Alternative force-directed visualization

## Why Archived?

These systems were "haunting" the codebase - creating parallel layers that blocked input and caused confusion. The ghost `QuantumVisualizationController` Control node in FarmUI.tscn (z_index=1, fullscreen, no script) was blocking all touch input to the actual working visualization.

## Current Active System (Dec 2024)

- `BathQuantumVisualizationController.gd` - Bath-first quantum visualization controller
- `QuantumForceGraph.gd` - Force-directed physics engine with touch gesture detection
- `QuantumNode.gd` - Quantum node component with visual state management
- `BiomeLayoutCalculator.gd` - Shared layout calculator for plot/bubble positioning

## Date Archived
December 28, 2024
