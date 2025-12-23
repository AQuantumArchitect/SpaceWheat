class_name Market
extends Node

## Market System: Sells flour and converts to classical credits
## Part of production chain: Wheat → Flour → Market → Credits
##
## The market buys flour at a market rate and combines with existing credits
## to create classical resource credits for the economy
##
## Pricing:
## - Flour price: 100 credits per unit
## - Market margin: 20% (farmer gets 80% of sale price)
## - So 1 flour = 80 credits to farmer (20 credits to market)

const FLOUR_PRICE = 100  # Credits market will pay per flour
const MARKET_MARGIN = 0.20  # Market takes 20%, farmer gets 80%

func sell_flour(flour_amount: int) -> Dictionary:
	"""
	Sell flour at market rate

	Returns: {
		"flour_sold": int,
		"credits_received": int,
		"market_cut": int,
		"efficiency": float  # % of gross price farmer keeps
	}
	"""
	if flour_amount <= 0:
		return {
			"flour_sold": 0,
			"credits_received": 0,
			"market_cut": 0,
			"efficiency": 100.0
		}

	var gross_sale = flour_amount * FLOUR_PRICE
	var market_cut = int(gross_sale * MARKET_MARGIN)
	var farmer_cut = gross_sale - market_cut

	return {
		"flour_sold": flour_amount,
		"credits_received": farmer_cut,
		"market_cut": market_cut,
		"efficiency": (farmer_cut / float(gross_sale)) * 100.0
	}


func get_flour_value(flour_amount: int) -> int:
	"""Get credits farmer receives from selling flour"""
	var gross = flour_amount * FLOUR_PRICE
	var market_cut = int(gross * MARKET_MARGIN)
	return gross - market_cut


func get_market_price() -> Dictionary:
	"""Return current market price info"""
	return {
		"flour_price_gross": FLOUR_PRICE,
		"farmer_price_net": get_flour_value(1),
		"market_margin_percent": MARKET_MARGIN * 100.0
	}


func combine_resources(flour_amount: int, loose_credits: int) -> int:
	"""
	Combine flour + loose credits into classical credits
	Flour sold, then combined with existing credits
	"""
	var flour_sale_result = sell_flour(flour_amount)
	return flour_sale_result["credits_received"] + loose_credits
