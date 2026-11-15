class_name StapleRescue
extends RefCounted

## No soft lock in the economy loop (#87).
##
## Explore spends 🍞, Strike spends 👥 and Gather spends 🧺. Each staple is
## bought back on the Village board (campaign `resources` table): 🧺 with 👥,
## 👥 and 🍞 with 🌾. 🌾 has no trade, only plots, and every plot pays out
## through a Gather. So a wallet like 0🧺 · 3👥 · 0🌾 is a dead end: the
## basket trade wants 6👥, the 👥 trade wants 4🌾, and the 🌾 needs a Gather
## that needs a basket.
##
## A wallet is STRANDED for a staple when it holds less than the verb's fee
## and no chain of Village rescue trades it can pay reaches the fee. Only in
## that state the verb's fee is waived (the Hearth Keepers lend it), so a
## broke player always has one free move in the loop. As soon as a trade
## could buy the staple again, the fee comes back. FarmEconomy.get_action_cost
## applies the waiver, so the chip badge, the preflight and the spend agree.

## The fee-paying verb for each staple.
const VERB_STAPLE := {"pop": "🧺", "measure": "👥", "explore": "🍞"}
## Plain words beside the glyph in refusals: 👥 alone read as "handshake"
## to a playtester (issue #87).
const STAPLE_NAMES := {"🧺": "baskets", "👥": "people", "🍞": "bread", "🍼": "milk"}
## Trades deep a chain may go (🧺 ← 👥 ← 🌾 is two).
const CHAIN_DEPTH := 2
## Trades a chain may take in total (a bound, not a tuning knob).
const CHAIN_TRADES := 8


## Reap spends 🍼 (Fibonacci, BalanceService.get_reap_cost). 🍼 is no staple:
## it has no Village trade and is never lent, so a short wallet is not
## rescued here. It is routed instead (#93): the refusal and the Guide both
## send the player to the Arc, where "Find the milk" is offered.
const MILK := "🍼"
## The toast route a 🍼-short reap refusal carries (PlayerShell._route_to_callable).
const MILK_ROUTE := "arc"


## True while the wallet holds less 🍼 than the next reap costs. State, not
## a flag: it reads the wallet every call, so the cue stands as long as the
## shortage does and goes the moment 🍼 is back.
static func milk_short(farm) -> bool:
	if farm == null or not ("economy" in farm) or farm.economy == null \
			or not farm.economy.has_method("get_resource"):
		return false
	var cost: Dictionary = BalanceService.get_reap_cost(farm, ProbeActions._get_reap_count(farm))
	var need := int(cost.get(MILK, 0))
	return need > 0 and int(farm.economy.get_resource(MILK)) < need


static func staple_for(action: String) -> String:
	return str(VERB_STAPLE.get(action, ""))


## "🧺 baskets", "👥 people"; any other glyph as it is.
static func named(emoji: String) -> String:
	var n := str(STAPLE_NAMES.get(emoji, ""))
	return emoji if n == "" else "%s %s" % [emoji, n]


## The fee with a stranded staple taken out. Any other cost passes through.
static func effective_cost(action: String, cost: Dictionary, economy) -> Dictionary:
	var staple := staple_for(action)
	if staple == "" or not cost.has(staple):
		return cost
	if not stranded(staple, int(ceil(float(cost[staple]))), economy):
		return cost
	var out := cost.duplicate()
	out.erase(staple)
	return out


## True when `economy` holds under `need` of `emoji` and no chain of Village
## rescue trades it can pay gets it there.
static func stranded(emoji: String, need: int, economy) -> bool:
	if need <= 0 or economy == null or not economy.has_method("get_resource"):
		return false
	if int(economy.get_resource(emoji)) >= need:
		return false
	var wallet := {}
	return not _raise(emoji, need, wallet, economy, 0, [0])


## Every resource the chain toward `emoji` might touch, read once.
static func _held(wallet: Dictionary, economy, emoji: String) -> int:
	if not wallet.has(emoji):
		wallet[emoji] = int(economy.get_resource(emoji))
	return int(wallet[emoji])


## Simulate buying `emoji` up to `need` on the Village board. Mutates `wallet`.
static func _raise(emoji: String, need: int, wallet: Dictionary, economy, depth: int, trades: Array) -> bool:
	var t := CampaignRuntime.rescue_trade(emoji)
	var got := int(t.get("get", 0))
	var give := CampaignRuntime.trade_give(t)
	if t.is_empty() or got <= 0 or give.is_empty():
		return _held(wallet, economy, emoji) >= need
	while _held(wallet, economy, emoji) < need:
		if int(trades[0]) >= CHAIN_TRADES:
			return false
		for g in give:
			if _held(wallet, economy, str(g)) < int(give[g]):
				if depth >= CHAIN_DEPTH or str(g) == emoji:
					return false
				if not _raise(str(g), int(give[g]), wallet, economy, depth + 1, trades):
					return false
		for g in give:
			wallet[str(g)] = _held(wallet, economy, str(g)) - int(give[g])
		wallet[emoji] = _held(wallet, economy, emoji) + got
		trades[0] = int(trades[0]) + 1
	return true
