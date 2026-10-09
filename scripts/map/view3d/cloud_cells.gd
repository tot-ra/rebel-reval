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
## nearest to the camera and fade ordinary cells before the wrap seam (storm
## cells tile a wider STORM_DOMAIN). Storming copies also draw from further away.
##
## R-1481: cumulus are lobed and stretched by the wind (shader side), each one
## rides the wind at its own speed and slight veer so clouds overtake and meet,
## an ageing cloud spreads, shrinks and tatters before it fades, and cumulus that
## crowd together merge into a towering thunderstorm (`towers`) that can rain and
## throw lightning. Still a pure function of the same inputs plus the smoothed
## wind strength, which the weather state already saves.
##
## R-1495: a cloudy sky carries more cumulus (20 slots), so a thunderstorm needs a
## really crowded patch of sky, and towers no longer look like clones. Each tower
## draws its own height gain and keeps part of its lobes, and every periodic copy
## of the cumulus tile gets its own shape seed (hashed from its absolute tile, so
## it never pops).
##
## R-1501: a merged cluster only becomes a thunderstorm in the copy that sits in a
## convective hotspot. Hotspots lie on a HOT_SPACING lattice (three cumulus tiles)
## that drifts with the wind, so the same cluster stays ordinary cumulus in its
## other copies and the player sees at most one storm per hotspot instead of one
## wherever they stand. That leaves room for storms as wide as real
## cumulonimbus (TOWER_RADIUS), which the 3.2 km tile could not hold as copies.

## Fair-weather cumulus slots, then cumulonimbus slots, in one packed array.
const CUMULUS_SLOTS := 20
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
## becomes a storm in its hotspot copy (R-1501): it widens to TOWER_RADIUS, rises
## to TOWER_HEIGHT, its base drops toward TOWER_BASE, and it is pulled toward its
## neighbours' centroid so the cluster fuses into one thunderstorm mass.
const TOWER_TOUCH := 0.55
const TOWER_APART := 1.1
## R-1501: back to the R-1481 ramp: a cluster now also needs a hotspot to storm.
const TOWER_CROWDING := Vector2(1.35, 2.0)
## R-1501: a storm is the merged mass of a cumulus cluster, sized like the native
## storm slots (real cumulonimbus are several kilometres across, art-compressed):
## per generation a radius and top height from these ranges. R-1495 towers were
## 0.3-0.6 km wide and read as narrow columns.
const TOWER_RADIUS := Vector2(900.0, 1500.0)
const TOWER_HEIGHT := Vector2(1100.0, 2000.0)
## R-1495: a merged tower folds its lobes only this far (storm slots fold fully),
## so it stays a cluster of turrets rather than a round dome. Mirrors
## CELL_TOWER_LOBE_FOLD.
const TOWER_LOBE_FOLD := 0.45
const TOWER_BASE := 480.0
const TOWER_PULL := 0.45
## R-1501: within one merging cluster only the most crowded cloud grows into the
## storm; the others shrink into its base. Leadership blends over this score
## margin, so a change of leader never pops.
const TOWER_LEAD := 0.25
## A tower at least this far merged can rain and charge lightning.
const TOWER_MATURE := 0.75
## R-1493: towers draw copies of the periodic field beyond the nearest one, full
## strength through 5 km and zero at 6 km. A 5x5 neighbourhood covers the circle
## from any camera position, including both sides of a wrap seam.
const TOWER_FADE := Vector2(5000.0, 6000.0)
const TOWER_COPIES := 25
## R-1501: convective hotspots. A cumulus copy storms by towers x hot_at(copy):
## full inside HOT_RADIUS.x of a hotspot, none beyond HOT_RADIUS.y. HOT_RADIUS.y
## stays under half a cumulus tile, so at most one copy of a cluster storms per
## hotspot; HOT_SPACING (three tiles) keeps hotspots one view radius apart. The
## lattice rides the base cloud drift; cumulus ride 1.8-3.6x faster and pass
## through. Mirrors CELL_HOT_SPACING / CELL_HOT_RADIUS.
const HOT_SPACING := 9600.0
const HOT_RADIUS := Vector2(700.0, 1400.0)
const HOT_ORIGIN := Vector2(2100.0, 5300.0)
## Absolute tile coordinates wrap at this count; packed into the free uniform lane.
const TILE_WRAP := 64
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
const STORM_REACH := 2.4
const LOBES := 3
## vec4 per slot in uniforms(); matches CELL_STRIDE in the shader include.
const STRIDE := 4
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
## R-1495: absolute tile of each cumulus centre (mod TILE_WRAP), so a periodic copy
## keeps its own shape seed while the wrapped centre crosses the tile seam.
var tiles := PackedVector2Array()
## R-1501: what each cumulus becomes in a hotspot copy: centre offset toward its
## cluster, radius and top height (fair values when it is not merging).
var tower_pulls := PackedVector2Array()
var tower_radii := PackedFloat32Array()
var tower_heights := PackedFloat32Array()
## R-1501: one hotspot centre, wrapped into [0, HOT_SPACING).
var hot_centre := HOT_ORIGIN


