class_name MarketContract
extends RefCounted

## Contract — pure record describing the right to measure a specific qubit on a
## specific biome. The qubit itself lives on biome.qc; this record holds only
## the metadata of the right.
##
## Lifecycle: open → owned → exercised | expired
## - open: faction is offering the option; not yet purchased
## - owned: player paid price_paid; can exercise until expiry_phrame
## - exercised: player measured the qubit; classical reward delivered
## - expired: player let the offer/option lapse; no reward
##
## Phase VI ships with no save persistence — open offers regenerate from
## substrate on next view; owned contracts are session-scoped.

const STATUS_OPEN: String = "open"
const STATUS_OWNED: String = "owned"
const STATUS_EXERCISED: String = "exercised"
const STATUS_EXPIRED: String = "expired"

var id: int = 0
var resource: String = ""           # the emoji being measured (must match biome.qc.qubit())
var faction: String = ""            # who sold the option
var biome_name: String = ""         # which biome's qubit
var qubit_pole: int = 1             # pole that pays player on measurement (1 = "north" by convention)
var offer_phrame: int = 0
var expiry_phrame: int = 0
var price_paid: float = 0.0         # cost_amount actually paid at buy() time (denominated in cost_emoji)
var cost_emoji: String = ""         # commodity that buyer pays in (e.g. "🌾", "🧂"); empty = legacy/free
var cost_amount: float = 0.0        # how much of cost_emoji is required
var status: String = STATUS_OPEN


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
	}


func _to_string() -> String:
	return "Contract<%s/%s in %s, pole=%d, %s, %.1f%s>" % [
		resource, faction, biome_name, qubit_pole, status, cost_amount, cost_emoji
	]
