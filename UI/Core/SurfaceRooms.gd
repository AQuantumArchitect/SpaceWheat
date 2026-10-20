class_name SurfaceRooms
extends Object

## One grammar for C and X.
##   T  identity of the surface (Manifold / Self)
##   Y  the board of offers (Market / Arc)
##   U  what you have taken on (Commitments / Charge)
##   I  information (Guide, on X)
##
## Commitments hold market contracts only. Charge holds signed teachings.
## The item noun is Contract on C, Teaching on X — toasts, tabs, and
## Accept/Claim gold compose from this file.

const KEY_IDENTITY := "T"
const KEY_OFFERS := "Y"
const KEY_HELD := "U"
const KEY_INFO := "I"

const ROOM_MANIFOLD := "manifold"
const ROOM_MARKET := "market"
const ROOM_COMMITMENTS := "commitments"
const ROOM_SELF := "self"
const ROOM_ARC := "arc"
const ROOM_CHARGE := "charge"
const ROOM_GUIDE := "guide"

const NAME_MANIFOLD := "Manifold"
const NAME_MARKET := "Market"
const NAME_COMMITMENTS := "Commitments"
const NAME_SELF := "Self"
const NAME_ARC := "Arc"
const NAME_CHARGE := "Charge"
const NAME_GUIDE := "Guide"

const NOUN_C := "Contract"
const NOUN_X := "Teaching"


static func c_tabs() -> Array:
	return [
		{"key": KEY_IDENTITY, "frame": ROOM_MANIFOLD, "name": NAME_MANIFOLD},
		{"key": KEY_OFFERS, "frame": ROOM_MARKET, "name": NAME_MARKET},
		{"key": KEY_HELD, "frame": ROOM_COMMITMENTS, "name": NAME_COMMITMENTS},
	]


static func x_tabs() -> Array:
	return [
		{"key": KEY_IDENTITY, "frame": ROOM_SELF, "name": NAME_SELF},
		{"key": KEY_OFFERS, "frame": ROOM_ARC, "name": NAME_ARC},
		{"key": KEY_HELD, "frame": ROOM_CHARGE, "name": NAME_CHARGE},
		{"key": KEY_INFO, "frame": ROOM_GUIDE, "name": NAME_GUIDE},
	]


static func item_noun(surface: String) -> String:
	if str(surface) == "C":
		return NOUN_C
	return NOUN_X


## Selected-row gold: ▸ [R] Accept the [G] Contract (C) / Teaching (X).
static func row_item_cue(surface: String, verb_cue: String, key: String = "") -> String:
	var k := str(key).strip_edges()
	if k != "":
		return "▸ %s the [%s] %s" % [verb_cue, k, item_noun(surface)]
	return "▸ %s" % verb_cue


static func tab_cue(key: String, name: String) -> String:
	return "[%s]%s" % [str(key), str(name)]


static func offers_cue(surface: String) -> String:
	if str(surface) == "C":
		return tab_cue(KEY_OFFERS, NAME_MARKET)
	return tab_cue(KEY_OFFERS, NAME_ARC)


static func held_cue(surface: String) -> String:
	if str(surface) == "C":
		return tab_cue(KEY_HELD, NAME_COMMITMENTS)
	return tab_cue(KEY_HELD, NAME_CHARGE)


static func walk_open_offers(surface: String) -> String:
	if str(surface) == "C":
		return "▸ [C]ontracts then %s" % offers_cue("C")
	return "▸ [X] then Arc [%s]" % KEY_OFFERS


static func walk_open_held(surface: String) -> String:
	if str(surface) == "C":
		return "▸ [C]ontracts then %s" % held_cue("C")
	return "▸ [X] then Charge [%s]" % KEY_HELD


static func self_pointer_with_doors() -> String:
	return "this is Self [%s]  ·  open doors live on Arc [%s]" % [KEY_IDENTITY, KEY_OFFERS]


static func self_pointer_banner() -> String:
	return "this is Self [%s]  ·  the live door is the banner" % KEY_IDENTITY
