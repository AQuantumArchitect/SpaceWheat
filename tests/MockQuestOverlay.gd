extends Control

var pair_scope_history: Array = []
var clear_calls: int = 0


func activate() -> void:
	pass


func set_pair_scope(name_a: String, name_b: String) -> void:
	pair_scope_history.append([name_a, name_b])


func clear_pair_scope() -> void:
	clear_calls += 1