func _init() -> void:
	centers.resize(SLOTS)
	radii.resize(SLOTS)
	heights.resize(SLOTS)
	weights.resize(SLOTS)
	lives.resize(SLOTS)
	seeds.resize(SLOTS)
	towers.resize(SLOTS)
	tiles.resize(SLOTS)
	tower_pulls.resize(SLOTS)
	tower_radii.resize(SLOTS)
	tower_heights.resize(SLOTS)


static func kind_of(slot: int) -> int:
	return KIND_STORM if slot >= CUMULUS_SLOTS else KIND_CUMULUS


## How many cumulus and cumulonimbus cells a weather profile shows. Fractions fade
## the next slot in, so a weather transition grows or thins the field smoothly.
## Cumulus are a blue-sky cloud: they peak at moderate cover and, once a deck closes,
## are gone (the sky shader darkens the remaining ones toward rain-bearing grey, see
## cloud_gloom). Cumulonimbus need real storm development.
static func counts_for(coverage: float, storm: float) -> Vector2:
	var deck := smoothstep(0.6, 0.92, coverage)
	# R-1495: none below 0.08 (a cloudless sky); about 8 on a `clear` day (0.30) as
	# before, while a cloudy sky fills all 20 slots before its deck closes.
	var cumulus := float(CUMULUS_SLOTS) * clampf((coverage - 0.08) / 0.55, 0.0, 1.0)
	cumulus *= 1.0 - deck
	var storms := float(STORM_SLOTS) * smoothstep(0.3, 1.0, storm)
	return Vector2(cumulus, storms)


## Rebuilds every slot for this instant. `drift` is the shared cloud offset in UV
## units (SkyWeather3D.cloud_offset()), so cells move with the dome and the wind.
## `wind` (0..1, the smoothed drift strength) stretches and shears the cumulus.
func update(clock: float, drift: Vector2, counts: Vector2, wind: float = 0.0) -> void:
	var shift := drift * METRES_PER_UV
	windiness = clampf(wind, 0.0, 1.0)
	hot_centre = Vector2(
		fposmod(HOT_ORIGIN.x + shift.x, HOT_SPACING), fposmod(HOT_ORIGIN.y + shift.y, HOT_SPACING)
	)
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
		tiles[slot] = _tile_of(spawn, Vector2.ZERO)
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
	for slot in SLOTS:
		tower_pulls[slot] = Vector2.ZERO
		tower_radii[slot] = radii[slot]
		tower_heights[slot] = heights[slot]
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
	var scores := PackedFloat32Array()
	scores.resize(CUMULUS_SLOTS)
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
		scores[i] = crowding * weights[i]
		pulls.append(pull / pull_weight if pull_weight > 0.0 else Vector2.ZERO)
	for i in CUMULUS_SLOTS:
		var tower := levels[i]
		if tower <= 0.0:
			continue
		towers[i] = tower
		# R-1501: the geometry is applied per copy by hot_at(), so the fair
		# centre, radius and height stay as they are for every other copy.
		var best_other := -INF
		for j in CUMULUS_SLOTS:
			if j == i or levels[j] <= 0.0:
				continue
			var gap := wrap_delta(flat[j], flat[i]).length()
			if gap < (radii[i] + radii[j]) * TOWER_APART * 2.0:
				best_other = maxf(best_other, scores[j])
		var lead := 1.0 if best_other == -INF else smoothstep(
			-TOWER_LEAD, TOWER_LEAD, scores[i] - best_other
		)
		var seed := seeds[i]
		var radius := lerpf(TOWER_RADIUS.x, TOWER_RADIUS.y, fposmod(seed * 3.7, 1.0))
		var top := lerpf(TOWER_HEIGHT.x, TOWER_HEIGHT.y, fposmod(seed * 4.1, 1.0))
		tower_pulls[i] = pulls[i] * TOWER_PULL
		tower_radii[i] = lerpf(radii[i] * 0.5, radius, lead)
		tower_heights[i] = lerpf(heights[i], top, lead)


