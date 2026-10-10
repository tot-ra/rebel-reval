class_name CityShore
extends Node3D

## Shore dressing along the whole coast (docs/SYSTEMS/CITY_SEA.md): granite
## erratics in the shallows, half-buried boulders, stone clusters and pebble beds
## above the swash, glacial erratics on the coastal grass behind the beach, wrack
## lines at the waterline and weed skirts on the seabed. Nothing lands on a cart
## road, paving or a field (R-1606). Reuses the
## district maps' CO-02 meshes (MapViewShoreDebris). Placement is a pure function
## of the plan heightfield, so the same coast always carries the same stones.
## Visual only: no collision (a boulder in the shallows can be swum through).

const ShoreDebris := preload("res://scripts/map/view3d/map_view_shore_debris.gd")
const CELL := 3.0
## Coast probe block (metres): blocks wholly inland or in deep water are skipped.
const BLOCK := 24.0
const CHUNK := 96.0
const DRAW_RANGE := 190.0
const SEED := 7717
## Height bands above the 1343 sea (world units = metres).
const WRACK_BAND := Vector2(0.1, 0.55)
const SHINGLE_BAND := Vector2(0.35, 1.7)
const STONE_BAND := Vector2(0.5, 2.3)
const ERRATIC_BAND := Vector2(-2.4, 0.15)
const WEED_BAND := Vector2(-3.2, -0.25)
## R-1606: coastal land behind the beach; erratics thin out with height.
const HINTERLAND_BAND := Vector2(2.3, 9.0)
## Pebble beds are small: past this they are below a pixel and the ground
## shader's shingle carries the band.
const PEBBLE_DRAW_RANGE := 80.0

static var _block_live := false
## Land-use rasters of the plan, cached per plan file (CityGrass reads the same).
static var _splat: Image
static var _roads: Image
static var _raster_plan := ""
var plan: CityPlan
var counts: Dictionary = {}


static func create(city_plan: CityPlan) -> CityShore:
	var node := CityShore.new()
	node.name = "Shore"
	node.plan = city_plan
	node._build()
	return node


func _build() -> void:
	var placements := placements_for(plan)
	var buckets: Dictionary = {}
	for p: Dictionary in placements:
		var at: Vector3 = (p["transform"] as Transform3D).origin
		var key := [p["kind"], Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))]
		if not buckets.has(key):
			buckets[key] = [[] as Array[Transform3D], [] as Array[Color]]
		buckets[key][0].append(p["transform"])
		buckets[key][1].append(p["color"])
		counts[p["kind"]] = int(counts.get(p["kind"], 0)) + 1
	var keys := buckets.keys()
	keys.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))
	for key: Array in keys:
		var kind: StringName = key[0]
		var mesh := ShoreDebris.shore_debris_mesh(kind)
		if mesh == null:
			continue
		var inst := MapViewMeshBuilderPrimitives.multi_mesh(
			"Shore_%s_%d_%d" % [kind, key[1].x, key[1].y],
			mesh,
			buckets[key][0],
			buckets[key][1],
			null,
			Vector3.ZERO
		)
		inst.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if bool(ShoreDebris.SHORE_DEBRIS_KINDS[kind][2])
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		inst.visibility_range_end = (
			PEBBLE_DRAW_RANGE if kind in [&"pebble_patch_a", &"pebble_patch_b"] else DRAW_RANGE
		)
		add_child(inst)


