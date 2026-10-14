class_name CityWallFootScatter
extends Node3D

## R-1932: real 3D clutter that breaks the straight line where a city wall meets
## the ground, the way games hide that seam. R-1930 (ground band) and R-1931
## (wall band) blend the two surfaces in the shaders; this adds the silhouette:
##   grass clumps  - a dense, unmown 0-0.6 m strip hugging every wall, tallest
##                   next to the wall (nobody scythes into the plinth)
##   tall weeds    - nettle, mugwort, burdock in flower or dry, and dock-like
##                   leaf rosettes (drawn with the burdock rosette model),
##                   mostly at wall corners and on shaded north faces
##   fieldstones   - a few half-buried stones kicked against the plinth
##   wood chips    - small clusters of split-off chips
##   fallen plank  - now and then one weathered board lying along a wall
##   mud ridge     - a low ridge of earth pushed up against the wall foot
## Nothing is placed on the door step span (door_edge/door_t, the same span the
## plinth leaves open), on paving or market stone, on the body of a heavily used
## road (roads.png B wear), inside a neighbouring house or on a site.
##
## Deterministic per building: every draw comes from an RNG seeded by the
## building id and is taken whether or not the spot survives, so the season
## (VegetationPhenology, plants die back in winter) never moves a stone.
## Nothing is saved. Reuses CityForbMeshes (burdock), MapViewPlantMeshes
## (nettle, mugwort) and the grass blade clump; stones, chips, plank and ridge
## are code primitives (no art files, asset freeze P0-040).
##
## Drawing: one MultiMesh per model for every building within RANGE of the
## player, refilled from per-building instance buffers when the player enters a
## new cell (the CityForbs pattern), so the whole strip is about ten draw calls.

const ForbMeshes := preload("res://scripts/city/city_forb_meshes.gd")
const Forbs := preload("res://scripts/city/city_forbs.gd")
const PlantMeshes := preload("res://scripts/map/view3d/map_view_plant_meshes.gd")
const PlantSpecies := preload("res://scripts/map/view3d/map_view_plant_species.gd")

const KIND_GRASS := &"grass"
const KIND_NETTLE := &"nettle"
const KIND_MUGWORT := &"mugwort"
const KIND_STONE := &"stone"
const KIND_CHIP := &"chip"
const KIND_PLANK := &"plank"
const KIND_RIDGE := &"ridge"
const PLANT_KINDS: Array[StringName] = [
	KIND_NETTLE, KIND_MUGWORT, ForbMeshes.KIND_BURDOCK,
	ForbMeshes.KIND_BURDOCK_FLOWERING, ForbMeshes.KIND_BURDOCK_DRY,
]
const ALL_KINDS: Array[StringName] = [
	KIND_GRASS, KIND_NETTLE, KIND_MUGWORT, ForbMeshes.KIND_BURDOCK,
	ForbMeshes.KIND_BURDOCK_FLOWERING, ForbMeshes.KIND_BURDOCK_DRY,
	KIND_STONE, KIND_CHIP, KIND_PLANK, KIND_RIDGE,
]

## Buildings whose footprint lies within this distance of the player are dressed.
const RANGE := 40.0
## The building set is re-read when the player enters a new cell this size.
const CELL := 6.0
## Floats per MultiMesh instance (3x4 transform + colour), as CityForbs.
const STRIDE := 16
const SEED_SALT := 19321

## Strip width from the footprint: the plinth stands 0.08 m proud, so plants
## root just outside it and thin out by STRIP.
const PROUD := 0.1
const STRIP := 0.6
## Sample draws per metre of wall; most become grass clumps.
const SAMPLES_PER_M := 7.0
## Share of samples that become a tall weed: a little everywhere, much more at
## corners (within ~2 m) and on north faces.
const TALL_BASE := 0.03
const TALL_CORNER := 0.32
const TALL_NORTH := 0.14
const STONE_SHARE := 0.035
const CHIP_SHARE := 0.02
const PLANK_CHANCE := 0.22
## Mud ridge pieces: one try per RIDGE_STEP metres of wall.
const RIDGE_STEP := 1.3
const RIDGE_BASE := 0.3
const RIDGE_NORTH := 0.35

## Door step span left clear on the door edge (beyond the door half-width) and
## round the door point on every edge (steps stick out from the wall).
const DOOR_MARGIN := 0.6
const DOOR_CLEAR := 1.3
## Surface limits: paving channel (CityGrass.surface_at r) and the road body /
## wear (CityGrass.road_at r, b) above which a cart road counts as busy.
const PAVED := 0.35
const ROAD_BODY := 0.3
const HEAVY_WEAR := 0.45

