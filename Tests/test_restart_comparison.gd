extends SceneTree

var farm_view = null
var initial_state = {}
var restart_state = {}

func _init():
	var sep = "============================================================"
	print("\n" + sep)
	print("🎮 GAME RESTART COMPARISON TEST")
	print(sep + "\n")

func _initialize():
	print("📦 Starting NEW GAME...")
	var scene = load("res://scenes/FarmView.tscn")
	farm_view = scene.instantiate()
	root.add_child(farm_view)
	
	await create_timer(2.0).timeout
	
	var sep = "============================================================"
	print("\n" + sep)
	print("📸 CAPTURING INITIAL STATE")
	print(sep)
	capture_state(initial_state, "INITIAL")
	
	await create_timer(1.0).timeout
	
	print("\n" + sep)
	print("🔄 RESTARTING GAME...")
	print(sep)
	
	# Trigger restart
	farm_view._on_restart_pressed()
	
	await create_timer(2.0).timeout
	
	print("\n" + sep)
	print("📸 CAPTURING RESTART STATE")
	print(sep)
	capture_state(restart_state, "RESTART")
	
	await create_timer(0.5).timeout
	
	print("\n" + sep)
	print("🔍 COMPARISON ANALYSIS")
	print(sep)
	compare_states()
	
	quit()

func capture_state(state: Dictionary, label: String):
	print("\n--- " + label + " STATE ---")
	
	# Economy
	state["credits"] = farm_view.economy.credits
	state["wheat_inventory"] = farm_view.economy.wheat_inventory
	state["flour_inventory"] = farm_view.economy.flour_inventory
	print("💰 Credits: " + str(state["credits"]))
	print("🌾 Wheat: " + str(state["wheat_inventory"]))
	print("🍞 Flour: " + str(state["flour_inventory"]))
	
	# Goals
	state["current_goal_index"] = farm_view.goals.current_goal_index
	state["total_goals"] = farm_view.goals.goals.size()
	print("🎯 Goal: " + str(state["current_goal_index"] + 1) + "/" + str(state["total_goals"]))
	if state["current_goal_index"] < state["total_goals"]:
		var goal = farm_view.goals.goals[state["current_goal_index"]]
		print("   Current: " + goal["title"])
	
	# Contracts
	state["contracts_count"] = farm_view.contract_manager.active_contracts.size()
	print("📜 Active Contracts: " + str(state["contracts_count"]))
	
	# Icons
	state["biotic_strength"] = farm_view.biotic_icon.activation_strength
	state["chaos_strength"] = farm_view.chaos_icon.activation_strength
	state["imperium_strength"] = farm_view.imperium_icon.activation_strength
	print("✨ Icon Activations:")
	print("   🌾 Biotic: " + str(state["biotic_strength"]))
	print("   🍅 Chaos: " + str(state["chaos_strength"]))
	print("   🏰 Imperium: " + str(state["imperium_strength"]))
	
	# Plots
	var planted_count = 0
	var measured_count = 0
	var mature_count = 0
	for y in range(5):
		for x in range(5):
			var plot = farm_view.farm_grid.get_plot(Vector2i(x, y))
			if plot.is_planted:
				planted_count += 1
			if plot.has_been_measured:
				measured_count += 1
			if plot.is_mature:
				mature_count += 1
	
	state["planted_plots"] = planted_count
	state["measured_plots"] = measured_count
	state["mature_plots"] = mature_count
	print("🌱 Plots: " + str(planted_count) + " planted, " + str(measured_count) + " measured, " + str(mature_count) + " mature")
	
	# Conspiracy network
	state["conspiracies_count"] = farm_view.conspiracy_network.active_conspiracies.size()
	print("🍅 Active Conspiracies: " + str(state["conspiracies_count"]))
	
	# Vocabulary
	state["vocab_size"] = farm_view.vocabulary_evolution.discovered_forms.size()
	print("📖 Vocabulary Size: " + str(state["vocab_size"]))

func compare_states():
	print("\n🔄 CHANGES AFTER RESTART:\n")
	
	var changed = false
	
	# Check economy
	if initial_state["credits"] != restart_state["credits"]:
		print("💰 Credits: " + str(initial_state["credits"]) + " → " + str(restart_state["credits"]))
		changed = true
	
	# Check goals
	if initial_state["current_goal_index"] != restart_state["current_goal_index"]:
		print("🎯 Goal Index: " + str(initial_state["current_goal_index"]) + " → " + str(restart_state["current_goal_index"]))
		changed = true
	
	# Check contracts
	if initial_state["contracts_count"] != restart_state["contracts_count"]:
		print("📜 Contracts: " + str(initial_state["contracts_count"]) + " → " + str(restart_state["contracts_count"]))
		changed = true
	
	# Check plots
	if initial_state["planted_plots"] != restart_state["planted_plots"]:
		print("🌱 Planted Plots: " + str(initial_state["planted_plots"]) + " → " + str(restart_state["planted_plots"]))
		changed = true
	
	# Check vocabulary
	if initial_state["vocab_size"] != restart_state["vocab_size"]:
		print("📖 Vocabulary: " + str(initial_state["vocab_size"]) + " → " + str(restart_state["vocab_size"]))
		changed = true
	
	if not changed:
		print("✅ No changes detected - restart appears to reset to initial state")
	
	var sep = "============================================================"
	print("\n" + sep)
	print("💡 OBSERVATIONS FOR LEVEL/STAGE SYSTEM:")
	print(sep)
	print("")
	print("Based on what resets and what persists, we can design:")
	print("1. What should carry over between levels?")
	print("2. What should reset each stage?")
	print("3. How should difficulty/complexity progress?")
	print("")