## R-1501: 0..1 how strongly a point is inside a convective hotspot. Mirrors
## cell_hot() in the shader include.
func hot_at(p: Vector2) -> float:
	var q := p - hot_centre
	q -= (q / HOT_SPACING).round() * HOT_SPACING
	return smoothstep(HOT_RADIUS.y, HOT_RADIUS.x, q.length())


## Fair-copy centre of cumulus `slot` nearest to `p`.
func fair_copy_near(slot: int, p: Vector2) -> Vector2:
	var c := centers[slot]
	return p + wrap_delta(Vector2(c.x, c.z), p)


## R-1501: the copy of `slot` whose fair centre is `fair`, as drawn:
## [x, base, z, radius, height, storminess, seed, lobe fold]. A cumulus copy storms
## by towers x hot_at(fair) and moves, widens and rises toward its tower shape by
## that much. Mirrors cell_copy_shape() in the shader include.
func copy_shape(slot: int, fair: Vector2) -> PackedFloat32Array:
	var c := centers[slot]
	if kind_of(slot) == KIND_STORM:
		return PackedFloat32Array([
			fair.x, c.y, fair.y, radii[slot], heights[slot], 1.0, seeds[slot], 1.0,
		])
	var t := towers[slot] * hot_at(fair)
	var centre := fair + tower_pulls[slot] * t
	return PackedFloat32Array([
		centre.x, lerpf(c.y, TOWER_BASE, t), centre.y,
		lerpf(radii[slot], tower_radii[slot], t), lerpf(heights[slot], tower_heights[slot], t),
		t, copy_seed(slot, fair), t * TOWER_LOBE_FOLD,
	])


## R-1501: storm level of a cumulus slot's strongest copy (the one nearest a
## hotspot; the hotspot lattice is three tiles, so that copy is the same for every
## hotspot). 1 for storm slots. Drives lightning, thunder and rain.
func tower_level(slot: int) -> float:
	if kind_of(slot) == KIND_STORM:
		return 1.0
	if towers[slot] <= 0.0:
		return 0.0
	return towers[slot] * hot_at(fair_copy_near(slot, hot_centre))


## Fair centre of the storming copy of `slot` nearest to `eye`: the copy in the
## hotspot closest to the eye.
func tower_copy_centre(slot: int, eye: Vector2) -> Vector2:
	var q := hot_centre - eye
	q -= (q / HOT_SPACING).round() * HOT_SPACING
	return fair_copy_near(slot, eye + q)


## Absolute tile (mod TILE_WRAP) of unwrapped position `p`, counted on from `base`.
static func _tile_of(p: Vector2, base: Vector2) -> Vector2:
	return Vector2(
		posmod(int(base.x) + floori(p.x / DOMAIN), TILE_WRAP),
		posmod(int(base.y) + floori(p.y / DOMAIN), TILE_WRAP)
	)


