extends RefCounted

## One creature's adaptive motion style (ADR 0051): situation in, smoothed style knobs out.
##
## Each frame the owner calls `update(dt, conditions, exposure, speed)` with the conditions under
## the
## creature (ground, weather, its own afflictions such as "drunk") and the exposure (rain, shelter,
## water, fire). The agent merges them with its body state, asks the shared network at `RATE_HZ`
## (cached, so creatures in the same situation share one evaluation), eases the result, and steps
## the
## body state with the style actually in use. Presenters read `style` (and `speed_factor()`) and
## apply
## it to a skeleton, a clip's playback or a wingbeat. Deterministic: no randomness, fixed rates.

const MotionStyleNet := preload("res://scripts/motion/motion_style_net.gd")
const MotionConditions := preload("res://scripts/motion/motion_conditions.gd")
const MotionBodyState := preload("res://scripts/motion/motion_body_state.gd")

const RATE_HZ := 4.0
const SMOOTH_SECONDS := 0.45
const G := 9.81

var kind: StringName = &"biped"
var mass := 70.0
var leg := 0.9
var airborne := false
var net: RefCounted
var registry: RefCounted
var body: RefCounted
## Current eased style {knob: value}; neutral until the first update.
var style: Dictionary = {}
## Last merged channels (surroundings + body), for debugging and presenters.
var channels: Dictionary = {}
## Seconds of body time per second of game time (1 = real time). The game may compress it.
var body_time_scale := 1.0

var _target: Dictionary = {}
var _query_in := 0.0
var _body_dt := 0.0


func _init(
	body_kind: StringName = &"biped",
	body_mass: float = 70.0,
	leg_length: float = 0.9,
	phase: float = 0.0
) -> void:
	kind = body_kind
	mass = body_mass
	leg = leg_length
	net = MotionStyleNet.shared()
	registry = MotionConditions.shared(net) if net != null else null
	body = MotionBodyState.new(body_mass)
	if net != null:
		style = net.neutral_style()
		_target = style.duplicate()
		channels = net.neutral_channels()
	# Spread queries of many creatures over the frames.
	_query_in = fposmod(phase, 1.0) / RATE_HZ


func is_ready() -> bool:
	return net != null and registry != null


func add_wound(
	region: String, side: String = "L", rate: float = 0.6, wound_pain: float = 0.5
) -> void:
	if registry != null:
		body.add_wound(region, side, rate, wound_pain, registry)


func update(
	dt: float, conditions: Array, exposure: Dictionary = {}, speed: float = 0.0
) -> Dictionary:
	if not is_ready():
		return style
	_body_dt += dt
	_query_in -= dt
	if _query_in <= 0.0:
		_query_in += 1.0 / RATE_HZ
		_tick(conditions, exposure, speed)
	var a := minf(1.0, dt / SMOOTH_SECONDS)
	for k: String in _target:
		var cur := float(style[k])
		style[k] = cur + (float(_target[k]) - cur) * a
	return style


## Channels, body state and the network's answer, at RATE_HZ.
func _tick(conditions: Array, exposure: Dictionary, speed: float) -> void:
	var env: Dictionary = registry.channels_cached(conditions)
	channels = env.duplicate()
	var own: Dictionary = body.channels()
	for k: String in own:
		if k.begins_with("pain") or k in ["wet", "fatigue", "core_cold"]:
			channels[k] = maxf(float(channels.get(k, 0.0)), float(own[k]))
		else:
			channels[k] = own[k]
	var froude := minf(speed * speed / (G * maxf(leg, 0.02)), 3.0)
	_target = net.calibrated(kind, mass, leg, airborne, froude, channels)
	var vn := speed * float(style.get("speed_frac", 1.0)) / sqrt(G * maxf(leg, 0.02))
	var power := (
		0.9 * vn * vn * (1.0 + float(channels["load"]))
		+ 0.9 * pow(float(style["crouch"]), 2) * (0.4 + vn)
		+ 0.7 * pow(float(style["width"]) - 1.0, 2)
		+ 0.25 * float(style["arm_out"])
		+ 1.6 * float(channels["sink"]) * vn
	)
	var press := maxf(float(style["press_L"]), float(style["press_R"])) if kind == &"biped" else 0.0
	body.step(_body_dt * body_time_scale, env, exposure, style, kind, airborne, power, 0.9 * press)
	_body_dt = 0.0


## Multiplier for the creature's movement speed: share of the command taken, caution, and what the
## body can still hold (blood loss, fatigue, cold, sinking feet, load).
func speed_factor(speed: float = 1.0) -> float:
	if style.is_empty():
		return 1.0
	var f := float(style["speed_frac"]) * (1.0 - 0.35 * float(style["care"]))
	var strength := (
		(1.0 - 0.65 * float(channels.get("blood_lost", 0.0)))
		* (1.0 - 0.45 * float(channels.get("fatigue", 0.0)))
		* (1.0 - 0.35 * float(channels.get("core_cold", 0.0)))
	)
	var fr_cap := (
		3.0
		* strength
		* strength
		* pow(1.0 - 0.75 * float(channels.get("sink", 0.0)), 2)
		* (1.0 - 0.4 * float(channels.get("load", 0.0)))
	)
	var v_cap := sqrt(maxf(fr_cap, 1e-4) * G * leg)
	if speed > 1e-3 and speed * f > v_cap:
		f = v_cap / speed
	return f


## Cadence multiplier for a locomotion clip: speed over stride, so a short careful step on ice plays
## the
## walk faster per metre than a long one.
func cadence_factor(speed: float = 1.0) -> float:
	var stride := float(style.get("stride", 1.0))
	return speed_factor(speed) / maxf(stride, 0.3)
