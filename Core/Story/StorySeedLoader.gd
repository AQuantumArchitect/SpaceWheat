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
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("StorySeedLoader: %s not found" % path)
		return graph
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
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

	# Seed initial density on the first-act node ("first_breath" if present).
	var seed_id := _pick_seed(graph)
	if seed_id != "":
		graph.init_seed_density(seed_id)
	else:
		graph.init_uniform_density()
	return graph


static func _pick_seed(graph) -> String:
	# Prefer the act-0 node if any; else the first node by insertion order.
	for nid in graph.nodes.keys():
		var n = graph.nodes[nid]
		if n != null and n.act == 0:
			return nid
	if graph.nodes.is_empty():
		return ""
	return graph.nodes.keys()[0]
