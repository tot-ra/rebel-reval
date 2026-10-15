class_name CityAnimalTracks
extends RefCounted

## Animal prints for the ground trail (CityGroundTrail): every city animal leaves
## a print of its own kind in mud, soft earth and snow: hooves (the trail's
## HOOVES table), paws (dog, fox, cat), bounding groups (hare, rat) and bird feet
## (chicken, goose). Kept beside the trail rather than
## in it so the stamping shapes stay in one small file; it uses the trail's mark
## bookkeeping (`_advance_mark`, `_softness_at`, `_weight`) as a companion would.
##
## Sizes are on the trail's scale (a boot is ~0.38 wu, about 1.4x a real one) and
## floored near one trail cell (0.04 wu): a smaller toe would fall between texels
## and flicker in and out instead of reading as a toe.

## Pads and toes: main pad half extents (along, across), toe radius, how far the
## toes sit ahead of the pad centre, their fan angle each side, distance between
## left and right line, distance walked per footfall and weight against a
## person's. A fox walks one straight line (direct register, gauge 0); a cat
## carries its claws in, a dog and a fox show claw tips ahead of the toes.
const PAWS := {
	&"dog": {
		"pad": Vector2(0.036, 0.048), "toe": 0.024, "reach": 0.085, "fan": 0.8,
		"gauge": 0.13, "step": 0.38, "weight": 0.8, "claws": true,
	},
	&"red_fox": {
		"pad": Vector2(0.03, 0.036), "toe": 0.02, "reach": 0.07, "fan": 0.6,
		"gauge": 0.0, "step": 0.34, "weight": 0.55, "claws": true,
	},
	&"cat": {
		"pad": Vector2(0.028, 0.036), "toe": 0.02, "reach": 0.055, "fan": 0.8,
		"gauge": 0.07, "step": 0.26, "weight": 0.4, "claws": false,
	},
}
## Bounders land in groups of four, one group per bound: the long hind feet
## side by side in front, the small fore feet one behind the other behind them.
## `hind` and `fore` are half extents (along, across).
const BOUNDERS := {
	&"hare": {
		"hind": Vector2(0.085, 0.034), "fore": Vector2(0.034, 0.028), "gauge": 0.12,
		"stride": 1.2, "weight": 0.6,
	},
	&"rat": {
		"hind": Vector2(0.03, 0.02), "fore": Vector2(0.022, 0.022), "gauge": 0.06,
		"stride": 0.3, "weight": 0.3,
	},
}
## Birds walk a narrow zigzag of three-toed arrows. `toe` is one toe's half
## extents (along, across), `fan` the angle of the outer toes, `toe_in` how far
## each foot turns towards the line (geese waddle pigeon-toed), `web` fills the
## gap between the toes.
const BIRD_FEET := {
	&"chicken": {
		"toe": Vector2(0.05, 0.02), "fan": 0.55, "gauge": 0.07, "step": 0.22,
		"weight": 0.45, "toe_in": 0.0, "web": false,
	},
	&"goose": {
		"toe": Vector2(0.062, 0.022), "fan": 0.5, "gauge": 0.12, "step": 0.3,
		"weight": 0.7, "toe_in": 0.2, "web": true,
	},
}


## True if `species` leaves any print on the trail (hooves, paws, bounds, feet).
static func leaves_tracks(species: StringName) -> bool:
	return (
		CityGroundTrail.HOOVES.has(species) or PAWS.has(species)
		or BOUNDERS.has(species) or BIRD_FEET.has(species)
	)


## One call per animal per frame, from CityTrailFeed: picks the print for the
## species. Anything with no entry (fish, birds in flight) leaves nothing.
static func track(
	trail: CityGroundTrail, key: Variant, world_xz: Vector2, species: StringName
) -> void:
	if CityGroundTrail.HOOVES.has(species):
		_track_hooves(trail, key, world_xz, CityGroundTrail.HOOVES[species])
	elif PAWS.has(species):
		_track_paws(trail, key, world_xz, PAWS[species])
	elif BOUNDERS.has(species):
		_track_bounds(trail, key, world_xz, BOUNDERS[species])
	elif BIRD_FEET.has(species):
		_track_bird(trail, key, world_xz, BIRD_FEET[species])


