class_name PlayerSwimState
extends RefCounted

## ADR 0021 medium state machine: walk -> wade -> swim -> dive. The medium is a
## pure function of the water column under Kalev plus the dive input, so it needs
## no saved fields: loading a game always resumes at the surface with full breath
## (the ADR's own rule for a save taken in `dive`).
##
## All depths and speeds are world units (1 unit = 1 cell) and seconds. Kalev is
## about 2 units tall, so the thresholds read as ankle, hip, chest.

enum Medium { WALK, WADE, SWIM, DIVE }

## Ankle-deep: below this the water only splashes.
const WADE_MIN_DEPTH := 0.12
## Chest-deep: the feet leave the bed and Kalev starts to swim. The exit threshold
## is lower so a wave or a sloping bed cannot flicker between wading and swimming.
const SWIM_ENTER_DEPTH := 1.25
const SWIM_EXIT_DEPTH := 1.05
## Dive needs a column this deep so the body still clears the bed.
const DIVE_MIN_DEPTH := 1.7
const BED_CLEARANCE := 0.45
const MAX_DIVE_DEPTH := 3.0
const DESCEND_SPEED := 1.5
const ASCEND_SPEED := 2.0
## Head below the surface once the body centre is this deep; breath drains from here.
const HEAD_SUBMERGED_DEPTH := 0.55

const BREATH_MAX_SEC := 20.0
const BREATH_REFILL_SEC := 3.0
## After running out of breath the dive stays locked until this fraction is back and the
## dive input has been released (holding it must not re-dive into another penalty).
const BREATH_RELOCK_FRACTION := 0.25
## Non-lethal stamina cost of being forced to the surface (ADR 0021 decision 4).
const OUT_OF_BREATH_STAMINA_PENALTY := 30.0

## Fractions of the run speed; ignore the walk modifier because a swimmer cannot stroll.
const SWIM_SPEED_FRACTION := 0.32
const DIVE_SPEED_FRACTION := 0.26
const WADE_SPEED_FRACTION_SHALLOW := 0.8
const WADE_SPEED_FRACTION_DEEP := 0.4

var medium: Medium = Medium.WALK
var depth := 0.0
## Depth of the body centre below the surface: 0 while floating, positive diving.
var submersion := 0.0
var breath_sec := BREATH_MAX_SEC
var dive_locked := false
## Set for exactly one update when breath ran out; the owner applies the penalty.
var out_of_breath_event := false


static func classify(column_depth: float, previous: Medium) -> Medium:
	var swimming := previous == Medium.SWIM or previous == Medium.DIVE
	if column_depth >= (SWIM_EXIT_DEPTH if swimming else SWIM_ENTER_DEPTH):
		return previous if swimming else Medium.SWIM
	if column_depth >= WADE_MIN_DEPTH:
		return Medium.WADE
	return Medium.WALK


## Fraction of the run speed while in `state` at `column_depth`; 1.0 on land.
static func speed_fraction(state: Medium, column_depth: float) -> float:
	match state:
		Medium.SWIM:
			return SWIM_SPEED_FRACTION
		Medium.DIVE:
			return DIVE_SPEED_FRACTION
		Medium.WADE:
			var t := inverse_lerp(WADE_MIN_DEPTH, SWIM_ENTER_DEPTH, column_depth)
			return lerpf(WADE_SPEED_FRACTION_SHALLOW, WADE_SPEED_FRACTION_DEEP, clampf(t, 0.0, 1.0))
	return 1.0


## Deepest the body centre may sink in a column of this depth.
static func max_submersion(column_depth: float) -> float:
	return clampf(column_depth - BED_CLEARANCE, 0.0, MAX_DIVE_DEPTH)


func is_swimming() -> bool:
	return medium == Medium.SWIM or medium == Medium.DIVE


func is_head_submerged() -> bool:
	return submersion >= HEAD_SUBMERGED_DEPTH


func breath_fraction() -> float:
	return clampf(breath_sec / BREATH_MAX_SEC, 0.0, 1.0)


## Combat is disabled in the water (ADR 0021 decision 4).
func blocks_combat() -> bool:
	return is_swimming()


func speed_multiplier() -> float:
	return speed_fraction(medium, depth)


func update(column_depth: float, dive_held: bool, delta: float) -> void:
	out_of_breath_event = false
	depth = column_depth
	medium = classify(column_depth, medium)
	if not is_swimming():
		submersion = 0.0
		_refill_breath(delta, dive_held)
		return
	var target := 0.0
	if dive_held and not dive_locked and column_depth >= DIVE_MIN_DEPTH:
		target = max_submersion(column_depth)
	var rate := DESCEND_SPEED if target > submersion else ASCEND_SPEED
	submersion = move_toward(submersion, minf(target, max_submersion(column_depth)), rate * delta)
	medium = Medium.DIVE if is_head_submerged() else Medium.SWIM
	if is_head_submerged():
		breath_sec = maxf(breath_sec - delta, 0.0)
		if breath_sec <= 0.0:
			# Forced to the surface: dive locked until some breath is back.
			dive_locked = true
			out_of_breath_event = true
			submersion = minf(submersion, HEAD_SUBMERGED_DEPTH - 0.01)
			medium = Medium.SWIM
	else:
		_refill_breath(delta, dive_held)


func reset() -> void:
	medium = Medium.WALK
	depth = 0.0
	submersion = 0.0
	breath_sec = BREATH_MAX_SEC
	dive_locked = false
	out_of_breath_event = false


func _refill_breath(delta: float, dive_held: bool) -> void:
	breath_sec = minf(breath_sec + BREATH_MAX_SEC / BREATH_REFILL_SEC * delta, BREATH_MAX_SEC)
	if dive_locked and not dive_held and breath_fraction() >= BREATH_RELOCK_FRACTION:
		dive_locked = false
