class_name SkyWeatherState
extends RefCounted

## Versioned, scene-tree-free state shared by exterior map presenters.
##
## This is the persistence boundary for sky/weather continuity. It deliberately
## contains simulation inputs and deterministic accumulators, but never renderer
## objects such as Environment, Sky, Camera3D, particles, or audio players.

const SelfScript := preload("res://scripts/map/view3d/sky_weather_state.gd")
const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")
const DayNightCycleScript := preload("res://scripts/global/day_night_cycle.gd")

const CURRENT_VERSION := 1
const DEFAULT_WEATHER := &"clear"
const WEATHER_CLEAR := &"clear"
const WEATHER_CLOUDY := &"cloudy"
const WEATHER_OVERCAST := &"overcast"
const WEATHER_RAIN := &"rain"
const WEATHER_STORM := &"storm"
const WEATHER_MODES: Array[StringName] = [
	WEATHER_CLEAR, WEATHER_CLOUDY, WEATHER_OVERCAST, WEATHER_RAIN, WEATHER_STORM
]
const DEFAULT_TIME_SCALE := 1.0
const MIN_TIME_SCALE := 0.0
const MAX_TIME_SCALE := 20.0
const DEFAULT_CYCLE_PROGRESS := DayNightCycleScript.DEFAULT_PROGRESS
const LAST_RAIN_NEVER := -1.0
const PROFILE_FIELDS: Array[StringName] = [
	&"coverage",
	&"darken",
	&"sun_energy",
	&"ambient_energy",
	&"gray",
	&"rain",
	&"wind",
	&"chaos",
	&"storm",
	&"locality",
	&"thunder",
]

var schema_version: int = CURRENT_VERSION
var weather: StringName = DEFAULT_WEATHER
var transition_from_weather: StringName = DEFAULT_WEATHER
var transition_progress := 1.0
var time_in_state := 0.0
var state_duration := 60.0
var auto_weather := true
var time_scale := DEFAULT_TIME_SCALE
var rain_suppressed := false
var calendar_date: Dictionary = GameCalendarScript.DEFAULT_DATE.duplicate()
var cycle_progress := DEFAULT_CYCLE_PROGRESS
var elapsed_days := 0
var cloud_offset := Vector2.ZERO
var cloud_detail_offset := Vector2.ZERO
var puddle_wetness := 0.0
var seconds_since_rain := LAST_RAIN_NEVER
var gust := 0.0
var gust_time := -1.0
var lightning := 0.0
var lightning_direction := Vector2(1.0, 0.0)
var lightning_time := -1.0
var time_to_strike := 0.0
var weather_rng_state := -1
var lightning_rng_state := -1
## Profiles are copied so a transition can resume exactly after a map swap.
var current_profile: Dictionary = {}
var transition_from_profile: Dictionary = {}


static func default_state() -> SkyWeatherState:
	return SelfScript.new()


func duplicate_state() -> SkyWeatherState:
	return SelfScript.from_dict(to_dict())


