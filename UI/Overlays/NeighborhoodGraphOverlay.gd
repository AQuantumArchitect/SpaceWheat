class_name NeighborhoodGraphOverlay
extends "res://UI/Core/OverlayBase.gd"

## NeighborhoodGraphOverlay — a GraphEdit node-flow view of ONE neighborhood's
## quantum cluster (the 4-6 qubit reservoir of the active biome).
##
## Thin host: it resolves the active biome, derives a [NeighborhoodGraph] from the
## canonical Biome data (source of truth), and hands it to a shared
## [NeighborhoodGraphView] for rendering + live population bars. The same view powers
## the M · Graph drill-down, so the cluster renderer lives in exactly one place.
## Read/inspect only for now — editing that writes session deltas is a later step.

const NeighborhoodGraphRef = preload("res://Core/QuantumSubstrate/NeighborhoodGraph.gd")
const NeighborhoodGraphViewRef = preload("res://UI/Overlays/NeighborhoodGraphView.gd")

var farm: Node = null
var _active_biome: Node = null          # live BiomeBase node (live populations)
var _view: GraphEdit = null             # shared NeighborhoodGraphView


func _init() -> void:
	overlay_name = "neighborhood_graph"
	overlay_icon = "🕸"
	overlay_tier = 12
	panel_title = "🕸 Neighborhood Graph"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.LARGE
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.8)
	panel_border_color = Color(0.4, 0.5, 0.7, 0.85)
	use_scroll_container = false   # GraphEdit fills the panel itself
	content_spacing = 4
	navigation_mode = NavigationMode.NONE


func _build_content(container: Control) -> void:
	_view = NeighborhoodGraphViewRef.new()
	_view.custom_minimum_size = Vector2(720, 460)
	container.add_child(_view)


func _on_activated() -> void:
	_resolve()
	_rebuild_graph()


func _resolve() -> void:
	if not farm:
		var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
		if gsm and gsm.has_method("get_active_farm"):
			farm = gsm.get_active_farm()
	_active_biome = null
	if not farm:
		return
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm and farm.grid and farm.grid.has_method("get_biome"):
		_active_biome = farm.grid.get_biome(abm.get_active_biome())


## Build the derived graph from the canonical Biome data (source of truth) for the
## active biome; the live node only supplies population readouts to the view.
func _rebuild_graph() -> void:
	if _view == null:
		return
	var biome_name := ""
	if _active_biome and _active_biome.has_method("get_biome_type"):
		biome_name = _active_biome.get_biome_type()
	var canonical = _canonical_biome(biome_name)
	if canonical != null:
		_view.populate(NeighborhoodGraphRef.from_biome(canonical))
		set_title("🕸 %s — neighborhood" % biome_name)
	else:
		_view.populate(null)
	var qc = _active_biome.quantum_computer if (_active_biome and "quantum_computer" in _active_biome) else null
	_view.set_live_source(qc)


func _canonical_biome(biome_name: String):
	if biome_name == "":
		return null
	var reg = load("res://Core/Biomes/BiomeRegistry.gd")
	if reg != null and reg.has_method("get_shared"):
		var shared = reg.get_shared()
		if shared != null and shared.has_method("get_by_name"):
			return shared.get_by_name(biome_name)
	return null


## E-inspect (touch-first "more information" — OverlayBase toasts this on E):
## the cluster legend, the sealed-webway law, and the live entanglement readout.
func get_inspect_text() -> String:
	if _view != null and is_instance_valid(_view) and _view.has_method("inspect_text"):
		return str(_view.inspect_text())
	return ""
