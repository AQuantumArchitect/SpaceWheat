extends SceneTree

## known_word_probe.gd — known words glow everywhere, and the glow is the payout (#105).
##
## Boots the real game headless (demos_normal), then:
##
##   KNOWN_TRACE {"phase": "before"}   the ledger is read; which plots already glow
##   KNOWN_TRACE {"phase": "ledger"}   a StarterForest word, 🌾/👥 and 🔥/❄ are incorporated; per
##                                     loaded biome, the registers word_known lights
##                                     and the multiplier each register would pay
##   KNOWN_TRACE {"phase": "field"}    per loaded biome, the 3D field's lit halos
##   KNOWN_TRACE {"phase": "strike"}   a strike on the known plot and on a stranger:
##                                     known, multiplier, and the receipt flier text
##   KNOWN_TRACE {"phase": "guide"}    a second word: Guide.known_word_col picks the newest
##
##   godot --headless --script tests/known_word_probe.gd
##
## tests/test_known_word_glow.py runs it. Set SW_PROBE_USER_DIR_PREFIX to refuse
## to boot unless user:// resolves under it.

const PRR = preload("res://Core/GameMechanics/PlotRegisterResolver.gd")
const Guide = preload("res://Core/Campaign/Guide.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("KNOWN_PROBE " + msg)
	quit(1)


func _trace(d: Dictionary) -> void:
	print("KNOWN_TRACE " + JSON.stringify(d))


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _axes(biome) -> Array:
	var out: Array = []
	var rm = biome.quantum_computer.register_map
	for q in range(int(rm.num_qubits)):
		var ax: Dictionary = rm.axis(q)
		out.append([str(ax.get("north", "")), str(ax.get("south", ""))])
	return out


func _lit(farm, biome) -> Array:
	var out: Array = []
	var axes := _axes(biome)
	for q in range(axes.size()):
		if ProbeActions.word_known(farm, axes[q][0], axes[q][1]):
			out.append(q)
	return out


func _tiers(farm, biome) -> Array:
	var out: Array = []
	for ax in _axes(biome):
		out.append(str(ProbeActions.vocabulary_tier(farm, ax[0], ax[1]).get("tier", "")))
	return out


func _reward_layer(n: Node):
	if n is FloatingRewardLayer:
		return n
	for c in n.get_children():
		var hit = _reward_layer(c)
		if hit != null:
			return hit
	return null


func _find_field(n: Node):
	if n is QuantumField3D:
		return n
	for c in n.get_children():
		var hit = _find_field(c)
		if hit != null:
			return hit
	return null


func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(str(n.text))
	for c in n.get_children():
		_labels(c, out)


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("KNOWN_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
		quit(2)
		return
	var app_root = load("res://scenes/AppRoot.gd").new()
	app_root.name = "AppRoot"
	get_root().add_child(app_root)
	var gsm = get_root().get_node_or_null("GameStateManager")
	if gsm and gsm.pending_boot:
		gsm.pending_boot.requested = true
		gsm.pending_boot.slot = -1
		gsm.pending_boot.scenario_id = "demos_normal"
	var booted := false
	for _i in range(3000):
		var gr = app_root.game_root if "game_root" in app_root else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null:
			booted = true
			break
		await process_frame
	if not booted:
		_fail("boot did not yield a farm")
		return
	var farm = app_root.game_root.farm
	var shell = app_root.get_player_shell()
	var inst = InstrumentLocator.resolve_quantum_instrument(shell)
	seed(7)
	await _frames(10)
	for e in ["🍞", "👥", "⛰", "🌾"]:
		farm.economy.add_resource(e, 5000, "probe")
	var biomes: Dictionary = farm.grid.get_all_biomes()
	if not biomes.has("StarterForest"):
		_fail("no StarterForest loaded")
		return
	farm.set_incorporated_icons([])

	var before := {}
	for nm in biomes:
		before[nm] = _lit(farm, biomes[nm])
	var before_tiers := {}
	for nm in biomes:
		before_tiers[nm] = _tiers(farm, biomes[nm])
	_trace({"phase": "before", "ledger": farm.incorporated_icons.size(), "lit": before,
		"tiers": before_tiers})

	# ledger: incorporate the word on the StarterForest plot the strike will use.
	var forest = biomes["StarterForest"]
	var positions: Array = farm.grid.get_plot_positions_for_biome("StarterForest")
	var known_pos: Vector2i = positions[0]
	var known_reg := int(PRR.resolve(farm, known_pos).get("register_id", int(known_pos.x)))
	var faxes := _axes(forest)
	var word: Array = faxes[known_reg]
	farm.mark_icon_incorporated(word[0], word[1])
	# Two more words from other biomes: the Demos' own axis written the other
	# way round (an icon is its axis), and the Village hearth.
	farm.mark_icon_incorporated("🌾", "👥")
	farm.mark_icon_incorporated("🔥", "❄")
	var lit := {}
	var mult := {}
	var axes_by := {}
	for nm in biomes:
		lit[nm] = _lit(farm, biomes[nm])
		axes_by[nm] = _axes(biomes[nm])
		var ms: Array = []
		for ax in axes_by[nm]:
			ms.append(ProbeActions._incorporation_reward_multiplier(ax[0], ax[1], 1.0, farm))
		mult[nm] = ms
	var tiers := {}
	for nm in biomes:
		tiers[nm] = _tiers(farm, biomes[nm])
	_trace({"phase": "ledger", "word": word, "lit": lit, "mult": mult, "axes": axes_by, "tiers": tiers})

	# field: the 3D field's halos, biome by biome.
	var abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
	var field = _find_field(get_root())
	var mounted := field != null
	if field == null:
		# Headless boots may mount no 3D field; stand one up on the same farm.
		field = QuantumField3D.new()
		get_root().add_child(field)
		field.connect_to_farm(farm)
		await _frames(3)
	var halos := {}
	var shared_halos := {}
	if field != null and field.has_method("known_glow_regs") and abm != null:
		for nm in biomes:
			abm.set_active_biome(nm)
			await _frames(8)
			if str(field.get("_last_biome")) == nm:
				var regs: Array = field.known_glow_regs()
				regs.sort()
				halos[nm] = regs
				var sh: Array = field.shared_emoji_regs()
				sh.sort()
				shared_halos[nm] = sh
	_trace({"phase": "field", "has_field": field != null, "mounted": mounted, "halos": halos,
		"shared_halos": shared_halos})

	# strike: the known plot, then a stranger in the same forest.
	if abm != null:
		abm.set_active_biome("StarterForest")
		await _frames(5)
	var strikes: Array = []
	var on_action := func(action: String, result: Dictionary):
		if action == "measure" and bool(result.get("success", false)):
			strikes.append(result)
	inst.action_performed.connect(on_action)
	var layer = _reward_layer(get_root())
	inst.action_explore("StarterForest", known_pos)
	await _frames(5)
	inst.action_measure(known_pos)
	await _frames(2)
	var layer_text: Array = []
	if layer != null:
		_labels(layer, layer_text)
	var stranger_pos := Vector2i(-1, -1)
	for p in positions:
		var r := int(PRR.resolve(farm, p).get("register_id", int(p.x)))
		if r >= 0 and r < faxes.size() and not ProbeActions.word_known(farm, faxes[r][0], faxes[r][1]):
			stranger_pos = p
			break
	if stranger_pos.x >= 0:
		inst.action_explore("StarterForest", stranger_pos)
		await _frames(5)
		inst.action_measure(stranger_pos)
		await _frames(2)
	var rows: Array = []
	for s in strikes:
		rows.append({"register_id": int(s.get("register_id", -1)), "known": bool(s.get("known", false)),
			"known_multiplier": float(s.get("known_multiplier", -1.0)), "amount": int(s.get("amount", 0))})
	_trace({"phase": "strike", "known_reg": known_reg, "strikes": rows, "has_layer": layer != null,
		"layer_text": layer_text,
		"sample_text": FloatingRewardLayer.known_strike_text(12, "icon"),
		"sample_emoji_text": FloatingRewardLayer.known_strike_text(12, "emoji")})

	# guide: a second forest word; the newest one is where the guide points.
	var second := -1
	for q in range(faxes.size()):
		if not ProbeActions.word_known(farm, faxes[q][0], faxes[q][1]):
			second = q
			break
	var first_pick: Dictionary = Guide.known_word_col(farm, forest.quantum_computer.register_map, faxes.size())
	if second >= 0:
		farm.mark_icon_incorporated(faxes[second][0], faxes[second][1])
	var newest_pick: Dictionary = Guide.known_word_col(farm, forest.quantum_computer.register_map, faxes.size())
	_trace({"phase": "guide", "first_reg": known_reg, "second_reg": second,
		"first_pick": first_pick, "newest_pick": newest_pick})
	quit(0)
