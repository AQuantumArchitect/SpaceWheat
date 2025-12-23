class_name MarketQubit
extends Resource

## Market Qubit System: Quantum Exchange Rate Mechanism
##
## The market lives in quantum superposition: (🌾 flour, 💰 coins)
##
## Gameplay Loop:
## 1. QUANTUM STATE: Market qubit in superposition (theta, phi, radius)
## 2. MEASUREMENT: Player initiates trade → measure market state
## 3. COLLAPSE: Measurement collapses to classical outcome (flour or coins abundant)
## 4. EXCHANGE: Classical exchange happens post-measurement
## 5. INJECTION: Trading injects supply, updates theta for next measurement
##
## Key Insight: Market probabilities (sin²/cos²) ARE the exchange rates!
##   P(flour) = sin²(θ/2) → determines flour value
##   P(coins) = cos²(θ/2) → determines coin value

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

## Market state qubit: (🌾 flour, 💰 coins)
var market_qubit: DualEmojiQubit = null

## Measurement history (for price trends)
var measurement_history: Array = []
var max_history: int = 20

## Base exchange rate (before probability adjustment)
var base_flour_value: int = 100  # 1 flour = 100 coins at theta=π/2 (balanced)

## Injection strength (how much transactions move theta)
var injection_strength: float = 0.01
var energy_decay_rate: float = 0.99  # Market decay each transaction

func _init():
	## Initialize market in balanced superposition
	market_qubit = DualEmojiQubit.new("🌾", "💰", PI / 2.0)  # Balanced
	market_qubit.phi = 0.0
	market_qubit.radius = 1.0  # Full market energy


func get_measurement_probabilities() -> Dictionary:
	"""Get current measurement probabilities without collapsing"""
	if not market_qubit:
		return {"flour": 0.5, "coins": 0.5, "theta": 0.0}

	var flour_prob = sin(market_qubit.theta / 2.0) ** 2
	var coins_prob = cos(market_qubit.theta / 2.0) ** 2

	return {
		"flour": flour_prob,
		"coins": coins_prob,
		"theta": market_qubit.theta,
		"energy": market_qubit.radius
	}


func measure_market() -> String:
	"""
	MEASUREMENT: Collapse market qubit to classical state

	Returns: "flour" or "coins" based on sin²(θ/2) / cos²(θ/2)
	"""
	if not market_qubit:
		return "balanced"

	var flour_prob = sin(market_qubit.theta / 2.0) ** 2

	# Measurement collapses to one outcome
	var outcome = "flour" if randf() < flour_prob else "coins"

	# Record measurement
	measurement_history.append({
		"outcome": outcome,
		"flour_prob": flour_prob,
		"theta": market_qubit.theta,
		"energy": market_qubit.radius,
		"timestamp": Time.get_ticks_msec()
	})

	# Keep history bounded
	if measurement_history.size() > max_history:
		measurement_history.pop_front()

	print("📊 Market measured: %s state (P(flour)=%.1f%%)" % [outcome, flour_prob * 100])

	return outcome


func get_exchange_rate_for_flour(flour_amount: int) -> Dictionary:
	"""
	Calculate exchange rate BEFORE measurement
	Based on measurement probabilities (what COULD happen)

	Returns: {
		"flour_sold": int,
		"expected_credits": int,      # Expected value
		"best_case": int,              # If measured coins-side
		"worst_case": int,             # If measured flour-side
		"flour_probability": float,
		"coins_probability": float
	}
	"""
	var probs = get_measurement_probabilities()
	var flour_prob = probs["flour"]
	var coins_prob = probs["coins"]

	# Exchange rate depends on measurement outcome
	# If flour is abundant (flour_prob high): flour worth less
	# If coins are abundant (coins_prob high): flour worth more

	var rate_if_flour_measured = int(base_flour_value * (1.0 - flour_prob))
	var rate_if_coins_measured = int(base_flour_value * (1.0 + coins_prob))

	var expected_rate = int(
		rate_if_flour_measured * flour_prob +
		rate_if_coins_measured * coins_prob
	)

	return {
		"flour_sold": flour_amount,
		"expected_credits": flour_amount * expected_rate,
		"best_case": flour_amount * rate_if_coins_measured,
		"worst_case": flour_amount * rate_if_flour_measured,
		"best_case_rate": rate_if_coins_measured,
		"worst_case_rate": rate_if_flour_measured,
		"expected_rate": expected_rate,
		"flour_probability": flour_prob,
		"coins_probability": coins_prob,
		"energy": market_qubit.radius
	}


