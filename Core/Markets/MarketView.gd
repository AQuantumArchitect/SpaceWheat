class_name MarketView
extends RefCounted

## MarketView — the player's geometric lens onto the market.
##
## MarketLattice is independent of any one character; it bids on the world
## supply ledger. MarketView projects those offers through the player's own
## inventory to produce a *view* — the same offers, sorted/annotated by how
## the player relates to them.
##
## The geometry: think of resources as orthogonal axes in N-space (one per
## emoji). The player's inventory is a point `inv = (credits[e_1], …)`. Each
## offer is a one-hot vector `o = qty · ê_emoji`. From these two facts come
## two pure scalars per offer:
##
##     share(offer) = credits[emoji] / |inv|         ∈ [0,1]
##                  = cos(angle(offer_dir, inv_dir))
##
##     depth(offer) = qty / (qty + credits[emoji])   ∈ [0,1]
##                  = drain ratio (what fraction of post-fulfillment + give-up
##                    the offer would consume)
##
## Each offer is then a point in the unit square (share, depth). The diagonal
## `share = depth` separates two natural regions:
##
##     share > depth  →  comfort  (you have lots, offer is small)
##     depth > share  →  stretch  (you have little, offer is heavy)
##
## The signed distance from the diagonal is the canonical sort key:
##
##     comfort = share - depth ∈ [-1, +1]
##
## No magic numbers, no tuning. The view annotates each offer with these two
## scalars so the UI can render them; the sort modes order by either of them
## or by raw quantity.

enum SortMode {
	COMFORT,    ## descending (share - depth) — easiest to fulfill first
	STRETCH,    ## ascending  (share - depth) — most challenging first
	MAGNITUDE,  ## descending quantity        — biggest raw deals first
	TENSION,    ## descending pair tension    — most contested manifold pairs first
}


## Compute and attach view metadata to each offer in place.
## Adds three keys: `view_share`, `view_depth`, `view_comfort`.
## Returns the same array (mutated). Inventory should be {emoji: credits}.
static func annotate(offers: Array, inventory: Dictionary) -> Array:
	var inv_norm: float = _l2_norm(inventory)
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var emoji: String = str(offer.get("resource", ""))
		var qty: float = float(offer.get("quantity", 0.0))
		var holding: float = float(inventory.get(emoji, 0.0))
		var share: float = (holding / inv_norm) if inv_norm > 0.0 else 0.0
		var depth: float = (qty / (qty + holding)) if (qty + holding) > 0.0 else 0.0
		offer["view_share"] = share
		offer["view_depth"] = depth
		offer["view_comfort"] = share - depth
	return offers


## Return a NEW array containing the offers sorted by the chosen mode.
## Annotates in place as a side effect (idempotent — re-annotation is cheap).
static func sort_view(offers: Array, inventory: Dictionary, mode: int = SortMode.COMFORT) -> Array:
	annotate(offers, inventory)
	var out: Array = offers.duplicate()
	match mode:
		SortMode.COMFORT:
			out.sort_custom(func(a, b): return float(a.get("view_comfort", 0.0)) > float(b.get("view_comfort", 0.0)))
		SortMode.STRETCH:
			out.sort_custom(func(a, b): return float(a.get("view_comfort", 0.0)) < float(b.get("view_comfort", 0.0)))
		SortMode.MAGNITUDE:
			out.sort_custom(func(a, b): return float(a.get("quantity", 0.0)) > float(b.get("quantity", 0.0)))
		SortMode.TENSION:
			out.sort_custom(func(a, b): return float(a.get("tension", 0.0)) > float(b.get("tension", 0.0)))
	return out


## Inventory L2 norm: |inv| = sqrt(Σ credits²). The denominator of cosine
## similarity. Zero only when the player has nothing of any resource.
static func _l2_norm(inventory: Dictionary) -> float:
	var sum_sq: float = 0.0
	for emoji in inventory:
		var v: float = float(inventory[emoji])
		sum_sq += v * v
	return sqrt(sum_sq)
