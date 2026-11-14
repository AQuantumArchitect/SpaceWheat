class_name MarketContract
extends RefCounted

## Contract — the one contract record: a faction's offer on one axis (emoji and
## pole) of one biome. The qubit lives on biome.qc; this record holds the terms.
##
## Its price is LIVE: MarketLattice.quote() reads the biome's ρ every time the
## board's heartbeat asks, so an offer's ask moves while you look at it. A LOCK
## freezes the quote (ask and reward) for LOCK_SECONDS of play without
## accepting; Accept takes whatever quote is showing. A `table` contract (the
## campaign's supply trades) never requotes.
##
## Lifecycle: open → owned (held: accepted on the board) → exercised | expired
## - open: on offer; requoted from ρ unless locked
## - owned: accepted; the held quest dict carries the frozen terms
## - exercised: delivered — the axis was Born-sampled and collapsed
## - expired: lapsed
##
## Unheld offers are not saved: ρ is, and they requote from it. A locked offer
## is saved with its lock (MarketLattice.to_save_dict).

const STATUS_OPEN: String = "open"
const STATUS_OWNED: String = "owned"
const STATUS_EXERCISED: String = "exercised"
const STATUS_EXPIRED: String = "expired"

const PRICING_LIVE: String = "live"     # requoted from ρ on the board heartbeat
const PRICING_TABLE: String = "table"   # a fixed table price (campaign trades)
const SETTLE_ONCE: String = "once"      # deliver: Born-sample the axis, collapse
const SETTLE_FLOW: String = "flow"      # a Lindblad channel that ticks (Merchant)

var id: int = 0
var resource: String = ""           # the emoji being measured (must match biome.qc.qubit())
var faction: String = ""            # who sold the option
var biome_name: String = ""         # which biome's qubit
var qubit_pole: int = 1             # pole that pays player on measurement (1 = "north" by convention)
var offer_phrame: int = 0
var expiry_phrame: int = 0
var price_paid: float = 0.0         # cost_amount actually paid at buy() time (denominated in cost_emoji)
var cost_emoji: String = ""         # commodity buyer pays in (e.g. "🌾", "🧂"); empty → settle pays in the deliverable resource itself (see MarketLattice._settle)
var cost_amount: float = 0.0        # how much of cost_emoji is required
var status: String = STATUS_OPEN

var pricing: String = PRICING_LIVE
var settle: String = SETTLE_ONCE
## The prior the arbitrage term prices against: a fixed marginal (a
## neighbourhood spec's prior, p_prior ≥ 0) or a partner biome's LIVE marginal
## (prior_biome, pair offers). Neither → no arbitrage term.
var p_prior: float = -1.0
var prior_biome: String = ""
var ask_cap: int = 0                # 0 = uncapped (apprentice re-deals cap at 8)
var quote_p: float = 0.5            # live marginal the current quote read
var quote_kT: float = 0.0
var last_ask: int = 0               # the ask one heartbeat ago (the ▲▼ on the row)
var lock_seconds_left: float = 0.0  # > 0 while locked
var locked_view: Dictionary = {}    # the board row as it stood when locked


func ask() -> int:
	return maxi(1, int(round(cost_amount)))


func is_locked() -> bool:
	return lock_seconds_left > 0.0


static func make(
	resource_emoji: String,
	faction_name: String,
	biome: String,
	pole: int,
	offer_p: int,
	price: float,
	expiry_p: int,
	cost_emoji_arg: String = "",
	cost_amount_arg: float = 0.0
) -> RefCounted:
	var c = load("res://Core/Markets/Contract.gd").new()
	c.resource = resource_emoji
	c.faction = faction_name
	c.biome_name = biome
	c.qubit_pole = pole
	c.offer_phrame = offer_p
	c.expiry_phrame = expiry_p
	c.price_paid = price
	c.cost_emoji = cost_emoji_arg
	c.cost_amount = cost_amount_arg if cost_amount_arg > 0.0 else price
	c.status = STATUS_OPEN
	c.id = hash([resource_emoji, faction_name, biome, pole, offer_p])
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"resource": resource,
		"faction": faction,
		"biome_name": biome_name,
		"qubit_pole": qubit_pole,
		"offer_phrame": offer_phrame,
		"expiry_phrame": expiry_phrame,
		"price_paid": price_paid,
		"cost_emoji": cost_emoji,
		"cost_amount": cost_amount,
		"status": status,
		"pricing": pricing,
		"settle": settle,
		"p_prior": p_prior,
		"prior_biome": prior_biome,
		"ask_cap": ask_cap,
		"quote_p": quote_p,
		"quote_kT": quote_kT,
		"last_ask": last_ask,
		"lock_seconds_left": lock_seconds_left,
		"locked_view": locked_view.duplicate(true),
		"meta": {
			"pair_a": str(get_meta("pair_a", "")),
			"pair_b": str(get_meta("pair_b", "")),
			"tension": float(get_meta("tension", 0.0)),
			"shared": bool(get_meta("shared", false)),
		},
	}


