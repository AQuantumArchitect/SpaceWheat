class_name VisualizationConstants
extends RefCounted

## Visualization Constants - Single Source of Truth
##
## Shared constants for all bubble rendering systems to ensure
## visual consistency across Atlas, Native, and Fallback renderers.

# Season system constants (phi decomposition into RGB primaries)
# Used for seasonal coupling, phi broadcast, and angular force
const SEASON_ANGLES: Array[float] = [
	0.0,           # Red season (0°)
	TAU / 3.0,     # Green season (120°)
	2.0 * TAU / 3.0  # Blue season (240°)
]

const SEASON_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3),  # Red (0°)
	Color(0.3, 1.0, 0.3),  # Green (120°)
	Color(0.3, 0.3, 1.0)   # Blue (240°)
]

# Circle segment counts for arc/ring rendering
const CIRCLE_SEGMENTS_DEFAULT: int = 16
const ARC_SEGMENTS_DEFAULT: int = 24

# Glow layer multipliers (for multi-layer glow systems)
const GLOW_OUTER_MULT: float = 2.2
const GLOW_MID_MULT: float = 1.6
const GLOW_INNER_MULT: float = 1.3
