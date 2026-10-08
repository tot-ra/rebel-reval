class_name CloudCells
extends RefCounted

## R-1400: discrete clouds as world-space objects. The dome's continuous cloud field
## is drawn per view direction, so it has no position: it cannot cast a shadow that
## matches what the player sees, and a lightning bearing picked on it can land in
## blue sky. These cells are the individual clouds instead: each one has a centre,
## a base altitude, a radius and a height in world units, drifts with the shared
## cloud offset, and lives through a grow / mature / dissipate cycle. The sky dome
## ray-marches them, the ground pass projects them along the sun, god rays are cut
## by them, and lightning is only ever born inside a mature cumulonimbus cell.
##
## Everything is a pure function of (cell clock, cloud drift, weather counts), so the
## field is deterministic, survives save/load through those three inputs, and needs
## no per-cell state. Cells tile a periodic DOMAIN square: shaders pick the copy
## nearest to the camera and fade cells out before the wrap seam (storm cells
## tile a wider STORM_DOMAIN).

## Fair-weather cumulus slots, then cumulonimbus slots, in one packed array.
const CUMULUS_SLOTS := 13
const STORM_SLOTS := 3
const SLOTS := CUMULUS_SLOTS + STORM_SLOTS
const KIND_CUMULUS := 0
const KIND_STORM := 1
## Periodic tile edge in world units (metres in the seamless city). Must match
## CELL_DOMAIN / CELL_STORM_DOMAIN in cloud_cells.gdshaderinc. Storm cells use a
## wider tile so a 2 km thunderhead stays in view from several kilometres away.
const DOMAIN := 3200.0
const STORM_DOMAIN := 9600.0
## World units per unit of SkyWeather3D._cloud_offset. Cells drift 2.5-10 m/s with
## the wind, quick enough for a shadow edge to visibly sweep a street.
const METRES_PER_UV := 5000.0
## Art-compressed sizes: real fair-weather cumulus sit 1-1.5 km up and are 1 km
## wide, which would make one shadow bigger than the town. These keep several
## shadows readable over a district while the clouds still read as kilometre-scale.
const CUMULUS_BASE := Vector2(600.0, 850.0)
const CUMULUS_RADIUS := Vector2(160.0, 380.0)
const CUMULUS_HEIGHT_RATIO := Vector2(0.7, 1.2)
## A thunderstorm is a wide, squat mass, wider than it is tall (a squall cluster
## several kilometres across), not a pillar with a mushroom cap.
const STORM_BASE := Vector2(420.0, 560.0)
const STORM_RADIUS := Vector2(1100.0, 1700.0)
const STORM_HEIGHT := Vector2(1300.0, 1900.0)
## Seconds per life (grow, hold, dissipate) per slot. Sized against the 60 s game
## day so the sky visibly turns over within one day.
const CUMULUS_PERIOD := Vector2(36.0, 62.0)
const STORM_PERIOD := Vector2(150.0, 220.0)
## Storm slots after the first are dormant for the rest of their cycle, so
## thunderheads are rare: each shows for this share of its period.
const STORM_ACTIVE_SHARE := 0.5
const GROW_END := 0.22
const DECAY_START := 0.72
## Lightning only charges in a storm cell that is grown and not yet collapsing.
const STORM_MATURE_LIFE := Vector2(0.2, 0.85)
const STORM_MATURE_WEIGHT := 0.5
## Footprint radius (x R) the ground shadow uses: mid-height for cumulus, the anvil
## spread for cumulonimbus. Mirrors cells_ground_shadow() in the shader include.
const CUMULUS_FOOTPRINT := 0.94
const STORM_FOOTPRINT := 1.1
const CUMULUS_OPACITY := 0.82
const STORM_OPACITY := 0.97
const SEED := 24217

## Per slot, wrapped into [0, DOMAIN): x, base altitude, z.
var centers := PackedVector3Array()
var radii := PackedFloat32Array()
var heights := PackedFloat32Array()
## 0..1 visible strength: weather activation x life envelope.
var weights := PackedFloat32Array()
## 0..1 progress through the current life.
var lives := PackedFloat32Array()
var seeds := PackedFloat32Array()


func _init() -> void:
	centers.resize(SLOTS)
	radii.resize(SLOTS)
	heights.resize(SLOTS)
	weights.resize(SLOTS)
	lives.resize(SLOTS)
	seeds.resize(SLOTS)


static func kind_of(slot: int) -> int:
	return KIND_STORM if slot >= CUMULUS_SLOTS else KIND_CUMULUS


## How many cumulus and cumulonimbus cells a weather profile shows. Fractions fade
## the next slot in, so a weather transition grows or thins the field smoothly.
## Cumulus are a blue-sky cloud: they peak at moderate cover and, once a deck closes,
## are gone (the sky shader darkens the remaining ones toward rain-bearing grey, see
## cloud_gloom). Cumulonimbus need real storm development.
static func counts_for(coverage: float, storm: float) -> Vector2:
	var deck := smoothstep(0.6, 0.92, coverage)
	var cumulus := float(CUMULUS_SLOTS) * clampf((coverage - 0.05) / 0.5, 0.0, 1.0)
	cumulus *= 1.0 - deck
	var storms := float(STORM_SLOTS) * smoothstep(0.3, 1.0, storm)
	return Vector2(cumulus, storms)


