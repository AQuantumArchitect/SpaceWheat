extends SceneTree

## EntangledCluster Integration Tests
## Tests integration of N-qubit clusters with FarmGrid and WheatPlot

func _initialize():
	print("\n" + "=".repeat(80))
	print("  ENTANGLED CLUSTER - INTEGRATION TESTS")
	print("  Testing N-Qubit Cluster Integration with Game Mechanics")
	print("=".repeat(80) + "\n")

	# Load scripts
	var FarmGridScript = load("res://Core/GameMechanics/FarmGrid.gd")
	var WheatPlotScript = load("res://Core/GameMechanics/WheatPlot.gd")

	# Test 1: Baseline - 2-Qubit Pair Creation
	print("TEST 1: Baseline - 2-Qubit Pair Creation")
	print("─".repeat(40))

	var grid = FarmGridScript.new()
	grid.grid_width = 5
	grid.grid_height = 5
	grid._ready()  # Initialize

	# Plant plots
	var pos_a = Vector2i(0, 0)
	var pos_b = Vector2i(1, 0)
	grid.plant_wheat(pos_a)
	grid.plant_wheat(pos_b)

	# Create entanglement
	var success = grid.create_entanglement(pos_a, pos_b, "phi_plus")

	var plot_a = grid.get_plot(pos_a)
	var plot_b = grid.get_plot(pos_b)

	print("  Entanglement created: %s" % ("✅" if success else "❌"))
	print("  EntangledPair count: %d" % grid.entangled_pairs.size())
	print("  EntangledCluster count: %d" % grid.entangled_clusters.size())
	print("  Plot A has pair: %s" % ("✅" if plot_a.quantum_state.is_in_pair() else "❌"))
	print("  Plot B has pair: %s" % ("✅" if plot_b.quantum_state.is_in_pair() else "❌"))

	if success and grid.entangled_pairs.size() == 1 and grid.entangled_clusters.size() == 0:
		print("  ✅ 2-qubit pair creation working\n")
	else:
		print("  ❌ 2-qubit pair creation failed\n")
		quit(1)

	# Test 2: Pair-to-Cluster Upgrade
	print("TEST 2: Pair-to-Cluster Upgrade (2→3 qubits)")
	print("─".repeat(40))

	var grid2 = FarmGridScript.new()
	grid2.grid_width = 5
	grid2.grid_height = 5
	grid2._ready()

	# Create initial pair
	var p_a = Vector2i(0, 0)
	var p_b = Vector2i(1, 0)
	var p_c = Vector2i(2, 0)

	grid2.plant_wheat(p_a)
	grid2.plant_wheat(p_b)
	grid2.plant_wheat(p_c)

	grid2.create_entanglement(p_a, p_b, "phi_plus")
	print("  Created initial pair: A-B")
	print("    Pairs: %d, Clusters: %d" % [grid2.entangled_pairs.size(), grid2.entangled_clusters.size()])

	# Add third qubit (should upgrade to cluster)
	var upgrade_success = grid2.create_entanglement(p_b, p_c)
	print("  Added C to B (should upgrade to cluster)")
	print("    Pairs: %d, Clusters: %d" % [grid2.entangled_pairs.size(), grid2.entangled_clusters.size()])

	var plot2_a = grid2.get_plot(p_a)
	var plot2_b = grid2.get_plot(p_b)
	var plot2_c = grid2.get_plot(p_c)

	var all_in_cluster = (plot2_a.quantum_state.is_in_cluster() and
	                      plot2_b.quantum_state.is_in_cluster() and
	                      plot2_c.quantum_state.is_in_cluster())

	var cluster_size = 0
	if plot2_a.quantum_state.is_in_cluster():
		cluster_size = plot2_a.quantum_state.entangled_cluster.get_qubit_count()

	print("  All plots in cluster: %s" % ("✅" if all_in_cluster else "❌"))
	print("  Cluster size: %d" % cluster_size)
	print("  Pair removed: %s" % ("✅" if grid2.entangled_pairs.size() == 0 else "❌"))

	if upgrade_success and all_in_cluster and cluster_size == 3 and grid2.entangled_clusters.size() == 1:
		print("  ✅ Pair-to-cluster upgrade working\n")
	else:
		print("  ❌ Pair-to-cluster upgrade failed\n")
		quit(1)

	# Test 3: Sequential Cluster Expansion (3→4→5 qubits)
	print("TEST 3: Sequential Cluster Expansion (3→4→5 qubits)")
	print("─".repeat(40))

	var grid3 = FarmGridScript.new()
	grid3.grid_width = 5
	grid3.grid_height = 5
	grid3._ready()

	# Create 3-qubit cluster
	var s_a = Vector2i(0, 0)
	var s_b = Vector2i(1, 0)
	var s_c = Vector2i(2, 0)
	var s_d = Vector2i(3, 0)
	var s_e = Vector2i(4, 0)

	grid3.plant_wheat(s_a)
	grid3.plant_wheat(s_b)
	grid3.plant_wheat(s_c)
	grid3.plant_wheat(s_d)
	grid3.plant_wheat(s_e)

	grid3.create_entanglement(s_a, s_b)
	grid3.create_entanglement(s_b, s_c)  # 2→3
	print("  3-qubit cluster: %d" % grid3.get_plot(s_a).quantum_state.entangled_cluster.get_qubit_count())

	grid3.create_entanglement(s_c, s_d)  # 3→4
	print("  4-qubit cluster: %d" % grid3.get_plot(s_a).quantum_state.entangled_cluster.get_qubit_count())

	grid3.create_entanglement(s_d, s_e)  # 4→5
	var final_size = grid3.get_plot(s_a).quantum_state.entangled_cluster.get_qubit_count()
	print("  5-qubit cluster: %d" % final_size)

	if final_size == 5 and grid3.entangled_clusters.size() == 1:
		print("  ✅ Sequential expansion to 5 qubits working\n")
	else:
		print("  ❌ Sequential expansion failed\n")
		quit(1)

	# Test 4: 6-Qubit Limit
	print("TEST 4: 6-Qubit Limit (soft cap)")
	print("─".repeat(40))

	var grid4 = FarmGridScript.new()
	grid4.grid_width = 7
	grid4.grid_height = 1
	grid4._ready()

	# Plant 7 plots
	for i in range(7):
		grid4.plant_wheat(Vector2i(i, 0))

	# Create 6-qubit cluster
	for i in range(5):
		grid4.create_entanglement(Vector2i(i, 0), Vector2i(i + 1, 0))

	var size_before_7th = grid4.get_plot(Vector2i(0, 0)).get_cluster_size()
	print("  Cluster size before 7th: %d" % size_before_7th)

	# Try to add 7th (should fail)
	var seventh_success = grid4.create_entanglement(Vector2i(5, 0), Vector2i(6, 0))
	var size_after_7th = grid4.get_plot(Vector2i(0, 0)).get_cluster_size()
	print("  7th add attempt: %s (should fail)" % ("Success" if seventh_success else "Failed"))
	print("  Cluster size after 7th attempt: %d" % size_after_7th)

	if size_before_7th == 6 and not seventh_success and size_after_7th == 6:
		print("  ✅ 6-qubit limit enforced\n")
	else:
		print("  ❌ 6-qubit limit not working\n")
		quit(1)

	# Test 5: Cluster Measurement Cascade
	print("TEST 5: Cluster Measurement Cascade")
	print("─".repeat(40))

	var grid5 = FarmGridScript.new()
	grid5.grid_width = 4
	grid5.grid_height = 1
	grid5._ready()

	# Create 4-qubit GHZ cluster
	for i in range(4):
		var pos = Vector2i(i, 0)
		grid5.plant_wheat(pos)
		grid5.get_plot(pos).growth_progress = 1.0
		grid5.get_plot(pos).is_mature = true

	grid5.create_entanglement(Vector2i(0, 0), Vector2i(1, 0))
	grid5.create_entanglement(Vector2i(1, 0), Vector2i(2, 0))
	grid5.create_entanglement(Vector2i(2, 0), Vector2i(3, 0))

	var cluster_before = grid5.get_plot(Vector2i(0, 0)).get_cluster_size()
	print("  Cluster size before measurement: %d" % cluster_before)

	# Measure one plot (should collapse entire cluster)
	var harvest_result = grid5.harvest_with_topology(Vector2i(0, 0))

	var cluster_after = grid5.get_plot(Vector2i(0, 0)).get_cluster_size()
	var all_collapsed = true
	for i in range(4):
		var plot = grid5.get_plot(Vector2i(i, 0))
		if plot.quantum_state and plot.quantum_state.is_in_cluster():
			all_collapsed = false
			break

	print("  Cluster size after measurement: %d" % cluster_after)
	print("  All plots collapsed: %s" % ("✅" if all_collapsed else "❌"))
	print("  Clusters remaining: %d" % grid5.entangled_clusters.size())

	if cluster_before == 4 and cluster_after == 0 and all_collapsed and grid5.entangled_clusters.size() == 0:
		print("  ✅ Cluster measurement cascade working\n")
	else:
		print("  ❌ Cluster measurement cascade failed\n")
		quit(1)

	# Test 6: UI Helper Methods
	print("TEST 6: UI Helper Methods")
	print("─".repeat(40))

	var grid6 = FarmGridScript.new()
	grid6.grid_width = 3
	grid6.grid_height = 1
	grid6._ready()

	grid6.plant_wheat(Vector2i(0, 0))
	grid6.plant_wheat(Vector2i(1, 0))
	grid6.plant_wheat(Vector2i(2, 0))

	grid6.create_entanglement(Vector2i(0, 0), Vector2i(1, 0))
	grid6.create_entanglement(Vector2i(1, 0), Vector2i(2, 0))

	var plot6 = grid6.get_plot(Vector2i(0, 0))
	var size = plot6.get_cluster_size()
	var state_type = plot6.get_cluster_state_type()
	var description = plot6.get_entanglement_description()

	print("  Cluster size: %d" % size)
	print("  Cluster state type: %s" % state_type)
	print("  Entanglement description: %s" % description)

	if size == 3 and state_type == "GHZ" and description.contains("3-qubit"):
		print("  ✅ UI helper methods working\n")
	else:
		print("  ❌ UI helper methods failed\n")
		quit(1)

	# Test 7: Topology Integration (Complete Graph K₃)
	print("TEST 7: Topology Integration (3-Qubit Cluster = Complete Graph)")
	print("─".repeat(40))

	var grid7 = FarmGridScript.new()
	grid7.grid_width = 3
	grid7.grid_height = 1
	grid7._ready()

	grid7.plant_wheat(Vector2i(0, 0))
	grid7.plant_wheat(Vector2i(1, 0))
	grid7.plant_wheat(Vector2i(2, 0))

	grid7.create_entanglement(Vector2i(0, 0), Vector2i(1, 0))
	grid7.create_entanglement(Vector2i(1, 0), Vector2i(2, 0))

	# Check gameplay entanglement tracking
	var plot7_a = grid7.get_plot(Vector2i(0, 0))
	var plot7_b = grid7.get_plot(Vector2i(1, 0))
	var plot7_c = grid7.get_plot(Vector2i(2, 0))

	var entangled_count_a = plot7_a.entangled_plots.size()
	var entangled_count_b = plot7_b.entangled_plots.size()
	var entangled_count_c = plot7_c.entangled_plots.size()

	print("  Plot A connections: %d (expect 2)" % entangled_count_a)
	print("  Plot B connections: %d (expect 2)" % entangled_count_b)
	print("  Plot C connections: %d (expect 2)" % entangled_count_c)

	# Each plot should be connected to the other 2 (complete graph K₃)
	if entangled_count_a == 2 and entangled_count_b == 2 and entangled_count_c == 2:
		print("  ✅ Topology integration working (complete graph)\n")
	else:
		print("  ❌ Topology integration failed\n")
		quit(1)

	# Summary
	print("=".repeat(80))
	print("  ALL INTEGRATION TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	print("📊 Test Summary:")
	print("  ✅ 2-qubit pair creation (baseline)")
	print("  ✅ Pair-to-cluster upgrade (2→3)")
	print("  ✅ Sequential cluster expansion (3→4→5)")
	print("  ✅ 6-qubit limit enforcement")
	print("  ✅ Cluster measurement cascade")
	print("  ✅ UI helper methods")
	print("  ✅ Topology integration (complete graph)")
	print("\n🌟 EntangledCluster integration complete!")
	print("⚛️ Ready for production use!\n")

	quit()
