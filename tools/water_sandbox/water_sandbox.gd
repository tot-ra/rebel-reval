extends Node3D

## Water sandbox (docs/SYSTEMS/WATER_SANDBOX.md, task R-1498 / WR-0).
##
## WHY: the sea, surf, foam and spray are tuned inside the full city, where a
## single plate mixes every case (sand, quays, rocks, boats) and a run takes
## minutes. This builds a small synthetic coast from code with one bay per case,
## then runs the *runtime* city water on it: the same CityPlan heightfield API,
## CityTerrainBuilder ground, CityShoreField bake and surf band, CityWorld3D sea
## grid, shore spray and shared water material. Nothing here is a copy of the
## shader or its parameters, so what changes in the sandbox changes in the game.
##
## Bays run west to east along the shore (z = 0, sea to the north at -z, as in
## the city). Every bay is BAY_WIDTH wide; neighbours blend over BAY_BLEND.

const CityWorld3DScript := preload("res://scripts/city/city_world_3d.gd")
const ShoreDebris := preload("res://scripts/map/view3d/map_view_shore_debris.gd")

const BAY_WIDTH := 140.0
const BAY_BLEND := 24.0
const CELL := 2.0
const SEA_EXTENT := 220.0
const LAND_EXTENT := 70.0
const SEED := 1343

## Case id -> description. Order is the west-to-east bay order.
const CASES := {
	"sand": "gentle sand beach (1:30) with an offshore bar and trough",
	"shingle": "steep shingle beach (1:8) with small, medium and large pebbles",
	"boulders": "boulder field, 0.3-3 m rocks in the swash and shallows",
	"stack": "rock platform with a sea stack and a steep headland",
	"quay": "vertical quay wall into 4 m of water (hard edge)",
	"reef": "sand beach behind a submerged rock reef (combination case)",
}

var plan: CityPlan
var world: Node3D
## Case id -> bay centre x (world units).
var bay_centres: Dictionary = {}
## Rocks placed per case: Array of {at: Vector3, diameter: float, stamped: bool}.
var rocks: Dictionary = {}
var _rng := RandomNumberGenerator.new()


static func create() -> Node3D:
	var sandbox: Node3D = load("res://tools/water_sandbox/water_sandbox.gd").new()
	sandbox.name = "WaterSandbox"
	sandbox._build()
	return sandbox


func case_ids() -> Array:
	return CASES.keys()


func _build() -> void:
	_rng.seed = SEED
	var index := 0
	for id: String in CASES:
		bay_centres[id] = BAY_WIDTH * (float(index) + 0.5)
		rocks[id] = []
		index += 1
	plan = _synthetic_plan()
	world = CityWorld3DScript.new()
	world.name = "CityWorld3D"
	world.plan = plan
	add_child(world)
	CityTerrainBuilder.build(plan, world)
	world._build_water()
	_build_rocks()
	_build_pebbles()


## Heights are written straight into a bare CityPlan: the city loads them from
## JSON, the sandbox computes them, every consumer reads the same accessors.
func _synthetic_plan() -> CityPlan:
	var p := CityPlan.new()
	var width := BAY_WIDTH * float(CASES.size())
	var origin := Vector2(-BAY_BLEND, -SEA_EXTENT)
	var nx := int((width + BAY_BLEND * 2.0) / CELL) + 1
	var ny := int((SEA_EXTENT + LAND_EXTENT) / CELL) + 1
	p._nx = nx
	p._ny = ny
	p._cell = CELL
	p._origin = origin
	p.bounds = Rect2(origin, Vector2(float(nx - 1), float(ny - 1)) * CELL)
	p.metres_per_unit = 1.0
	p.data = {}
	_plan_rocks()
	p._heights.resize(nx * ny)
	for j in ny:
		for i in nx:
			var at := origin + Vector2(i, j) * CELL
			p._heights[j * nx + i] = height_at(at)
	return p


