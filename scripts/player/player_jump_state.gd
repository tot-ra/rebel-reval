class_name PlayerJumpState
extends RefCounted

## Hop and slope slide for the hero. The logic plane is flat 2D, so height is a
## presentation value (world units, 1 unit = 1 cell): while it is above zero the
## owner masks CollisionLayers.STEEP out and the body clears a steep strip such as
## a ditch between two houses. Slope slide is a pure function of the ground
## gradient, so it needs no saved fields (a load resumes standing).

## Initial lift speed and gravity (units/s, units/s^2): 0.65 s in the air, 0.85 unit apex.
const TAKEOFF_SPEED := 5.2
const GRAVITY := 16.0
## Fraction of the run speed kept while airborne: a hop carries a little farther
## than a stride, enough to cross about 5 units at a run.
const AIR_SPEED_FRACTION := 1.4
const STAMINA_COST := 8.0
## Ground steeper than this starts to pull the hero downhill. 22 degrees.
const SLIDE_START_SLOPE := 0.384
## Matches CityCollisionBuilder.MAX_WALK_SLOPE_DEG: where the ground turns solid.
const SLIDE_FULL_SLOPE := 0.6632
## Logic px/s of downhill drift at SLIDE_FULL_SLOPE; steeper ground slides faster, up to 1.5x.
const SLIDE_MAX_SPEED_PX := 140.0

var height := 0.0
var lift_speed := 0.0


func is_airborne() -> bool:
	return height > 0.0 or lift_speed > 0.0


func start() -> void:
	height = 0.0001
	lift_speed = TAKEOFF_SPEED


## Advance the arc. Returns true on the tick the feet touch the ground again.
func update(delta: float) -> bool:
	if not is_airborne():
		return false
	lift_speed -= GRAVITY * delta
	height += lift_speed * delta
	if height <= 0.0:
		height = 0.0
		lift_speed = 0.0
		return true
	return false


func reset() -> void:
	height = 0.0
	lift_speed = 0.0


## Downhill drift in logic px/s for a gradient (`downhill` from
## MapDefinition.downhill_at_world, length = tan(slope)).
static func slide_velocity(downhill: Vector2) -> Vector2:
	var rise := downhill.length()
	if rise <= 0.0001:
		return Vector2.ZERO
	var slope := atan(rise)
	if slope <= SLIDE_START_SLOPE:
		return Vector2.ZERO
	var t := (slope - SLIDE_START_SLOPE) / (SLIDE_FULL_SLOPE - SLIDE_START_SLOPE)
	return downhill / rise * SLIDE_MAX_SPEED_PX * clampf(t, 0.0, 1.5)
