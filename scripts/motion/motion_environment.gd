extends RefCounted

## The situation the world puts a creature in, for the motion style network (ADR 0051).
##
## The map view refreshes one shared snapshot per frame from the weather, the season and the time of
## day (`MotionEnvironment.update_current`); presenters then ask for the conditions at a creature's
## place and facing. Everything is a translation of simulated state into condition data, never a
## motion: rain is an exposure that wets the body over time, puddles are slippery ground, puddles
## below freezing are ice, lying snow makes feet sink, wind comes from a side relative to the body,
## a dark night hides the ground, the season's clothing warmth is the insulation.

const SeasonStateScript := preload("res://scripts/global/season_state.gd")

## Shared per-frame snapshot (set by the city map view; neutral when nothing set it).
static var _current: RefCounted

var rain := 0.0
var sheltered := false
var puddle_wetness := 0.0
var air_temp_c := 15.0
var clothing_warmth := 0.3
## Wind direction (world XZ, the way it blows) and strength 0..1.
var wind_dir := Vector2.ZERO
var wind_strength := 0.0
var darkness := 0.0
var snow_cover := 0.0
## Callable(world_xz: Vector2) -> float snow depth in metres; empty: no snow lookup.
var snow_depth_at: Callable


static func current() -> RefCounted:
	if _current == null:
		_current = new()
	return _current


static func set_current(env: RefCounted) -> void:
	_current = env


## Refresh the shared snapshot from the city's weather and season state.
static func update_current(
	weather: Object,
	presentation: Object,
	date: Dictionary,
	day_blend: float,
	snow_cover_value: float,
	depth_lookup: Callable
) -> void:
	var env := current()
	env.rain = float(presentation.get(&"rain_intensity")) if presentation != null else 0.0
	env.sheltered = bool(weather.get(&"rain_suppressed")) if weather != null else false
	env.puddle_wetness = float(presentation.get(&"puddle_wetness")) if presentation != null else 0.0
	if not date.is_empty():
		var doy := SeasonStateScript.day_of_year_for(date)
		env.air_temp_c = SeasonStateScript.mean_temperature_c(doy)
		env.clothing_warmth = SeasonStateScript.clothing_warmth(doy)
	if presentation != null:
		var d: Variant = presentation.get(&"wind_direction")
		env.wind_dir = (d as Vector2) if d is Vector2 else Vector2.ZERO
		env.wind_strength = clampf(float(presentation.get(&"wind_strength")), 0.0, 1.0)
	env.darkness = clampf(1.0 - day_blend, 0.0, 1.0)
	env.snow_cover = snow_cover_value
	env.snow_depth_at = depth_lookup


## Conditions for a creature at `world_xz` facing `facing_xz` (world XZ). `insulation` is the body's
## own (clothing for people, fur or plumage for animals); -1 uses the season's clothing.
func conditions_at(world_xz: Vector2, facing_xz: Vector2, insulation: float = -1.0) -> Array:
	var out: Array = []
	var depth := 0.0
	if snow_cover > 0.001 and snow_depth_at.is_valid():
		depth = float(snow_depth_at.call(world_xz))
	if depth > 0.02:
		out.append([&"deep_snow", clampf(depth / 0.3, 0.2, 1.0)])
	elif air_temp_c < -0.5 and puddle_wetness > 0.05:
		out.append([&"ice", clampf(puddle_wetness * 1.5, 0.2, 1.0)])
	elif snow_cover > 0.2:
		out.append([&"packed_snow", clampf(snow_cover, 0.0, 1.0)])
	elif puddle_wetness > 0.05 or rain > 0.05:
		out.append([&"wet_cobbles", clampf(maxf(puddle_wetness, rain), 0.0, 1.0)])
	if (
		wind_strength > 0.05
		and not sheltered
		and not wind_dir.is_zero_approx()
		and not facing_xz.is_zero_approx()
	):
		# The wind comes from -wind_dir; express that bearing relative to the body (+ = from the
		# left).
		var f := facing_xz.normalized()
		var from := -wind_dir.normalized()
		var left := Vector2(f.y, -f.x)
		out.append([&"gale", wind_strength, {"dir": atan2(from.dot(left), from.dot(f))}])
	if darkness > 0.3:
		out.append([&"night", clampf((darkness - 0.3) / 0.6, 0.0, 1.0)])
	# Measured values last, so the season's temperature wins over a condition's typical one.
	var warm := 0.2 + 0.65 * clothing_warmth if insulation < 0.0 else insulation
	out.append({"air_temp": air_temp_c, "insulation": warm})
	return out


func exposure() -> Dictionary:
	return {"rain": 0.0 if sheltered else rain, "shelter": 1.0 if sheltered else 0.0}
