class_name AceChipResolvers
extends Object

const UIProgression = preload("res://UI/Core/UIProgression.gd")

## Contextual patches for the Ace frame's chips.
##
## F is the expedition verb (owner ruling 2026-07-11): on an UNEXPLORED plot
## it explores (binds the terminal, costs 🍞); on an explored plot it keeps
## its fast-forward/play meaning ("doubling down on a particular space").
## Both the chip text and the dispatcher consult this, so what the chip
## shows is exactly what F fires. No quest remaps: Ace F never becomes
## Reap, Ace E never becomes Superpose. Those are other hats / Shift+F.


static func resolve_r(_ctx) -> Dictionary:
	# Do not call _basket_walk_line here — _perform_action hung in that
	# walk (w124 calling perform never returned).
	# w156: this chip fired on Act 0 and buried Strike. Only while lantern_door.
	if not UIProgression.lantern_well_live():
		return {}
	var label := "Find Lanternfall ▸ 🧺"
	if str(UIProgression.last_lantern_strike) != "":
		label = str(UIProgression.last_lantern_strike)
	return {
		"action": "measure",
		"label": label,
		"hint": "Strike the Village 🧺 well",
	}


static func resolve_f(ctx) -> Dictionary:
	# While a toast owns F, the chip must name that job — not Explore /
	# Fast-Fwd (wave 13 literalist: Wheel toast [F] opens the Arc vs [F]
	# Fast-Fwd). Action stays put; PlayerShell intercepts the key.
	var toast_lbl := _toast_f_chip_label()
	if toast_lbl != "":
		return {"label": toast_lbl, "emoji": "📋"}
	# w62: paused banner is [F] Play. Chip must not say Explore/Fast-Fwd.
	if UIProgression._sim_paused():
		return {"label": "▶ Play", "emoji": "▶"}
	# w181: Middle Cannot Hold — F must Fast-Fwd, not Explore the horn.
	if UIProgression._is_horn_ask(UIProgression._best_objective()) \
			or UIProgression._is_horn_ask(UIProgression._banner_quest()):
		return {}
	# w61: after ESC from the board, chip stayed Fast-Fwd while the
	# banner said Explore (chip_ctx lost focus). One verb on F.
	var banner_explore: bool = UIProgression.ace_f_would_explore()
	if ctx != null and ctx.has_focused_qubit() and ctx.register_bound and not banner_explore:
		return {}
	if banner_explore or (ctx != null and ctx.has_focused_qubit() and not ctx.register_bound):
		var axis: Dictionary = ctx.focused_axis() if (ctx != null and ctx.has_method("focused_axis")) else {}
		var north := str(axis.get("north", "")).replace("\uFE0F", "").replace("\uFE0E", "")
		var south := str(axis.get("south", "")).replace("\uFE0F", "").replace("\uFE0E", "")
		var well: bool = north.contains("🧺") or south.contains("🧺")
		var hint := "Explore — mount an expedition to this 🧺 plot (no 🍞). Binding the register is what makes it strikeable." \
				if well else \
				"Explore — mount an expedition to this plot (costs 🍞). Binding the register is what makes it strikeable."
		return {
			"action": "explore",
			"label": "Explore",
			"emoji": "🧭",
			"hint": hint,
		}
	return {}


static func _toast_f_chip_label() -> String:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return ""
	var shells := (ml as SceneTree).get_nodes_in_group("player_shell")
	if shells.is_empty():
		return ""
	var shell = shells[0]
	if shell != null and shell.has_method("toast_f_chip_label"):
		return str(shell.toast_f_chip_label()).strip_edges()
	return ""
