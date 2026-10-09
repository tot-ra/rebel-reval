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
##
## R-1481: cumulus are lobed and stretched by the wind (shader side), each one
## rides the wind at its own speed and slight veer so clouds overtake and meet,
## an ageing cloud spreads, shrinks and tatters before it fades, and cumulus that
## crowd together merge into a towering thunderstorm (`towers`) that can rain and
## throw lightning. Still a pure function of the same inputs plus the smoothed
## wind strength, which the weather state already saves.

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
## R-1481: cumulus ride the wind faster than the dome deck (art-compressed against
## the short game day, so a cloud crosses several of its own widths in one life
## instead of hanging in place). Each generation draws its own speed share and a
## small veer off the wind bearing, so neighbours overtake, meet and part.
const CUMULUS_WIND_GAIN := 2.6
const CUMULUS_SPEED := Vector2(0.7, 1.4)
const CUMULUS_VEER := 0.3
## Art-compressed sizes: real fair-weather cumulus sit 1-1.5 km up and are 1 km
## wide, which would make one shadow bigger than the town. These keep several
## shadows readable over a district while the clouds still read as kilometre-scale.
## The radius is the main heap; side lobes make a cloud up to ~3x as long.
const CUMULUS_BASE := Vector2(600.0, 850.0)
const CUMULUS_RADIUS := Vector2(140.0, 300.0)
const CUMULUS_HEIGHT_RATIO := Vector2(0.7, 1.2)
## A thunderstorm is a wide, squat mass, wider than it is tall (a squall cluster
## several kilometres across), not a pillar with a mushroom cap.
const STORM_BASE := Vector2(420.0, 560.0)
const STORM_RADIUS := Vector2(1100.0, 1700.0)
const STORM_HEIGHT := Vector2(1300.0, 1900.0)
## Seconds per life (grow, hold, dissipate) per slot. Sized against the 60 s game
## day so the sky visibly turns over within one day.
const CUMULUS_PERIOD := Vector2(55.0, 90.0)
const STORM_PERIOD := Vector2(150.0, 220.0)
## Storm slots after the first are dormant for the rest of their cycle, so
## thunderheads are rare: each shows for this share of its period.
const STORM_ACTIVE_SHARE := 0.5
const GROW_END := 0.22
const DECAY_START := 0.72
## R-1481: a cumulus dissolves slowly. From SHRINK_START it shrinks (to
## CUMULUS_SHRINK_TO of its size) and flattens while the shader tatters it, and
## only from FADE_START does it actually turn transparent.
const CUMULUS_GROW_END := 0.18
const CUMULUS_SHRINK_START := 0.5
const CUMULUS_FADE_START := 0.8
const CUMULUS_SHRINK_TO := 0.3
## R-1481: merging. A cumulus's crowding is the overlap-weighted sum of its
## neighbours (overlap 1 when centres are TOWER_TOUCH x their summed radii apart,
## 0 beyond TOWER_APART). Crowding across TOWER_CROWDING turns it into a tower: it
## grows up to TOWER_HEIGHT_GAIN x taller and TOWER_RADIUS_GAIN wider, its base
## drops toward TOWER_BASE, and it is pulled toward its neighbours' centroid so
## the cluster fuses into one thunderstorm mass.
const TOWER_TOUCH := 0.55
const TOWER_APART := 1.1
const TOWER_CROWDING := Vector2(1.35, 2.0)
const TOWER_HEIGHT_GAIN := 3.4
const TOWER_RADIUS_GAIN := 0.6
const TOWER_BASE := 480.0
const TOWER_PULL := 0.45
## A tower at least this far merged can rain and charge lightning.
const TOWER_MATURE := 0.75
## Lightning only charges in a storm cell that is grown and not yet collapsing.
const STORM_MATURE_LIFE := Vector2(0.2, 0.85)
const STORM_MATURE_WEIGHT := 0.5
## Footprint radius (x R) the ground shadow uses: mid-height for cumulus, the anvil
## spread for cumulonimbus. Mirrors cells_ground_shadow() in the shader include.
const CUMULUS_FOOTPRINT := 0.94
const STORM_FOOTPRINT := 1.1
const CUMULUS_OPACITY := 0.82
const STORM_OPACITY := 0.97
## Shader ray-march reach (x R) used to bound the footprint search; matches
## CELL_CU_REACH / CELL_CB_REACH.
const CUMULUS_REACH := 3.0
const STORM_REACH := 1.9
const LOBES := 3
## vec4 per slot in uniforms(); matches CELL_STRIDE in the shader include.
const STRIDE := 3
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
## R-1481: 0..1 how far a crowded cumulus has merged into a thunderstorm (0 for
## storm slots, which are cumulonimbus already).
var towers := PackedFloat32Array()
## 0..1 wind strength stretching and shearing the cumulus (same for every slot).
var windiness := 0.0