## Darker than the footing's CityFooting.FIELDSTONE_TINT: that multiplies a texture,
## these are the whole albedo, and the city's outdoor exposure gain turned
## plinth-level greys into white blobs in the sun.
const STONE_TINTS := [
	Color(0.36, 0.34, 0.31), Color(0.4, 0.35, 0.32), Color(0.31, 0.31, 0.3), Color(0.44, 0.42, 0.37)
]
const CHIP_TINT := Color(0.5, 0.4, 0.27)
const PLANK_TINT := Color(0.3, 0.27, 0.23)
## Packed earth of the R-1930 ground band, a shade darker where it is pushed up.
const RIDGE_TINT := Color(0.36, 0.3, 0.23)

static var _meshes: Dictionary = {}
static var _primitive_material: StandardMaterial3D

var grass: CityGrass
var day_of_year := GameCalendar.day_of_year(GameCalendar.DEFAULT_DATE)
var _cache: Dictionary = {}  # building index -> {kind: PackedFloat32Array}
var _wanted: Array[int] = []
var _cell := Vector2i(0x7fffffff, 0x7fffffff)
var _layers: Dictionary = {}  # kind -> MultiMeshInstance3D
var _dirty := false


static func create(city_grass: CityGrass) -> CityWallFootScatter:
	var node := CityWallFootScatter.new()
	node.name = "WallFootScatter"
	node.grass = city_grass
	for kind: StringName in ALL_KINDS:
		var inst := MultiMeshInstance3D.new()
		inst.name = String(kind).to_pascal_case()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh_for(kind)
		inst.multimesh = multi
		inst.material_override = _material_for(kind)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.visible = false
		node.add_child(inst)
		node._layers[kind] = inst
	return node


## True when the wall-foot weeds stand above ground on `day` (they follow the
## burdock season: up from mid-April, gone after mid-November).
static func plants_up(day: int) -> bool:
	return VegetationPhenology.forb_phase(&"burdock", day) != VegetationPhenology.FORB_NONE


## Weeds grow and die back with the campaign date; stones, chips, planks and the
## ridge stay. Cached buffers are dropped only when the burdock phase changes.
func set_calendar_date(date: Dictionary) -> void:
	var day := GameCalendar.day_of_year(date)
	var old_phase := VegetationPhenology.forb_phase(&"burdock", day_of_year)
	day_of_year = day
	if VegetationPhenology.forb_phase(&"burdock", day) != old_phase:
		_cache.clear()
		_dirty = true


## Builds missing buildings round `world_xz` until `deadline_us` (at least one
## unless `built_any`) and refills the layers when the set changed. Returns true
## while buildings are still missing.
func update_for(world_xz: Vector2, deadline_us: int, built_any: bool) -> bool:
	var cell := Vector2i(floori(world_xz.x / CELL), floori(world_xz.y / CELL))
	if cell != _cell:
		_cell = cell
		_wanted = grass.plan.buildings_near(world_xz, RANGE)
		var plan := grass.plan
		_wanted.sort_custom(func(a: int, b: int) -> bool:
			return plan.footprint(a)[0].distance_squared_to(world_xz) \
				< plan.footprint(b)[0].distance_squared_to(world_xz))
		var keep := {}
		for index in _wanted:
			keep[index] = true
		for index: int in _cache.keys():
			if not keep.has(index):
				_cache.erase(index)
		_dirty = true
	var pending := false
	for index in _wanted:
		if _cache.has(index):
			continue
		if built_any and Time.get_ticks_usec() >= deadline_us:
			pending = true
			break
		_cache[index] = building_buffers(grass, index, day_of_year)
		built_any = true
		_dirty = true
	if _dirty:
		_refill()
		_dirty = false
	return pending


func _refill() -> void:
	var merged: Dictionary = {}
	for kind: StringName in ALL_KINDS:
		merged[kind] = PackedFloat32Array()
	for index: int in _cache:
		var parts: Dictionary = _cache[index]
		for kind: StringName in parts:
			var buf: PackedFloat32Array = merged[kind]
			buf.append_array(parts[kind])
			merged[kind] = buf
	for kind: StringName in ALL_KINDS:
		var inst: MultiMeshInstance3D = _layers[kind]
		var buf: PackedFloat32Array = merged[kind]
		inst.multimesh.instance_count = buf.size() / STRIDE
		if inst.multimesh.instance_count > 0:
			inst.multimesh.buffer = buf
		inst.visible = inst.multimesh.instance_count > 0


