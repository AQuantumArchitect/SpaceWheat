class_name BuildInfo
extends RefCounted

## SINGLE AUTHORITY for "which build am I?" — the string a player reads off the
## title screen and pastes into a bug report.
##
## Two halves, because they fail in different ways:
##
##  - `application/config/version` in project.godot is the human-facing RELEASE
##    NAME. It is hand-maintained, so it drifts: it sat at "0.9.0-beta.2" for
##    66 commits — through the whole mouse-only campaign and the 3D field work —
##    while releases/packages/ already held v1.0-rc1 and v1.0-rc2. Every bug
##    report filed in that window named a build that had not been played.
##
##  - The COMMIT STAMP cannot drift, because nobody types it. It is written by
##    scripts/build-desktop-local.sh from `git rev-parse` immediately before the
##    export and deleted immediately after, so it exists only inside a shipped
##    pack.
##
## Running from source there is no stamp, and we say "source" rather than invent
## one — an unstamped build honestly reporting that it is unstamped is the point.
## Same rule as the rest of this codebase: an instrument that cannot measure
## says so; it does not guess (#141).

const STAMP_PATH := "res://Core/Config/build_stamp.json"

static var _stamp: Dictionary = {}
static var _stamp_loaded := false

## The hand-maintained release name, e.g. "1.0-rc3".
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))

## {commit, built, branch} from the export-time stamp; empty when running from
## source. Optional by design — a missing stamp is a mode, not a failure, so
## JsonFileLoader is asked with required=false and stays silent about it.
static func stamp() -> Dictionary:
	if _stamp_loaded:
		return _stamp
	_stamp_loaded = true
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		STAMP_PATH, {"context": "BuildInfo", "required": false, "root": "dictionary"})
	_stamp = res.get("data", {}) if bool(res.get("ok", false)) else {}
	return _stamp

## True when this is a packed build carrying a commit stamp.
static func is_stamped() -> bool:
	return not stamp().is_empty()

## The one line every surface shows:
##   packed  → "v1.0-rc3 · a1b2c3d · 2026-08-12"
##   source  → "v1.0-rc3 · source"
static func display() -> String:
	var s := stamp()
	if s.is_empty():
		return "v%s · source" % version()
	return "v%s · %s · %s" % [version(), str(s.get("commit", "?")), str(s.get("built", "?"))]
