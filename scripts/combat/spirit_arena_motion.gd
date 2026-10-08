class_name SpiritArenaMotion
extends RefCounted
## Real-time positions inside a SpiritArena3D (ADR 0038, SA3D-2). The opponent circles,
## advances or retreats by the move kind of the line it speaks; an incoming blow locks a strike
## zone on the floor (an arc in front of the opponent for an attack, a circle where the hero
## stood for pressure and feints). At impact SpiritDuel asks hit_check(): out of the zone is a
## dodge, and a raised guard counts only while the hero faces the opponent.
## Deterministic: no randomness, positions advance only through step(delta).

const BEHAVIOUR_HOLD := &"hold"
const BEHAVIOUR_ADVANCE := &"advance"
const BEHAVIOUR_RETREAT := &"retreat"
const BEHAVIOUR_CIRCLE := &"circle"
## Opponent footwork per move kind of its current line (no move or an unknown kind circles).
const BEHAVIOUR_BY_KIND: Dictionary = {
	&"attack": BEHAVIOUR_ADVANCE,
	&"pressure": BEHAVIOUR_ADVANCE,
	&"feint": BEHAVIOUR_CIRCLE,
	&"defense": BEHAVIOUR_RETREAT,
	&"appeal": BEHAVIOUR_HOLD,
}
const OPPONENT_SPEED := 2.2
## Advancing stops this close to the hero, retreating this far from him.
const CLOSE_DISTANCE := 2.2
const FAR_DISTANCE := 6.0
const SHAPE_ARC := &"arc"
const SHAPE_CIRCLE := &"circle"
## An attack arc reaches this far past where the hero stood when the blow was telegraphed.
const ARC_EXTRA_REACH := 1.5
const ARC_HALF_ANGLE := 0.6981317  # 40 degrees
## Pressure and feints land on the spot the hero stood on; one or two steps clear them.
const CIRCLE_RADIUS: Dictionary = {&"pressure": 2.2, &"feint": 1.4}
const DEFAULT_CIRCLE_RADIUS := 1.8
## A guard only meets a blow the hero faces: within 60 degrees of the line to the opponent.
const GUARD_FACING_COS := 0.5

var arena: SpiritArena3D
var hero_position := Vector3.ZERO
## Planar facing of the hero (y ignored); zero means unknown and never guards.
var hero_facing := Vector3.FORWARD
var opponent_position := Vector3.ZERO
var behaviour: StringName = BEHAVIOUR_HOLD
## The locked strike zone of the telegraphed blow, empty between blows.
var zone: Dictionary = {}


func _init(on_arena: SpiritArena3D = null) -> void:
	arena = on_arena


## The opponent speaks a line: its move kind picks the footwork until the next line.
func set_line(move: Dictionary) -> void:
	behaviour = BEHAVIOUR_BY_KIND.get(StringName(String(move.get("kind", ""))), BEHAVIOUR_CIRCLE)


## Freeze the strike zone of `move` at the fighters' current places (telegraph start).
func lock_zone(move: Dictionary) -> Dictionary:
	var kind := StringName(String(move.get("kind", "")))
	if kind == &"attack":
		var aim := _flat(hero_position - opponent_position)
		zone = {
			"shape": SHAPE_ARC,
			"origin": opponent_position,
			"direction": aim.normalized() if aim.length() > 0.001 else Vector3.FORWARD,
			"reach": aim.length() + ARC_EXTRA_REACH,
			"half_angle": ARC_HALF_ANGLE,
			"kind": String(kind),
			"element": String(move.get("element", "")),
		}
	else:
		zone = {
			"shape": SHAPE_CIRCLE,
			"origin": hero_position,
			"radius": float(CIRCLE_RADIUS.get(kind, DEFAULT_CIRCLE_RADIUS)),
			"kind": String(kind),
			"element": String(move.get("element", "")),
		}
	return zone.duplicate()


func clear_zone() -> void:
	zone = {}


func in_zone(position: Vector3) -> bool:
	if zone.is_empty():
		return false
	var offset := _flat(position - (zone["origin"] as Vector3))
	if zone["shape"] == SHAPE_CIRCLE:
		return offset.length() <= float(zone["radius"])
	if offset.length() > float(zone["reach"]):
		return false
	if offset.length() < 0.001:
		return true
	return offset.normalized().dot(zone["direction"] as Vector3) >= cos(float(zone["half_angle"]))


func guard_facing() -> bool:
	var facing := _flat(hero_facing)
	var to_opponent := _flat(opponent_position - hero_position)
	if facing.length() < 0.001 or to_opponent.length() < 0.001:
		return false
	return facing.normalized().dot(to_opponent.normalized()) >= GUARD_FACING_COS


## SpiritDuel.hit_check hook: where the hero stands and faces at impact.
func hit_check(_move: Dictionary) -> Dictionary:
	return {"in_zone": in_zone(hero_position), "guard_facing": guard_facing()}


## The hero's place pulled back onto the disc (SpiritArena3D.clamp_position).
func clamp_hero(position: Vector3) -> Vector3:
	hero_position = arena.clamp_position(position) if arena != null else position
	return hero_position


## Move the opponent by its footwork. It stands still while a blow is wound up, so the
## locked zone and the body that throws it agree.
func step(delta: float) -> void:
	if delta <= 0.0 or not zone.is_empty():
		return
	var offset := _flat(opponent_position - hero_position)
	var distance := offset.length()
	var away := offset / distance if distance > 0.001 else Vector3.BACK
	var travel := OPPONENT_SPEED * delta
	match behaviour:
		BEHAVIOUR_ADVANCE:
			distance = maxf(CLOSE_DISTANCE, distance - travel) if distance > CLOSE_DISTANCE else distance
		BEHAVIOUR_RETREAT:
			distance = minf(FAR_DISTANCE, distance + travel) if distance < FAR_DISTANCE else distance
		BEHAVIOUR_CIRCLE:
			# Counter-clockwise around the hero at the current distance (arc length = travel).
			away = away.rotated(Vector3.UP, travel / maxf(distance, CLOSE_DISTANCE))
		_:
			return
	var next := hero_position + away * distance
	next.y = opponent_position.y
	opponent_position = arena.clamp_position(next) if arena != null else next


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