## Instances drawn by the layer of `kind` (tests, benchmarks).
func instance_count(kind: StringName) -> int:
	return (_layers[kind] as MultiMeshInstance3D).multimesh.instance_count


## Instance buffers for building `index` on `day`, by model: deterministic, pure
## data (MultiMesh buffer layout, see Forbs._pack).
static func building_buffers(grass: CityGrass, index: int, day: int) -> Dictionary:
	var plan := grass.plan
	var b: Dictionary = plan.buildings[index]
	var ring := plan.footprint(index)
	var out: Dictionary = {}
	var count := ring.size()
	if count < 3:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(b.get("id", str(index)))) + SEED_SALT
	var phase := VegetationPhenology.forb_phase(&"burdock", day)
	var plants := phase != VegetationPhenology.FORB_NONE
	# Door span on its edge, the way CityBuildingBuilder cuts the plinth.
	var door_edge := -1
	var door_t := 0.5
	var door_xy := Vector2.INF
	var door_half := CityBuildingBuilder.door_size(b).x * 0.5 + DOOR_MARGIN
	var door: Variant = b.get("door")
	if door != null:
		door_xy = Vector2(door[0], door[1])
		door_edge = CityBuildingBuilder._closest_edge(ring, door_xy)
		var da := ring[door_edge]
		var dc := ring[(door_edge + 1) % count]
		door_t = clampf(
			(door_xy - da).dot(dc - da) / maxf((dc - da).length_squared(), 0.001), 0.0, 1.0
		)
	var plank_edge := -1
	if rng.randf() < PLANK_CHANCE:
		plank_edge = rng.randi_range(0, count - 1)
	for i in count:
		var a := ring[i]
		var c := ring[(i + 1) % count]
		var length := a.distance_to(c)
		if length < 0.3:
			continue
		var dir := (c - a) / length
		var n := _outward(ring, (a + c) * 0.5, dir)
		# +z is south: an outward normal pointing to -z faces north, into shade.
		var north := clampf(-n.y, 0.0, 1.0)
		var gap := Vector2(-1.0, -1.0)
		if i == door_edge:
			gap = Vector2(door_t * length - door_half, door_t * length + door_half)
		var ctx := {
			"a": a, "dir": dir, "n": n, "length": length, "gap": gap, "door": door_xy,
		}
		# Mud ridge pieces pushed against the wall.
		for k in int(length / RIDGE_STEP):
			var s := (float(k) + rng.randf()) * RIDGE_STEP
			var roll := rng.randf()
			var size := Vector3(
				rng.randf_range(0.7, 1.4), rng.randf_range(0.1, 0.2), rng.randf_range(0.22, 0.38)
			)
			var tone := rng.randf_range(0.85, 1.08)
			if roll >= RIDGE_BASE + RIDGE_NORTH * north:
				continue
			var p := a + dir * s + n * (PROUD + size.z * 0.35)
			if not _spot_ok(grass, ctx, s, p):
				continue
			var h := plan.ground_height(p)
			# Local x runs along the wall (Basis.scaled would scale in world axes).
			var basis := Basis(Vector3.UP, -dir.angle()) * Basis.from_scale(size)
			var damp := 1.0 - 0.12 * north
			_add(out, KIND_RIDGE, Transform3D(basis, Vector3(p.x, h - size.y * 0.15, p.y)),
				RIDGE_TINT * tone * damp)
		if i == plank_edge and length > 2.4:
			_plank(out, grass, ctx, rng)
		for k in int(ceil(length * SAMPLES_PER_M)):
			var s := rng.randf() * length
			var depth := PROUD + pow(rng.randf(), 1.7) * STRIP
			var roll := rng.randf()
			var pick := rng.randf()
			var yaw := rng.randf() * TAU
			var size := rng.randf_range(0.85, 1.3)
			var tone := rng.randf_range(0.86, 1.08)
			var p := a + dir * s + n * depth
			if not _spot_ok(grass, ctx, s, p):
				continue
			var h := plan.ground_height(p)
			var corner := 1.0 - smoothstep(0.4, 2.0, minf(s, length - s))
			var tall := TALL_BASE + TALL_CORNER * corner + TALL_NORTH * north
			if roll < tall:
				if plants:
					_weed(out, p, h, pick, yaw, size, tone, phase)
			elif roll < tall + STONE_SHARE:
				_stone(out, p, h, n, pick, yaw, size)
			elif roll < tall + STONE_SHARE + CHIP_SHARE:
				_chips(out, grass, ctx, s, p, pick, yaw)
			else:
				# Unmown: tallest against the wall, settling to yard height.
				var lift := lerpf(1.9, 1.15, (depth - PROUD) / STRIP) * size
				var basis := Basis(Vector3.UP, yaw).scaled(
					Vector3(sqrt(lift), lift * (0.85 + 0.3 * pick), sqrt(lift))
				)
				var shade := 1.0 - 0.1 * north
				_add(out, KIND_GRASS, Transform3D(basis, Vector3(p.x, h - 0.02, p.y)),
					Color(tone * shade, tone * shade * 1.02, tone * 0.88 * shade))
	return out


