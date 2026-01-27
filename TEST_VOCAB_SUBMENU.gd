# Quick test script - paste into console or run via script
# Tests vocab injection submenu

extends Node

func test_vocab_submenu():
	var qii = get_tree().root.get_node_or_null("FarmView/PlayerShell/QuantumInstrumentInput")
	if not qii:
		print("ERROR: Could not find QuantumInstrumentInput")
		return

	if qii._current_submenu.is_empty():
		print("ERROR: No submenu currently active")
		print("  (Try pressing 4 then Q to open vocab injection submenu first)")
		return

	var submenu = qii._current_submenu
	print("\n════════════════════════════════════════════════════════════")
	print("VOCAB INJECTION SUBMENU DEBUG")
	print("════════════════════════════════════════════════════════════")
	print("In submenu: %s" % qii._in_submenu)
	print("Current page: %d" % qii._submenu_page)
	print("")

	var actions = submenu.get("actions", {})
	print("Available vocab options:")
	print("─────────────────────────────────────────────────────────────")

	for key in ["Q", "E", "R"]:
		if actions.has(key):
			var action = actions[key]
			var vocab_pair = action.get("vocab_pair", {})
			var north = vocab_pair.get("north", "?")
			var south = vocab_pair.get("south", "?")
			var affinity = action.get("affinity", 0.0)
			var label = action.get("label", "")
			print("  [%s]  %s/%s  (affinity: %.2f, label: %s)" % [key, north, south, affinity, label])
		else:
			print("  [%s]  <empty slot>" % key)

	print("─────────────────────────────────────────────────────────────")
	print("Total pages: %d (current: %d)" % [submenu.get("max_pages", 1), submenu.get("page", 0) + 1])
	print("")
	print("INSTRUCTIONS:")
	print("  • Press Q/E/R to inject the vocab option from that slot")
	print("  • Press F to cycle to next page of options")
	print("  • Press Escape/1/2/3/4 to exit submenu")
	print("════════════════════════════════════════════════════════════\n")


# Simpler version - just list what's available
func list_vocab_options():
	var qii = get_tree().root.get_node_or_null("FarmView/PlayerShell/QuantumInstrumentInput")
	if not qii or qii._current_submenu.is_empty():
		print("❌ Submenu not active. Try: Press 4, then Q")
		return

	var actions = qii._current_submenu.get("actions", {})
	print("✓ Submenu Active - Available:")
	for key in ["Q", "E", "R"]:
		if actions.has(key):
			print("  %s: %s" % [key, actions[key].get("label", "?")])
