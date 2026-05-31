extends SceneTree

## Synthetic tests for Frontmatter parser. No file I/O — all inputs inline.


var fail_count := 0


func _init() -> void:
	test_happy_path_basic()
	test_inline_list()
	test_iso_date()
	test_body_preserved()
	test_empty_body_ok()
	test_missing_opener_returns_empty()
	test_missing_closer_returns_empty()
	test_empty_input_returns_empty()
	test_quoted_string_returns_empty()
	test_multiline_indicator_returns_empty()
	if fail_count == 0:
		print("[frontmatter-test] OK — all checks passed")
		quit(0)
	else:
		printerr("[frontmatter-test] FAIL — %d failure(s)" % fail_count)
		quit(1)


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ok  %s" % label)
	else:
		printerr("  FAIL %s" % label)
		fail_count += 1


func _doc(meta_block: String, body: String = "") -> String:
	return "---\n%s---\n%s" % [meta_block, body]


func test_happy_path_basic() -> void:
	print("test_happy_path_basic")
	var text := _doc("term: cloud\nshort_def: A set of atoms.\nstatus: canonical\n")
	var r = Frontmatter.parse_text(text)
	_check("not empty",        not r.is_empty())
	_check("has meta",         r.has("meta"))
	_check("term == cloud",    r["meta"].get("term", "") == "cloud")
	_check("short_def present",r["meta"].has("short_def"))
	_check("status canonical", r["meta"].get("status", "") == "canonical")


func test_inline_list() -> void:
	print("test_inline_list")
	var text := _doc("term: icon\nrelated: [atom, cloud, sibling]\n")
	var r = Frontmatter.parse_text(text)
	var rel = r.get("meta", {}).get("related", null)
	_check("related is Array", rel is Array)
	_check("related size 3",   rel != null and (rel as Array).size() == 3)
	_check("contains atom",    rel != null and (rel as Array).has("atom"))


func test_iso_date() -> void:
	print("test_iso_date")
	var text := _doc("term: sibling\nsince: 2026-05-09\n")
	var r = Frontmatter.parse_text(text)
	_check("since present",    r.get("meta", {}).has("since"))
	_check("since value",      r.get("meta", {}).get("since", "") == "2026-05-09")


func test_body_preserved() -> void:
	print("test_body_preserved")
	var text := _doc("term: atom\n", "This is the body.\nSecond line.")
	var r = Frontmatter.parse_text(text)
	_check("body not empty",   r.get("body", "") != "")
	_check("body has 'body'",  "body" in r.get("body", ""))


func test_empty_body_ok() -> void:
	print("test_empty_body_ok")
	var text := _doc("term: atom\n")
	var r = Frontmatter.parse_text(text)
	_check("parses ok",  not r.is_empty())
	_check("body empty", r.get("body", "NONE") == "")


func test_missing_opener_returns_empty() -> void:
	print("test_missing_opener_returns_empty")
	var text := "term: cloud\nshort_def: A set of atoms.\n---\n"
	var r = Frontmatter.parse_text(text)
	_check("returns empty", r.is_empty())


func test_missing_closer_returns_empty() -> void:
	print("test_missing_closer_returns_empty")
	var text := "---\nterm: cloud\nshort_def: A set of atoms.\n"
	var r = Frontmatter.parse_text(text)
	_check("returns empty", r.is_empty())


func test_empty_input_returns_empty() -> void:
	print("test_empty_input_returns_empty")
	var r = Frontmatter.parse_text("")
	_check("returns empty", r.is_empty())


func test_quoted_string_returns_empty() -> void:
	print("test_quoted_string_returns_empty")
	var text := _doc("term: \"quoted\"\n")
	var r = Frontmatter.parse_text(text)
	_check("returns empty on quoted string", r.is_empty())


func test_multiline_indicator_returns_empty() -> void:
	print("test_multiline_indicator_returns_empty")
	var text := _doc("body: |\n")
	var r = Frontmatter.parse_text(text)
	_check("returns empty on multiline indicator", r.is_empty())
