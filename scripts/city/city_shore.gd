class_name CityShore
extends Node3D

## Shore dressing along the whole coast (docs/SYSTEMS/CITY_SEA.md): granite
## erratics in the shallows, stone clusters and shingle lenses above the swash,
## wrack lines at the waterline and weed skirts on the seabed. Reuses the
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

static var _block_live := false
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
		inst.visibility_range_end = DRAW_RANGE
		add_child(inst)


## Deterministic placements: {kind, transform, color}. Pure data for tests.
static func placements_for(city_plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := city_plan.bounds
	var nx := int(r.size.x / CELL)
	var nz := int(r.size.y / CELL)
	var per_block := int(BLOCK / CELL)
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
			if h < WEED_BAND.x or h > STONE_BAND.y:
				continue
			if _taken(city_plan, spot):
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
			if h >= SHINGLE_BAND.x and h <= SHINGLE_BAND.y and slope < 0.4:
				if rng.randf() < 0.2 * smoothstep(0.45, 0.65, patch):
					var kind := &"pebble_patch_a" if rng.randf() < 0.6 else &"pebble_patch_b"
					out.append(_item(kind, city_plan, spot, rng, 0.9, 1.3, 0.03, Color(0.74, 0.72, 0.7), true))
					continue
			if h >= STONE_BAND.x and h <= STONE_BAND.y and rng.randf() < 0.012 * (0.4 + cluster):
				var kind := &"stone_cluster_a" if rng.randf() < 0.5 else &"stone_cluster_b"
				out.append(_item(kind, city_plan, spot, rng, 0.85, 1.2, 0.0, Color(0.95, 0.93, 0.92)))
	return out


static func _block_has_coast(city_plan: CityPlan, origin: Vector2) -> bool:
	var low := INF
	var high := -INF
	for dx in 3:
		for dz in 3:
			var h := city_plan.ground_height(origin + Vector2(dx, dz) * (BLOCK * 0.5))
			low = minf(low, h)
			high = maxf(high, h)
	return high >= WEED_BAND.x - 1.0 and low <= STONE_BAND.y + 1.0


static func _add_boulder(
	out: Array[Dictionary], city_plan: CityPlan, spot: Vector2, rng: RandomNumberGenerator, cluster: float
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
		out.append(_item(&"algae_skirt", city_plan, spot + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)), rng, 1.0, 1.6, 0.0, Color(0.85, 0.95, 0.8)))


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
			city_plan.ground_height(spot - Vector2(step, 0.0)) - city_plan.ground_height(spot + Vector2(step, 0.0)),
			2.0 * step,
			city_plan.ground_height(spot - Vector2(0.0, step)) - city_plan.ground_height(spot + Vector2(0.0, step))
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
	for probe: Vector2 in [Vector2.ZERO, Vector2(2.0, 0.0), Vector2(-2.0, 0.0), Vector2(0.0, 2.0), Vector2(0.0, -2.0)]:
		if not is_nan(city_plan.bridge_deck_height(spot + probe)):
			return true
	return false
