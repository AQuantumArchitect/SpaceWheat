class_name Frontmatter
extends RefCounted

## Frontmatter — line-based YAML-frontmatter scanner for Markdown files.
##
## Scope-locked: handles only the four field shapes used by the glossary.
## NOT a general YAML parser — multiline values, anchors, nested dicts etc.
## are not supported and will be flagged via push_error.
##
## Recognized value shapes:
##   bare string:   key: hello world
##   ISO date:      key: 2026-05-09
##   inline list:   key: [a, b, c]
##
## Returns {"meta": Dictionary, "body": String} or {} on parse failure.
##
## All methods are static so the class can be used without instantiation.


## Parse a file at `path`. File must exist and be UTF-8 text.
static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Frontmatter: cannot open '%s'" % path)
		return {}
	var text := f.get_as_text()
	f.close()
	return parse_text(text)


## Parse raw text. `path` is optional (used only in error messages).
static func parse_text(text: String, path: String = "<text>") -> Dictionary:
	if text.strip_edges() == "":
		push_error("Frontmatter(%s): empty input" % path)
		return {}

	var lines := text.split("\n")
	# First non-empty line must be "---"
	var start := _find_opener(lines)
	if start < 0:
		push_error("Frontmatter(%s): missing opening '---'" % path)
		return {}

	var closer := _find_closer(lines, start + 1)
	if closer < 0:
		push_error("Frontmatter(%s): missing closing '---'" % path)
		return {}

	var meta := {}
	for i in range(start + 1, closer):
		var line := lines[i]
		if line.strip_edges() == "":
			continue
		var parsed := _parse_line(line, path)
		if parsed.is_empty():
			return {}
		meta[parsed["key"]] = parsed["value"]

	# Everything after the closing --- is the body.
	var body_lines: Array = []
	for i in range(closer + 1, lines.size()):
		body_lines.append(lines[i])
	var body := "\n".join(body_lines).strip_edges()

	return {"meta": meta, "body": body}


## ── Internal helpers ────────────────────────────────────────────────────────

static func _find_opener(lines: PackedStringArray) -> int:
	for i in range(lines.size()):
		var l := lines[i].strip_edges()
		if l == "---":
			return i
		if l != "":
			return -1  # Non-empty non-dashes before opener
	return -1


static func _find_closer(lines: PackedStringArray, from: int) -> int:
	for i in range(from, lines.size()):
		if lines[i].strip_edges() == "---":
			return i
	return -1


## Parse "key: value" line. Returns {"key": String, "value": Variant} or {}.
static func _parse_line(line: String, path: String) -> Dictionary:
	var colon := line.find(":")
	if colon < 0:
		push_error("Frontmatter(%s): line has no ':': '%s'" % [path, line])
		return {}
	var key := line.left(colon).strip_edges()
	if key == "":
		push_error("Frontmatter(%s): empty key in line: '%s'" % [path, line])
		return {}
	var raw := line.substr(colon + 1).strip_edges()
	var value = _parse_value(raw, path)
	if value == null:
		return {}
	return {"key": key, "value": value}


## Recognise and parse a value string. Returns null on unrecognised shape.
static func _parse_value(raw: String, path: String) -> Variant:
	if raw == "":
		return ""

	# Inline list: [a, b, c]
	if raw.begins_with("[") and raw.ends_with("]"):
		var inner := raw.substr(1, raw.length() - 2)
		var parts: Array = []
		for part in inner.split(","):
			var s := part.strip_edges()
			if s != "":
				parts.append(s)
		return parts

	# Detect unsupported quoted strings
	if raw.begins_with("\"") or raw.begins_with("'"):
		push_error("Frontmatter(%s): quoted strings not supported: '%s'" % [path, raw])
		return null

	# Detect unsupported multiline value indicator
	if raw == "|" or raw == ">":
		push_error("Frontmatter(%s): multiline values not supported: '%s'" % [path, raw])
		return null

	# ISO date: YYYY-MM-DD
	if _is_iso_date(raw):
		return raw  # Keep as string; callers can parse if needed.

	# Bare string (including simple enums like "canonical")
	return raw


static func _is_iso_date(s: String) -> bool:
	if s.length() != 10:
		return false
	return s[4] == "-" and s[7] == "-" \
		and s.substr(0, 4).is_valid_int() \
		and s.substr(5, 2).is_valid_int() \
		and s.substr(8, 2).is_valid_int()
