extends RefCounted

## CPU scope timers for the performance overlay (PerfMonitor, docs/SYSTEMS/PERFORMANCE_MONITOR.md).
## Systems wrap their per-frame work in `start()` / `stop(&"name", t)`. While the overlay is
## closed `start()` returns 0 and `stop()` returns at once, so shipped builds pay one static
## read per scope. Load with `preload`, not `class_name` (new class names need an editor pass).

static var enabled := false
static var _usec: Dictionary = {}


static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func stop(scope: StringName, started: int) -> void:
	if started == 0:
		return
	_usec[scope] = int(_usec.get(scope, 0)) + Time.get_ticks_usec() - started


## Microseconds spent per scope since the last call; resets the counters.
static func take_frame() -> Dictionary:
	var out := _usec
	_usec = {}
	return out
