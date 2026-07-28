class_name CandleLight3D
extends Node

## Warm local fill for candle props. Stronger after dusk so interiors stay
## readable when window daylight fades, with restrained uneven flicker from the
## same runtime effect that renders the animated flame.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const DEFAULT_PROFILE := {
	"color": Color8(255, 196, 112),
	"day_energy": 0.18,
	"night_energy": 1.35,
	"range": 3.2,
}

var _light: OmniLight3D
var _flame: GPUParticles3D
var _light_color: Color = DEFAULT_PROFILE["color"]
var _day_energy := float(DEFAULT_PROFILE["day_energy"])
var _night_energy := float(DEFAULT_PROFILE["night_energy"])
var _base_energy := float(DEFAULT_PROFILE["day_energy"])
var _time := 0.0
var _phase := 0.0


func configure(light: OmniLight3D, flame: GPUParticles3D, profile: Dictionary = {}) -> void:
	name = "CandleLight"
	_light = light
	_flame = flame
	_light_color = profile.get("color", DEFAULT_PROFILE["color"])
	_day_energy = float(profile.get("day_energy", DEFAULT_PROFILE["day_energy"]))
	_night_energy = float(profile.get("night_energy", DEFAULT_PROFILE["night_energy"]))
	_base_energy = _day_energy
	_phase = float(profile.get("flicker_phase", 0.0))
	_light.light_color = _light_color
	_light.light_energy = _base_energy
	_light.omni_range = float(profile.get("range", DEFAULT_PROFILE["range"]))
	_light.shadow_enabled = false


func _process(delta: float) -> void:
	_time += delta
	if _light == null:
		return
	var flicker := 1.0 \
		+ 0.075 * sin(_time * 8.7 + _phase) \
		+ 0.045 * sin(_time * 15.9 + _phase * 1.8) \
		+ 0.025 * sin(_time * 27.3 + 0.7)
	_light.light_energy = _base_energy * flicker
	if _flame != null:
		# A slight lateral sway complements particle drift without moving the wick
		# anchor or the light itself.
		_flame.rotation.z = 0.025 * sin(_time * 6.4 + _phase)


func apply_cycle_progress(progress: float) -> void:
	if _light == null:
		return
	var night := 1.0 - DayNightCycle.day_blend(progress)
	_base_energy = lerpf(_day_energy, _night_energy, night)
	_light.light_energy = _base_energy
