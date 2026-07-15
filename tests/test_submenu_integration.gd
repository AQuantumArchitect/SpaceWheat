extends SceneTree

## Integration test for submenu system with mock game state
## Run: godot --headless --script tests/test_submenu_integration.gd


var passed = 0
var failed = 0

const DIVIDER = "============================================================"


func _init():
	print("\n" + DIVIDER)
	print("SUBMENU INTEGRATION TESTS")
	print(DIVIDER)

	test_gate_selection_integration()
	test_icon_injection_integration()
	test_pagination_integration()
	test_empty_state_handling()
	test_cost_integration()
	test_multi_page_offers_every_icon()
	test_instrument_page_cycling_advances()

	print("\n" + DIVIDER)
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	print(DIVIDER + "\n")

	quit(0 if failed == 0 else 1)


func test_gate_selection_integration():
	# Test GateSelectionSubmenu generates correct actions.
	print("\n[GateSelection Integration]")

	var mock_biome = MockBiome.new()
	var mock_farm = MockFarm.new()

	# Test 2-qubit selection
	var sel_2 = [Vector2i(0, 0), Vector2i(1, 0)]
	var submenu = GateSelectionSubmenu.generate_submenu(mock_biome, mock_farm, sel_2, 0)

	assert_eq(submenu["name"], "gate_selection", "Submenu name")
	assert_eq(submenu["dynamic"], true, "Is dynamic")
	assert_eq(submenu["selection_count"], 2, "Selection count tracked")
	assert_true(submenu["actions"].has("Q"), "Has Q action")

	var q = submenu["actions"]["Q"]
	assert_eq(q["action"], "build_gate", "Q action is build_gate")
	assert_true(q.has("gate_type"), "Has gate_type")
	assert_true(q.has("label"), "Has label")
	assert_true(q.has("hint"), "Has hint")
	assert_eq(q["enabled"], true, "Action enabled")

	print("  [Available Gates]")
	for key in ["Q", "E", "R"]:
		if submenu["actions"].has(key):
			var action = submenu["actions"][key]
			print("    %s: %s - %s" % [key, action["label"], action["hint"]])

	# Test 3-qubit selection includes multi-qubit gates
	var sel_3 = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var submenu_3 = GateSelectionSubmenu.generate_submenu(mock_biome, mock_farm, sel_3, 0)

	assert_true(submenu_3["total_options"] >= 6, "3 qubits: includes GHZ/Cluster")
	print("  ✓ 3-qubit selection: %d gate types available" % submenu_3["total_options"])


func test_icon_injection_integration():
	# Test IconInjectionSubmenu with mock data.
	print("\n[IconInjection Integration]")

	var mock_biome = MockBiome.new()
	var mock_farm = MockFarm.new()

	# Give farm some known icons
	mock_farm.known_icons = [
		{"north": "🌱", "south": "🌾"},
		{"north": "🐄", "south": "🥛"}
	]

	var submenu = IconInjectionSubmenu.generate_submenu(mock_biome, mock_farm, 0)

	assert_eq(submenu["name"], "icon_injection", "Submenu name")
	assert_true(submenu.has("actions"), "Has actions")

	if submenu["total_options"] > 0:
		var q = submenu["actions"]["Q"]
		assert_eq(q["action"], "inject_icon", "Q action is inject_icon")
		assert_true(q.has("icon"), "Has icon")
		assert_true(q.has("affinity"), "Has affinity")
		assert_true(q.has("cost"), "Has cost")

		print("  ✓ Found %d injectable icons" % submenu["total_options"])
		print("  ✓ First icon: %s/%s (affinity: %.2f)" % [
			q["icon"]["north"],
			q["icon"]["south"],
			q["affinity"]
		])