## Deterministic placements: {kind, transform, color}. Pure data for tests.
static func placements_for(city_plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := city_plan.bounds
	var nx := int(r.size.x / CELL)
	var nz := int(r.size.y / CELL)
	var per_block := int(BLOCK / CELL)
	_load_rasters(city_plan)
	for j in nz:
		for i in nx:
			# Most of the plan is far inland or deep sea: skip whole blocks cheaply.
			if i % per_block == 0 and j % per_block == 0:
				_block_live = _block_has_coast(city_plan, r.position + Vector2(i, j) * CELL)
			if not _block_live:
				continue
			var cell := Vector2i(i, j)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(i, j)) ^ SEED
			var spot := r.position + (Vector2(cell) + Vector2(rng.randf(), rng.randf())) * CELL
			var h := city_plan.ground_height(spot)
			if h < WEED_BAND.x or h > HINTERLAND_BAND.y:
				continue
			if _taken(city_plan, spot):
				continue
			# Above the waterline stones lie on natural ground only.
			if h > WRACK_BAND.x and not _natural_ground(city_plan, spot):
				continue
			var cluster := _noise(spot / 34.0, 1.0)
			var patch := _noise(spot / 22.0, 7.0)
			var slope := city_plan.slope_at(spot)
			var roll := rng.randf()
			if h >= ERRATIC_BAND.x and h <= ERRATIC_BAND.y:
				# Erratics cluster: dense where the cluster noise is high.
				if roll < lerpf(0.004, 0.09, smoothstep(0.55, 0.8, cluster)):
					_add_boulder(out, city_plan, spot, rng, cluster)
					continue
			if h >= WEED_BAND.x and h <= WEED_BAND.y and roll > 0.93 - 0.1 * patch:
				out.append(_item(&"algae_skirt", city_plan, spot, rng, 0.9, 1.5, 0.0, Color(0.9, 1.0, 0.85)))
				continue
			if h >= WRACK_BAND.x and h <= WRACK_BAND.y and rng.randf() < 0.28 * smoothstep(0.35, 0.6, patch):
				var kind := &"wrack_line_a" if rng.randf() < 0.55 else &"wrack_line_b"
				out.append(_item(kind, city_plan, spot, rng, 0.85, 1.2, 0.02, Color(0.95, 0.88, 0.76), true))
				continue
			# Beds lie on the beach sand (splat or the shore strip), not in the turf.
			var on_sand := _raster_at(city_plan, _splat, spot).b > 0.3 or h < 1.0
			if h >= SHINGLE_BAND.x and h <= SHINGLE_BAND.y and slope < 0.4 and on_sand:
				# Pebble beds (3D stones, R-1606) follow the same strands as the ground's
				# shingle; their own density falls off at the rim.
				if rng.randf() < 0.35 * smoothstep(0.4, 0.65, patch):
					var kind := &"pebble_patch_a" if rng.randf() < 0.6 else &"pebble_patch_b"
					out.append(_item(kind, city_plan, spot, rng, 0.85, 1.25, 0.0, _beach_tint(rng), true))
					continue
			if h >= STONE_BAND.x and h <= STONE_BAND.y:
				var stone_roll := rng.randf()
				# Half-buried erratics on the beach: Estonian shores are strewn with them.
				var boulder_p := 0.045 * (0.3 + cluster)
				if stone_roll < boulder_p:
					_add_land_boulder(out, city_plan, spot, rng, 0.85)
					continue
				if stone_roll < boulder_p + 0.08 * (0.4 + cluster):
					var kind := &"stone_cluster_a" if rng.randf() < 0.5 else &"stone_cluster_b"
					out.append(_item(kind, city_plan, spot, rng, 0.85, 1.3, 0.0, _beach_tint(rng)))
					continue
			if h > STONE_BAND.y and h <= HINTERLAND_BAND.y and slope < 0.5:
				# Glacial erratics and cleared stones in the coastal grass, thinning inland.
				var inland := 1.0 - smoothstep(HINTERLAND_BAND.x, HINTERLAND_BAND.y, h)
				var land_roll := rng.randf()
				var erratic_p := 0.03 * inland * (0.3 + cluster)
				if land_roll < erratic_p:
					_add_land_boulder(out, city_plan, spot, rng, 0.6)
				elif land_roll < erratic_p + 0.035 * inland:
					var kind := &"stone_cluster_a" if rng.randf() < 0.5 else &"stone_cluster_b"
					out.append(_item(kind, city_plan, spot, rng, 0.8, 1.15, -0.03, _beach_tint(rng)))
	return out


static func _load_rasters(city_plan: CityPlan) -> void:
	if _raster_plan == city_plan.splat_path() and _splat != null:
		return
	_splat = (load(city_plan.splat_path()) as Texture2D).get_image()
	_roads = (load(city_plan.roads_path()) as Texture2D).get_image()
	for image: Image in [_splat, _roads]:
		if image.is_compressed():
			image.decompress()
	_raster_plan = city_plan.splat_path()


static func _raster_at(city_plan: CityPlan, image: Image, spot: Vector2) -> Color:
	var t := (spot - city_plan.bounds.position) / city_plan.bounds.size * Vector2(image.get_size())
	return image.get_pixel(
		clampi(int(t.x), 0, image.get_width() - 1), clampi(int(t.y), 0, image.get_height() - 1)
	)


## Not a cart road, paving or a ploughed field (same rasters as the ground shader),
## probed a stone's reach round `spot` so nothing overhangs a road edge.
static func _natural_ground(city_plan: CityPlan, spot: Vector2) -> bool:
	for probe: Vector2 in [
		Vector2.ZERO, Vector2(1.5, 0.0), Vector2(-1.5, 0.0), Vector2(0.0, 1.5), Vector2(0.0, -1.5)
	]:
		var at := spot + probe
		if _raster_at(city_plan, _roads, at).r > 0.03:
			return false
		var s := _raster_at(city_plan, _splat, at)
		if s.r > 0.2 or CityGrass.field_share(s) > 0.0:
			return false
	return true


