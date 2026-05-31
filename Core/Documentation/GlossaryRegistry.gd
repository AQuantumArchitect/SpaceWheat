class_name GlossaryRegistry
extends RefCounted

## GlossaryRegistry — loads docs/glossary/*.md files and exposes a stable
## read API for use by the in-game Guide tab and any tooling that needs
## canonical term definitions.
##
## The canonical glossary lives at res://docs/glossary/. One file per term,
## each with YAML frontmatter. This registry is the single in-memory index.
##
## Usage:
##   var reg := GlossaryRegistry.new()
##   reg.load_all()   # returns count
##   reg.get_term("cloud")  # → {short_def, related, since, status, body}


const GLOSSARY_DIR := "res://docs/glossary"

## Required frontmatter fields (files lacking these are skipped with push_error).
const REQUIRED := ["term", "short_def"]

## Allowed status values.
const VALID_STATUS := ["canonical", "proposed"]

var _by_term: Dictionary = {}


## Load all *.md files from GLOSSARY_DIR (excluding INDEX.md). Returns count
## of successfully loaded terms. Logs validation failures via push_error.
func load_all() -> int:
	_by_term.clear()
	var dir := DirAccess.open(GLOSSARY_DIR)
	if dir == null:
		push_error("GlossaryRegistry: cannot open directory '%s'" % GLOSSARY_DIR)
		return 0
	dir.list_dir_begin()
	var paths: Array = []
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".md") and fname.to_lower() != "index.md":
			paths.append(GLOSSARY_DIR + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()

	# First pass: parse + basic validation.
	var raw_entries: Array = []
	for path in paths:
		var parsed: Dictionary = Frontmatter.parse_file(path)
		if parsed.is_empty():
			continue
		var meta: Dictionary = parsed.get("meta", {})
		var body: String = parsed.get("body", "")
		var ok := true
		for req in REQUIRED:
			if not meta.has(req) or str(meta[req]).strip_edges() == "":
				push_error("GlossaryRegistry: '%s' missing required field '%s'" % [path, req])
				ok = false
		if not ok:
			continue
		var short_def := str(meta.get("short_def", ""))
		if short_def.length() > 80:
			push_error("GlossaryRegistry: '%s' short_def exceeds 80 chars (%d)" % [path, short_def.length()])
			continue
		var term := str(meta.get("term", "")).strip_edges().to_lower()
		if term == "":
			push_error("GlossaryRegistry: '%s' term is empty after normalisation" % path)
			continue
		if _by_term.has(term):
			push_error("GlossaryRegistry: duplicate term '%s' in '%s'" % [term, path])
			continue
		var status := str(meta.get("status", "canonical"))
		if not (status in VALID_STATUS):
			push_error("GlossaryRegistry: '%s' invalid status '%s'" % [path, status])
			continue
		_by_term[term] = {
			"term":      term,
			"short_def": short_def,
			"related":   meta.get("related", []),
			"since":     str(meta.get("since", "")),
			"status":    status,
			"body":      body,
		}
		raw_entries.append(term)

	# Second pass: validate related references.
	for term in raw_entries:
		var entry: Dictionary = _by_term[term]
		var related = entry.get("related", [])
		if not (related is Array):
			continue
		for ref in (related as Array):
			if not _by_term.has(str(ref)):
				push_error("GlossaryRegistry: term '%s' related '%s' not found" % [term, ref])
				# Don't remove the term — it's still valid; just the reference is broken.

	return _by_term.size()


## Clear and reload from disk.
func reload() -> int:
	return load_all()


## Look up a term. Returns {} if not found.
func get_term(term: String) -> Dictionary:
	return _by_term.get(term.strip_edges().to_lower(), {})


## All term keys in alphabetical order.
func all_terms_sorted() -> Array:
	var keys := _by_term.keys()
	keys.sort()
	return keys


func size() -> int:
	return _by_term.size()
