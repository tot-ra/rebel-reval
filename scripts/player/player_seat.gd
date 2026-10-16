extends RefCounted

## Kalev sitting on a chair, a stool or a bench (docs/SYSTEMS/SITTING.md): sit down, stay seated
## until he moves or asks to stand, stand up. The seat is a CitySeats record; the logic body
## stands where the residents' seated bodies stand (SIT_BACK in front of the seat's centre) and the
## rig is lowered so the Sit_Chair clips rest on the seat, exactly as CitizenActor seats people.

enum Phase { NONE, DOWN, SEATED, UP }

const SIT_BACK := 0.44
const SIT_SURFACE := 0.95
const DOWN_SEC := 1.2
const UP_SEC := 1.0
## Where he stands after getting up: this far in front of the seat's centre.
const STAND_FRONT := 0.6

var phase: Phase = Phase.NONE
var seat: Dictionary = {}
var elapsed := 0.0
var px_per_m := 32.0


func is_active() -> bool:
	return phase != Phase.NONE


func is_seated() -> bool:
	return phase == Phase.SEATED


func sit(chosen: Dictionary) -> void:
	seat = chosen
	phase = Phase.DOWN
	elapsed = 0.0


func stand() -> void:
	if phase == Phase.SEATED or phase == Phase.DOWN:
		phase = Phase.UP
		elapsed = 0.0


## Advance by `delta`; returns the logic position for this frame.
func advance(delta: float, current: Vector2) -> Vector2:
	if phase == Phase.NONE:
		return current
	elapsed += delta
	match phase:
		Phase.DOWN:
			if elapsed >= DOWN_SEC:
				phase = Phase.SEATED
				elapsed = 0.0
		Phase.UP:
			if elapsed >= UP_SEC:
				phase = Phase.NONE
				return stand_point()
	return seated_point()


## Logic position of the seated body (the rig origin in front of the seat).
func seated_point() -> Vector2:
	var p: Vector2 = seat["pos"] + (seat["facing"] as Vector2) * SIT_BACK
	return p * px_per_m


func stand_point() -> Vector2:
	var p: Vector2 = seat["pos"] + (seat["facing"] as Vector2) * STAND_FRONT
	return p * px_per_m


func facing() -> Vector2:
	return seat.get("facing", Vector2.DOWN)


## How far the rig sits below the floor height so the clip's thighs rest on the seat.
func height_offset() -> float:
	if phase == Phase.NONE:
		return 0.0
	return float(seat.get("h", 0.45)) - SIT_SURFACE


func animation() -> StringName:
	match phase:
		Phase.DOWN:
			return &"sit_down"
		Phase.SEATED:
			return &"sit_idle"
		Phase.UP:
			return &"sit_up"
	return &"idle"
