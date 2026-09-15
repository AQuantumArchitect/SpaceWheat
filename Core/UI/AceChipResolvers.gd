class_name AceChipResolvers
extends Object

const IntroVoice = preload("res://Core/Story/IntroVoice.gd")

## Contextual patches for the Ace frame's chips.
##
## F is the expedition verb (owner ruling 2026-07-11): on an UNEXPLORED plot
## it explores (binds the terminal, costs 🍞); on an explored plot it keeps
## its fast-forward/play meaning ("doubling down on a particular space").
## Both the chip text and the dispatcher consult this, so what the chip
## shows is exactly what F fires.


## When Superpose is the live door, Ace E *is* Superpose (_maybe_wear_live_hat
## wears Druid then Hadamards). Naming it Pause next to a Superpose banner is
## the dual-[E] wall (wave 6). Pause stays the Ace label the rest of the time —
## E still pauses; the word is just the worse term while Superpose is the ask.
static func resolve_e(_ctx) -> Dictionary:
	var live: Dictionary = IntroVoice.live_quest()
	if str(live.get("tutorial_teaches", "")) != "superposition":
		return {}
	return {
		"label": "Superpose",
		"disabled": false,
		"hint": "Superpose — spread the qubit across both poles.",
	}


static func resolve_f(ctx) -> Dictionary:
	if ctx == null or not ctx.has_focused_qubit():
		return {}
	if ctx.register_bound:
		# Capstone: F on a plot that's already in play IS the reap. Shift+F
		# stayed the keyboard chord; a mouse on Operator-after-loom never
		# held Shift, and Operator gate-mode has no F. QuantumInstrumentInput
		# also consults this on any hat during reap_season so mash F works
		# after the Bell weave. Explore still wins on sleeping ground so the
		# field can be put in play first.
		var live: Dictionary = IntroVoice.live_quest()
		if str(live.get("tutorial_teaches", "")) == "reap_season":
			return {
				"action": "reap",
				"label": "Reap",
				"emoji": "🌾",
				"hint": "Reap the season — every plot in play pays at once.",
			}
		return {}
	return {
		"action": "explore",
		"label": "Explore",
		"emoji": "🧭",
		"hint": "Explore — mount an expedition to this plot (costs 🍞). Binding the register is what makes it strikeable.",
	}
