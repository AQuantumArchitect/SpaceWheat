@tool
extends SceneTree

## tests/market_view_geometry.gd — verify the player's geometric lens onto
## the market produces the right (share, depth, comfort) annotations and
## that each sort mode orders correctly.
##
## The scenario: the player is rich in 🌾 (100), modest in 🍞 (10), and has
## nothing in 🍄 (0). Three offers all of equal quantity (5):
##
##     A. asks for 🌾 — high share, low depth        → high comfort
##     B. asks for 🍞 — low share, medium depth      → middling comfort
##     C. asks for 🍄 — zero share, max depth (1.0)  → most negative comfort
##
## And one big-quantity offer for 🌾 (qty 200) to show MAGNITUDE sort.
##
## Run: godot --headless -s tests/market_view_geometry.gd


const TOL: float = 1e-6


func _init() -> void:
	print("\n=== MARKET VIEW GEOMETRY TEST ===")

	var inventory: Dictionary = {"🌾": 100.0, "🍞": 10.0, "🍄": 0.0}
	# |inv| = sqrt(100² + 10² + 0²) = sqrt(10100) ≈ 100.499
	var expected_norm: float = sqrt(100.0 * 100.0 + 10.0 * 10.0)

	var offers: Array = [
		{"label": "A_wheat_small", "resource": "🌾", "quantity": 5},
		{"label": "B_bread_small", "resource": "🍞", "quantity": 5},
		{"label": "C_mushroom_small", "resource": "🍄", "quantity": 5},
		{"label": "D_wheat_huge",  "resource": "🌾", "quantity": 200},
	]

	# --- Annotation correctness -----------------------------------------
	MarketView.annotate(offers, inventory)
	for o in offers:
		print("  %s: share=%.4f depth=%.4f comfort=%+.4f" % [
			o.get("label"),
			float(o.get("view_share", 0.0)),
			float(o.get("view_depth", 0.0)),
			float(o.get("view_comfort", 0.0)),
		])

	var failures: int = 0

	# A: share = 100 / 100.499 ≈ 0.99504; depth = 5/(5+100) ≈ 0.04762
	if not _approx(offers[0]["view_share"], 100.0 / expected_norm, TOL):
		print("FAIL: A share wrong"); failures += 1
	if not _approx(offers[0]["view_depth"], 5.0 / 105.0, TOL):
		print("FAIL: A depth wrong"); failures += 1

	# B: share = 10 / 100.499 ≈ 0.09950; depth = 5/(5+10) = 0.33333
	if not _approx(offers[1]["view_share"], 10.0 / expected_norm, TOL):
		print("FAIL: B share wrong"); failures += 1
	if not _approx(offers[1]["view_depth"], 5.0 / 15.0, TOL):
		print("FAIL: B depth wrong"); failures += 1

	# C: share = 0; depth = 5/(5+0) = 1.0
	if not _approx(offers[2]["view_share"], 0.0, TOL):
		print("FAIL: C share wrong"); failures += 1
	if not _approx(offers[2]["view_depth"], 1.0, TOL):
		print("FAIL: C depth wrong"); failures += 1

	# D: share = 100 / 100.499; depth = 200/(200+100) = 0.66667
	if not _approx(offers[3]["view_share"], 100.0 / expected_norm, TOL):
		print("FAIL: D share wrong"); failures += 1
	if not _approx(offers[3]["view_depth"], 200.0 / 300.0, TOL):
		print("FAIL: D depth wrong"); failures += 1

	# --- COMFORT sort (descending share-depth) -------------------------
	# Comforts: A=+0.948, D=+0.328, B=-0.234, C=-1.000
	# Expected order: A, D, B, C
	var by_comfort: Array = MarketView.sort_view(offers, inventory, MarketView.SortMode.COMFORT)
	var comfort_labels: Array = []
	for o in by_comfort:
		comfort_labels.append(o.get("label"))
	print("  COMFORT order:   %s" % str(comfort_labels))
	if comfort_labels != ["A_wheat_small", "D_wheat_huge", "B_bread_small", "C_mushroom_small"]:
		print("FAIL: COMFORT order wrong"); failures += 1

	# --- STRETCH sort (ascending share-depth) --------------------------
	# Reverse: C, B, D, A
	var by_stretch: Array = MarketView.sort_view(offers, inventory, MarketView.SortMode.STRETCH)
	var stretch_labels: Array = []
	for o in by_stretch:
		stretch_labels.append(o.get("label"))
	print("  STRETCH order:   %s" % str(stretch_labels))
	if stretch_labels != ["C_mushroom_small", "B_bread_small", "D_wheat_huge", "A_wheat_small"]:
		print("FAIL: STRETCH order wrong"); failures += 1

	# --- MAGNITUDE sort (descending quantity) --------------------------
	# Quantities: D=200, then A=B=C=5 (stable order among equal keys)
	var by_mag: Array = MarketView.sort_view(offers, inventory, MarketView.SortMode.MAGNITUDE)
	if str(by_mag[0].get("label")) != "D_wheat_huge":
		print("FAIL: MAGNITUDE first should be D"); failures += 1
	var mag_labels: Array = []
	for o in by_mag:
		mag_labels.append(o.get("label"))
	print("  MAGNITUDE order: %s" % str(mag_labels))

	# --- Edge case: empty inventory ------------------------------------
	# All offers should annotate as share=0; depth = qty/qty = 1 except qty=0.
	var empty_offers: Array = [{"resource": "🌾", "quantity": 5}]
	MarketView.annotate(empty_offers, {})
	if not _approx(empty_offers[0]["view_share"], 0.0, TOL):
		print("FAIL: empty-inventory share should be 0"); failures += 1
	if not _approx(empty_offers[0]["view_depth"], 1.0, TOL):
		print("FAIL: empty-inventory depth should be 1.0 when qty>0"); failures += 1

	print()
	if failures == 0:
		print("✅ MARKET VIEW GEOMETRY PASS — share/depth/comfort + 3 sort modes correct")
		quit(0)
	else:
		print("❌ MARKET VIEW GEOMETRY FAIL — %d check(s) failed" % failures)
		quit(1)


func _approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) < tol
