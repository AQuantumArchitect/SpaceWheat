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
	if milk_at_home(farm):
		return false  # the home biome yields it (#123): never short again
	var cost: Dictionary = BalanceService.get_reap_cost(farm, ProbeActions._get_reap_count(farm))
	var need := int(cost.get(MILK, 0))
	return need > 0 and int(farm.economy.get_resource(MILK)) < need


## The player faction's home biomes: the biomes it governs
## (factions.json governing_biome_slots; for The Demos, StarterForest and
## Village). Pinned faction first, The Demos when no pin is readable.
static func home_biomes(farm) -> Array:
	var fname := "The Demos"
	if farm != null and farm.has_method("get_pinned_faction_name"):
		var pinned := str(farm.get_pinned_faction_name())
		if pinned != "":
			fname = pinned
	var faction = FactionRegistry.get_shared().get_by_name(fname)
	if faction == null:
		return []
	var out: Array = []
	for slot in faction.governing_biome_slots:
		var b := str(faction.governing_biome_slots[slot])
		if b != "" and not out.has(b):
			out.append(b)
	return out


## The win condition (#123): a planted icon carrying 🍼 (a live register
## axis with 🍼 as either pole) stands in one of the player faction's home
## biomes. Read from the registers every call, so uprooting it ends the
## supply again.
static func milk_at_home(farm) -> bool:
	return milk_home_biome(farm) != ""


## The home biome holding a 🍼 icon, or "" when none does.
static func milk_home_biome(farm) -> String:
	return home_biome_with(farm, MILK)


## The first home biome with a planted icon that has `emoji` as a pole, or "".
static func home_biome_with(farm, emoji: String) -> String:
	if emoji == "":
		return ""
	if farm == null or not ("grid" in farm) or farm.grid == null \
			or not farm.grid.has_method("get_biome"):
		return ""
	for bname in home_biomes(farm):
		var biome = farm.grid.get_biome(str(bname))
		if biome == null or biome.get("quantum_computer") == null:
			continue
		var rm = biome.quantum_computer.register_map
		if rm == null:
			continue
		for q in range(int(rm.num_qubits)):
			var ax: Dictionary = rm.axes.get(q, {})
			if str(ax.get("north", "")) == emoji or str(ax.get("south", "")) == emoji:
				return str(bname)
	return ""


## Infinite access (#123): with 🍼 planted at home, the home biome yields
## whatever the next reap is short of, so the cost is still shown and still
## spent, and is always covered. Called right before the reap preflight.
## Returns the 🍼 credited (0 when nothing was short or no milk is at home).
static func draw_home_milk(farm, cost: Dictionary) -> int:
	var need := int(cost.get(MILK, 0))
	if need <= 0 or farm == null or not ("economy" in farm) or farm.economy == null:
		return 0
	var home := milk_home_biome(farm)
	if home == "":
		return 0
	var short := need - int(farm.economy.get_resource(MILK))
	if short <= 0:
		return 0
	farm.economy.add_resource(MILK, short, "home_milk", home)
	return short


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