func trade_flour_for_coins(flour_amount: int) -> Dictionary:
	"""
	Complete trade: MEASURE → COLLAPSE → EXCHANGE → INJECT

	Process:
	1. Measure market state (quantum collapse)
	2. Determine classical exchange rate from measurement
	3. Execute trade (classical)
	4. Inject: flour sold pushes market toward coins-abundant
	5. Energy decays slightly

	Returns: {
		"success": bool,
		"flour_sold": int,
		"credits_received": int,
		"rate_achieved": int,
		"measurement": "flour" or "coins",
		"flour_probability": float,
		"new_theta": float,
		"new_energy": float
	}
	"""
	if not market_qubit or flour_amount <= 0:
		return {"success": false}

	# Step 1: MEASUREMENT
	var measurement = measure_market()
	var probs = get_measurement_probabilities()

	# Step 2: EXCHANGE RATE (post-measurement, classical)
	var rate_if_flour = int(base_flour_value * (1.0 - probs["flour"]))
	var rate_if_coins = int(base_flour_value * (1.0 + probs["coins"]))

	var actual_rate = rate_if_flour if measurement == "flour" else rate_if_coins
	var credits_received = flour_amount * actual_rate

	# Step 3: INJECTION
	# Flour sold → pushes market toward coins-abundant state
	# This makes sense: more flour supply → coins become valuable
	var theta_injection = flour_amount * injection_strength
	market_qubit.theta -= theta_injection  # Push toward 0 (coins-rich)

	# Keep theta in bounds
	market_qubit.theta = fmod(market_qubit.theta, TAU)
	if market_qubit.theta < 0:
		market_qubit.theta += TAU

	# Step 4: ENERGY DECAY
	# Market loses coherence as volume passes through
	market_qubit.radius *= energy_decay_rate

	print("💰 Traded %d flour → %d credits (rate: %d/flour) [%s state]" % [
		flour_amount, credits_received, actual_rate, measurement
	])

	return {
		"success": true,
		"flour_sold": flour_amount,
		"credits_received": credits_received,
		"rate_achieved": actual_rate,
		"measurement": measurement,
		"flour_probability": probs["flour"],
		"new_theta": market_qubit.theta,
		"new_energy": market_qubit.radius
	}


func inject_flour_from_mill(flour_amount: int) -> Dictionary:
	"""
	Mill produces flour and injects it into market

	Effect:
	- Increases flour supply in market
	- Pushes theta toward π (flour-abundant)
	- Increases market energy (new volume)

	Returns: Market state after injection
	"""
	if not market_qubit or flour_amount <= 0:
		return {
			"flour_injected": 0,
			"new_theta": market_qubit.theta if market_qubit else 0.0,
			"new_energy": market_qubit.radius if market_qubit else 1.0,
			"flour_probability": 0.0
		}

	# Flour injection pushes toward flour-abundant state
	var theta_injection = flour_amount * injection_strength * 0.5  # Mill is gentler than trading
	market_qubit.theta += theta_injection  # Push toward π (flour-rich)

	# Keep bounded
	market_qubit.theta = fmod(market_qubit.theta, TAU)

	# Mill injection adds energy (new production)
	var energy_addition = min(0.05, flour_amount * 0.001)  # Small boost
	market_qubit.radius = min(1.0, market_qubit.radius + energy_addition)

	print("🏭 Mill injected %d flour → Market pushed toward flour-abundance" % flour_amount)

	return {
		"flour_injected": flour_amount,
		"new_theta": market_qubit.theta,
		"new_energy": market_qubit.radius,
		"flour_probability": sin(market_qubit.theta / 2.0) ** 2
	}


func get_market_state() -> Dictionary:
	"""Full market state for display/analysis"""
	var probs = get_measurement_probabilities()

	return {
		"theta": market_qubit.theta,
		"phi": market_qubit.phi,
		"energy": market_qubit.radius,
		"flour_probability": probs["flour"],
		"coins_probability": probs["coins"],
		"flour_value": int(base_flour_value * (1.0 + probs["coins"])),
		"coin_scarcity": 1.0 - probs["coins"],
		"last_measurements": measurement_history.slice(-5),
		"theta_degrees": market_qubit.theta * 180.0 / PI
	}


func reset_to_balanced():
	"""Reset market to balanced state"""
	if market_qubit:
		market_qubit.theta = PI / 2.0  # Balanced
		market_qubit.radius = 1.0  # Full energy
		measurement_history.clear()
		print("🔄 Market reset to balanced state")
