class_name FrameCostLedger
extends RefCounted

## Cumulative wall-clock ledger for named main-thread seams.
##
## Why this exists. The batcher already reports native/merge/consume/refill/poll
## as shares of wall time. Headed endgame on the 960M (2026-08-13) spent 14% of
## wall inside those seams and 86% somewhere else. The somewhere else is other
## `_process` / `_draw` work — the default 3D field, the legacy 2D force graph,
## the farm tick, the plot grid — and without a ledger those frames had no name.
##
## PerfSampler copies `totals()` into every snapshot and turns first/last
## deltas into `attribution` shares, the same way it already treats the batcher.
##
## Inert unless SW_PERF_LOG is set (or the web query `sw_perf=1`): a player's
## build pays one env/query read the first time anyone calls add_us, then every
## later add_us is a single integer compare. Do not "always-on average this".

static var _on: int = -1
static var _ms: Dictionary = {}


static func active() -> bool:
	if _on < 0:
		_on = 1 if RuntimeEnv.perf_log_path() != "" else 0
	return _on == 1


static func add_us(key: String, us: int) -> void:
	if not active() or us <= 0:
		return
	_ms[key] = float(_ms.get(key, 0.0)) + float(us) / 1000.0


static func totals() -> Dictionary:
	return _ms.duplicate()


static func reset() -> void:
	_ms.clear()
	_on = -1