## Rebuilds every slot for this instant. `drift` is the shared cloud offset in UV
## units (SkyWeather3D.cloud_offset()), so cells move with the dome and the wind.
func update(clock: float, drift: Vector2, counts: Vector2) -> void:
	var shift := drift * METRES_PER_UV
	for slot in SLOTS:
		var storm := kind_of(slot) == KIND_STORM
		var rank := slot - CUMULUS_SLOTS if storm else slot
		var active := clampf((counts.y if storm else counts.x) - float(rank), 0.0, 1.0)
		var span := STORM_PERIOD if storm else CUMULUS_PERIOD
		# Period and phase are fixed per slot, so the generation counter is monotonic.
		var period := lerpf(span.x, span.y, _hash01(slot, 0, 1))
		var cycle := clock / period + _hash01(slot, 0, 2)
		var generation := floori(cycle)
		var life := cycle - float(generation)
		var dormant := false
		if storm and rank > 0:
			# Only the first part of the cycle is alive; stretch it back to 0..1.
			dormant = life > STORM_ACTIVE_SHARE
			life = minf(life / STORM_ACTIVE_SHARE, 1.0)
		var grow := smoothstep(0.0, GROW_END, life)
		var decay := 1.0 - smoothstep(DECAY_START, 1.0, life)
		var rand := func(salt: int) -> float: return _hash01(slot, generation, salt)
		var base_range := STORM_BASE if storm else CUMULUS_BASE
		var radius_range := STORM_RADIUS if storm else CUMULUS_RADIUS
		var radius := lerpf(radius_range.x, radius_range.y, rand.call(5))
		var height := lerpf(STORM_HEIGHT.x, STORM_HEIGHT.y, rand.call(6))
		if not storm:
			height = radius * lerpf(CUMULUS_HEIGHT_RATIO.x, CUMULUS_HEIGHT_RATIO.y, rand.call(6))
		var domain := STORM_DOMAIN if storm else DOMAIN
		var spawn := Vector2(rand.call(3), rand.call(4)) * domain + shift
		centers[slot] = Vector3(
			fposmod(spawn.x, domain), lerpf(base_range.x, base_range.y, rand.call(7)),
			fposmod(spawn.y, domain)
		)
		# A newborn cell is a small puff; a dying one thins and shrinks a little.
		# Storm cells also tower up as they grow, so a thunderhead visibly builds.
		radii[slot] = radius * lerpf(0.55, 1.0, grow) * lerpf(0.85, 1.0, decay)
		heights[slot] = height * (lerpf(0.35, 1.0, grow) if storm else lerpf(0.6, 1.0, grow))
		weights[slot] = 0.0 if dormant else active * grow * decay
		lives[slot] = life
		seeds[slot] = rand.call(8)


## Two vec4 per slot for the `cloud_cells` uniform in cloud_cells.gdshaderinc:
## (x, base, z, radius), (height, weight, kind, seed).
func uniforms() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(SLOTS * 2)
	for slot in SLOTS:
		var c := centers[slot]
		out[slot * 2] = Vector4(c.x, c.y, c.z, radii[slot])
		out[slot * 2 + 1] = Vector4(heights[slot], weights[slot], float(kind_of(slot)), seeds[slot])
	return out


## Offset from cell centre `c` to `p` on the periodic domain of `kind` (nearest copy).
static func wrap_delta(p: Vector2, c: Vector2, kind: int = KIND_CUMULUS) -> Vector2:
	var domain := STORM_DOMAIN if kind == KIND_STORM else DOMAIN
	var d := p - c
	return d - (d / domain).round() * domain


## Share of direct light that the cells stop on the way from `point` toward
## `light_dir` (0 = open sky, 1 = fully shadowed). The noise-free CPU mirror of
## cells_ground_shadow(): ground shadows, sun-behind-cloud and tests all use it.
func shadow_at(point: Vector3, light_dir: Vector3) -> float:
	var lit := 1.0
	var sun_y := maxf(light_dir.y, 0.15)
	for slot in SLOTS:
		lit *= 1.0 - slot_shadow(slot, point, light_dir, sun_y)
	return 1.0 - lit


func slot_shadow(slot: int, point: Vector3, light_dir: Vector3, sun_y: float = -1.0) -> float:
	if weights[slot] <= 0.001:
		return 0.0
	if sun_y < 0.0:
		sun_y = maxf(light_dir.y, 0.15)
	var storm := kind_of(slot) == KIND_STORM
	var c := centers[slot]
	var layer := c.y + heights[slot] * (0.25 if storm else 0.35)
	var q := Vector2(point.x, point.z) + Vector2(light_dir.x, light_dir.z) / sun_y * (layer - point.y)
	var r := radii[slot] * (STORM_FOOTPRINT if storm else CUMULUS_FOOTPRINT)
	var dist := wrap_delta(q, Vector2(c.x, c.z), kind_of(slot)).length() / maxf(r, 1.0)
	return smoothstep(1.0, 0.8, dist) * weights[slot] * (STORM_OPACITY if storm else CUMULUS_OPACITY)


## Storm slots that can throw lightning right now.
func mature_storm_cells() -> Array[int]:
	var out: Array[int] = []
	for slot in range(CUMULUS_SLOTS, SLOTS):
		var life := lives[slot]
		if (
			weights[slot] >= STORM_MATURE_WEIGHT
			and life >= STORM_MATURE_LIFE.x
			and life <= STORM_MATURE_LIFE.y
		):
			out.append(slot)
	return out


## Strongest cell weight of a kind; tests and debug overlays read it.
func max_weight(kind: int) -> float:
	var best := 0.0
	for slot in SLOTS:
		if kind_of(slot) == kind:
			best = maxf(best, weights[slot])
	return best


## Integer hash to 0..1. GDScript ints are 64-bit and wrap deterministically.
static func _hash01(a: int, b: int, c: int) -> float:
	var h := (a * 374761393 + b * 668265263 + c * 1274126177 + SEED * 2246822519) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1103515245) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 2654435761) & 0xFFFFFFFF
	h ^= h >> 15
	return float(h & 0xFFFFFF) / 16777216.0
