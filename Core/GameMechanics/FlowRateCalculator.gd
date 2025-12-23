class_name FlowRateCalculator

## Flow Rate Calculator - Statistical analysis of measurement outcomes
## Computes mean, variance, and confidence from measurement history

static func compute_flow_rate(
	measurement_history: Array,
	window_size_seconds: float = 60.0
) -> Dictionary:
	"""Compute flour production flow rate statistics

	Analyzes recent measurements within the time window.

	Args:
		measurement_history: Array of measurement dictionaries with keys:
			- time: Time in milliseconds (from Time.get_ticks_msec())
			- flour_produced: Number of flour outcomes
			- wheat_count: Number of wheat coupled to mill
		window_size_seconds: Analysis window in seconds (default 60s)

	Returns:
		Dictionary with keys:
		- mean: Average flour per measurement
		- variance: Variance of flour outcomes
		- std_error: Standard error estimate
		- confidence: Confidence metric (0.0 to 1.0)
	"""
	var current_time = Time.get_ticks_msec()
	var window_millis = int(window_size_seconds * 1000.0)

	# Filter measurements within the time window
	var recent_measurements = measurement_history.filter(func(m):
		return (current_time - m.time) < window_millis
	)

	# Handle empty case
	if recent_measurements.is_empty():
		return {
			"mean": 0.0,
			"variance": 0.0,
			"std_error": 0.0,
			"confidence": 0.0
		}

	# Calculate total flour produced in window
	var total_flour = 0
	for m in recent_measurements:
		total_flour += m.flour_produced

	var measurement_count = recent_measurements.size()
	var mean_flour = float(total_flour) / float(measurement_count)

	# Estimate variance (using empirical variance)
	var variance = 0.0
	for m in recent_measurements:
		var diff = float(m.flour_produced) - mean_flour
		variance += diff * diff
	variance /= float(measurement_count)

	# Standard error
	var std_error = sqrt(variance) if variance > 0.0 else 0.0

	# Confidence metric: decreases with uncertainty
	# High confidence: low std_error relative to mean
	# Low confidence: high std_error or low mean
	var confidence = 0.0
	if mean_flour > 0.0:
		confidence = 1.0 / (1.0 + (std_error / mean_flour))
		confidence = clamp(confidence, 0.0, 1.0)

	return {
		"mean": mean_flour,
		"variance": variance,
		"std_error": std_error,
		"confidence": confidence,
		"window_seconds": window_size_seconds,
		"measurement_count": measurement_count
	}


static func compute_poisson_expectation(
	measurement_count: int,
	flour_probability: float
) -> Dictionary:
	"""Compute expected statistics for Poisson-distributed outcomes

	Args:
		measurement_count: Number of measurements/wheat
		flour_probability: Probability of flour per measurement

	Returns:
		Dictionary with expected mean and variance
	"""
	var expected_mean = float(measurement_count) * flour_probability
	var expected_variance = expected_mean  # Poisson: variance = mean

	return {
		"expected_mean": expected_mean,
		"expected_variance": expected_variance,
		"std_error": sqrt(expected_variance)
	}


static func get_confidence_interval(
	mean: float,
	std_error: float,
	confidence_level: float = 0.95
) -> Array[float]:
	"""Compute confidence interval for mean measurement

	Args:
		mean: Measured mean
		std_error: Standard error
		confidence_level: Confidence level (0.0 to 1.0, default 95%)

	Returns:
		Array with [lower_bound, upper_bound]
	"""
	# Z-score for 95% confidence: 1.96
	var z_score = 1.96
	var margin = z_score * std_error

	return [mean - margin, mean + margin]
