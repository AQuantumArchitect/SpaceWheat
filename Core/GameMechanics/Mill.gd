class_name Mill
extends Node

## Mill System: Converts raw wheat into flour + modest credit bonus
## Part of the production chain: Wheat → Flour → Market → Credits
##
## Economics:
## - Input: 10 wheat
## - Output: 8 flour + 50 credits (processing labor bonus)
## - Flour then goes to market for further conversion

const WHEAT_TO_FLOUR_RATIO = 0.8  # 10 wheat → 8 flour (20% loss in processing)
const CREDIT_BONUS_PER_FLOUR = 5  # Each flour unit processed gives 5 credits

func process_wheat(amount: int) -> Dictionary:
	"""
	Convert wheat into flour and processing credits

	Returns: {
		"flour_produced": int,
		"credits_earned": int
	}
	"""
	if amount <= 0:
		return {"flour_produced": 0, "credits_earned": 0}

	var flour_produced = int(amount * WHEAT_TO_FLOUR_RATIO)
	var credits_earned = flour_produced * CREDIT_BONUS_PER_FLOUR

	return {
		"flour_produced": flour_produced,
		"credits_earned": credits_earned
	}


func get_flour_output(wheat_amount: int) -> int:
	"""Calculate flour output for given wheat amount"""
	return int(wheat_amount * WHEAT_TO_FLOUR_RATIO)


func get_processing_credits(wheat_amount: int) -> int:
	"""Calculate credit bonus for processing wheat"""
	var flour = get_flour_output(wheat_amount)
	return flour * CREDIT_BONUS_PER_FLOUR


func get_processing_efficiency() -> float:
	"""Return efficiency percentage (how much wheat becomes flour)"""
	return WHEAT_TO_FLOUR_RATIO * 100.0
