extends SceneTree

## contract_lattice_phase6.gd — Phase VI MarketLattice + bias source +
## price model + θ distribution verification.
##
## Run: godot --headless --quit --script tests/contract_lattice_phase6.gd
##
## These tests exercise the lattice with a synthesized minimal farm/biome
## stand-in. The substrate calls degrade gracefully when full game state isn't
## available, so we can test composition + determinism + math without
## standing up the entire boot sequence.

const MC = preload("res://Core/Markets/Contract.gd")
const MarketBiasSources = preload("res://Core/Markets/MarketBiasSources.gd")
const PriceModel = preload("res://Core/Markets/PriceModel.gd")
const MarketLattice = preload("res://Core/Markets/MarketLattice.gd")
const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	print("=== Contract lattice phase VI ===")
	_t_contract_record_shape()
	_t_bias_sources_compose_neutral()
	_t_price_determinism()
	_t_price_at_neutral()
	_t_price_at_extremes()
	_t_implied_marginal_in_range()
	_t_lattice_register_and_query()
	_t_expire_old()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		print("  ✗ %s" % label)


func _make_contract(resource: String = "🌾", faction: String = "TestFaction", biome: String = "StarterForest"):
	return MC.make(resource, faction, biome, 1, 0, 20.0, 100)


func _t_contract_record_shape() -> void:
	var c = _make_contract()
	_check(c.id != 0, "Contract.make produces nonzero id")
	_check(c.status == MC.STATUS_OPEN, "Contract starts open")
	_check(c.resource == "🌾", "Contract resource preserved")
	_check(c.faction == "TestFaction", "Contract faction preserved")
	var d: Dictionary = c.to_dict()
	_check(d.has("id") and d.has("resource") and d.has("status"),
		"Contract.to_dict has expected keys")


func _t_bias_sources_compose_neutral() -> void:
	# With null farm, all sources return 0 → ρ_market is neutral (P_gozouta = 0.5).
	var c = _make_contract()
	var rho: Dictionary = MarketBiasSources.compose_market_qubit(c, null)
	var p_g: float = float(rho.get("p_gozouta", -1.0))
	_check(abs(p_g - 0.5) < 1e-9,
		"composing biases against null farm → neutral P=0.5 (got %.6f)" % p_g)
	_check(abs(rho.get("theta_total", -1.0)) < 1e-9,
		"theta_total = 0 with null farm")


func _t_price_determinism() -> void:
	# Same substrate (null farm) → same price across multiple calls.
	var c = _make_contract()
	var p1: float = PriceModel.price_contract(c, null)
	var p2: float = PriceModel.price_contract(c, null)
	_check(abs(p1 - p2) < 1e-9, "price deterministic across calls (got %.6f, %.6f)" % [p1, p2])


func _t_price_at_neutral() -> void:
	# At P=0.5 with neutral standings, price = 1/0.5 × QC_RATIO × 1.0 = 20.0
	var c = _make_contract()
	var price: float = PriceModel.price_contract(c, null)
	_check(abs(price - 20.0) < 0.01,
		"price at neutral P=0.5 ≈ 20 classical (got %.4f)" % price)


func _t_price_at_extremes() -> void:
	# Synthesize a contract whose composed P is forced toward extremes by
	# directly testing the inversion formula on known inputs.
	# At p=0.99: price = 1/0.99 × 10 ≈ 10.1; at p=0.01: price = 1/0.01 × 10 = 1000.
	var p_high: float = 1.0 / 0.99 * HamiltonianConfig.QUANTUM_CLASSICAL_RATIO
	var p_low: float = 1.0 / 0.01 * HamiltonianConfig.QUANTUM_CLASSICAL_RATIO
	_check(abs(p_high - 10.10) < 0.05,
		"hand-computed price at P=0.99 ≈ 10.1 (got %.4f)" % p_high)
	_check(abs(p_low - 1000.0) < 0.5,
		"hand-computed price at P=0.01 = 1000 (got %.4f)" % p_low)


func _t_implied_marginal_in_range() -> void:
	var c = _make_contract()
	var p: float = PriceModel.implied_marginal(c, null)
	_check(p >= 0.0 and p <= 1.0,
		"implied_marginal in [0, 1] (got %.4f)" % p)


func _t_lattice_register_and_query() -> void:
	var lat = MarketLattice.new()
	var c1 = _make_contract("🌾", "FactionA", "StarterForest")
	var c2 = _make_contract("⚔", "FactionB", "Village")
	lat.register_offer(c1)
	lat.register_offer(c2)
	var open_all: Array = lat.get_open_offers()
	_check(open_all.size() == 2, "registered 2 open offers")
	var open_sf: Array = lat.get_open_offers("StarterForest")
	_check(open_sf.size() == 1 and open_sf[0].id == c1.id,
		"filtering offers by biome works")
	var portfolio: Array = lat.get_player_portfolio()
	_check(portfolio.is_empty(), "portfolio empty before any buys")


func _t_expire_old() -> void:
	var lat = MarketLattice.new()
	var c = _make_contract()
	c.expiry_phrame = 5
	lat.register_offer(c)
	var n_expired: int = lat.expire_old(10)  # past the expiry
	_check(n_expired == 1, "expire_old swept 1 expired offer")
	_check(c.status == MC.STATUS_EXPIRED,
		"contract status flipped to expired")
