class_name SurfaceSpeed
extends RefCounted

## One table of walking speed per ground surface, as a fraction of the speed on
## paving (R-1907). CityGrass, CitySnow, the city's soft-ground drag,
## MapTerrainMovement mud and PlayerSwimState wading all read these numbers, so
## the feel of the ground is tuned here and nowhere else. Callers preload this
## script (no class_name lookup at parse time).

## Cobbles, flagstones, floors, bridge decks: the reference speed.
const PAVED := 1.0
## Dry packed earth or dried mud: barely slower than paving.
const DRY_EARTH := 0.95
## Standing grass, short turf or waist-high meadow alike.
const GRASS := 0.85
## Soaked mud after rain: the feet sink and slip.
const WET_MUD := 0.6
## Snow just past a dusting, and snow half a metre deep or more.
const SNOW_SHALLOW := 0.8
const SNOW_DEEP := 0.3
## Wading: ankle deep, and chest deep just before the feet leave the bed.
const WADE_SHALLOW := 0.8
const WADE_DEEP := 0.15


## Earth or mud at `wetness` 0 (dry) .. 1 (saturated).
static func soft_ground(wetness: float) -> float:
	var saturation := smoothstep(0.0, 1.0, clampf(wetness, 0.0, 1.0))
	return lerpf(DRY_EARTH, WET_MUD, saturation)
