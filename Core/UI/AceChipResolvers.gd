class_name AceChipResolvers
extends Object

## Contextual patches for the Ace frame's chips.
##
## F is the expedition verb (owner ruling 2026-07-11): on an UNEXPLORED plot
## it explores (binds the terminal, costs 🍞); on an explored plot it keeps
## its fast-forward/play meaning ("doubling down on a particular space").
## Both the chip text and the dispatcher consult this, so what the chip
## shows is exactly what F fires.


static func resolve_f(ctx) -> Dictionary:
	if ctx == null or not ctx.has_focused_qubit():
		return {}
	if ctx.register_bound:
		return {}
	return {
		"action": "explore",
		"label": "Explore",
		"emoji": "🧭",
		"hint": "Explore — mount an expedition to this plot (costs 🍞). Binding the register is what makes it strikeable.",
	}
