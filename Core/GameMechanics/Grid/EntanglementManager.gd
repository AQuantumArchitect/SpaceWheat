class_name EntanglementManager
extends RefCounted


## EntanglementManager - Multi-qubit entanglement and quantum operations
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles entanglement creation/removal, cluster management, and auto-infrastructure.


# Signals
signal entanglement_created(from: Vector2i, to: Vector2i)
signal entanglement_removed(from: Vector2i, to: Vector2i)

# Entanglement state lives in the density matrix (Model C): the biome's
# QuantumComputer owns it, and plot.entangled_plots carries the gameplay
# topology. The old EntangledPair/EntangledCluster object model was retired
# 2026-07-04 (never populated post-Model-C).

# Component dependencies (injected via set_dependencies)
var _plot_manager = null  # GridPlotManager
var _biome_routing = null  # BiomeRoutingManager
var _verbose = null


func set_dependencies(plot_manager, biome_routing) -> void:
	# Inject component dependencies.
	_plot_manager = plot_manager
	_biome_routing = biome_routing


func set_verbose(verbose_ref) -> void:
	# Set verbose logger reference.
	_verbose = verbose_ref


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API - Entanglement Creation/Removal
# ═══════════════════════════════════════════════════════════════════════════════

func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	# Create entanglement between two plots (PLOT INFRASTRUCTURE MODEL)

	# NEW: Entanglement is plot-level infrastructure (like gates)
	# - Plots remember entanglement links even after harvest/replant
	# - When planting in an entangled plot, quantum states auto-entangle

	# Args:
	# pos_a: Position of first plot
	# pos_b: Position of second plot
	# bell_type: Type of Bell state (used when both plots are planted)

	# Returns:
	# true if entanglement infrastructure created successfully
	if not _plot_manager.is_valid_position(pos_a) or not _plot_manager.is_valid_position(pos_b):
		return false

	if pos_a == pos_b:
		return false

	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	if plot_a == null or plot_b == null:
		return false

	# CRITICAL: Cross-biome entanglement prevention (Semantic Revolution requirement)
	# Each biome is an isolated quantum system - entanglement cannot span biomes
	var biome_id_a = _biome_routing.get_biome_id_for_plot(pos_a)
	var biome_id_b = _biome_routing.get_biome_id_for_plot(pos_b)

	if biome_id_a != biome_id_b:
		push_warning("FORBIDDEN: Cannot entangle plots from different biomes!")
		push_warning("   Plot %s biome: %s" % [pos_a, biome_id_a if biome_id_a != "" else "unassigned"])
		push_warning("   Plot %s biome: %s" % [pos_b, biome_id_b if biome_id_b != "" else "unassigned"])
		if _verbose:
			_verbose.warn("farm", "❌", "Cross-biome entanglement blocked: %s (%s) ↔ %s (%s)" % [
				pos_a, biome_id_a, pos_b, biome_id_b
			])
		return false

	if biome_id_a == "":
		push_warning("Cannot entangle plots with no biome assignment")
		if _verbose:
			_verbose.warn("farm", "❌", "Entanglement blocked: plots must be assigned to a biome")
		return false

	# NEW: Set up register-level entanglement blueprints (works even if not planted)
	var reg_a = _biome_routing.get_register_for_plot(pos_a)
	var reg_b = _biome_routing.get_register_for_plot(pos_b)
	var biome_ref = _biome_routing.get_biome_for_plot(pos_a)
	if biome_ref and biome_ref.quantum_computer and reg_a >= 0 and reg_b >= 0:
		var qc = biome_ref.quantum_computer
		var infra_a = qc._ensure_register_infra(reg_a)
		var infra_b = qc._ensure_register_infra(reg_b)
		if reg_b not in infra_a["entanglement_blueprints"]:
			infra_a["entanglement_blueprints"].append(reg_b)
		if reg_a not in infra_b["entanglement_blueprints"]:
			infra_b["entanglement_blueprints"].append(reg_a)
		if _verbose:
			_verbose.debug("farm", "🏗️", "Register infrastructure: reg %d ↔ reg %d (entanglement blueprint installed)" % [reg_a, reg_b])

	# Mark Bell gate in biome layer (historical entanglement record)
	var biome_a = _biome_routing.get_biome_for_plot(pos_a)
	if biome_a and biome_a.has_method("mark_bell_gate"):
		biome_a.mark_bell_gate([pos_a, pos_b])

	# If both plots are NOT planted, just set up infrastructure and return
	if not plot_a.is_active() or not plot_b.is_active():
		if _verbose:
			_verbose.info("farm", "→", "Infrastructure ready. Quantum entanglement will auto-activate when both plots are planted.")
		entanglement_created.emit(pos_a, pos_b)
		return true  # Infrastructure created successfully

	# Both plots are planted → Create quantum entanglement using helper
	var success = _create_quantum_entanglement(pos_a, pos_b, bell_type)
	if success:
		entanglement_created.emit(pos_a, pos_b)
	return success