## Clamps user/save input while preserving a future schema version for rejection.
func normalize() -> void:
	if not WEATHER_MODES.has(weather):
		weather = DEFAULT_WEATHER
	if not WEATHER_MODES.has(transition_from_weather):
		transition_from_weather = weather
	transition_progress = clampf(transition_progress, 0.0, 1.0)
	time_in_state = maxf(time_in_state, 0.0)
	state_duration = maxf(state_duration, 0.001)
	time_scale = clampf(time_scale, MIN_TIME_SCALE, MAX_TIME_SCALE)
	calendar_date = GameCalendarScript.normalize_date(calendar_date)
	cycle_progress = wrapf(cycle_progress, 0.0, 1.0)
	elapsed_days = maxi(elapsed_days, 0)
	puddle_wetness = clampf(puddle_wetness, 0.0, 1.0)
	seconds_since_rain = maxf(seconds_since_rain, LAST_RAIN_NEVER)
	gust = clampf(gust, 0.0, 1.0)
	lightning = clampf(lightning, 0.0, 1.0)
	if lightning_direction.length_squared() < 0.000001:
		lightning_direction = Vector2.RIGHT
	else:
		lightning_direction = lightning_direction.normalized()
	_normalize_profile(current_profile)
	_normalize_profile(transition_from_profile)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if schema_version != CURRENT_VERSION:
		errors.append(
			"unsupported sky/weather state version %d (expected %d)"
			% [schema_version, CURRENT_VERSION]
		)
	if not WEATHER_MODES.has(weather):
		errors.append("weather must be one of the shared weather modes")
	if not WEATHER_MODES.has(transition_from_weather):
		errors.append("transition_from_weather must be one of the shared weather modes")
	if transition_progress < 0.0 or transition_progress > 1.0:
		errors.append("transition_progress must be in the 0..1 range")
	if time_scale < MIN_TIME_SCALE or time_scale > MAX_TIME_SCALE:
		errors.append("time_scale must be in the 0..20 range")
	if cycle_progress < 0.0 or cycle_progress >= 1.0:
		errors.append("cycle_progress must be in the wrapped 0..1 range")
	if puddle_wetness < 0.0 or puddle_wetness > 1.0:
		errors.append("puddle_wetness must be in the 0..1 range")
	for profile_name in [&"current_profile", &"transition_from_profile"]:
		var profile: Dictionary = (
			current_profile if profile_name == &"current_profile" else transition_from_profile
		)
		for field in PROFILE_FIELDS:
			if profile.has(field) and not is_finite(float(profile[field])):
				errors.append("%s.%s must be finite" % [profile_name, field])
	return errors


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"weather": String(weather),
		"transition_from_weather": String(transition_from_weather),
		"transition_progress": transition_progress,
		"time_in_state": time_in_state,
		"state_duration": state_duration,
		"auto_weather": auto_weather,
		"time_scale": time_scale,
		"rain_suppressed": rain_suppressed,
		"calendar_date": calendar_date.duplicate(true),
		"cycle_progress": cycle_progress,
		"elapsed_days": elapsed_days,
		"cloud_offset": _vector_to_array(cloud_offset),
		"cloud_detail_offset": _vector_to_array(cloud_detail_offset),
		"puddle_wetness": puddle_wetness,
		"seconds_since_rain": seconds_since_rain,
		"gust": gust,
		"gust_time": gust_time,
		"lightning": lightning,
		"lightning_direction": _vector_to_array(lightning_direction),
		"lightning_time": lightning_time,
		"time_to_strike": time_to_strike,
		# JSON numbers are IEEE-754 doubles in the save path and cannot carry a
		# full 64-bit RNG state. Strings keep deterministic map transitions exact.
		"weather_rng_state": str(weather_rng_state),
		"lightning_rng_state": str(lightning_rng_state),
		"current_profile": current_profile.duplicate(true),
		"transition_from_profile": transition_from_profile.duplicate(true),
	}


static func from_dict(data: Dictionary) -> SkyWeatherState:
	var state := SelfScript.new()
	state.schema_version = int(data.get("schema_version", CURRENT_VERSION))
	state.weather = StringName(data.get("weather", DEFAULT_WEATHER))
	state.transition_from_weather = StringName(
		data.get("transition_from_weather", state.weather)
	)
	state.transition_progress = float(data.get("transition_progress", 1.0))
	state.time_in_state = float(data.get("time_in_state", 0.0))
	state.state_duration = float(data.get("state_duration", 60.0))
	state.auto_weather = bool(data.get("auto_weather", true))
	state.time_scale = float(data.get("time_scale", DEFAULT_TIME_SCALE))
	state.rain_suppressed = bool(data.get("rain_suppressed", false))
	var raw_date: Variant = data.get("calendar_date", GameCalendarScript.DEFAULT_DATE)
	if raw_date is Dictionary:
		state.calendar_date = raw_date.duplicate(true)
	else:
		state.calendar_date = GameCalendarScript.DEFAULT_DATE.duplicate()
	state.cycle_progress = float(data.get("cycle_progress", DEFAULT_CYCLE_PROGRESS))
	state.elapsed_days = int(data.get("elapsed_days", 0))
	state.cloud_offset = _vector_from_value(data.get("cloud_offset", []), Vector2.ZERO)
	state.cloud_detail_offset = _vector_from_value(data.get("cloud_detail_offset", []), Vector2.ZERO)
	state.puddle_wetness = float(data.get("puddle_wetness", 0.0))
	state.seconds_since_rain = float(data.get("seconds_since_rain", LAST_RAIN_NEVER))
	state.gust = float(data.get("gust", 0.0))
	state.gust_time = float(data.get("gust_time", -1.0))
	state.lightning = float(data.get("lightning", 0.0))
	state.lightning_direction = _vector_from_value(
		data.get("lightning_direction", [1.0, 0.0]), Vector2.RIGHT
	)
	state.lightning_time = float(data.get("lightning_time", -1.0))
	state.time_to_strike = float(data.get("time_to_strike", 0.0))
	state.weather_rng_state = _int_from_value(data.get("weather_rng_state", "-1"))
	state.lightning_rng_state = _int_from_value(data.get("lightning_rng_state", "-1"))
	var raw_current: Variant = data.get("current_profile", {})
	var raw_from: Variant = data.get("transition_from_profile", {})
	state.current_profile = raw_current.duplicate(true) if raw_current is Dictionary else {}
	state.transition_from_profile = raw_from.duplicate(true) if raw_from is Dictionary else {}
	state.normalize()
	return state


func _normalize_profile(profile: Dictionary) -> void:
	for field in PROFILE_FIELDS:
		if profile.has(field):
			profile[field] = float(profile[field])


static func _int_from_value(value: Variant) -> int:
	if value is String:
		return int(value)
	return int(value)


static func _vector_to_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]


static func _vector_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
