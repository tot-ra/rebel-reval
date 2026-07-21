class_name BoatFloat3D
extends Node

## Moored fishing boats and merchant cogs ride the same world-space wave field
## as the water shader, then heel into weather wind. Authored prop anchors stay
## fixed; only the view transform bobbles so logic collision never moves.

const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

## Visual exaggeration over the water shader's tiny vertex displacement so the
## isometric camera can still read a hull floating instead of glued to glass.
const BASE_HEAVE := 0.085
const BASE_PITCH_RAD := deg_to_rad(2.4)
const BASE_ROLL_RAD := deg_to_rad(3.2)
const WIND_HEEL_RAD := deg_to_rad(5.5)
const SURGE_METERS := 0.045

var _host: Node3D
var _rest_position := Vector3.ZERO
var _rest_basis := Basis.IDENTITY
var _motion_scale := 1.0
var _phase := 0.0
var _sky: SkyWeather3D


func configure(host: Node3D, motion_scale: float, phase_seed: int) -> void:
	name = "BoatFloat"
	_host = host
	_motion_scale = motion_scale
	_phase = float(absi(phase_seed) % 6283) / 1000.0
	_rest_position = host.position
	_rest_basis = host.basis
	_sky = _find_sky_weather()


func _process(_delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if _sky == null or not is_instance_valid(_sky):
		_sky = _find_sky_weather()
	var wind := 0.28
	var rain := 0.0
	var wind_dir := Vector2(1.0, 0.35).normalized()
	if _sky != null:
		wind = _sky.wind_strength()
		rain = _sky.rain_intensity()
		wind_dir = _sky.wind_direction_xz()
	# Clear harbor chop stays gentle; storms push both heave and heel.
	var sea := lerpf(0.55, 1.45, wind) * lerpf(1.0, 1.4, rain) * _motion_scale
	var time := Time.get_ticks_msec() * 0.001 + _phase
	# Prefer world XZ so hulls crest with the water shader; fall back to local
	# pose when a headless test drives _process before the prop enters the tree.
	var world_xz := Vector2(_host.position.x, _host.position.z)
	if _host.is_inside_tree():
		world_xz = Vector2(_host.global_position.x, _host.global_position.z)
	var wave := sample_wave(world_xz, time)
	var heave := wave.x * BASE_HEAVE * sea
	var pitch := clampf(wave.y * BASE_PITCH_RAD * sea, -BASE_PITCH_RAD * 2.2, BASE_PITCH_RAD * 2.2)
	var roll := clampf(wave.z * BASE_ROLL_RAD * sea, -BASE_ROLL_RAD * 2.2, BASE_ROLL_RAD * 2.2)
	# Wind heel is applied in the hull's local frame so a rotated cog still leans
	# away from the weather rather than toward world +X.
	var local_wind := _rest_basis.inverse() * Vector3(wind_dir.x, 0.0, wind_dir.y)
	roll += local_wind.z * WIND_HEEL_RAD * wind * _motion_scale
	pitch += local_wind.x * WIND_HEEL_RAD * 0.45 * wind * _motion_scale
	var surge := Vector3(wind_dir.x, 0.0, wind_dir.y) * (sin(time * 0.55 + _phase) * SURGE_METERS * sea)
	# Convert world surge into the parent's local space (parent is usually Props).
	var parent_node := _host.get_parent() as Node3D
	if parent_node != null and parent_node.is_inside_tree():
		surge = parent_node.global_transform.basis.inverse() * surge
	_host.position = _rest_position + Vector3(surge.x, heave, surge.z)
	_host.basis = _rest_basis * Basis.from_euler(Vector3(pitch, 0.0, roll))


## Matches the water shader's primary wave trains so hulls crest with the surface
## instead of bobbing on an unrelated sine. Returns height plus X/Z slopes.
static func sample_wave(position: Vector2, time: float) -> Vector3:
	var warp := Vector2(
		_noise(position * 0.115 + Vector2(time * 0.035, -time * 0.021) + Vector2(17.2, -8.4)),
		_noise(position * 0.115 * 0.83 + Vector2(time * 0.035, -time * 0.021) + Vector2(-11.7, 23.9))
	) - Vector2(0.5, 0.5)
	warp *= 2.8
	var shape := _wave(position, Vector2(1.0, 0.28), 0.97, 0.68, 0.46, time, warp, 0.3)
	shape += _wave(position, Vector2(0.36, 1.0), 2.11, 1.03, 0.23, time, warp * 0.72, 2.1)
	var amplitude_noise := _noise(position * 0.16 + Vector2(time * 0.035, -time * 0.021) * 1.7 + Vector2(5.3, 41.2))
	return shape * lerpf(0.72, 1.22, amplitude_noise)


static func _wave(
	position: Vector2,
	direction: Vector2,
	frequency: float,
	speed: float,
	amplitude: float,
	time: float,
	warp: Vector2,
	phase_offset: float
) -> Vector3:
	var heading := direction.normalized()
	var phase := (position + warp).dot(heading) * frequency - time * speed + phase_offset
	var slope := cos(phase) * frequency * amplitude
	return Vector3(sin(phase) * amplitude, heading.x * slope, heading.y * slope)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453123, 1.0)


static func _noise(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := Vector2(p.x - i.x, p.y - i.y)
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(
		lerpf(_hash(i), _hash(i + Vector2(1.0, 0.0)), u.x),
		lerpf(_hash(i + Vector2(0.0, 1.0)), _hash(i + Vector2(1.0, 1.0)), u.x),
		u.y
	)


func _find_sky_weather() -> SkyWeather3D:
	var node: Node = _host
	while node != null:
		if node.has_method(&"sky_weather"):
			return node.call(&"sky_weather") as SkyWeather3D
		node = node.get_parent()
	return null