## One paw print: a broad heel pad and four toes fanned ahead of it, claw nicks
## ahead of the two middle toes. `facing` is the direction of travel.
static func stamp_paw(
	trail: CityGroundTrail, world_xz: Vector2, facing: Vector2, spec: Dictionary,
	weight: float
) -> void:
	var fwd := facing.normalized()
	var depth := minf(0.5 * weight * float(spec["weight"]), 0.9)
	# A thin rim: a heavy one would heap over the toes and blur the pad gaps.
	var rim := 0.08 * weight
	var pad: Vector2 = spec["pad"]
	stamp_oval_safe(trail, world_xz, pad, fwd, depth, rim)
	var toe := float(spec["toe"])
	var reach := float(spec["reach"])
	var fan := float(spec["fan"])
	# Outer toes sit a little further back than the middle pair, as on a real paw.
	var angles: Array[float] = [-fan, -fan * 0.33, fan * 0.33, fan]
	for i in angles.size():
		var outer := i == 0 or i == angles.size() - 1
		var dir := fwd.rotated(angles[i])
		var at := world_xz + dir * reach * (0.86 if outer else 1.0)
		stamp_oval_safe(trail, at, Vector2(toe, toe * 0.9), fwd, depth * 0.85, rim * 0.5)
		if bool(spec["claws"]) and not outer:
			stamp_oval_safe(
				trail, at + dir * toe * 1.6, Vector2(toe * 0.45, toe * 0.4), fwd, depth * 0.6, 0.0
			)


## One bird foot: three forward toes from a common heel, a short hind toe for a
## chicken, a shallow web between the toes for a goose.
static func stamp_bird_foot(
	trail: CityGroundTrail, world_xz: Vector2, facing: Vector2, spec: Dictionary,
	weight: float
) -> void:
	var fwd := facing.normalized()
	var depth := minf(0.5 * weight * float(spec["weight"]), 0.9)
	var toe: Vector2 = spec["toe"]
	var fan := float(spec["fan"])
	for angle: float in [-fan, 0.0, fan]:
		var dir := fwd.rotated(angle)
		stamp_oval_safe(trail, world_xz + dir * toe.x, toe, dir, depth, 0.04 * weight)
	if bool(spec["web"]):
		stamp_oval_safe(
			trail, world_xz + fwd * toe.x * 1.1, Vector2(toe.x * 0.7, toe.x * 0.75), fwd,
			depth * 0.45, 0.0
		)
	else:
		stamp_oval_safe(
			trail, world_xz - fwd * toe.x * 0.45, Vector2(toe.x * 0.45, toe.y), fwd,
			depth * 0.7, 0.0
		)


## stamp_oval with radii floored to half a trail cell, so a small toe always
## presses at least the texel it sits on.
static func stamp_oval_safe(
	trail: CityGroundTrail, world_xz: Vector2, radii: Vector2, facing: Vector2,
	depth: float, rim: float
) -> void:
	var floor_r := CityGroundTrail.CELL * 0.5
	trail.stamp_oval(
		world_xz, Vector2(maxf(radii.x, floor_r), maxf(radii.y, floor_r)), facing, depth, rim
	)


## Ground weight at a spot: wetness as for people, and settled snow takes a print
## as deeply as wet clay does (the same rule as Kalev's own footfalls).
static func _ground_weight(trail: CityGroundTrail, world_xz: Vector2) -> float:
	return trail._weight(CitySnow.patch(world_xz, trail.snow_cover))


## Advance the walker's mark by `step`; returns the mark when a print is due on
## ground that gives, else {}.
static func _due(
	trail: CityGroundTrail, key: Variant, world_xz: Vector2, step: float
) -> Dictionary:
	var mark := trail._advance_mark(key, world_xz)
	if mark.is_empty() or float(mark["travelled"]) < step:
		return {}
	mark["travelled"] = fmod(float(mark["travelled"]), step)
	if trail._softness_at(world_xz).x < CityGroundTrail.MIN_SOFTNESS:
		return {}
	return mark


