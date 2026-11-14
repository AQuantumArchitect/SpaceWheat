extends SceneTree

## Banks on several plots across biomes; ProbeActions._gather_all_banks (the
## first step of Reap) must pay every bank into the economy and clear them,
## leaving the plots' binding untouched.
## Run: godot --headless --script tests/reap_gathers_banks_probe.gd

const PA := preload("res://Core/Actions/ProbeActions.gd")
const Pool := preload("res://Core/GameMechanics/TerminalPool.gd")

class FakeFarm extends RefCounted:
	var terminal_pool

class FakeEconomy extends RefCounted:
	var paid: Dictionary = {}
	func add_resource(e: String, n: int, _src: String = "") -> void:
		paid[e] = int(paid.get(e, 0)) + n


func _init() -> void:
	var farm := FakeFarm.new()
	farm.terminal_pool = Pool.new(6)
	var econ := FakeEconomy.new()
	var ts: Array = farm.terminal_pool.terminals
	ts[0].bind_to_register(0, "BioA") if ts[0].has_method("bind_to_register") else null
	ts[0].bank_strike("🌱", 3, 0.4)
	ts[0].bank_strike("🌱", 2, 0.3)
	ts[1].bank_strike("🍄", 5, 0.5)   # a second plot
	ts[4].bank_strike("🌾", 7, 0.6)   # a plot "in another biome"
	var gathered: Dictionary = PA._gather_all_banks(farm, econ)
	var left := 0
	for t in ts:
		left += t.strikes.size()
	print(JSON.stringify({"probe": "reap-gathers-banks", "paid": econ.paid,
		"gathered": gathered.get("totals", {}), "left": left}))
	quit()
