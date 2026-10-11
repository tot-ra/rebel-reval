class_name MapViewRuntimeTimeFlow
extends RefCounted

## Day/night pacing controls for MapViewRuntime: speed ladder, pause state, and
## weather time-scale sync. MapViewRuntime keeps the scene-facing signal and API.

const TIME_SPEED_LADDER: Array[float] = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 20.0]
const TIME_SPEED_DEFAULT := 1.0

var time_speed := TIME_SPEED_DEFAULT
var time_paused := false

var _host: MapViewRuntime
var _changed_callback: Callable


func configure(runtime_host: MapViewRuntime, on_changed: Callable) -> void:
	_host = runtime_host
	_changed_callback = on_changed


func effective_time_speed() -> float:
	return 0.0 if time_paused else time_speed


func toggle_time_pause() -> void:
	set_time_paused(not time_paused)


func set_time_paused(paused: bool) -> void:
	if time_paused == paused:
		return
	time_paused = paused
	_notify()


func time_speed_up() -> void:
	_step_time_speed(1)


func time_speed_down() -> void:
	_step_time_speed(-1)


func set_time_speed(speed: float) -> void:
	time_speed = clampf(speed, TIME_SPEED_LADDER[0], TIME_SPEED_LADDER[-1])
	_notify()


func reset_time_flow() -> void:
	time_speed = TIME_SPEED_DEFAULT
	time_paused = false
	_notify()


func scaled_delta(delta: float) -> float:
	return delta * effective_time_speed()


func apply_weather_time_scale() -> void:
	var map_view := _map_view()
	if map_view != null:
		map_view.set_weather_time_scale(effective_time_speed())


func _step_time_speed(direction: int) -> void:
	time_paused = false
	var index := _nearest_ladder_index()
	index = clampi(index + direction, 0, TIME_SPEED_LADDER.size() - 1)
	time_speed = TIME_SPEED_LADDER[index]
	_notify()


func _nearest_ladder_index() -> int:
	var best := 0
	var best_gap := absf(TIME_SPEED_LADDER[0] - time_speed)
	for i in range(1, TIME_SPEED_LADDER.size()):
		var gap := absf(TIME_SPEED_LADDER[i] - time_speed)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


func _map_view() -> MapView3D:
	return _host.view if _host != null else null


func _notify() -> void:
	apply_weather_time_scale()
	if _changed_callback.is_valid():
		_changed_callback.call(effective_time_speed(), time_paused)
