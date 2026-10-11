class_name WindField
extends RefCounted

## R-1321 (VEGR-2): one deterministic wind field for everything that moves.
##
## The weather presentation (direction + strength) maps to a small set of
## global shader parameters (`wind_*_g`, declared in project.godot
## [shader_globals] and read through scripts/map/view3d/wind_field.gdshaderinc).
## MapViewWindMaterials.apply_world_wind is the only caller of publish(), so a
## gust front is one event across grass, crowns, flags, ropes and nets.
##
## The field is a pure function of world XZ, time and the weather snapshot: no
## RNG, no stored simulation state. The static functions below mirror the
## shader include line for line so tests and CPU consumers (leaf fall) sample
## the same gusts the GPU draws.

const DEFAULT_DIRECTION := Vector2(0.9285, 0.3714)
const DEFAULT_STRENGTH := 0.22
## Godot wraps the shader TIME built-in at rendering/limits/time/time_rollover_secs.
const TIME_ROLLOVER_SECONDS := 3600.0

const GLOBAL_DIRECTION := &"wind_dir_g"
const GLOBAL_STRENGTH := &"wind_strength_g"
const GLOBAL_GUST_AMP := &"wind_gust_amp_g"
const GLOBAL_WAVELENGTH := &"wind_gust_wavelength_g"
const GLOBAL_SPEED := &"wind_speed_g"
const GLOBAL_TURBULENCE := &"wind_turbulence_g"


## Shader-facing wind parameters for one weather snapshot.
class Params extends RefCounted:
	var direction := DEFAULT_DIRECTION
	var strength := DEFAULT_STRENGTH
	## Height of a gust above the steady push (0.12 calm .. 1.0 at full storm).
	var gust_amplitude := 0.0
	## Distance between gust fronts in metres; storms carry longer fronts.
	var gust_wavelength := 0.0
	## Front speed in metres per second along `direction`.
	var front_speed := 0.0
	## 0..1 flutter / cross-wind chaos.
	var turbulence := 0.0

	func to_dict() -> Dictionary:
		return {
			"direction": direction,
			"strength": strength,
			"gust_amplitude": gust_amplitude,
			"gust_wavelength": gust_wavelength,
			"front_speed": front_speed,
			"turbulence": turbulence,
		}


static var _current: Params = params_for(DEFAULT_DIRECTION, DEFAULT_STRENGTH)


## Weather mapping. Calm air keeps small, slow, short fronts so the wave nearly
## stops; a storm raises amplitude, front length and speed, and turbulence.
static func params_for(direction: Vector2, strength: float) -> Params:
	var params := Params.new()
	params.direction = (
		DEFAULT_DIRECTION if direction.length_squared() < 0.0001 else direction.normalized()
	)
	var s := clampf(strength, 0.0, 1.0)
	params.strength = s
	params.gust_amplitude = 0.12 + 0.88 * sqrt(s)
	params.gust_wavelength = lerpf(14.0, 34.0, s)
	params.front_speed = lerpf(2.0, 11.0, s)
	params.turbulence = clampf(0.15 + 0.85 * s * s, 0.0, 1.0)
	return params


## Pushes one snapshot to every shader at once. Global shader parameters are a
## renderer-wide write, so this costs the same with one or a thousand materials.
static func publish(params: Params) -> void:
	_current = params
	RenderingServer.global_shader_parameter_set(GLOBAL_DIRECTION, params.direction)
	RenderingServer.global_shader_parameter_set(GLOBAL_STRENGTH, params.strength)
	RenderingServer.global_shader_parameter_set(GLOBAL_GUST_AMP, params.gust_amplitude)
	RenderingServer.global_shader_parameter_set(GLOBAL_WAVELENGTH, params.gust_wavelength)
	RenderingServer.global_shader_parameter_set(GLOBAL_SPEED, params.front_speed)
	RenderingServer.global_shader_parameter_set(GLOBAL_TURBULENCE, params.turbulence)


## Last published snapshot (`global_shader_parameter_get` is editor-only).
static func current() -> Params:
	return _current


## Wall-clock seconds matching the shader TIME built-in closely enough for
## presentation-only CPU consumers. Tests pass explicit times instead.
static func clock() -> float:
	return fposmod(Time.get_ticks_msec() * 0.001, TIME_ROLLOVER_SECONDS)


# --- CPU mirror of wind_field.gdshaderinc ----------------------------------


static func _cell_hash(cell: Vector2) -> float:
	var c := Vector2(fposmod(cell.x, 289.0), fposmod(cell.y, 289.0))
	var v := sin(c.dot(Vector2(127.1, 311.7))) * 43758.5453
	return v - floorf(v)


static func _value_noise(p: Vector2) -> float:
	var cell := p.floor()
	var f := p - cell
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _cell_hash(cell)
	var b := _cell_hash(cell + Vector2(1.0, 0.0))
	var c := _cell_hash(cell + Vector2(0.0, 1.0))
	var d := _cell_hash(cell + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)


## Gust front intensity at `xz` and `time` (0 in a lull, about 1.2 at a crest).
static func gust(xz: Vector2, time: float, params: Params = null) -> float:
	var p := params if params != null else _current
	var d := p.direction
	var across := Vector2(-d.y, d.x)
	var wavelength := maxf(p.gust_wavelength, 1.0)
	var along := xz.dot(d) - time * p.front_speed
	var side := xz.dot(across)
	var broad := 0.5 + 0.5 * sin(along * TAU / wavelength + 0.6 * sin(side * TAU / (wavelength * 2.3)))
	var narrow := 0.5 + 0.5 * sin(along * TAU / (wavelength * 0.37) + 1.7)
	var patch := _value_noise(Vector2(along, side) / (wavelength * 1.5))
	var front := broad * broad * broad * lerpf(0.55, 1.25, patch)
	return clampf(front * 0.78 + narrow * narrow * 0.22, 0.0, 1.25)


## Front without patch noise, as tree crowns sample it (wind_gust_coarse).
static func gust_coarse(xz: Vector2, time: float, params: Params = null) -> float:
	var p := params if params != null else _current
	var d := p.direction
	var wavelength := maxf(p.gust_wavelength, 1.0)
	var along := xz.dot(d) - time * p.front_speed
	var side := xz.dot(Vector2(-d.y, d.x))
	var broad := 0.5 + 0.5 * sin(along * TAU / wavelength + 0.6 * sin(side * TAU / (wavelength * 2.3)))
	var narrow := 0.5 + 0.5 * sin(along * TAU / (wavelength * 0.37) + 1.7)
	return clampf(broad * broad * broad * 0.9 * 0.78 + narrow * narrow * 0.22, 0.0, 1.25)


## Downwind push factor; multiply by strength for a displacement scale.
static func pressure(xz: Vector2, time: float, params: Params = null) -> float:
	var p := params if params != null else _current
	return 0.48 + p.gust_amplitude * 2.0 * gust(xz, time, p)


## Effective local wind 0..1 (strength times the local gust), for CPU drift.
static func local_strength(xz: Vector2, time: float, params: Params = null) -> float:
	var p := params if params != null else _current
	return clampf(p.strength * pressure(xz, time, p) / 0.8, 0.0, 1.0)


static func flutter_scale(params: Params = null) -> float:
	var p := params if params != null else _current
	return 0.8 + 1.05 * p.turbulence
