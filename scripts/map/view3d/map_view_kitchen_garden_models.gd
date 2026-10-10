class_name MapViewKitchenGardenModels
extends RefCounted

## Peasant kitchen garden (R-1645): raised beds of dark tilled soil edged with low
## woven wattle, planted in rows of cabbage, turnip or onion (the 1343 garden crops
## of tools/city/build_reval_city_plan.py GARDEN_CROPS). Shared by the
## `kitchen_garden` map prop and the farmstead yards of the open city
## (CityFarmland), so both read the same. Model space is metres: beds run along X,
## the origin is the ground centre of the whole patch.

const PlantMeshes := preload("res://scripts/map/view3d/map_view_plant_meshes.gd")
const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

const CROPS: Array[StringName] = [&"cabbage", &"turnip", &"onion"]
## Per crop: (row gap across the bed, plant step along it, mesh width factor,
## mesh height factor). Garden onions are kept low: the shared field mesh at full
## height read as a bamboo stand in a bed this small.
const SPACING := {
	&"cabbage": Vector4(0.4, 0.42, 0.7, 0.85),
	&"turnip": Vector4(0.28, 0.26, 0.75, 0.8),
	&"onion": Vector4(0.22, 0.17, 0.9, 0.5),
}
## Soil crown above ground at the bed centre and at the wattle.
const SOIL_CROWN := 0.17
const SOIL_EDGE := 0.11
const SOIL_COLOR := Color(0.24, 0.17, 0.11)
const SOIL_DRY := Color(0.36, 0.27, 0.18)
const PATH_COLOR := Color(0.4, 0.33, 0.24)
const WATTLE_HEIGHT := 0.2
const STAKE_STEP := 0.2
const WITHY_LAYERS := 3
const STAKE_COLOR := Color(0.42, 0.34, 0.24)
const WITHY_COLOR := Color(0.5, 0.4, 0.27)
## Below this growth the beds are bare, freshly dug soil.
const MIN_GROWTH := 0.05
## Wattle and soil meshes are cached per bed size and one of a few variants, so a
## city full of gardens shares a handful of meshes.
const VARIANTS := 4

static var _cache: Dictionary = {}


## Adds `bed_count` parallel beds of `bed_size` (x length, y width) separated by
## `path` metres of trodden earth. `growth` 0..1 scales the plants (see
## CityFarmland.growth); below MIN_GROWTH the beds are bare. Deterministic for a
## given `seed_id`; neighbouring beds never repeat a crop.
static func add_model(
	root: Node3D,
	seed_id: String,
	bed_size: Vector2,
	bed_count: int,
	path: float,
	growth: float = 1.0,
	draw_range: float = 0.0
) -> void:
	var seed := absi(hash(seed_id))
	var variant := seed % VARIANTS
	var pitch := bed_size.y + path
	var first_crop := (seed / VARIANTS) % CROPS.size()
	if path > 0.0 and bed_count > 1:
		_add_path(root, bed_size.x, pitch * (bed_count - 1), draw_range)
	for index in bed_count:
		var bed := Node3D.new()
		bed.name = "Bed%d" % index
		bed.position.z = (float(index) - float(bed_count - 1) * 0.5) * pitch
		root.add_child(bed)
		var crop: StringName = CROPS[(first_crop + index) % CROPS.size()]
		_mesh_child(bed, "Soil", soil_mesh(bed_size, variant), _soil_material(), draw_range)
		_mesh_child(bed, "Wattle", wattle_mesh(bed_size, variant), _wattle_material(), draw_range)
		if growth >= MIN_GROWTH:
			_add_plants(bed, crop, bed_size, variant, growth, seed + index * 7919, draw_range)
		bed.set_meta(&"crop", crop)


## Total (length, depth) the patch covers, wattle included.
static func patch_size(bed_size: Vector2, bed_count: int, path: float) -> Vector2:
	return Vector2(bed_size.x, bed_size.y * bed_count + path * maxi(bed_count - 1, 0)) + Vector2(0.08, 0.08)  # gdlint: ignore=max-line-length


