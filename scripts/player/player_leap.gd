extends RefCounted

## The hero's context-aware jump (ADR 0053, docs/SYSTEMS/LEAPING.md). `plan()` probes what lies
## ahead (ground height, wall tops, water) and asks the leap network what to do; `advance()` then
## plays the answer on the flat logic plane: a step or two to the take-off point, a crouch (or
## lowering oneself from the edge on the hands), a ballistic flight over the wall, the gap or the
## drop, and a landing that gives at the knees or rolls. Height is presentation:
## `height_above(ground)` lifts the rig, and `pose()` feeds `LeapPoseModifier` (hands on the
## obstacle, tucked legs, landing bend).
## Logic collision is off while the body is in the air: the profile already proved the way clear
## and the landing place free.

enum Phase { NONE, APPROACH, CROUCH, LOWER, FLIGHT, LAND, REFUSE }

const LeapNet := preload("res://scripts/motion/motion_leap_net.gd")
const LeapProbe := preload("res://scripts/motion/motion_leap_probe.gd")

const G := 9.81
const CROUCH_SEC := 0.18
const LOWER_SEC := 0.75
const REFUSE_SEC := 0.7
const APPROACH_SPEED := 2.6
## The hero: an 18-year-old apprentice on the shared rig.
const BODY_KIND := &"biped"
const BODY_MASS := 58.0
const BODY_LEG := 0.86
## How much the player wants across when the jump key is pressed (training covers 0..1).
const PLAYER_URGENCY := 0.9

var phase: Phase = Phase.NONE
var decision: Dictionary = {}
var elapsed := 0.0
## Logic positions (px) of the start, take-off and landing.
var start := Vector2.ZERO
var takeoff := Vector2.ZERO
var landing := Vector2.ZERO
## World heights (m): the ground under the feet at the start, the arc's start and landing.
var ground0 := 0.0
var z_start := 0.0
var z_land := 0.0
var vz := 0.0
var flight_sec := 0.0
var land_sec := 0.3
## World point (x, y, z in metres) the hands go to: the top passed over, or the edge.
var hand_point := Vector3.ZERO
var has_hand_point := false
var px_per_m := 32.0

var _y := 0.0


func is_active() -> bool:
	return phase != Phase.NONE


func is_airborne() -> bool:
	return phase in [Phase.LOWER, Phase.FLIGHT]


## Probe and decide. `ground_fn(world_xz) -> Vector2(ground_y, water_surface_y)`; `space` gives the
## wall tops (CityCollisionBuilder tags each wall with its top). Returns the decision; on "jump" the
## leap starts, on "refuse" the hero balks for a moment.
func plan(
	space: PhysicsDirectSpaceState2D,
	ground_fn: Callable,
	from_logic: Vector2,
	direction: Vector2,
	speed_mps: float,
	channels: Dictionary,
	strength: float = 1.0
) -> Dictionary:
	var net: RefCounted = LeapNet.shared()
	if net == null or direction.is_zero_approx():
		return {}
	var dir := direction.normalized()
	var probe: Dictionary = LeapProbe.profile(
		space, ground_fn, from_logic, dir, BODY_LEG, net.n_samples, net.spacing, px_per_m
	)
	decision = net.decide(
		BODY_KIND,
		BODY_MASS,
		BODY_LEG,
		speed_mps,
		strength,
		PLAYER_URGENCY,
		channels,
		probe["z"],
		probe["w"],
		probe["standable"]
	)
	decision["probe"] = probe
	start = from_logic
	ground0 = float(probe["ground0"])
	elapsed = 0.0
	if decision.get("action", "refuse") != "jump":
		phase = Phase.REFUSE
		return decision
	var kn: Dictionary = decision["knobs"]
	takeoff = from_logic + dir * float(decision["take_m"]) * px_per_m
	landing = from_logic + dir * float(decision["land_m"]) * px_per_m
	z_start = ground0 + float(decision["start_z_m"])
	z_land = ground0 + float(decision["land_z_m"])
	flight_sec = maxf(float(decision["flight_s"]), 0.12)
	vz = G * float(decision["rise_s"])
	var flex := float(kn["flex"])
	land_sec = 0.18 + 0.35 * flex
	if float(kn["roll"]) > 0.5:
		land_sec = 0.6
	_hand_target(probe, kn)
	phase = Phase.APPROACH if from_logic.distance_to(takeoff) > 2.0 else _after_approach()
	_y = ground0
	return decision