## The trail's own `track_hooves` pattern (left and right hoof per stride, the
## right half a stride behind), but weighted by settled snow as well as wetness:
## `track_hooves` presses snow as lightly as dry earth, so a horse in January left
## fainter prints than a cat.
static func _track_hooves(
	trail: CityGroundTrail, key: Variant, world_xz: Vector2, spec: Dictionary
) -> void:
	var mark := _due(trail, key, world_xz, float(spec["stride"]))
	if mark.is_empty():
		return
	var facing: Vector2 = mark["facing"]
	var side := Vector2(-facing.y, facing.x)
	var half := float(spec["gauge"]) * 0.5
	var radii: Vector2 = spec["radii"]
	var w := _ground_weight(trail, world_xz)
	var depth := minf(0.5 * w * float(spec["weight"]), 0.95)
	var back := facing * float(spec["stride"]) * 0.5
	trail.stamp_oval(world_xz + side * half, radii, facing, depth, 0.14 * w)
	trail.stamp_oval(world_xz - side * half - back, radii, facing, depth, 0.14 * w)


static func _track_paws(
	trail: CityGroundTrail, key: Variant, world_xz: Vector2, spec: Dictionary
) -> void:
	var mark := _due(trail, key, world_xz, float(spec["step"]))
	if mark.is_empty():
		return
	var facing: Vector2 = mark["facing"]
	var foot_sign := 1.0 if mark["left"] else -1.0
	mark["left"] = not mark["left"]
	# Walking, the hind paw lands in the fore paw's print, so one line of single
	# prints per side reads as the whole animal.
	var at := world_xz + Vector2(-facing.y, facing.x) * float(spec["gauge"]) * 0.5 * foot_sign
	stamp_paw(trail, at, facing, spec, _ground_weight(trail, at))


static func _track_bounds(
	trail: CityGroundTrail, key: Variant, world_xz: Vector2, spec: Dictionary
) -> void:
	var mark := _due(trail, key, world_xz, float(spec["stride"]))
	if mark.is_empty():
		return
	var fwd: Vector2 = mark["facing"]
	var side := Vector2(-fwd.y, fwd.x)
	var w := _ground_weight(trail, world_xz) * float(spec["weight"])
	var depth := minf(0.5 * w, 0.9)
	var hind: Vector2 = spec["hind"]
	var fore: Vector2 = spec["fore"]
	var half := float(spec["gauge"]) * 0.5
	# The hind feet swing past the fore feet and land ahead of them.
	for s: float in [1.0, -1.0]:
		stamp_oval_safe(trail, world_xz + side * half * s, hind, fwd, depth, 0.06 * w)
	var back := hind.x + fore.x * 1.6
	stamp_oval_safe(trail, world_xz - fwd * back + side * half * 0.25, fore, fwd, depth, 0.06 * w)
	stamp_oval_safe(
		trail, world_xz - fwd * (back + fore.x * 3.0) - side * half * 0.25, fore, fwd, depth,
		0.06 * w
	)


static func _track_bird(
	trail: CityGroundTrail, key: Variant, world_xz: Vector2, spec: Dictionary
) -> void:
	var mark := _due(trail, key, world_xz, float(spec["step"]))
	if mark.is_empty():
		return
	var facing: Vector2 = mark["facing"]
	var foot_sign := 1.0 if mark["left"] else -1.0
	mark["left"] = not mark["left"]
	var at := world_xz + Vector2(-facing.y, facing.x) * float(spec["gauge"]) * 0.5 * foot_sign
	# Toe-in: each foot's toes turn in towards the line it walks along.
	var dir := facing.rotated(-float(spec["toe_in"]) * foot_sign)
	stamp_bird_foot(trail, at, dir, spec, _ground_weight(trail, at))