## Soil height above ground at bed-local (x, z): a mounded crown with shallow
## furrows between the plant rows and small clods. Plants stand on this surface.
static func soil_height(bed_size: Vector2, variant: int, x: float, z: float) -> float:
	var half := bed_size * 0.5
	var across := clampf(absf(z) / maxf(half.y, 0.01), 0.0, 1.0)
	var along := clampf(absf(x) / maxf(half.x, 0.01), 0.0, 1.0)
	var crown := lerpf(SOIL_CROWN, SOIL_EDGE, maxf(pow(across, 3.0), pow(along, 6.0)))
	var clods := (
		MeshMath.hash01(int(floor(x * 12.0)), int(floor(z * 12.0)), 9101 + variant) - 0.5
	) * 0.018
	return crown + clods


static func soil_mesh(bed_size: Vector2, variant: int) -> ArrayMesh:
	var key := "soil/%.2f/%.2f/%d" % [bed_size.x, bed_size.y, variant]
	if _cache.has(key):
		return _cache[key]
	var half := bed_size * 0.5 - Vector2(0.02, 0.02)
	var nx := maxi(int(bed_size.x / 0.07), 4)
	var nz := maxi(int(bed_size.y / 0.06), 4)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var quad: Array[Vector3] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var x := lerpf(-half.x, half.x, float(ix + corner.x) / nx)
				var z := lerpf(-half.y, half.y, float(iz + corner.y) / nz)
				quad.append(Vector3(x, soil_height(bed_size, variant, x, z), z))
			# Wound so generate_normals() points the top at the sky (tested).
			for k: int in [0, 1, 2, 1, 3, 2]:
				var p := quad[k]
				# Crests dry paler than the damp hollows.
				var dry := clampf((p.y - SOIL_EDGE) / (SOIL_CROWN - SOIL_EDGE + 0.02), 0.0, 1.0)
				var tone := 0.9 + MeshMath.hash01(ix, iz, 9203 + variant) * 0.2
				var colour := SOIL_COLOR.lerp(SOIL_DRY, dry * 0.55) * tone
				colour.a = 1.0
				st.set_color(colour)
				st.add_vertex(p)
	# Skirt down to ground so the bed has a body when the wattle has gaps.
	var ring: Array[Vector2] = [
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	]
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var steps := maxi(int(a.distance_to(b) / 0.1), 1)
		for s in steps:
			var p0 := a.lerp(b, float(s) / steps)
			var p1 := a.lerp(b, float(s + 1) / steps)
			var top0 := Vector3(p0.x, soil_height(bed_size, variant, p0.x, p0.y), p0.y)
			var top1 := Vector3(p1.x, soil_height(bed_size, variant, p1.x, p1.y), p1.y)
			var foot0 := Vector3(p0.x, -0.04, p0.y)
			var foot1 := Vector3(p1.x, -0.04, p1.y)
			st.set_color(SOIL_COLOR * 0.85)
			for v: Vector3 in [top0, foot0, top1, top1, foot0, foot1]:
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Low wattle round the bed: stakes every STAKE_STEP and withies woven in front
## of one stake and behind the next, each layer offset by one stake.
static func wattle_mesh(bed_size: Vector2, variant: int) -> ArrayMesh:
	var key := "wattle/%.2f/%.2f/%d" % [bed_size.x, bed_size.y, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331 + variant
	var half := bed_size * 0.5
	var corners: Array[Vector2] = [
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var span := a.distance_to(b)
		var dir := (b - a) / span
		var side := Vector2(-dir.y, dir.x)
		var stakes := maxi(int(round(span / STAKE_STEP)), 1)
		var step := span / stakes
		# The corner stake belongs to the next side, so skip k == stakes.
		for k in stakes:
			var p := a + dir * step * k
			var top := WATTLE_HEIGHT + rng.randf_range(0.02, 0.07)
			var foot := Vector3(p.x, -0.05, p.y)
			var head := Vector3(
				p.x + rng.randf_range(-0.012, 0.012), top, p.y + rng.randf_range(-0.012, 0.012)
			)
			_tube(st, PackedVector3Array([foot, head]), rng.randf_range(0.014, 0.02), 5, _shade(STAKE_COLOR, rng))  # gdlint: ignore=max-line-length
		for layer in WITHY_LAYERS:
			var height := 0.05 + layer * (WATTLE_HEIGHT - 0.08) / maxf(WITHY_LAYERS - 1, 1)
			var points := PackedVector3Array()
			var samples := maxi(int(span / 0.05), 2)
			for s in samples + 1:
				var along := span * float(s) / samples
				var phase := PI * (along / step + float((layer + i) % 2))
				var weave: float = 0.022 * signf(sin(phase)) * minf(absf(sin(phase)) * 3.0, 1.0)
				var p := a + dir * along + side * weave
				points.append(Vector3(p.x, height + rng.randf_range(-0.006, 0.006), p.y))
			_tube(st, points, rng.randf_range(0.011, 0.015), 4, _shade(WITHY_COLOR, rng))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func reset_cache() -> void:
	_cache.clear()


static func _add_plants(
	bed: Node3D,
	crop: StringName,
	bed_size: Vector2,
	variant: int,
	growth: float,
	seed: int,
	draw_range: float
) -> void:
	var spacing: Vector4 = SPACING[crop]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var inner := bed_size - Vector2(0.16, 0.12)
	var rows := maxi(int(inner.y / spacing.x) + 1, 1)
	var per_row := maxi(int(inner.x / spacing.y) + 1, 1)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for r in rows:
		var z := (float(r) - float(rows - 1) * 0.5) * spacing.x
		for c in per_row:
			var x := (float(c) - float(per_row - 1) * 0.5) * spacing.y
			x += rng.randf_range(-0.03, 0.03)
			var zz := z + rng.randf_range(-0.025, 0.025)
			# A few gaps where a seedling failed or was already pulled.
			if rng.randf() < 0.06:
				continue
			var variety := rng.randf_range(0.85, 1.12)
			var width := lerpf(0.55, 1.0, growth) * variety * spacing.z
			var height := maxf(growth, 0.2) * variety * spacing.w
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
			var ground := soil_height(bed_size, variant, x, zz) - 0.015
			transforms.append(Transform3D(basis, Vector3(x, ground, zz)))
			var shade := rng.randf_range(0.88, 1.06)
			colors.append(Color(shade, shade, shade, 1.0))
	if transforms.is_empty():
		return
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Crop_%s" % crop,
		PlantMeshes.mesh_for(crop),
		transforms,
		colors,
		MapViewMaterials.grass_blades(),
		Vector3.ZERO
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if draw_range > 0.0:
		inst.visibility_range_end = draw_range
	bed.add_child(inst)


## Trodden path between the beds: a thin earth sheet, paler than the soil.
static func _add_path(root: Node3D, length: float, depth: float, draw_range: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "Path"
	var plane := PlaneMesh.new()
	plane.size = Vector2(length, depth)
	instance.mesh = plane
	instance.position.y = 0.012
	var material := StandardMaterial3D.new()
	material.albedo_color = PATH_COLOR
	material.roughness = 1.0
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if draw_range > 0.0:
		instance.visibility_range_end = draw_range
	root.add_child(instance)


static func _mesh_child(
	parent: Node3D, node_name: String, mesh: Mesh, material: Material, draw_range: float
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	if draw_range > 0.0:
		instance.visibility_range_end = draw_range
	parent.add_child(instance)


static func _soil_material() -> StandardMaterial3D:
	if _cache.has("soil_material"):
		return _cache["soil_material"]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# The palette constants are authored in sRGB, like the rest of the art.
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	_cache["soil_material"] = material
	return material


static func _wattle_material() -> StandardMaterial3D:
	if _cache.has("wattle_material"):
		return _cache["wattle_material"]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	# Thin rods are seen from both sides at grazing angles.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["wattle_material"] = material
	return material


static func _shade(base: Color, rng: RandomNumberGenerator) -> Color:
	var shade := rng.randf_range(0.82, 1.1)
	return Color(base.r * shade, base.g * shade, base.b * shade)


## Round rod along `points` (same construction as CityFences._tube, kept local so
## the map view layer does not depend on scripts/city).
static func _tube(
	st: SurfaceTool, points: PackedVector3Array, radius: float, sides: int, color: Color
) -> void:
	var count := points.size()
	if count < 2:
		return
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i in count:
		var tangent := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var n1 := ref.cross(tangent).normalized()
		var n2 := tangent.cross(n1)
		var ring := PackedVector3Array()
		var ring_n := PackedVector3Array()
		for k in sides + 1:
			var ang := TAU * float(k) / sides
			var n := n1 * cos(ang) + n2 * sin(ang)
			ring.append(points[i] + n * radius)
			ring_n.append(n)
		rings.append(ring)
		normals.append(ring_n)
	for i in count - 1:
		for k in sides:
			for corner: Vector2i in [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
				Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)
			]:
				st.set_color(color)
				st.set_normal(normals[i + corner.x][k + corner.y])
				st.add_vertex(rings[i + corner.x][k + corner.y])