## Stable label of the periodic copy of `slot` centred at world `copy_centre`: its
## tile step from the wrapped centre minus the tiles the cloud has drifted. When
## the drift carries the centre over the seam both terms grow by one, so a copy
## keeps its label. Mirrors cell_copy_tile() in the shader include.
func copy_tile(slot: int, copy_centre: Vector2) -> Vector2:
	var c := centers[slot]
	var step := ((copy_centre - Vector2(c.x, c.z)) / DOMAIN).round()
	return Vector2(
		fposmod(step.x - tiles[slot].x, float(TILE_WRAP)),
		fposmod(step.y - tiles[slot].y, float(TILE_WRAP))
	)


## 0..1 hash of a copy's absolute tile, the slot seed and a salt. Small inputs keep
## the float32 GPU result within ~1e-4 of this one. Mirrors cell_copy_hash().
static func copy_hash(tile: Vector2, seed: float, salt: float) -> float:
	var p := Vector3(tile.x, tile.y, seed * 61.0 + salt)
	p = Vector3(fposmod(p.x * 0.1031, 1.0), fposmod(p.y * 0.1031, 1.0), fposmod(p.z * 0.1031, 1.0))
	var dd := p.dot(Vector3(p.z, p.y, p.x) + Vector3.ONE * 3.33)
	p += Vector3.ONE * dd
	return fposmod((p.x + p.y) * p.z, 1.0)


## Shape seed of a cumulus copy (every periodic copy is its own cloud). Storm
## slots draw one copy and keep their seed.
func copy_seed(slot: int, copy_centre: Vector2) -> float:
	if kind_of(slot) == KIND_STORM:
		return seeds[slot]
	return copy_hash(copy_tile(slot, copy_centre), seeds[slot], 0.0)


## Four vec4 per slot for the `cloud_cells` uniform in cloud_cells.gdshaderinc:
## (x, base, z, radius), (height, weight, kind, seed), (life, tower, windiness, tile)
## where tile packs the absolute tile as x + TILE_WRAP * z (R-1495), and
## (pull x, pull z, tower radius, tower height) (R-1501). A last vec4 carries the
## hotspot centre (x, z, 0, 0).
func uniforms() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(SLOTS * STRIDE + 1)
	for slot in SLOTS:
		var c := centers[slot]
		out[slot * STRIDE] = Vector4(c.x, c.y, c.z, radii[slot])
		out[slot * STRIDE + 1] = Vector4(
			heights[slot], weights[slot], float(kind_of(slot)), seeds[slot]
		)
		var tile := tiles[slot]
		out[slot * STRIDE + 2] = Vector4(
			lives[slot], towers[slot], windiness, tile.x + float(TILE_WRAP) * tile.y
		)
		var pull := tower_pulls[slot]
		out[slot * STRIDE + 3] = Vector4(pull.x, pull.y, tower_radii[slot], tower_heights[slot])
	out[SLOTS * STRIDE] = Vector4(hot_centre.x, hot_centre.y, 0.0, 0.0)
	return out


## CPU mirrors of the shared shader visibility helpers. Copy 0 is nearest;
## distant copies are presentation only, not extra simulated/cloud uniform slots.
static func view_copy_offset(copy: int) -> Vector2:
	var grid := 12 if copy == 0 else (0 if copy == 12 else copy)
	return Vector2(float(grid % 5 - 2), float(floori(float(grid) / 5.0) - 2)) * DOMAIN


