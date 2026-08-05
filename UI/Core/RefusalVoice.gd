class_name RefusalVoice
extends RefCounted

## The ONE voice for non-progression refusals (anti-gating law: a started
## action is never silently hindered — every dead key speaks).
##
## Two shapes:
##   RefusalVoice.refuse("Plant", "no biome selected — T Y U picks one")
##       → "✗ Plant — no biome selected …"      (an action was attempted and blocked)
##   RefusalVoice.note("no biome in slot P yet — Captain 7: R discovers")
##       → "• no biome in slot P yet …"          (a key simply has nothing here)
##
## Progression locks stay on UIProgression.redirect_locked() — a different law:
## that voice points at the OBJECTIVE ("🔒 not yet — now: …"); this one points
## at the MECHANISM. QII's _toast_refusal/_toast_player remain for refusals
## carried in action result-dicts; new guard-band coverage routes here so the
## voice + rate policy has one home.
##
## Rate policy: PER-MESSAGE dedupe (1.5s per identical text), deliberately NOT
## a single global cooldown — a global timer would eat the second of two
## DIFFERENT refusals, which is exactly the silence this class exists to end.
## (PlayerShell.show_hint additionally folds identical live toasts into ×N.)

const PER_MESSAGE_COOLDOWN_MS := 1500

static var _last_ms_by_text: Dictionary = {}


static func refuse(verb: String, why: String) -> void:
	_speak("✗ %s — %s" % [verb, why])


static func note(text: String) -> void:
	_speak("• %s" % text)


static func _speak(text: String) -> void:
	var now := Time.get_ticks_msec()
	var last: int = int(_last_ms_by_text.get(text, -PER_MESSAGE_COOLDOWN_MS))
	if now - last < PER_MESSAGE_COOLDOWN_MS:
		return
	_last_ms_by_text[text] = now
	if _last_ms_by_text.size() > 64:
		_last_ms_by_text.clear()  # bounded memory; a rare double-toast beats a leak
	var shell := _shell()
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint(text, 2)


static func _shell() -> Node:
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var shells: Array = (ml as SceneTree).get_nodes_in_group("player_shell")
	return shells[0] if not shells.is_empty() else null