func create_triplet_entanglement(pos_a: Vector2i, pos_b: Vector2i, pos_c: Vector2i) -> bool:
	# Create triple entanglement (3-qubit Bell state) for kitchen measurement

	# This marks three plots as a potential kitchen measurement target.
	# The spatial arrangement of the plots determines the Bell state type:
	# - Horizontal/Vertical/Diagonal → GHZ state
	# - L-shape → W state
	# - T-shape → Cluster state

	# Args:
	# pos_a, pos_b, pos_c: Positions of the three plots

	# Returns:
	# true if triplet entanglement infrastructure created successfully
	if not _plot_manager.is_valid_position(pos_a) or not _plot_manager.is_valid_position(pos_b) or not _plot_manager.is_valid_position(pos_c):
		return false

	# All positions must be different
	if pos_a == pos_b or pos_b == pos_c or pos_a == pos_c:
		return false

	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)
	var plot_c = _plot_manager.get_plot(pos_c)

	if plot_a == null or plot_b == null or plot_c == null:
		return false

	# CRITICAL: Cross-biome entanglement prevention (triplet version)
	var biome_id_a = _biome_routing.get_biome_id_for_plot(pos_a)
	var biome_id_b = _biome_routing.get_biome_id_for_plot(pos_b)
	var biome_id_c = _biome_routing.get_biome_id_for_plot(pos_c)

	if biome_id_a != biome_id_b or biome_id_b != biome_id_c:
		push_warning("FORBIDDEN: Cannot create triplet entanglement across different biomes!")
		push_warning("   Plot %s biome: %s" % [pos_a, biome_id_a])
		push_warning("   Plot %s biome: %s" % [pos_b, biome_id_b])
		push_warning("   Plot %s biome: %s" % [pos_c, biome_id_c])
		if _verbose:
			_verbose.warn("farm", "❌", "Cross-biome triplet entanglement blocked")
		return false

	if biome_id_a == "":
		push_warning("Cannot create triplet entanglement with unassigned plots")
		return false

	# Mark as triplet Bell gate in biome (kitchen can query these)
	var biome_a = _biome_routing.get_biome_for_plot(pos_a)
	if biome_a and biome_a.has_method("mark_bell_gate"):
		biome_a.mark_bell_gate([pos_a, pos_b, pos_c])
		if _verbose:
			_verbose.info("farm", "🔔", "Triple entanglement marked: %s, %s, %s (kitchen ready)" % [pos_a, pos_b, pos_c])

	# Emit signal for UI feedback
	entanglement_created.emit(pos_a, pos_b)  # Use first two positions for signal

	return true


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i) -> void:
	# Remove entanglement between two plots
	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	# Remove entanglement tracking
	if plot_a:
		plot_a.remove_entanglement(plot_b.plot_id if plot_b else "")
	if plot_b:
		plot_b.remove_entanglement(plot_a.plot_id if plot_a else "")

	# Remove register-level entanglement blueprints
	var reg_a = _biome_routing.get_register_for_plot(pos_a)
	var reg_b = _biome_routing.get_register_for_plot(pos_b)
	var biome = _biome_routing.get_biome_for_plot(pos_a)
	if biome and biome.quantum_computer and reg_a >= 0 and reg_b >= 0:
		var qc = biome.quantum_computer
		var infra_a = qc.get_register_infra_field(reg_a, "entanglement_blueprints", [])
		var infra_b = qc.get_register_infra_field(reg_b, "entanglement_blueprints", [])
		infra_a.erase(reg_b)
		infra_b.erase(reg_a)

	entanglement_removed.emit(pos_a, pos_b)