## Dry beach stones: weathered granite grey to limestone buff. The shared granite
## and limestone plates are pale; a stone on the open beach is a mid tone.
static func _beach_tint(rng: RandomNumberGenerator) -> Color:
	return Color(0.66, 0.66, 0.67).lerp(Color(0.8, 0.75, 0.68), rng.randf())


## A dry-land boulder bedded about a quarter of its height in the ground.
static func _add_land_boulder(
	out: Array[Dictionary],
	city_plan: CityPlan,
	spot: Vector2,
	rng: RandomNumberGenerator,
	medium_share: float
) -> void:
	var roll := rng.randf()
	var kind := &"boulder_small"
	if roll > 0.97:
		kind = &"boulder_large"
	elif roll > medium_share:
		kind = &"boulder_medium"
	var scale := rng.randf_range(0.6, 1.3)
	var height := float(ShoreDebris.SHORE_DEBRIS_KINDS[kind][3]) * scale
	out.append(_item(kind, city_plan, spot, rng, scale, scale, -0.25 * height, _beach_tint(rng)))


static func _block_has_coast(city_plan: CityPlan, origin: Vector2) -> bool:
	var low := INF
	var high := -INF
	for dx in 3:
		for dz in 3:
			var h := city_plan.ground_height(origin + Vector2(dx, dz) * (BLOCK * 0.5))
			low = minf(low, h)
			high = maxf(high, h)
	return high >= WEED_BAND.x - 1.0 and low <= HINTERLAND_BAND.y + 1.0


static func _add_boulder(
	out: Array[Dictionary],
	city_plan: CityPlan,
	spot: Vector2,
	rng: RandomNumberGenerator,
	_cluster: float
) -> void:
	var roll := rng.randf()
	var kind := &"boulder_small"
	if roll > 0.93:
		kind = &"boulder_barnacled"
	elif roll > 0.8:
		kind = &"boulder_large"
	elif roll > 0.5:
		kind = &"boulder_medium"
	var wet := Color(0.78, 0.8, 0.82)
	var item := _item(kind, city_plan, spot, rng, 0.8, 1.35, -0.12, wet)
	out.append(item)
	# A weed skirt rides at the foot of most stones in the water.
	if rng.randf() < 0.6:
		out.append(
			_item(
				&"algae_skirt", city_plan,
				spot + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)),
				rng, 1.0, 1.6, 0.0, Color(0.85, 0.95, 0.8)
			)
		)


static func _item(
	kind: StringName,
	city_plan: CityPlan,
	spot: Vector2,
	rng: RandomNumberGenerator,
	scale_min: float,
	scale_max: float,
	lift: float,
	color: Color,
	flat := false
) -> Dictionary:
	var scale := rng.randf_range(scale_min, scale_max)
	var yaw := rng.randf() * TAU
	var basis := Basis(Vector3.UP, yaw)
	var y := city_plan.ground_height(spot) + lift
	if flat:
		# Flat dressing lies on the local slope.
		var step := 0.6
		var normal := Vector3(
			(
				city_plan.ground_height(spot - Vector2(step, 0.0))
				- city_plan.ground_height(spot + Vector2(step, 0.0))
			),
			2.0 * step,
			(
				city_plan.ground_height(spot - Vector2(0.0, step))
				- city_plan.ground_height(spot + Vector2(0.0, step))
			)
		).normalized()
		basis = Basis(Quaternion(Vector3.UP, normal)) * basis
	else:
		basis = basis * Basis(Vector3.RIGHT, (rng.randf() - 0.5) * 0.16)
	return {
		"kind": kind,
		"transform": Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(spot.x, y, spot.y)),
		"color": color,
	}


## Smooth value noise in 0..1 (cheap hash lattice).
static func _noise(p: Vector2, salt: float) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2.ONE * 3.0 - f * 2.0)
	var a := _h(i, salt)
	var b := _h(i + Vector2(1, 0), salt)
	var c := _h(i + Vector2(0, 1), salt)
	var d := _h(i + Vector2(1, 1), salt)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _h(p: Vector2, salt: float) -> float:
	return fposmod(sin(p.dot(Vector2(127.1, 311.7)) + salt * 74.7) * 43758.5453, 1.0)


## Off the foundations, the decks and the landing: no stone through a jetty.
static func _taken(city_plan: CityPlan, spot: Vector2) -> bool:
	if city_plan.building_at(spot) >= 0 or city_plan.site_at(spot) != null:
		return true
	for probe: Vector2 in [
		Vector2.ZERO, Vector2(2.0, 0.0), Vector2(-2.0, 0.0), Vector2(0.0, 2.0), Vector2(0.0, -2.0)
	]:
		if not is_nan(city_plan.bridge_deck_height(spot + probe)):
			return true
	return false
