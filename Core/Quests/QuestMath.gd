class_name QuestMath
extends RefCounted

## Differentiable math primitives for quest and story-flag evaluation.
##
## Replaces hard threshold comparisons (x >= t → bool) with smooth surfaces
## (x near t → float in [0,1]).  All functions are C∞ everywhere.
##
## Design note on widths:
##   Physics observables [0,1] — use width ≈ 0.05 (5% transition zone).
##   Integer counts           — use width ≈ 1.5  (smooth over ~3 units).
##   Accumulated phase/time   — use width ≈ 0.1  (10% of a unit).
##   Spectral gap (0–0.3)    — use width ≈ 0.02 (tighter, smaller range).


static func soft_gate(x: float, center: float, width: float = 0.05) -> float:
	## Smooth rising step: 0→1 as x crosses center, over a zone of ±width.
	## At x = center: exactly 0.5.  Mathematically: σ(tanh).
	return 0.5 * (1.0 + tanh((x - center) / maxf(width, 1e-6)))


static func soft_gate_inv(x: float, center: float, width: float = 0.05) -> float:
	## Smooth falling step: 1→0 as x crosses center (for "at most" predicates).
	return 1.0 - soft_gate(x, center, width)


static func fire_value(center: float, width: float = 0.05, fire_threshold: float = 0.85) -> float:
	## The x at which soft_gate(x, center, width) first reaches `fire_threshold` — i.e. the
	## REAL target a "≥ center" predicate must hit to actually fire, since soft_gate is only
	## 0.5 AT center. Inverse of soft_gate: x = center + width·atanh(2·fire − 1).
	## (atanh hand-rolled — not guaranteed in GDScript's global scope.)
	var f := clampf(fire_threshold, 0.5, 0.999)
	var y := 2.0 * f - 1.0
	return center + maxf(width, 1e-6) * 0.5 * log((1.0 + y) / (1.0 - y))


static func smooth_and(scores: Array) -> float:
	## Geometric mean of scores: ALL must be high for result to be high.
	## Penalises weakest link without zeroing out on any single low score.
	if scores.is_empty():
		return 0.0
	var prod := 1.0
	for s in scores:
		prod *= clampf(float(s), 0.0, 1.0)
	return pow(prod, 1.0 / scores.size())


static func smooth_accumulate(elapsed: float, gate: float, delta: float,
		drain_rate: float = 1.0) -> float:
	## Continuous timer: accumulates proportionally to gate (how on-target the
	## state is), drains at drain_rate × (1 − gate) when off-target.
	## drain_rate = 1.0 → symmetric: time above = time below to cancel out.
	## drain_rate = 2.0 → aggressive: drops below cost twice as much.
	var net := delta * gate - delta * (1.0 - gate) * drain_rate
	return maxf(0.0, elapsed + net)
