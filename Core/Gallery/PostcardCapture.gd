class_name PostcardCapture
extends CanvasLayer

## The Gallery, G2 (docs/ENGINE_FRONTIER.md, Part II): postcards.
##
## F12 captures the current view with a physics watermark strip rendered INTO
## the pixels — biome, act, purity, entanglement, sim age — and writes a
## sidecar JSON certificate beside the image. The sim is deterministic from a
## save, so a postcard plus its save is a reproducible claim: this exact
## universe, replayable. No other game can caption a screenshot with "this
## really happened, and here is how to make it happen again."
##
## Output: user://postcards/postcard_<stamp>.png + .json
## Also drivable from reels ({"postcard": true} — ReelRunner) and headless
## tooling via the "postcard_capture" group.

const POSTCARD_DIR := "user://postcards"
const STRIP_HEIGHT := 28

var farm: Node = null
var _strip: PanelContainer = null
var _label: Label = null
var _busy: bool = false


static func maybe_attach(farm_node: Node) -> void:
	if farm_node == null:
		return
	var cap := PostcardCapture.new()
	cap.name = "PostcardCapture"
	cap.farm = farm_node
	farm_node.add_child(cap)


func _ready() -> void:
	layer = 100
	add_to_group("postcard_capture")
	_strip = PanelContainer.new()
	_strip.visible = false
	_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_strip.offset_top = -STRIP_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	_strip.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_strip.add_child(_label)
	add_child(_strip)
	set_process_unhandled_key_input(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		capture()


func capture() -> void:
	# Show the watermark, let one frame draw so it lands in the pixels,
	# grab the viewport, hide the strip, write image + certificate.
	if _busy:
		return
	_busy = true
	var cert := _certificate()
	_label.text = _watermark_line(cert)
	_strip.visible = true
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_strip.visible = false
	_busy = false
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(POSTCARD_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var base := "%s/postcard_%s" % [POSTCARD_DIR, stamp]
	img.save_png(base + ".png")
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(cert, "  ") + "\n")
	# `user://` is a Godot virtual path — it does not exist on the player's disk,
	# and F12 is advertised in three player-facing places, so this toast is the
	# headline feature's only pointer to its own output. Globalize it so the
	# player can actually open the folder.
	_toast("📮 postcard: %s.png" % ProjectSettings.globalize_path(base))


func _watermark_line(cert: Dictionary) -> String:
	var bits: Array[String] = ["SpaceWheat"]
	if str(cert.get("biome", "")) != "":
		bits.append(str(cert["biome"]))
	bits.append("act %d" % int(cert.get("act", 0)))
	if float(cert.get("purity", -1.0)) >= 0.0:
		bits.append("Tr(ρ²)=%.3f" % float(cert["purity"]))
	if float(cert.get("max_mi_bits", -1.0)) >= 0.0:
		bits.append("MI %.2f bits" % float(cert["max_mi_bits"]))
	bits.append("phrame %d" % int(cert.get("phrames", 0)))
	bits.append(str(cert.get("date", "")))
	return " · ".join(bits)


func _certificate() -> Dictionary:
	# The physics certificate: everything needed to stand behind the image.
	# Deterministic replay = this save + this phrame count, not a magic seed.
	var cert := {
		"title": "SpaceWheat postcard",
		"date": Time.get_datetime_string_from_system(),
		"biome": "",
		"act": 0,
		"purity": -1.0,
		"max_mi_bits": -1.0,
		"phrames": 0,
		"flags_fired": 0,
		"bridges_alive": 0,
	}
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	var biome_name: String = str(abm.active_biome) if (abm != null and "active_biome" in abm) else ""
	cert["biome"] = biome_name
	if farm != null:
		if "story_log" in farm and farm.story_log is Array:
			cert["flags_fired"] = farm.story_log.size()
			var max_act := 0
			for row in farm.story_log:
				if row is Dictionary:
					max_act = maxi(max_act, int(row.get("act", 0)))
			cert["act"] = max_act
		if "biome_evolution_batcher" in farm and farm.biome_evolution_batcher != null \
				and "total_evolutions" in farm.biome_evolution_batcher:
			cert["phrames"] = int(farm.biome_evolution_batcher.total_evolutions)
		if "bridge_register" in farm and farm.bridge_register != null:
			cert["bridges_alive"] = farm.bridge_register.count()
		if biome_name != "" and "grid" in farm and farm.grid != null and farm.grid.has_method("get_biome"):
			var biome = farm.grid.get_biome(biome_name)
			var qc = biome.quantum_computer if (biome != null and "quantum_computer" in biome) else null
			if qc != null:
				if qc.has_method("get_purity"):
					cert["purity"] = float(qc.get_purity())
				if qc.has_method("has_cached_mi") and qc.has_cached_mi():
					var n: int = qc.register_map.num_qubits
					var best := 0.0
					for i in range(n):
						for j in range(i + 1, n):
							best = maxf(best, float(qc.get_cached_mutual_information(i, j)))
					cert["max_mi_bits"] = best
				if qc.has_method("is_open_here"):
					cert["regime"] = "open" if qc.is_open_here() else "closed"
	return cert


func _toast(text: String) -> void:
	var shell = InstrumentLocator.resolve_player_shell(self)
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint(text, 2, "")