## Ground height of the blended bay profiles, plus stamped rock domes.
func height_at(at: Vector2) -> float:
	var ids := CASES.keys()
	var total := 0.0
	var weight := 0.0
	for i in ids.size():
		var centre: float = bay_centres[ids[i]]
		var d := absf(at.x - centre) - BAY_WIDTH * 0.5
		var w := 1.0 - smoothstep(-BAY_BLEND * 0.5, BAY_BLEND * 0.5, d)
		if w <= 0.0:
			continue
		total += _bay_height(ids[i], Vector2(at.x - centre, at.y)) * w
		weight += w
	var h := total / maxf(weight, 0.0001)
	for id: String in rocks:
		for rock: Dictionary in rocks[id]:
			if not rock["stamped"]:
				continue
			var c: Vector3 = rock["at"]
			var r: float = rock["diameter"] * 0.5
			var q := Vector2(at.x - c.x, at.y - c.z).length() / r
			if q < 1.0:
				h = maxf(h, c.y + rock["diameter"] * 0.45 * sqrt(1.0 - q * q))
	return h


## Local bay profile; local.x is relative to the bay centre, local.y is world z.
func _bay_height(id: String, local: Vector2) -> float:
	var z := local.y
	var land := maxf(z, 0.0)
	match id:
		"sand":
			var h := z * 0.034
			h += 0.75 * _gauss(z + 48.0, 9.0) - 0.35 * _gauss(z + 34.0, 7.0)
			h += 0.25 * _gauss(z - 9.0, 4.0)
			return clampf(h, -7.0, 2.2) + land * land * 0.0004
		"shingle":
			var h := z * 0.125 if z > -18.0 else -2.25 + (z + 18.0) * 0.04
			h += 0.45 * _gauss(z - 5.0, 2.5)
			return clampf(h, -8.0, 2.4)
		"boulders":
			return clampf(z * 0.066, -8.0, 2.4)
		"stack":
			var h := z * 0.085
			# Headland: a rock ridge running seaward along the bay's east side.
			var ridge := _gauss(local.x - 45.0, 12.0) * smoothstep(-70.0, 0.0, z)
			h = maxf(h, lerpf(h, 3.2, ridge))
			return clampf(h, -9.0, 4.0)
		"quay":
			# 1.6 m deck, wall face within one height cell, 4 m dredged berth.
			return lerpf(-4.0, 1.6, smoothstep(-1.0, 1.0, z))
		"reef":
			var h := z * 0.03
			h += 0.4 * _gauss(z - 8.0, 4.0)
			return clampf(h, -6.0, 2.0)
	return z * 0.05


static func _gauss(x: float, width: float) -> float:
	return exp(-(x * x) / (width * width))


## Rock positions are decided before the heightfield, because the large ones are
## stamped into it: the shore field and water mesh must see them as obstacles.
func _plan_rocks() -> void:
	# Boulder bay: 0.3-3 m rocks from the swash out to 3 m depth.
	var cx: float = bay_centres["boulders"]
	for k in 70:
		var d := lerpf(0.3, 3.0, pow(_rng.randf(), 1.8))
		var x := cx + _rng.randf_range(-60.0, 60.0)
		var z := _rng.randf_range(-42.0, 6.0)
		_add_rock("boulders", Vector2(x, z), d)
	# Sea stack and a few fallen blocks at its foot.
	cx = bay_centres["stack"]
	_add_rock("stack", Vector2(cx - 15.0, -30.0), 13.0)
	for k in 9:
		var a := _rng.randf() * TAU
		var ring := Vector2(cos(a), sin(a)) * _rng.randf_range(8.0, 13.0)
		_add_rock("stack", Vector2(cx - 15.0, -30.0) + ring, _rng.randf_range(1.0, 2.6))
	# Reef: a band of low rocks 26-36 m offshore that the surf breaks over.
	cx = bay_centres["reef"]
	for k in 46:
		var x := cx + _rng.randf_range(-55.0, 40.0)
		var z := _rng.randf_range(-36.0, -26.0)
		_add_rock("reef", Vector2(x, z), _rng.randf_range(1.6, 3.4))


func _add_rock(id: String, at: Vector2, diameter: float) -> void:
	var base := _base_height(at)
	# Rocks bed in by a third; anything that would tower over a height cell
	# reshapes the ground too, so surf and slosh see it.
	rocks[id].append({
		"at": Vector3(at.x, base - diameter * 0.18, at.y),
		"diameter": diameter,
		"stamped": diameter >= CELL * 0.8,
	})


## Bay height without rock stamps (rocks are planned before the grid exists).
func _base_height(at: Vector2) -> float:
	var saved := rocks.duplicate(true)
	for id: String in rocks:
		rocks[id] = []
	var h := height_at(at)
	rocks = saved
	return h