func _init() -> void:
	centers.resize(SLOTS)
	radii.resize(SLOTS)
	heights.resize(SLOTS)
	weights.resize(SLOTS)
	lives.resize(SLOTS)
	seeds.resize(SLOTS)
	towers.resize(SLOTS)


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
## `wind` (0..1, the smoothed drift strength) stretches and shears the cumulus.
func update(clock: float, drift: Vector2, counts: Vector2, wind: float = 0.0) -> void:
	var shift := drift * METRES_PER_UV
	windiness = clampf(wind, 0.0, 1.0)
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
		var rand := func(salt: int) -> float: return _hash01(slot, generation, salt)
		var base_range := STORM_BASE if storm else CUMULUS_BASE
		var radius_range := STORM_RADIUS if storm else CUMULUS_RADIUS
		var radius := lerpf(radius_range.x, radius_range.y, rand.call(5))
		var height := lerpf(STORM_HEIGHT.x, STORM_HEIGHT.y, rand.call(6))
		if not storm:
			height = radius * lerpf(CUMULUS_HEIGHT_RATIO.x, CUMULUS_HEIGHT_RATIO.y, rand.call(6))
		var domain := STORM_DOMAIN if storm else DOMAIN
		var moved := shift
		if not storm:
			# Own speed and veer per generation. The shift is the integrated wind, so
			# scaling and turning it keeps motion continuous while the cell lives.
			var speed := CUMULUS_WIND_GAIN * lerpf(CUMULUS_SPEED.x, CUMULUS_SPEED.y, rand.call(9))
			moved = shift.rotated((rand.call(10) - 0.5) * 2.0 * CUMULUS_VEER) * speed
		var spawn := Vector2(rand.call(3), rand.call(4)) * domain + moved
		centers[slot] = Vector3(
			fposmod(spawn.x, domain), lerpf(base_range.x, base_range.y, rand.call(7)),
			fposmod(spawn.y, domain)
		)
		lives[slot] = life
		seeds[slot] = rand.call(8)
		towers[slot] = 0.0
		if storm:
			var built := smoothstep(0.0, GROW_END, life)
			var decay := 1.0 - smoothstep(DECAY_START, 1.0, life)
			# A newborn cell is a small puff; a dying one thins and shrinks a little.
			# Storm cells also tower up as they grow, so a thunderhead visibly builds.
			radii[slot] = radius * lerpf(0.55, 1.0, built) * lerpf(0.85, 1.0, decay)
			heights[slot] = height * lerpf(0.35, 1.0, built)
			weights[slot] = 0.0 if dormant else active * built * decay
			continue
		# Cumulus: grow from a puff, then shrink and flatten for a long while before
		# the last of it fades, so a cloud dissolves instead of blinking out.
		var grow := smoothstep(0.0, CUMULUS_GROW_END, life)
		var keep := 1.0 - smoothstep(CUMULUS_SHRINK_START, 1.0, life)
		var fade := 1.0 - smoothstep(CUMULUS_FADE_START, 1.0, life)
		radii[slot] = radius * lerpf(0.55, 1.0, grow) * lerpf(CUMULUS_SHRINK_TO, 1.0, keep)
		heights[slot] = height * lerpf(0.6, 1.0, grow) * lerpf(0.4, 1.0, keep)
		weights[slot] = active * grow * fade
	_merge_crowded_cumulus()


## R-1481: cumulus that crowd together merge into a thunderstorm. Reads the
## positions of this instant only (no history), so it stays a pure function and
## changes smoothly as cells drift together and apart or fade.
func _merge_crowded_cumulus() -> void:
	var flat: Array[Vector2] = []
	for slot in CUMULUS_SLOTS:
		flat.append(Vector2(centers[slot].x, centers[slot].z))
	var pulls: Array[Vector2] = []
	var levels := PackedFloat32Array()
	levels.resize(CUMULUS_SLOTS)
	for i in CUMULUS_SLOTS:
		var crowding := 0.0
		var pull := Vector2.ZERO
		var pull_weight := 0.0
		if weights[i] > 0.05:
			for j in CUMULUS_SLOTS:
				if j == i or weights[j] <= 0.05:
					continue
				var d := wrap_delta(flat[j], flat[i])
				var reach := radii[i] + radii[j]
				var overlap := smoothstep(TOWER_APART, TOWER_TOUCH, d.length() / maxf(reach, 1.0))
				var share := overlap * weights[j]
				crowding += share
				pull += d * share
				pull_weight += share
		# Only a grown cloud towers; a newborn puff or a dissolving remnant does not.
		var tower := smoothstep(TOWER_CROWDING.x, TOWER_CROWDING.y, crowding)
		tower *= smoothstep(0.3, 0.8, weights[i]) * (1.0 - smoothstep(0.85, 1.0, lives[i]))
		levels[i] = tower
		pulls.append(pull / pull_weight if pull_weight > 0.0 else Vector2.ZERO)
	for i in CUMULUS_SLOTS:
		var tower := levels[i]
		if tower <= 0.0:
			continue
		towers[i] = tower
		var c := centers[i]
		var pulled := Vector2(c.x, c.z) + pulls[i] * TOWER_PULL * tower
		centers[i] = Vector3(
			fposmod(pulled.x, DOMAIN), lerpf(c.y, TOWER_BASE, tower), fposmod(pulled.y, DOMAIN)
		)
		radii[i] *= 1.0 + TOWER_RADIUS_GAIN * tower
		heights[i] *= lerpf(1.0, TOWER_HEIGHT_GAIN, tower)


