class_name MapViewRuntimeEnvironment
extends RefCounted

## Shared sky clock, calendar date, MusicDirector sync, and SessionState weather
## binding for MapViewRuntime. MapViewRuntime keeps the scene-facing API stable.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")
## WS-04: the ocean clock wraps at 64 loops of the longest baked cascade
## (25.6 s). Every cascade period divides it, so the wrap is seamless, and float
## precision never degrades over long sessions.
const OCEAN_TIME_WRAP_SECONDS := 25.6 * 64.0
const OCEAN_TIME_GLOBAL := &"ocean_time"

## One sea clock shared by the water shader (global uniform) and CPU wave queries
## (WS-05 boats). Static because only one map runtime drives the sea at a time and
## CPU readers must not depend on a scene path to the host.
static var _ocean_time := 0.0

var cycle_enabled := true
var cycle_progress := DayNightCycle.DEFAULT_PROGRESS
var cycle_elapsed_days := 0

var _host: MapViewRuntime


func configure(runtime_host: MapViewRuntime) -> void:
	_host = runtime_host


func restore_from_music_director() -> void:
	var music_director := _music_director()
	if music_director == null:
		return
	if (
		music_director.has_method(&"is_cycle_active")
		and not bool(music_director.call(&"is_cycle_active"))
	):
		return
	if not music_director.has_method(&"get_cycle_progress"):
		return
	cycle_progress = float(music_director.call(&"get_cycle_progress"))
	if music_director.has_method(&"get_cycle_elapsed_days"):
		cycle_elapsed_days = int(music_director.call(&"get_cycle_elapsed_days"))


func sync_music_cycle() -> void:
	var music_director := _music_director()
	if music_director != null:
		music_director.call("set_cycle_progress", cycle_progress)
		if music_director.has_method(&"set_cycle_elapsed_days"):
			music_director.call(&"set_cycle_elapsed_days", cycle_elapsed_days)


func advance_cycle(scaled_delta: float, calendar_date_provider: Callable) -> void:
	# The sea keeps moving when the day clock is pinned (set_time_of_day), but it
	# follows the same scaled delta, so pausing the world also freezes the waves.
	advance_ocean_time(scaled_delta)
	if not cycle_enabled:
		return
	var map_view := _map_view()
	if map_view == null:
		return
	var clock_advance := DayNightCycle.advance_clock(cycle_progress, scaled_delta)
	cycle_progress = float(clock_advance["progress"])
	var completed_days := int(clock_advance["completed_days"])
	if completed_days > 0:
		cycle_elapsed_days += completed_days
		map_view.set_calendar_date(calendar_date_provider.call())
	map_view.apply_cycle_progress(cycle_progress)
	sync_music_cycle()


static func advance_ocean_time(scaled_delta: float) -> void:
	set_ocean_time(_ocean_time + maxf(scaled_delta, 0.0))


## Publishes the wrapped clock to the `ocean_time` shader global. Tests and
## capture tools use this to hold the sea at a fixed phase.
static func set_ocean_time(seconds: float) -> void:
	_ocean_time = fposmod(seconds, OCEAN_TIME_WRAP_SECONDS)
	RenderingServer.global_shader_parameter_set(OCEAN_TIME_GLOBAL, _ocean_time)


static func ocean_time() -> float:
	return _ocean_time


func set_time_of_day(next_time: StringName) -> void:
	cycle_enabled = false
	var map_view := _map_view()
	if map_view == null:
		return
	map_view.set_time_of_day(next_time)
	cycle_progress = 0.5 if next_time == MapView3D.TIME_DAY else 0.0
	sync_music_cycle()


func on_phase_changed(next: StringName) -> void:
	cycle_elapsed_days = 0
	var map_view := _map_view()
	if map_view != null:
		map_view.set_calendar_date(GameCalendarScript.date_for_phase(next))
	var music_director := _music_director()
	if music_director != null and music_director.has_method(&"set_cycle_elapsed_days"):
		music_director.call(&"set_cycle_elapsed_days", cycle_elapsed_days)


func current_calendar_date(equipment_state: GameState) -> Dictionary:
	var base_date := GameCalendarScript.DEFAULT_DATE
	if equipment_state != null:
		base_date = GameCalendarScript.date_for_phase(equipment_state.get_phase())
	return GameCalendarScript.add_days(base_date, cycle_elapsed_days)


func bind_environment_runtime() -> void:
	if _host == null:
		return
	var session_state := _host.get_node_or_null("/root/SessionState")
	if session_state == null or not session_state.has_method(&"bind_environment_runtime"):
		apply_presentation()
		return
	session_state.call("bind_environment_runtime", _host)


func snapshot() -> Dictionary:
	var map_view := _map_view()
	if map_view == null or map_view.sky_weather() == null:
		return {}
	return map_view.sky_weather().snapshot_state(cycle_progress, cycle_elapsed_days).to_dict()


func restore_snapshot(snapshot: Dictionary) -> bool:
	var map_view := _map_view()
	if map_view == null or map_view.sky_weather() == null:
		return false
	if not bool(map_view.sky_weather().restore_state(snapshot)):
		return false
	cycle_progress = float(snapshot.get("cycle_progress", cycle_progress))
	cycle_elapsed_days = int(snapshot.get("elapsed_days", cycle_elapsed_days))
	return true


func apply_presentation() -> void:
	var map_view := _map_view()
	if map_view == null:
		return
	map_view.activate_environment_binding()
	var definition := _map_definition()
	map_view.set_weather_rain_suppressed(
		definition != null and definition.suppresses_exterior_surroundings()
	)
	map_view.apply_cycle_progress(cycle_progress)


func deactivate_binding() -> void:
	var map_view := _map_view()
	if map_view != null:
		map_view.deactivate_environment_binding()


func weather_node() -> Node:
	var map_view := _map_view()
	return map_view.sky_weather() if map_view != null else null


func _music_director() -> Node:
	if _host == null or not _host.is_inside_tree():
		return null
	return _host.get_tree().root.get_node_or_null("MusicDirector")


func _map_view() -> MapView3D:
	return _host.view if _host != null else null


func _map_definition() -> MapDefinition:
	return _host._definition if _host != null else null