## May anything stand at `p` (s metres along the edge in `ctx`)?
static func _spot_ok(grass: CityGrass, ctx: Dictionary, s: float, p: Vector2) -> bool:
	var gap: Vector2 = ctx["gap"]
	if s > gap.x and s < gap.y:
		return false
	var door: Vector2 = ctx["door"]
	if door != Vector2.INF and p.distance_to(door) < DOOR_CLEAR:
		return false
	var plan := grass.plan
	if plan.building_at(p) >= 0 or plan.site_at(p) != null or plan.site_covers(p):
		return false
	if plan.ground_height(p) < 0.4:
		return false
	if grass.surface_at(p).r > PAVED:
		return false
	var road := grass.road_at(p)
	return not (road.r > ROAD_BODY and road.b > HEAVY_WEAR)


## A tall weed: nettle and mugwort stands, burdock (flowering or dry by season)
## and dock-like leaf rosettes.
static func _weed(
	out: Dictionary, p: Vector2, h: float, pick: float, yaw: float, size: float, tone: float,
	phase: StringName
) -> void:
	var kind: StringName
	var scale := size
	if pick < 0.38:
		kind = KIND_NETTLE
		var r := PlantSpecies.scale_range(&"nettle")
		scale = lerpf(r.x, r.y, pick / 0.38) * 1.25
	elif pick < 0.55:
		kind = KIND_MUGWORT
		var r := PlantSpecies.scale_range(&"mugwort")
		scale = lerpf(r.x, r.y, (pick - 0.38) / 0.17) * 1.15
	else:
		# Unscythed wall foot: wildness 0.7 lets about half the burdock flower.
		kind = Forbs._kind_for(&"burdock", (pick - 0.55) / 0.45, 0.7, phase)
		# Smaller than the meadow burdock: a cramped strip, half in the eave shade.
		scale = size * lerpf(0.7, 1.0, pick)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	_add(out, kind, Transform3D(basis, Vector3(p.x, h - 0.01, p.y)), Color(tone, tone, tone * 0.95))


## A half-buried fieldstone, a little tipped towards the wall.
static func _stone(
	out: Dictionary, p: Vector2, h: float, n: Vector2, pick: float, yaw: float, size: float
) -> void:
	var r := lerpf(0.09, 0.2, pick) * size
	var dims := Vector3(r * 1.3, r * 0.75, r)
	var tilt := Basis(Vector3(-n.y, 0.0, n.x), 0.18 * (pick - 0.5))
	var basis := tilt * Basis(Vector3.UP, yaw) * Basis.from_scale(dims)
	var tint: Color = STONE_TINTS[int(pick * 97.0) % STONE_TINTS.size()]
	_add(out, KIND_STONE, Transform3D(basis, Vector3(p.x, h - dims.y * 0.35, p.y)), tint)


## A small scatter of split-off chips round `p`.
static func _chips(
	out: Dictionary, grass: CityGrass, ctx: Dictionary, s: float, p: Vector2, pick: float,
	yaw: float
) -> void:
	var dir: Vector2 = ctx["dir"]
	for j in 3 + int(pick * 4.0):
		var ang := yaw + float(j) * 2.39996
		var off := Vector2.from_angle(ang) * (0.06 + 0.04 * float(j))
		var q := p + off
		if not _spot_ok(grass, ctx, s + off.dot(dir), q):
			continue
		var h := grass.plan.ground_height(q)
		var dims := Vector3(0.05 + 0.03 * fposmod(ang, 1.0), 0.012, 0.022)
		var basis := Basis(Vector3.UP, ang * 1.7).rotated(Vector3(1, 0, 0), 0.12 * sin(ang)) \
			* Basis.from_scale(dims)
		var tone := 0.88 + 0.2 * fposmod(ang * 3.1, 1.0)
		_add(out, KIND_CHIP, Transform3D(basis, Vector3(q.x, h + 0.004, q.y)), CHIP_TINT * tone)