func _build_rocks() -> void:
	var transforms: Dictionary = {}
	for id: String in rocks:
		for rock: Dictionary in rocks[id]:
			var d: float = rock["diameter"]
			var kind := &"boulder_small" if d < 0.9 else (&"boulder_medium" if d < 2.0 else &"boulder_large")
			if id == "stack":
				kind = &"boulder_barnacled" if d < 6.0 else &"boulder_large"
			var mesh := ShoreDebris.shore_debris_mesh(kind)
			if mesh == null:
				continue
			var size := mesh.get_aabb().size
			var scale := d / maxf(maxf(size.x, size.z), 0.01)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale)
			if id == "stack" and d >= 6.0:
				# A stack is taller than wide: stretch the boulder upward.
				basis = Basis(Vector3.UP, 0.7).scaled(Vector3(scale, scale * 1.9, scale))
			var at: Vector3 = rock["at"]
			if not transforms.has(kind):
				transforms[kind] = [[] as Array[Transform3D], [] as Array[Color]]
			transforms[kind][0].append(Transform3D(basis, at))
			transforms[kind][1].append(Color(0.8, 0.8, 0.82))
	for kind: StringName in transforms:
		var inst := MapViewMeshBuilderPrimitives.multi_mesh(
			"Rocks_%s" % kind, ShoreDebris.shore_debris_mesh(kind),
			transforms[kind][0], transforms[kind][1], null, Vector3.ZERO
		)
		add_child(inst)


## Shingle bay: three 45 m sections of small, medium and large pebbles from the
## berm down into the swash.
func _build_pebbles() -> void:
	var cx: float = bay_centres["shingle"]
	var sections := [[-45.0, 0.5], [0.0, 1.0], [45.0, 1.8]]
	var transforms: Dictionary = {}
	for section: Array in sections:
		for k in 220:
			var x: float = cx + section[0] + _rng.randf_range(-21.0, 21.0)
			var z := _rng.randf_range(-6.0, 7.0)
			var kind := &"pebble_patch_a"
			if k % 3 == 0:
				kind = &"pebble_patch_b" if k % 2 == 0 else &"stone_cluster_a"
			var s: float = section[1] * _rng.randf_range(0.7, 1.3)
			var at := Vector3(x, plan.ground_height(Vector2(x, z)) - 0.02, z)
			if not transforms.has(kind):
				transforms[kind] = [[] as Array[Transform3D], [] as Array[Color]]
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
			transforms[kind][0].append(Transform3D(basis, at))
			transforms[kind][1].append(Color(0.82, 0.8, 0.78))
	for kind: StringName in transforms:
		var mesh := ShoreDebris.shore_debris_mesh(kind)
		if mesh == null:
			continue
		add_child(MapViewMeshBuilderPrimitives.multi_mesh(
			"Pebbles_%s" % kind, mesh, transforms[kind][0], transforms[kind][1], null, Vector3.ZERO
		))


## Camera poses per case: eye and look target in world space.
func shots_for(id: String) -> Dictionary:
	var cx: float = bay_centres[id]
	var shots := {
		"close": [Vector3(cx, 1.7, 7.0), Vector3(cx, 0.0, -26.0), 62.0],
		"side": [Vector3(cx - 34.0, 1.3, 3.0), Vector3(cx + 18.0, 0.1, -5.0), 58.0],
		"wide": [Vector3(cx - 42.0, 17.0, 44.0), Vector3(cx, 0.0, -22.0), 55.0],
		"swim": [Vector3(cx, 0.45, -32.0), Vector3(cx, 0.6, 10.0), 62.0],
		"open": [Vector3(cx, 3.0, -150.0), Vector3(cx + 20.0, 0.0, -420.0), 60.0],
	}
	if id == "stack":
		var s := Vector3(cx - 15.0, 0.0, -30.0)
		shots["close"] = [s + Vector3(-6.0, 1.8, 30.0), s + Vector3(0.0, 1.0, 0.0), 60.0]
	if id == "quay":
		shots["close"] = [Vector3(cx, 3.3, 3.0), Vector3(cx + 4.0, 0.0, -14.0), 62.0]
		shots["side"] = [Vector3(cx - 30.0, 2.4, 1.6), Vector3(cx + 20.0, 0.2, -1.0), 58.0]
	return shots
