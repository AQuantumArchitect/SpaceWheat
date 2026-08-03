extends RefCounted

## The one JSON-file → data authority (slop knot #7). ~20 loaders hand-rolled
## the open/parse/error-report idiom with drifting diagnostics; callers differ
## on required-vs-optional, so the result is an explicit envelope, never a
## silent null:
##
##   load_json(path, {context, required, root}) ->
##     {ok: bool, data: Variant, error: "", missing: bool}
##
## - context (String): prefix for push_error — the caller's class name, so
##   diagnostics keep naming their owner exactly as the hand-rolled versions
##   did ("BiomeRegistry: JSON parse error in …").
## - required (default true): a MISSING/unopenable file with required=false
##   returns {ok:false, missing:true} with NO push_error — the optional-config
##   pattern. A file that EXISTS but is malformed is always loud: silent
##   parse failures are how frozen-physics bombs happen.
## - root ("array"/"dictionary", optional): loud root-type check.

static func load_json(path: String, opts: Dictionary = {}) -> Dictionary:
	var context := str(opts.get("context", "JsonFileLoader"))
	var required := bool(opts.get("required", true))
	if not FileAccess.file_exists(path):
		if required:
			push_error("%s: Required file missing: %s" % [context, path])
		return {"ok": false, "data": null, "error": "missing", "missing": true}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		if required:
			push_error("%s: Could not open %s" % [context, path])
		return {"ok": false, "data": null, "error": "unopenable", "missing": true}
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("%s: JSON parse error in %s line %d: %s" % [
			context, path, json.get_error_line(), json.get_error_message()])
		return {"ok": false, "data": null, "error": "parse", "missing": false}
	var data = json.data
	match str(opts.get("root", "")):
		"array":
			if not (data is Array):
				push_error("%s: Expected array at root of %s" % [context, path])
				return {"ok": false, "data": data, "error": "root_type", "missing": false}
		"dictionary":
			if not (data is Dictionary):
				push_error("%s: Expected dictionary at root of %s" % [context, path])
				return {"ok": false, "data": data, "error": "root_type", "missing": false}
	return {"ok": true, "data": data, "error": "", "missing": false}