func are_plots_entangled(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	# Check if two plots are entangled
	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	if plot_a == null or plot_b == null:
		return false

	return plot_a.entangled_plots.has(plot_b.plot_id)


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL HELPERS - Quantum Entanglement Creation
# ═══════════════════════════════════════════════════════════════════════════════

func _create_quantum_entanglement(pos_a: Vector2i, pos_b: Vector2i, _bell_type: String = "phi_plus") -> bool:
	# Create quantum state entanglement (internal helper) - Model C: apply CNOT gate
	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	if not plot_a or not plot_b or not plot_a.is_active() or not plot_b.is_active():
		return false

	# MODEL C: Entanglement via apply_gate_2q
	var biome_a = _biome_routing.get_biome_for_plot(pos_a)
	var biome_b = _biome_routing.get_biome_for_plot(pos_b)

	# Ensure both plots are in same biome
	if biome_a != biome_b:
		push_error("Cannot entangle plots from different biomes - each biome has its own quantum_computer")
		return false

	# Get register IDs from biome routing
	var reg_id_a = _biome_routing.get_register_for_plot(pos_a)
	var reg_id_b = _biome_routing.get_register_for_plot(pos_b)

	if reg_id_a < 0 or reg_id_b < 0:
		push_error("Cannot entangle: plots don't have valid register allocations")
		return false

	# Model C: Apply entangling gate (CNOT) and update entanglement graph
	if biome_a and biome_a.quantum_computer:
		var qc = biome_a.quantum_computer
		# Check if already entangled via entanglement_graph
		var entangled_ids = qc.get_entangled_component(reg_id_a)
		if reg_id_b in entangled_ids:
			if _verbose:
				_verbose.info("quantum", "ℹ️", "Plots already entangled")
			plot_a.add_entanglement(plot_b.plot_id, 1.0)
			plot_b.add_entanglement(plot_a.plot_id, 1.0)
			return true

		# Apply H then CNOT to create Bell state
		var H = QuantumGateLibrary.get_gate("H")["matrix"]
		var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]

		qc.apply_gate(reg_id_a, H)  # Put first qubit in superposition
		qc.apply_gate_2q(reg_id_a, reg_id_b, CNOT)  # Entangle

		if _verbose:
			_verbose.info("quantum", "🔗", "Created entanglement via H + CNOT: %d ↔ %d" % [reg_id_a, reg_id_b])
	else:
		push_error("Biome has no quantum_computer for entanglement")
		return false

	# Update gameplay entanglement tracking (metadata for visualization)
	plot_a.add_entanglement(plot_b.plot_id, 1.0)
	plot_b.add_entanglement(plot_a.plot_id, 1.0)

	return true


func clear_plot_entanglements(plot) -> void:
	# Clear all entanglements for a plot (called during harvest/measurement).
	for partner_id in plot.entangled_plots.keys():
		var partner_pos = _plot_manager.find_plot_by_id(partner_id)
		if partner_pos != GridSentinel.INVALID_POSITION:
			var partner_plot = _plot_manager.get_plot(partner_pos)
			if partner_plot:
				partner_plot.entangled_plots.erase(plot.plot_id)
	plot.entangled_plots.clear()