## The top of the highest thing passed over (or the landing edge for a pull-up, the take-off edge
## for a hang-drop), where the hands go.
func _hand_target(probe: Dictionary, kn: Dictionary) -> void:
	has_hand_point = false
	var pts: Array = probe["points"]
	var z: PackedFloat32Array = probe["z"]
	var cell := int(decision["cell"])
	if float(kn["lower"]) > 0.5 and float(decision["start_z_m"]) < -0.2:
		# The edge is the last sample still at the feet's height.
		var edge := 0
		for i in cell:
			if z[i] > -0.3:
				edge = i
		var p: Vector2 = pts[edge]
		hand_point = Vector3(p.x, ground0, p.y)
		has_hand_point = true
		return
	if float(kn["hands"]) < 0.3:
		return
	var best := -INF
	var best_i := cell
	for i in cell + 1:
		if float(decision["take_m"]) / BODY_LEG < (i + 1) * 0.25 and z[i] > best:
			best = z[i]
			best_i = i
	if best > 0.2:
		# The middle of the top: the hands go down where the body passes over it.
		var last := best_i
		while last + 1 <= cell and absf(z[last + 1] - best) < 0.05:
			last += 1
		var q: Vector2 = (pts[best_i] as Vector2).lerp(pts[last], 0.5)
		hand_point = Vector3(q.x, ground0 + best, q.y)
		has_hand_point = true


func _after_approach() -> Phase:
	var kn: Dictionary = decision["knobs"]
	if float(kn["lower"]) > 0.5 and float(decision["start_z_m"]) < -0.2:
		return Phase.LOWER
	return Phase.CROUCH


## Advance by `delta`; returns the logic position for this frame.
func advance(delta: float, current: Vector2) -> Vector2:
	elapsed += delta
	match phase:
		Phase.REFUSE:
			if elapsed >= REFUSE_SEC:
				_finish()
			return current
		Phase.APPROACH:
			var step := APPROACH_SPEED * px_per_m * delta
			var pos := current.move_toward(takeoff, step)
			if pos.distance_to(takeoff) < 0.5:
				_enter(_after_approach())
			return pos
		Phase.CROUCH:
			if elapsed >= CROUCH_SEC:
				_enter(Phase.FLIGHT)
			return takeoff
		Phase.LOWER:
			_y = lerpf(ground0, z_start, smoothstep(0.0, 1.0, elapsed / LOWER_SEC))
			if elapsed >= LOWER_SEC:
				_enter(Phase.FLIGHT)
			return takeoff
		Phase.FLIGHT:
			var t := minf(elapsed, flight_sec)
			_y = z_start + vz * t - 0.5 * G * t * t
			# Hands on the wall carry the body: it passes low over the top, legs tucked (the
			# network counted that support when it chose the arc).
			var w := hand_weight(t / flight_sec)
			if w > 0.0:
				# The hips pass a hand's breadth over the top; the tucked legs clear it.
				var low := hand_point.y + 0.15 - BODY_LEG
				_y = lerpf(_y, minf(_y, low), w)
			var pos := takeoff.lerp(landing, t / flight_sec)
			if elapsed >= flight_sec:
				_y = z_land
				_enter(Phase.LAND)
				return landing
			return pos
		Phase.LAND:
			_y = z_land
			if elapsed >= land_sec:
				_finish()
			return landing
	return current


## How much the hands bear on the obstacle at flight progress `u` (0 when they are not used).
func hand_weight(u: float) -> float:
	if not has_hand_point or float(decision.get("start_z_m", 0.0)) < -0.2:
		return 0.0
	var hands := float((decision.get("knobs", {}) as Dictionary).get("hands", 0.0))
	if hands < 0.3:
		return 0.0
	return minf(1.0, 1.4 * hands * smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.55, 0.8, u)))


func _enter(next: Phase) -> void:
	phase = next
	elapsed = 0.0
	if next == Phase.CROUCH or next == Phase.LOWER:
		_y = ground0


func _finish() -> void:
	phase = Phase.NONE
	elapsed = 0.0


func cancel() -> void:
	_finish()


## Height of the feet above `ground_y` (m) for the rig.
func height_above(ground_y: float) -> float:
	if phase in [Phase.LOWER, Phase.FLIGHT]:
		return _y - ground_y
	return 0.0


## Rig clip for the current phase.
func animation() -> StringName:
	match phase:
		Phase.APPROACH:
			return &"run"
		Phase.CROUCH:
			return &"jump_start"
		Phase.LOWER:
			return &"jump_air"
		Phase.FLIGHT:
			return &"jump_air"
		Phase.LAND:
			var kn: Dictionary = decision.get("knobs", {})
			return &"roll_forward" if float(kn.get("roll", 0.0)) > 0.5 else &"jump_land"
	return &"idle"


## Pose for LeapPoseModifier: phase, progress 0..1, the knobs and the hand target.
func pose() -> Dictionary:
	if phase == Phase.NONE:
		return {}
	var duration := 1.0
	match phase:
		Phase.CROUCH:
			duration = CROUCH_SEC
		Phase.LOWER:
			duration = LOWER_SEC
		Phase.FLIGHT:
			duration = flight_sec
		Phase.LAND:
			duration = land_sec
		Phase.REFUSE:
			duration = REFUSE_SEC
	return {
		"phase": phase,
		"t": clampf(elapsed / maxf(duration, 1e-3), 0.0, 1.0),
		"knobs": decision.get("knobs", {}),
		"hand_point": hand_point,
		"has_hand_point": has_hand_point,
		"hand_weight":
		hand_weight(elapsed / maxf(flight_sec, 1e-3)) if phase == Phase.FLIGHT else 0.0,
		"label": decision.get("label", ""),
	}