static func view_fade(distance: float, kind: int, tower: float) -> float:
	var domain := STORM_DOMAIN if kind == KIND_STORM else DOMAIN
	var near_fade := 1.0 - smoothstep(0.36 * domain, 0.5 * domain, distance)
	if kind == KIND_STORM:
		return near_fade
	var far_fade := 1.0 - smoothstep(TOWER_FADE.x, TOWER_FADE.y, distance)
	return lerpf(near_fade, far_fade, smoothstep(0.5, TOWER_MATURE, tower))


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
	var to_light := Vector2(light_dir.x, light_dir.z) / sun_y
	var flat := Vector2(point.x, point.z)
	var layer := c.y + heights[slot] * (0.25 if storm else 0.35)
	var q := flat + to_light * (layer - point.y)
	var near := q - wrap_delta(q, Vector2(c.x, c.z), kind_of(slot))
	# R-1501: a storming copy is wider than half a tile and pulled off its fair
	# centre, so a merging cumulus checks the 3x3 copies around the nearest one.
	var spread := 1 if storm or towers[slot] <= 0.0 else 3
	var half := float(spread - 1) * 0.5
	var best := 0.0
	for k in spread * spread:
		var cell := Vector2(float(k % spread), floorf(float(k) / float(spread))) - Vector2.ONE * half
		var fair := near + cell * DOMAIN
		var shape := copy_shape(slot, fair)
		var cb := shape[5]
		layer = shape[1] + shape[4] * lerpf(0.35, 0.25, cb)
		var d := flat + to_light * (layer - point.y) - Vector2(shape[0], shape[2])
		if d.length() > shape[3] * lerpf(CUMULUS_REACH, STORM_REACH, shape[7]):
			continue
		var dist := _footprint(d, shape, lives[slot])
		best = maxf(best, smoothstep(1.0, 0.8, dist) * lerpf(CUMULUS_OPACITY, STORM_OPACITY, cb))
	return best * weights[slot]


## Normalised footprint distance (1 = edge) at offset `d` from the centre of the
## fair copy of `slot` (no tower): the noise-free mirror of cell_footprint().
## `seed` is the copy's shape seed (copy_seed); negative takes the slot seed.
func footprint_distance(slot: int, d: Vector2, seed: float = -1.0) -> float:
	var c := centers[slot]
	var cb := 1.0 if kind_of(slot) == KIND_STORM else 0.0
	var shape := PackedFloat32Array([
		c.x, c.y, c.z, radii[slot], heights[slot], cb, seeds[slot] if seed < 0.0 else seed, cb,
	])
	return _footprint(d, shape, lives[slot])


## Footprint distance of the copy whose fair centre is `fair`, at offset `d` from
## its drawn centre.
func copy_footprint(slot: int, fair: Vector2, d: Vector2) -> float:
	return _footprint(d, copy_shape(slot, fair), lives[slot])


## Mirror of cell_footprint(): `shape` is a copy_shape() array.
static func _footprint(d: Vector2, shape: PackedFloat32Array, life: float) -> float:
	var cb := shape[5]
	var seed := shape[6]
	var fold := shape[7]
	var age := smoothstep(0.35, 1.0, life) * (1.0 - cb)
	var r := shape[3] * lerpf(CUMULUS_FOOTPRINT, STORM_FOOTPRINT, cb)
	var ax := Vector2.from_angle(fposmod(seed * 13.7, 1.0) * 3.14159)
	var u := Vector2(d.dot(ax), d.dot(Vector2(-ax.y, ax.x))) / maxf(r, 1.0)
	u.x /= lerpf(0.9, 1.3, fposmod(seed * 5.3, 1.0)) * lerpf(1.0, 1.2, cb)
	var dist := 1e3
	for k in LOBES:
		var lobe := _lobe(k, seed, fold, age)
		dist = _smin(dist, (u - Vector2(lobe.x, lobe.y)).length() / lobe.z, 0.35 * (1.0 - fold) + 0.001)
	return dist


## Mirror of cell_lobe() in the shader include: offset (x R), radius and top share.
## `cb` is the lobe fold (copy_shape()[7]), not the storminess.
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
		if tower_level(slot) >= TOWER_MATURE and weights[slot] >= STORM_MATURE_WEIGHT:
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


## Strongest storming copy among cumulus (0 when none storms in a hotspot),
## scaled by the cloud's weight. Drives tower thunder.
func max_tower() -> float:
	var best := 0.0
	for slot in CUMULUS_SLOTS:
		best = maxf(best, tower_level(slot) * weights[slot])
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
