class_name QuantumRounding
extends RefCounted

## QuantumRounding — stochastic rounding at the quantum/classical boundary.
##
## Plain `round()` collapses an inherently fractional quantum quantity into a
## fixed integer, throwing away the residual. Stochastic rounding preserves
## the residual *in expectation*: a value of 0.7 rounds to 1 with probability
## 0.7 and to 0 with probability 0.3. Across many roundings the running
## average converges to the true value — but each individual measurement
## carries the natural quantum unpredictability.
##
## Properties:
##   • E[stochastic_round(x)] == x  (zero bias)
##   • stochastic_round(integer) == integer  (no jitter on already-discrete)
##   • Two calls with same x produce different outcomes (no caching)
##
## Use anywhere a fractional quantum quantity has to be reported as an integer:
##   • Market contract cost amounts (was: ceil → always over-charged)
##   • Reward quantities on exercise (was: round → biased toward midpoint)
##   • Resource ledger writes (currently int-typed)
##   • Plot harvest yields
##   • Quest delivery quantities
##
## The "quantum²" variant — `quantum_round_amplitude` — treats the input as
## a Born-rule amplitude rather than a probability. P(round up) = x², which
## sharpens the distribution: low fractions almost never round up, high
## fractions almost always do. Use when you want a more "deterministic feel"
## while still preserving the quantum origin.

const _RNG: RandomNumberGenerator = null  # use static shared rng below


static var _rng: RandomNumberGenerator = _make_rng()


static func _make_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r


## Stochastic round: P(round up) = fractional part.
## E.g. 0.7 → 1 with prob 0.7, → 0 with prob 0.3.
## E[output] == input (unbiased).
static func stochastic_round(x: float) -> int:
	if is_nan(x) or is_inf(x):
		return 0
	var floor_x: int = int(floor(x))
	var frac: float = x - float(floor_x)
	if frac <= 0.0:
		return floor_x
	if frac >= 1.0:
		return floor_x + 1
	if _rng.randf() < frac:
		return floor_x + 1
	return floor_x


## Born-rule round: P(round up) = (fractional part)².
## Sharper distribution — low fractions resist rounding up, high fractions
## almost always do. Biased: E[output] < input. Use when you want the
## "quantum feel" with classical-bias.
static func quantum_round_amplitude(x: float) -> int:
	if is_nan(x) or is_inf(x):
		return 0
	var floor_x: int = int(floor(x))
	var frac: float = x - float(floor_x)
	if frac <= 0.0:
		return floor_x
	if frac >= 1.0:
		return floor_x + 1
	var p_up: float = frac * frac
	if _rng.randf() < p_up:
		return floor_x + 1
	return floor_x


## Seeded variant — for tests, replays, and any context where the same
## quantum quantity at the same time should produce the same rounding.
## Phrame-seeded rounding makes save/replay deterministic.
static func stochastic_round_seeded(x: float, seed_val: int) -> int:
	if is_nan(x) or is_inf(x):
		return 0
	var floor_x: int = int(floor(x))
	var frac: float = x - float(floor_x)
	if frac <= 0.0:
		return floor_x
	if frac >= 1.0:
		return floor_x + 1
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	if r.randf() < frac:
		return floor_x + 1
	return floor_x