static func from_dict(d: Dictionary) -> RefCounted:
	var c = load("res://Core/Markets/Contract.gd").new()
	c.id = int(d.get("id", 0))
	c.resource = str(d.get("resource", ""))
	c.faction = str(d.get("faction", ""))
	c.biome_name = str(d.get("biome_name", ""))
	c.qubit_pole = int(d.get("qubit_pole", 1))
	c.offer_phrame = int(d.get("offer_phrame", 0))
	c.expiry_phrame = int(d.get("expiry_phrame", 0))
	c.price_paid = float(d.get("price_paid", 0.0))
	c.cost_emoji = str(d.get("cost_emoji", ""))
	c.cost_amount = float(d.get("cost_amount", 0.0))
	c.status = str(d.get("status", STATUS_OPEN))
	c.pricing = str(d.get("pricing", PRICING_LIVE))
	c.settle = str(d.get("settle", SETTLE_ONCE))
	c.p_prior = float(d.get("p_prior", -1.0))
	c.prior_biome = str(d.get("prior_biome", ""))
	c.ask_cap = int(d.get("ask_cap", 0))
	c.quote_p = float(d.get("quote_p", 0.5))
	c.quote_kT = float(d.get("quote_kT", 0.0))
	c.last_ask = int(d.get("last_ask", 0))
	c.lock_seconds_left = float(d.get("lock_seconds_left", 0.0))
	var lv = d.get("locked_view", {})
	c.locked_view = (lv as Dictionary).duplicate(true) if lv is Dictionary else {}
	var meta = d.get("meta", {})
	if meta is Dictionary:
		for k in meta:
			if str(meta[k]) != "":
				c.set_meta(str(k), meta[k])
	return c


func to_quest_offer_dict() -> Dictionary:
	## Project the live market contract into the quest-board shape.
	##
	## This is a view/projection only; the contract record remains the authority.
	var pair_a: String = str(get_meta("pair_a", "")) if has_meta("pair_a") else ""
	var pair_b: String = str(get_meta("pair_b", "")) if has_meta("pair_b") else ""
	var tension: float = float(get_meta("tension", 0.0)) if has_meta("tension") else 0.0
	var shared: bool = bool(get_meta("shared", false)) if has_meta("shared") else false
	var qty: int = max(1, int(round(cost_amount)))
	return {
		"id": id,
		"status": "offered",
		"biome": biome_name,
		"biome_name": biome_name,
		"faction": faction,
		"resource": resource,
		"quantity": qty,
		"reward_resources": {resource: qty},
		"reward_multiplier": 1.0,
		"market_projection": {
			"resource": resource,
			"base_cost": qty,
			"effective_cost": qty,
			"multiplier": 1.0 + tension,
			"market_score": tension,
			"directional_edge": tension,
			"scarcity": 1.0 - tension,
			"alignment": 1.0 if shared else 0.0,
		},
		"_alignment": 1.0 if shared else 0.0,
		"_intensity": tension,
		"_complexity": 0.5,
		"_urgency": tension,
		"_variety": 0.5,
		"body": "%s ⊗ %s · deliver %s · pay ~%.1f %s in %s" % [pair_a, pair_b, resource, float(cost_amount), cost_emoji, biome_name],
		"full_text": "%s offers %s on %s. Pay ~%.2f %s (stochastic round). Exercise pops the qubit. Tension %.3f." % [
			faction, resource, biome_name, float(cost_amount), cost_emoji, tension
		],
		"source": "market_lattice_pair",
		"market_offer_id": id,
		"pair_a": pair_a,
		"pair_b": pair_b,
		"tension": tension,
		"cost_emoji": cost_emoji,
		"cost_amount": cost_amount,
	}


func _to_string() -> String:
	return "Contract<%s/%s in %s, pole=%d, %s, %.1f%s>" % [
		resource, faction, biome_name, qubit_pole, status, cost_amount, cost_emoji
	]
