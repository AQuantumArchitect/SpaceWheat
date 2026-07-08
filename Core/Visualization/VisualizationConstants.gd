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


## ============================================================================
## Bubble visual math — single authority
## ============================================================================
## Pure functions (no game state). Every bubble renderer derives color/season/
## uncertainty from THESE, so the formulas live in exactly one place.

## Station RIPENESS — the ambient "worth popping?" signal (Mini-Metro pass).
## Normalized binary entropy of the pole distribution: H(p)/ln2 ∈ [0,1].
## This is the honest expected pop payoff — MEASURE samples a pole and POP pays
## surprisal −kT·ln(p_outcome), so E[reward]/kT = H(p); kT cancels in the
## normalization. Peaks at even superposition, 0 at certainty (a near-certain
## collapse pays nothing). p0/p1 come straight from viz_cache bloch reads.
static func ripeness(p0: float, p1: float) -> float:
	var mass := p0 + p1
	if mass <= 1e-9:
		return 0.0
	var a := clampf(p0 / mass, 0.0, 1.0)
	var b := 1.0 - a
	var h := 0.0
	if a > 1e-9:
		h -= a * log(a)
	if b > 1e-9:
		h -= b * log(b)
	return clampf(h / log(2.0), 0.0, 1.0)


## Decompose a phase angle into the three season-basis intensities, scaled by
## coherence magnitude. Returns [R, G, B] projections at 0°/120°/240°.
static func season_projections(phi_raw: float, coh_magnitude: float) -> Array[float]:
	var out: Array[float] = [0.0, 0.0, 0.0]
	for i in range(3):
		out[i] = (1.0 + cos(phi_raw - SEASON_ANGLES[i])) * 0.5 * coh_magnitude
	return out


## Blend the three season colors weighted by their projections, normalized so the
## result is hue (not brightness). Returns `fallback` when there is no signal.
static func blend_season_color(projections: Array, fallback: Color = Color(0.5, 0.5, 0.5)) -> Color:
	if projections.size() < 3:
		return fallback
	var r_proj: float = projections[0]
	var g_proj: float = projections[1]
	var b_proj: float = projections[2]
	var total := r_proj + g_proj + b_proj
	if total <= 0.01:
		return fallback
	return (
		SEASON_COLORS[0] * r_proj
		+ SEASON_COLORS[1] * g_proj
		+ SEASON_COLORS[2] * b_proj
	) / total


## Bubble interior hue from phase + coherence (HSV: hue from phi, saturation from
## coherence). The direct color channel, distinct from the season-wedge blend.
static func phase_to_hsv(phi: float, coh_magnitude: float) -> Color:
	return Color.from_hsv((phi + PI) / TAU, coh_magnitude * 0.8, 0.9, 0.8)


## Two-outcome quantum uncertainty 2·√(p_n·p_s) over the normalized poles.
## 0 when fully collapsed, 1 at an even superposition.
static func uncertainty(p_north: float, p_south: float) -> float:
	var mass := p_north + p_south
	if mass <= 0.0:
		return 0.0
	var p_n := p_north / mass
	var p_s := p_south / mass
	return 2.0 * sqrt(p_n * p_s)
