extends SceneTree

## Integration test for GlossaryRegistry — loads the real Core/Documentation/glossary/*.md
## files and asserts structural invariants.


var fail_count := 0


func _init() -> void:
	var reg := GlossaryRegistry.new()
	var count: int = reg.load_all()
	print("[glossary-test] loaded %d terms" % count)

	test_count(reg, count)
	test_term_lookup(reg)
	test_short_def_length(reg)
	test_related_references_resolve(reg)
	test_all_terms_sorted(reg)
	test_status_values(reg)
	test_core_terms_match_biome_neighborhood_model(reg)

	if fail_count == 0:
		print("[glossary-test] OK — all checks passed")
		quit(0)
	else:
		printerr("[glossary-test] FAIL — %d failure(s)" % fail_count)
		quit(1)


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ok  %s" % label)
	else:
		printerr("  FAIL %s" % label)
		fail_count += 1


## The term count is DERIVED from the shipped .md files, never frozen as a
## literal. It was pinned at 9 while the glossary grew to 29 — and because this
## test was not in scripts/run_tests.sh, it sat red and unseen (the same rot that
## killed facade_parity/principal_mode for months). Count the directory instead.
func test_count(reg: GlossaryRegistry, count: int) -> void:
	print("test_count")
	var expected := _term_file_count()
	_check("every .md term file loaded (%d)" % expected, count == expected)
	_check("size() agrees with the loader", reg.size() == expected)
	_check("glossary is not empty", expected > 0)


## Number of *.md files in GLOSSARY_DIR excluding INDEX.md — the same set
## GlossaryRegistry.load_all() walks.
func _term_file_count() -> int:
	var n := 0
	var dir := DirAccess.open(GlossaryRegistry.GLOSSARY_DIR)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".md") and fname != "INDEX.md":
			n += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return n


func test_term_lookup(reg: GlossaryRegistry) -> void:
	print("test_term_lookup")
	for term in ["atom", "biome", "cloud", "faction", "family", "icon", "neighborhood", "signature", "sibling"]:
		var entry := reg.get_term(term)
		_check("'%s' found" % term,        not entry.is_empty())
		_check("'%s' has short_def" % term, entry.has("short_def"))
	_check("unknown term returns {}", reg.get_term("nonexistent").is_empty())


func test_short_def_length(reg: GlossaryRegistry) -> void:
	print("test_short_def_length")
	for term in reg.all_terms_sorted():
		var sd := str(reg.get_term(term).get("short_def", ""))
		_check("'%s' short_def <= 80 chars (%d)" % [term, sd.length()], sd.length() <= 80)
		_check("'%s' short_def non-empty" % term, sd.length() > 0)


func test_related_references_resolve(reg: GlossaryRegistry) -> void:
	print("test_related_references_resolve")
	for term in reg.all_terms_sorted():
		var related = reg.get_term(term).get("related", [])
		if not (related is Array):
			continue
		for ref in (related as Array):
			_check("'%s' -> '%s' resolves" % [term, ref], not reg.get_term(str(ref)).is_empty())


func test_all_terms_sorted(reg: GlossaryRegistry) -> void:
	print("test_all_terms_sorted")
	var sorted: Array = reg.all_terms_sorted()
	_check("sorted length matches the loaded set", sorted.size() == reg.size())
	for i in range(1, sorted.size()):
		_check("'%s' >= '%s'" % [sorted[i], sorted[i - 1]], sorted[i] >= sorted[i - 1])


func test_status_values(reg: GlossaryRegistry) -> void:
	print("test_status_values")
	var valid := ["canonical", "proposed"]
	for term in reg.all_terms_sorted():
		var status := str(reg.get_term(term).get("status", ""))
		_check("'%s' status valid ('%s')" % [term, status], status in valid)


func test_core_terms_match_biome_neighborhood_model(reg: GlossaryRegistry) -> void:
	print("test_core_terms_match_biome_neighborhood_model")
	var biome := reg.get_term("biome")
	var signature := reg.get_term("signature")
	var neighborhood := reg.get_term("neighborhood")
	var faction := reg.get_term("faction")
	var icon := reg.get_term("icon")

	_check("biome says full dissipative scaffold", str(biome.get("short_def", "")).find("full dissipative scaffold") != -1)
	_check("biome body says full dissipative substrate", str(biome.get("body", "")).find("full dissipative substrate") != -1)
	_check("signature is the icon side", str(signature.get("short_def", "")).find("icon side") != -1)
	_check("neighborhood is biome plus induced signature", str(neighborhood.get("short_def", "")).find("induced signature") != -1)
	_check("neighborhood body says configured cluster", str(neighborhood.get("body", "")).find("configured cluster") != -1)
	_check("faction short_def says icon signature", str(faction.get("short_def", "")).find("icon signature") != -1)
	_check("faction body says owns neighborhoods", str(faction.get("body", "")).find("Owns neighborhoods") != -1)
	_check("icon short_def says neighborhood", str(icon.get("short_def", "")).find("neighborhood") != -1)