func test_pagination_integration():
	# Test that pagination works across multiple pages.
	print("\n[Pagination Integration]")

	var mock_biome = MockBiome.new()
	var mock_farm = MockFarm.new()

	# Create selection that will have many gate options
	var sel_5 = []
	for i in range(5):
		sel_5.append(Vector2i(i, 0))

	var page_0 = GateSelectionSubmenu.generate_submenu(mock_biome, mock_farm, sel_5, 0)
	var page_1 = GateSelectionSubmenu.generate_submenu(mock_biome, mock_farm, sel_5, 1)

	assert_eq(page_0["page"], 0, "Page 0 index")
	assert_eq(page_1["page"], 1, "Page 1 index")
	assert_true(page_0["max_pages"] >= 2, "Multiple pages exist")

	# Verify different pages show different options
	var p0_gates = []
	var p1_gates = []
	for key in ["Q", "E", "R"]:
		if page_0["actions"].has(key):
			p0_gates.append(page_0["actions"][key].get("gate_type", ""))
		if page_1["actions"].has(key):
			p1_gates.append(page_1["actions"][key].get("gate_type", ""))

	print("  ✓ Page 0 gates: %s" % ", ".join(p0_gates))
	print("  ✓ Page 1 gates: %s" % ", ".join(p1_gates))
	print("  ✓ Total pages: %d (total gates: %d)" % [page_0["max_pages"], page_0["total_options"]])


func test_empty_state_handling():
	# Test that empty states are handled gracefully.
	print("\n[Empty State Handling]")

	var mock_biome = MockBiome.new()
	var mock_farm = MockFarm.new()

	# No selection
	var empty = GateSelectionSubmenu.generate_submenu(mock_biome, mock_farm, [], 0)
	assert_true(empty.get("_disabled", false), "0 qubits: disabled")
	assert_eq(empty["actions"]["Q"]["label"], "Select 2+ qubits", "Shows message")

	# Single selection
	var single = GateSelectionSubmenu.generate_submenu(mock_biome, mock_farm, [Vector2i(0, 0)], 0)
	assert_true(single.get("_disabled", false), "1 qubit: disabled")

	# Empty icon set
	mock_farm.known_icons = []
	var no_icons = IconInjectionSubmenu.generate_submenu(mock_biome, mock_farm, 0)
	assert_true(no_icons.get("_disabled", false), "No icons: disabled")
	print("  ✓ Empty icon message: %s" % no_icons.get("_message", ""))


func test_cost_integration():
	# Test that costs are applied to options.
	print("\n[Cost Integration]")

	var mock_biome = MockBiome.new()
	var mock_farm = MockFarm.new()

	# Set economy balance
	mock_farm.economy.energy = 0  # Can't afford anything

	mock_farm.known_icons = [
		{"north": "🌱", "south": "🌾"}
	]

	var submenu = IconInjectionSubmenu.generate_submenu(mock_biome, mock_farm, 0)

	if submenu["total_options"] > 0 and submenu["actions"].has("Q"):
		var q = submenu["actions"]["Q"]
		assert_true(q.has("cost"), "Has cost field")
		assert_true(q.has("can_afford"), "Has can_afford field")
		# With 0 energy, should not be affordable (if cost > 0)
		if not q["cost"].is_empty():
			print("  ✓ Cost: %s" % q.get("cost_display", str(q["cost"])))
			print("  ✓ Can afford: %s" % q["can_afford"])


