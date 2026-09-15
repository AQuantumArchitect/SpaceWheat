extends RefCounted

## Reads story_flags.json and synthesizes a StoryGraph.
##
## Predicate edges: for each flag b that lists `{type:"story_flag_set", id:a}`
## as a predicate, we add a → b. The substrate version of the dependency.
##
## Action edges: for each node, we synthesize a few "action slots" so the
## player has something to operate on with QERF. In the golden cut these
## slots loop back to self — content authoring
## adds real outgoing action edges later.

const StoryGraph := preload("res://Core/Story/StoryGraph.gd")
const StoryNode := preload("res://Core/Story/StoryNode.gd")
const StoryEdge := preload("res://Core/Story/StoryEdge.gd")

const FLAGS_PATH := "res://Core/Quests/data/story_flags.json"


static func load_default():
	return load_from_file(FLAGS_PATH)


static func load_from_file(path: String):
	var graph = StoryGraph.new()
	# One JSON-load authority (slop knot #7); a missing file keeps the old
	# warning, malformed files are loud via the loader.
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		path, {"context": "StorySeedLoader", "required": false})
	if res.missing:
		push_warning("StorySeedLoader: %s not found" % path)
		return graph
	if not res.ok:
		return graph
	var parsed = res.data
	if not (parsed is Array):
		push_warning("StorySeedLoader: root not Array in %s" % path)
		return graph

	# Pass 1: nodes
	for flag in parsed:
		if not (flag is Dictionary):
			continue
		graph.add_node(StoryNode.from_flag(flag))

	# Pass 2: predicate edges (a → b when b's predicates name a)
	for flag in parsed:
		if not (flag is Dictionary):
			continue
		var to_id := str(flag.get("id", ""))
		for pred in flag.get("predicates", []):
			if not (pred is Dictionary):
				continue
			if str(pred.get("type", "")) == "story_flag_set":
				var from_id := str(pred.get("id", ""))
				if from_id == "" or to_id == "" or from_id == to_id:
					continue
				if not graph.nodes.has(from_id):
					continue
				graph.add_edge(StoryEdge.make_predicate_edge(from_id, to_id))

	# Seed initial density on the first-act node ("first_harvest" if present).
	var seed_id := _pick_seed(graph)
	if seed_id != "":
		graph.init_seed_density(seed_id)
	else:
		graph.init_uniform_density()
	return graph


static func _pick_seed(graph) -> String:
	# Prefer an act-0 node that is NOT the reap capstone. Seeding
	# first_harvest made the Story lens say Harvest while the banner said
	# strike. loom_opens is the first act-0 recognition that isn't the end
	# of the tutorial.
	var fallback := ""
	for nid in graph.nodes.keys():
		var n = graph.nodes[nid]
		if n == null or n.act != 0:
			continue
		if str(nid) == "first_harvest":
			if fallback == "":
				fallback = nid
			continue
		return nid
	if fallback != "":
		return fallback
	if graph.nodes.is_empty():
		return ""
	return graph.nodes.keys()[0]
