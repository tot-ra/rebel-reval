class_name MapViewRockMesh
extends RefCounted

## Faceted procedural rock geometry for boulders and loose stones. Replaces the
## smooth SphereMesh instances that only ever read as a texture: real silhouette
## breakup (planar fracture cuts plus low-frequency lumps) is what makes a rock
## read as stone, the material only adds grain on top.

const VARIANTS := 4

static var _cache: Dictionary = {}


## One mesh per (variant, size, detail); MultiMesh layers share them.
## `height` is the full height; the mesh is centred on the origin like the
## SphereMesh it replaces so existing lift offsets keep working.
static func variant(index: int, radius: float, height: float, detail: int) -> ArrayMesh:
	var key := "%d:%.3f:%.3f:%d" % [index, radius, height, detail]
	if _cache.has(key):
		return _cache[key]
	var mesh := _build(9100 + index * 131, radius, height, detail)
	_cache[key] = mesh
	return mesh


## Splits instances round-robin into VARIANTS MultiMesh layers so a field of
## boulders is not one stamped shape.
static func add_variant_layers(
	root: Node3D,
	name: String,
	transforms: Array[Transform3D],
	colors: Array[Color],
	material: Material,
	mesh_lift: Vector3,
	radius: float,
	height: float,
	detail: int
) -> void:
	for v in VARIANTS:
		var subset: Array[Transform3D] = []
		var subset_colors: Array[Color] = []
		for i in range(v, transforms.size(), VARIANTS):
			subset.append(transforms[i])
			subset_colors.append(colors[i])
		if subset.is_empty():
			continue
		root.add_child(
			MapViewMeshBuilderPrimitives.multi_mesh(
				"%s_%d" % [name, v] if v > 0 else name,
				variant(v, radius, height, detail),
				subset,
				subset_colors,
				material,
				mesh_lift
			)
		)


static func _build(rock_seed: int, radius: float, height: float, detail: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	var lumps := FastNoiseLite.new()
	lumps.seed = rock_seed
	lumps.noise_type = FastNoiseLite.TYPE_SIMPLEX
	lumps.frequency = 0.9
	var grain := FastNoiseLite.new()
	grain.seed = rock_seed + 7
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grain.frequency = 2.6

	# Fracture planes: each clips the blob flat, giving the angular faces of
	# broken granite. Upper-hemisphere bias so the crown is faceted while the
	# foot stays a heavy mass.
	var planes: Array[Vector4] = []
	for _i in 10:
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1.0), rng.randf_range(-1, 1))
		n = n.normalized()
		planes.append(Vector4(n.x, n.y, n.z, rng.randf_range(0.58, 0.80)))
	var stretch := Vector3(rng.randf_range(0.9, 1.15), 1.0, rng.randf_range(0.85, 1.1))
	var half := Vector3(radius, height * 0.5, radius) * stretch

	var steps := maxi(detail, 1)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in 6:
		for j in steps:
			for i in steps:
				var p00 := _point(face, i, j, steps, lumps, grain, planes, half)
				var p10 := _point(face, i + 1, j, steps, lumps, grain, planes, half)
				var p01 := _point(face, i, j + 1, steps, lumps, grain, planes, half)
				var p11 := _point(face, i + 1, j + 1, steps, lumps, grain, planes, half)
				_tri(tool, p00, p10, p11)
				_tri(tool, p00, p11, p01)
	# Unindexed triangles + generate_normals = flat facets.
	tool.generate_normals()
	return tool.commit()


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Cube faces are wound consistently below; emit as-is and let culling be off
	# in the rock material as a safety net.
	for p in [a, b, c]:
		tool.set_uv(Vector2(p.x + p.z, p.y + p.z * 0.5))
		tool.add_vertex(p)


static func _point(
	face: int,
	i: int,
	j: int,
	steps: int,
	lumps: FastNoiseLite,
	grain: FastNoiseLite,
	planes: Array[Vector4],
	half: Vector3
) -> Vector3:
	var u := float(i) / float(steps) * 2.0 - 1.0
	var v := float(j) / float(steps) * 2.0 - 1.0
	var cube := Vector3.ZERO
	match face:
		0:
			cube = Vector3(1.0, v, -u)
		1:
			cube = Vector3(-1.0, v, u)
		2:
			cube = Vector3(u, 1.0, -v)
		3:
			cube = Vector3(u, -1.0, v)
		4:
			cube = Vector3(u, v, 1.0)
		_:
			cube = Vector3(-u, v, -1.0)
	var d := cube.normalized()
	var r := 1.0 + 0.26 * lumps.get_noise_3dv(d * 1.7) + 0.07 * grain.get_noise_3dv(d * 3.1)
	for plane in planes:
		var facing := d.x * plane.x + d.y * plane.y + d.z * plane.z
		if facing > 0.05:
			r = minf(r, plane.w / facing)
	var p := d * r * half
	# Sit flat: the underside is hidden in the ground anyway, so truncate it.
	p.y = maxf(p.y, -half.y * 0.55)
	return p
