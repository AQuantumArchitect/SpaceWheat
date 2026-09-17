class_name AceChipResolvers
extends Object

## Contextual patches for the Ace frame's chips.
##
## F is the expedition verb (owner ruling 2026-07-11): on an UNEXPLORED plot
## it explores (binds the terminal, costs 🍞); on an explored plot it keeps
## its fast-forward/play meaning ("doubling down on a particular space").
## Both the chip text and the dispatcher consult this, so what the chip
## shows is exactly what F fires. No quest remaps: Ace F never becomes
## Reap, Ace E never becomes Superpose. Those are other hats / Shift+F.


static func resolve_f(ctx) -> Dictionary:
	# While a toast owns F, the chip must name that job — not Explore /
	# Fast-Fwd (wave 13 literalist: Wheel toast [F] opens the Arc vs [F]
	# Fast-Fwd). Action stays put; PlayerShell intercepts the key.
	var toast_lbl := _toast_f_chip_label()
	if toast_lbl != "":
		return {"label": toast_lbl, "emoji": "📋"}
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