## One weathered board lying along the wall, one end on a stone or tussock.
static func _plank(
	out: Dictionary, grass: CityGrass, ctx: Dictionary, rng: RandomNumberGenerator
) -> void:
	var a: Vector2 = ctx["a"]
	var dir: Vector2 = ctx["dir"]
	var n: Vector2 = ctx["n"]
	var length: float = ctx["length"]
	var board := rng.randf_range(1.1, minf(1.8, length - 0.6))
	var s := rng.randf_range(0.3 + board * 0.5, length - 0.3 - board * 0.5)
	var depth := rng.randf_range(0.25, 0.42)
	var yaw := rng.randf_range(-0.15, 0.15)
	var lift := rng.randf_range(0.0, 0.08)
	var width := rng.randf_range(0.16, 0.24)
	var tone := rng.randf_range(0.85, 1.1)
	var p := a + dir * s + n * depth
	for end: float in [-0.5, 0.5]:
		var q := p + dir * board * end
		if not _spot_ok(grass, ctx, s + board * end, q):
			return
	var h0 := grass.plan.ground_height(p - dir * board * 0.5)
	var h1 := grass.plan.ground_height(p + dir * board * 0.5) + lift
	var along := Vector3(dir.x * board, h1 - h0, dir.y * board)
	var x := along.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x)
	var basis := Basis(x * board, y * 0.035, z * width).rotated(y.normalized(), yaw)
	var mid := Vector3(p.x, (h0 + h1) * 0.5 + 0.015, p.y)
	_add(out, KIND_PLANK, Transform3D(basis, mid), PLANK_TINT * tone)


static func _add(out: Dictionary, kind: StringName, t: Transform3D, c: Color) -> void:
	var buf: PackedFloat32Array = out.get(kind, PackedFloat32Array())
	buf.append_array(Forbs._pack(t, c))
	out[kind] = buf


## Unit normal of a ring edge (direction `dir`, through `p`) pointing outside.
static func _outward(ring: PackedVector2Array, p: Vector2, dir: Vector2) -> Vector2:
	var n := Vector2(-dir.y, dir.x)
	if Geometry2D.is_point_in_polygon(p + n * 0.05, ring):
		n = -n
	return n


## The model of each layer: existing plant meshes, code primitives for the rest.
static func mesh_for(kind: StringName) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		KIND_GRASS:
			mesh = MapViewMeshBuilderPrimitives.grass_blade_clump_mesh()
		KIND_NETTLE, KIND_MUGWORT:
			mesh = PlantMeshes.mesh_for(kind)
		KIND_STONE:
			# Few segments: a faceted fieldstone, not a ball.
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 7
			sphere.rings = 4
			mesh = sphere
		KIND_RIDGE:
			var mound := SphereMesh.new()
			mound.radius = 0.5
			mound.height = 1.0
			mound.radial_segments = 10
			mound.rings = 5
			mesh = mound
		KIND_CHIP, KIND_PLANK:
			mesh = BoxMesh.new()
		_:
			mesh = ForbMeshes.mesh_for(kind)
	if mesh is PrimitiveMesh:
		mesh = _with_vertex_colour(mesh as PrimitiveMesh)
	_meshes[kind] = mesh
	return mesh


## The primitive as an ArrayMesh carrying white vertex colours: without a colour
## array the renderer drew the instance tint as plain white.
static func _with_vertex_colour(primitive: PrimitiveMesh) -> ArrayMesh:
	var arrays := primitive.get_mesh_arrays()
	var colours := PackedColorArray()
	colours.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colours.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _material_for(kind: StringName) -> Material:
	match kind:
		KIND_GRASS, KIND_NETTLE, KIND_MUGWORT:
			# Same as the CityGrass blades and accent plants.
			return MapViewMaterials.grass_blades()
		KIND_STONE, KIND_CHIP, KIND_PLANK, KIND_RIDGE:
			if _primitive_material == null:
				_primitive_material = StandardMaterial3D.new()
				_primitive_material.vertex_color_use_as_albedo = true
				# Tints are authored in sRGB, like CityForestFloor's palette.
				_primitive_material.vertex_color_is_srgb = true
				_primitive_material.roughness = 1.0
				# Dry stone and old wood: no sky sheen (the plank read blue-grey).
				_primitive_material.metallic_specular = 0.15
			return _primitive_material
	return Forbs.material(true)