func test_multi_page_offers_every_icon():
	# Regression (sensor leg L2b): with >3 known icons the plant picker showed
	# only the top-3-by-affinity page and NOTHING advertised more — the rest of
	# the vocabulary (incl. a freshly taught 🪵/🪓) was unreachable. Every icon
	# must be exposed on SOME page, and multi-page menus must carry the F pager
	# chip so the extra pages are discoverable.
	print("\n[Multi-page: every icon reachable]")

	var mock_biome = MockBiome.new()
	var mock_farm = MockFarm.new()
	for i in range(9):
		mock_farm.known_icons.append({"north": "N%d" % i, "south": "S%d" % i})

	var page0 = IconInjectionSubmenu.generate_submenu(mock_biome, mock_farm, 0)
	assert_eq(page0["total_options"], 9, "9 known icons → 9 options")
	assert_eq(page0["max_pages"], 3, "9 options → 3 pages")

	# Multi-page menus advertise the pager.
	assert_true(page0["actions"].has("F"), "Multi-page submenu has F pager chip")
	assert_eq(page0["actions"]["F"]["action"], "cycle_page", "F chip is cycle_page")

	# Single-page menus do NOT grow a pager chip.
	var small_farm = MockFarm.new()
	small_farm.known_icons = [{"north": "A", "south": "B"}]
	var single = IconInjectionSubmenu.generate_submenu(mock_biome, small_farm, 0)
	assert_true(not single["actions"].has("F"), "Single-page submenu has no F chip")

	# Union of all pages == all 9 icons.
	var seen = {}
	for p in range(3):
		var sub = IconInjectionSubmenu.generate_submenu(mock_biome, mock_farm, p)
		for key in ["Q", "E", "R"]:
			if sub["actions"].has(key):
				var icon = sub["actions"][key].get("icon", {})
				seen["%s|%s" % [icon.get("north", ""), icon.get("south", "")]] = true
	assert_eq(seen.size(), 9, "All 9 icons reachable across pages")

	# Page index wraps.
	var wrapped = IconInjectionSubmenu.generate_submenu(mock_biome, mock_farm, 3)
	assert_eq(wrapped["page"], 0, "Page 3 of 3 wraps to page 0")


func test_instrument_page_cycling_advances():
	# Regression: QuantumInstrument.cycle_submenu_page incremented submenu_page
	# and then called enter_submenu(), whose first line RESET the page to 0 —
	# so F-paging always re-rendered page 0 and the pager was dead end-to-end.
	print("\n[Instrument page cycling advances]")

	var mock_biome = MockBiome.new()
	var mock_farm = MockFarm.new()
	for i in range(9):
		mock_farm.known_icons.append({"north": "N%d" % i, "south": "S%d" % i})
	var ctx = {"biome": mock_biome, "farm": mock_farm}

	var instrument = load("res://Core/Instrumentation/QuantumInstrument.gd").new()
	var opened = instrument.enter_submenu("icon_injection", ctx)
	assert_eq(int(opened["page"]), 0, "enter_submenu opens on page 0")

	var r1 = instrument.cycle_submenu_page(ctx)
	assert_eq(int(r1["submenu_data"]["page"]), 1, "First cycle lands on page 1")
	var r2 = instrument.cycle_submenu_page(ctx)
	assert_eq(int(r2["submenu_data"]["page"]), 2, "Second cycle lands on page 2")
	var r3 = instrument.cycle_submenu_page(ctx)
	assert_eq(int(r3["submenu_data"]["page"]), 0, "Third cycle wraps to page 0")

	# Re-entering resets to page 0 (fresh open, not sticky).
	var reopened = instrument.enter_submenu("icon_injection", ctx)
	assert_eq(int(reopened["page"]), 0, "Re-open resets to page 0")


func assert_eq(actual, expected, msg: String):
	if actual == expected:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)
		print("    Expected: %s" % str(expected))
		print("    Actual:   %s" % str(actual))


func assert_true(condition: bool, msg: String):
	if condition:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)


# ============================================================================
# MOCK OBJECTS
# ============================================================================

class MockBiome:
	extends RefCounted
	var biome_name = "TestBiome"
	var viz_cache = MockVizCache.new()

class MockVizCache:
	extends RefCounted
	func get_emojis() -> Array[String]:
		return []
	func has_metadata() -> bool:
		return false

class MockFarm:
	extends RefCounted
	var known_icons: Array = []
	var vocabulary_evolution = null
	var economy = MockEconomy.new()

	func get_known_icons() -> Array:
		return known_icons

class MockEconomy:
	extends RefCounted
	var energy = 100
	var milk = 100

	func get_balance(resource: String) -> int:
		if resource == "energy":
			return energy
		if resource == "milk":
			return milk
		return 0

	func can_afford(cost: Dictionary) -> bool:
		for resource in cost:
			var required = cost[resource]
			var available = get_balance(resource)
			if available < required:
				return false
		return true
