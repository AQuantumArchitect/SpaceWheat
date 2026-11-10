extends SceneTree

## glyph_chatter_ingame_probe.gd — boots the real game headless (AppRoot → GameRoot →
## farm, the rig listener's one boot path), lets the StoryEngine tick, and prints the
## chatter it produced with each event's glyph-language sentence:
##
##   GLYPH_CHATTER {"biome": ..., "emojis": [...], "marginals": [...], "glyph": {...}}
##
## Exits on its own (never left running). Run in the foreground:
##   godot --headless --script tests/glyph_chatter_ingame_probe.gd
## Set SW_PROBE_USER_DIR_PREFIX to refuse to boot unless user:// resolves under it
## (keeps a probe from writing into a player's real save directory).

const WAIT_FRAMES := 3600   # ~60 s at 60 Hz
const WANT := 4


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	print("GLYPH_PROBE user_dir=%s" % user_dir)
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("GLYPH_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
		printerr("GLYPH_PROBE boot did not yield a farm")
		quit(1)
		return
	print("GLYPH_PROBE booted")
	var engine = get_root().get_node_or_null("/root/StoryEngine")
	if engine == null:
		printerr("GLYPH_PROBE no StoryEngine")
		quit(1)
		return
	var chatter: Array = []
	for _i in range(WAIT_FRAMES):
		chatter = engine.recent_chatter(16)
		if chatter.size() >= WANT:
			break
		await process_frame
	for ev in chatter:
		if str(ev.get("kind", "")) != "chatter":
			continue
		print("GLYPH_CHATTER " + JSON.stringify({
			"faction": ev.get("faction", ""),
			"biome": ev.get("biome", ""),
			"emojis": ev.get("emojis", []),
			"marginals": ev.get("marginals", []),
			"glyph": ev.get("glyph", null),
		}))
	print("GLYPH_PROBE done chatter=%d" % chatter.size())
	quit(0)
