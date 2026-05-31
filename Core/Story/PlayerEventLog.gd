extends Node

## Ring-buffer log of player-facing events. Autoloaded as PlayerEventLog.
## Importance levels: 0=silent, 1=log-only, 2=toast-teal, 3=toast-gold.

signal event_added(entry: Dictionary)

const MAX_EVENTS := 100

var _log: Array[Dictionary] = []


func push(message: String, importance: int = 1, icon: String = "", category: String = "", path: String = "") -> void:
	var entry := {
		"message": message,
		"importance": importance,
		"icon": icon,
		"category": category,
		"path": path,
		"timestamp": Time.get_ticks_msec()
	}
	_log.append(entry)
	if _log.size() > MAX_EVENTS:
		_log.pop_front()
	event_added.emit(entry)


func get_recent(n: int = 20, min_importance: int = 0) -> Array:
	var out: Array = []
	for i in range(_log.size() - 1, -1, -1):
		if _log[i]["importance"] >= min_importance:
			out.append(_log[i])
		if out.size() >= n:
			break
	return out


func clear() -> void:
	_log.clear()
