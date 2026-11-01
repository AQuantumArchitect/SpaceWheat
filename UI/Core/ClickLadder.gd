class_name ClickLadder
extends RefCounted

## ClickLadder — one meaning for a click, on every information chip.
##
## Playtest 2026-09-09: the surfaces got better, but clicking still meant
## three different things depending on which card you touched. This is the
## one contract:
##
##   1. DETAIL  — expand in place. More copy, no travel.
##   2. HOME    — open the menu that already holds this information.
##   3. SCOOT   — close the menu and walk toward where the task is done
##                (the named biome, the pulsing verb).
##
## Action chips (QERF, hats, biomes, plots, pause, clock) stay IMMEDIATE —
## they are verbs, not information. The ladder is only for chips that POINT
## at information that already lives somewhere else.
##
## Law (2026-09-09 playtest): HUD popups are a TRACKER + a LINK. The how-to
## and the story body live once, in the menu the link opens (Arc, Guide, C).
## DETAIL is only for copy that does not already have a home — never a
## reprint of the postcard. Skip DETAIL (has_detail = false) on chips that
## only point at a menu.
##
## HUD map (2026-09-09):
##   HintToast          tracker + link (home → scoot). Never DETAIL — the
##                      path chip names the menu; the tap opens it.
##   ActFilament        tracker. Link only when the ask is fill/claim
##                      (Commitments). Field work is a label. No scoot.
##   ContractChip       tracker + link (C Market row → scoot). No DETAIL.
##   WelcomeOverlay     splash: identity + begin (not a ladder, not a lesson)
##   ResourcePanel      watch-only counters (not a ladder yet)
##   FpsDisplay         verb: tap pauses
##   ClockSpeedRow      verb: − / = / pause
##   ActionPreviewRow   verb: QERF
##   MenuSelectionRow   verb: open that surface
##   SelectionButtonRow verb: pick hat / biome
##   QuestBoard row     in-menu: select then act (accept/claim/deliver).
##                      not-ready / shortfall: scoot to the field puzzle.
##   Arc row            in-menu: inspect, then shunt (contract → C,
##                      verb → field). Never accept — sign-on is Accept [R].
##   TimeBar            chrome, mouse-filter IGNORE

enum Rung { FACE, DETAIL, HOME, DONE }

const TAP_FOR_MORE := "tap for more"
const TAP_FOR_HOME := "tap to open %s"
const KEY_OPENS := "[%s] opens %s"
const TAP_FOR_SCOOT := "tap to go there"
const TAP_AGAIN_HOME := "tap again to open %s"
const TAP_AGAIN_SCOOT := "tap again to go there"

var rung: int = Rung.FACE
var home_name: String = "the Arc"
## Keyboard key that opens this home. Empty = look up via key_for_home().
## Board homes resolve to C so a keyboard player can follow the chip.
var home_key: String = ""
var has_detail: bool = true
var has_home: bool = true
var has_scoot: bool = true


func reset() -> void:
	rung = Rung.FACE


func prompt() -> String:
	match rung:
		Rung.FACE:
			if has_detail:
				return TAP_FOR_MORE
			if has_home:
				return _open_cue()
			if has_scoot:
				return TAP_FOR_SCOOT
			return ""
		Rung.DETAIL:
			if has_home:
				return _open_again_cue()
			if has_scoot:
				return TAP_AGAIN_SCOOT
			return ""
		Rung.HOME:
			return TAP_AGAIN_SCOOT if has_scoot else ""
		_:
			return ""


## Keyboard-first: name the key when we know it. Mouse still clicks the chip.
func _resolved_home_key() -> String:
	if home_key != "":
		return home_key
	return key_for_home(home_name)


func _open_cue() -> String:
	var k := _resolved_home_key()
	if k != "":
		return KEY_OPENS % [k, home_name]
	return TAP_FOR_HOME % home_name


func _open_again_cue() -> String:
	var k := _resolved_home_key()
	if k != "":
		return KEY_OPENS % [k, home_name]
	return TAP_AGAIN_HOME % home_name


## Homes a keyboard player can open by one named key. Empty = mouse "tap".
static func key_for_home(name: String) -> String:
	var n := str(name).strip_edges().to_lower()
	if n == "the board" or n == "board" or n == "commitments":
		return "C"
	if n == "the arc" or n == "arc" or n == "story":
		return "X"
	return ""


## The action THIS click should fire. Call commit() after it lands.
func next_action() -> String:
	if rung == Rung.DONE:
		return "flatten"
	if rung == Rung.FACE and has_detail:
		return "expand"
	if rung == Rung.FACE or rung == Rung.DETAIL:
		if has_home:
			return "home"
		if has_scoot:
			return "scoot"
		return "flatten"
	if rung == Rung.HOME:
		return "scoot" if has_scoot else "flatten"
	return "flatten"


func commit(action: String) -> void:
	match action:
		"expand":
			rung = Rung.DETAIL
		"home":
			rung = Rung.HOME
		"scoot", "flatten":
			rung = Rung.DONE


static func tap_home(name: String, key: String = "") -> String:
	var k := key if key != "" else key_for_home(name)
	if k != "":
		return KEY_OPENS % [k, name]
	return TAP_FOR_HOME % name


static func home_prompt(name: String, key: String = "") -> String:
	var k := key if key != "" else key_for_home(name)
	if k != "":
		return KEY_OPENS % [k, name]
	return TAP_AGAIN_HOME % name