## 0 = fair cumulus, 1 = cumulonimbus (a storm slot or a fully merged tower).
## Mirrors cell_storminess() in the shader include.
func storminess(slot: int) -> float:
	return 1.0 if kind_of(slot) == KIND_STORM else towers[slot]


## Three vec4 per slot for the `cloud_cells` uniform in cloud_cells.gdshaderinc:
## (x, base, z, radius), (height, weight, kind, seed), (life, tower, windiness, 0).
func uniforms() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(SLOTS * STRIDE)
	for slot in SLOTS:
		var c := centers[slot]
		out[slot * STRIDE] = Vector4(c.x, c.y, c.z, radii[slot])
		out[slot * STRIDE + 1] = Vector4(
			heights[slot], weights[slot], float(kind_of(slot)), seeds[slot]
		)
		out[slot * STRIDE + 2] = Vector4(lives[slot], towers[slot], windiness, 0.0)
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
	var cb := storminess(slot)
	var c := centers[slot]
	var layer := c.y + heights[slot] * lerpf(0.35, 0.25, cb)
	var q := Vector2(point.x, point.z) + Vector2(light_dir.x, light_dir.z) / sun_y * (layer - point.y)
	var d := wrap_delta(q, Vector2(c.x, c.z), kind_of(slot))
	if d.length() > radii[slot] * lerpf(CUMULUS_REACH, STORM_REACH, cb):
		return 0.0
	var dist := footprint_distance(slot, d)
	return smoothstep(1.0, 0.8, dist) * weights[slot] * lerpf(CUMULUS_OPACITY, STORM_OPACITY, cb)


## Normalised footprint distance (1 = edge) at offset `d` from the cell centre:
## the noise-free mirror of cell_footprint() in the shader include.
func footprint_distance(slot: int, d: Vector2) -> float:
	var cb := storminess(slot)
	var seed := seeds[slot]
	var age := smoothstep(0.35, 1.0, lives[slot]) * (1.0 - cb)
	var r := radii[slot] * lerpf(CUMULUS_FOOTPRINT, STORM_FOOTPRINT, cb)
	var ax := Vector2.from_angle(fposmod(seed * 13.7, 1.0) * 3.14159)
	var u := Vector2(d.dot(ax), d.dot(Vector2(-ax.y, ax.x))) / maxf(r, 1.0)
	u.x /= lerpf(0.9, 1.3, fposmod(seed * 5.3, 1.0)) * lerpf(1.0, 1.2, cb)
	var dist := 1e3
	for k in LOBES:
		var lobe := _lobe(k, seed, cb, age)
		dist = _smin(dist, (u - Vector2(lobe.x, lobe.y)).length() / lobe.z, 0.35 * (1.0 - cb) + 0.001)
	return dist


## Mirror of cell_lobe() in the shader include: offset (x R), radius and top share.
static func _lobe(k: int, seed: float, cb: float, age: float) -> Vector4:
	if k == 0:
		return Vector4(0.0, 0.0, lerpf(0.8, 1.0, cb), 1.0)
	var fk := float(k)
	var side := 1.0 if k == 1 else -1.0
	var along := side * (0.5 + fposmod(seed * (17.3 + 9.1 * fk), 1.0) * 0.4)
	var across := (fposmod(seed * (31.7 + 5.3 * fk), 1.0) - 0.5) * 0.6
	var off := Vector2(along, across) * (1.0 + 0.3 * age) * (1.0 - cb)
	var r := lerpf(lerpf(0.5, 0.82, fposmod(seed * (7.9 + 3.3 * fk), 1.0)), 1.0, cb)
	var top := lerpf(lerpf(0.45, 0.9, fposmod(seed * (11.3 + 2.9 * fk), 1.0)), 1.0, cb)
	return Vector4(off.x, off.y, r, top)


static func _smin(x: float, y: float, k: float) -> float:
	var h := maxf(k - absf(x - y), 0.0) / k
	return minf(x, y) - h * h * k * 0.25


## Storm slots, and cumulus merged into a mature tower (R-1481), that can throw
## lightning right now.
func mature_storm_cells() -> Array[int]:
	var out: Array[int] = []
	for slot in CUMULUS_SLOTS:
		if towers[slot] >= TOWER_MATURE and weights[slot] >= STORM_MATURE_WEIGHT:
			out.append(slot)
	for slot in range(CUMULUS_SLOTS, SLOTS):
		var life := lives[slot]
		if (
			weights[slot] >= STORM_MATURE_WEIGHT
			and life >= STORM_MATURE_LIFE.x
			and life <= STORM_MATURE_LIFE.y
		):
			out.append(slot)
	return out


## Strongest merged-tower level among visible cumulus (0 when none has merged),
## scaled by the tower's weight. Drives tower thunder and rain.
func max_tower() -> float:
	var best := 0.0
	for slot in CUMULUS_SLOTS:
		best = maxf(best, towers[slot] * weights[slot])
	return best


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
