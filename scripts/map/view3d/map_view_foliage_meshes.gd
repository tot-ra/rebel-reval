class_name MapViewFoliageMeshes
extends RefCounted

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

## Cached procedural tree canopy and ground foliage meshes.
static var _mesh_cache: Dictionary = {}


## Three stacked, slightly offset cone tiers with a small top spike: a spruce
## silhouette with layered skirts instead of a single flat cone. Local y spans
## 0 (skirt) to about 2.9 (tip).


static func spruce_canopy_mesh() -> ArrayMesh:
	const CACHE_KEY := &"spruce_canopy"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := [
		[0.95, 0.0, 1.2],
		[0.74, 0.7, 1.1],
		[0.52, 1.4, 1.0],
		[0.28, 2.1, 0.8],
	]
	for tier_index in tiers.size():
		var tier: Array = tiers[tier_index]
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[2]
		cone.radial_segments = 9
		cone.rings = 1
		var offset := Vector3(
			(MeshMath.hash01(tier_index, 1, 97) - 0.5) * 0.12,
			float(tier[1]) + float(tier[2]) * 0.5,
			(MeshMath.hash01(tier_index, 5, 131) - 0.5) * 0.12
		)
		surface.append_from(cone, 0, Transform3D(Basis.IDENTITY, offset))
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Broadleaf canopy: several overlapping lobes merged into one lumpy crown
## centered near the local origin, replacing the single smooth sphere.


static func leaf_canopy_mesh() -> ArrayMesh:
	const CACHE_KEY := &"leaf_canopy"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.1, 0.0), 0.72],
		[Vector3(0.42, -0.08, 0.14), 0.5],
		[Vector3(-0.38, -0.02, 0.3), 0.54],
		[Vector3(0.08, 0.42, -0.3), 0.5],
		[Vector3(-0.12, 0.34, 0.34), 0.46],
		[Vector3(0.16, -0.18, -0.4), 0.48],
	]
	for lobe: Array in lobes:
		var sphere := SphereMesh.new()
		sphere.radius = lobe[1]
		sphere.height = float(lobe[1]) * 1.8
		sphere.radial_segments = 10
		sphere.rings = 6
		surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY, lobe[0]))
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Scots pine: fewer, lofted umbrella tiers with a clearer stem gap than spruce.
## Local y spans roughly 0.35 (lowest skirt) to 2.7 (tip).
static func pine_canopy_mesh() -> ArrayMesh:
	const CACHE_KEY := &"pine_canopy"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := [
		[0.78, 0.35, 0.85],
		[0.62, 0.95, 0.78],
		[0.4, 1.55, 0.7],
		[0.18, 2.1, 0.55],
	]
	for tier_index in tiers.size():
		var tier: Array = tiers[tier_index]
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[2]
		cone.radial_segments = 8
		cone.rings = 1
		var offset := Vector3(
			(MeshMath.hash01(tier_index, 3, 101) - 0.5) * 0.16,
			float(tier[1]) + float(tier[2]) * 0.5,
			(MeshMath.hash01(tier_index, 7, 149) - 0.5) * 0.16
		)
		surface.append_from(cone, 0, Transform3D(Basis.IDENTITY, offset))
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Birch/aspen column: taller stacked lobes, narrower than the oak/maple crown.
static func column_canopy_mesh() -> ArrayMesh:
	const CACHE_KEY := &"column_canopy"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.05, 0.0), 0.48],
		[Vector3(0.22, 0.35, 0.08), 0.38],
		[Vector3(-0.2, 0.55, -0.1), 0.36],
		[Vector3(0.06, 0.95, 0.12), 0.34],
		[Vector3(-0.08, 1.25, -0.06), 0.3],
		[Vector3(0.04, 1.55, 0.02), 0.24],
	]
	for lobe: Array in lobes:
		var sphere := SphereMesh.new()
		sphere.radius = lobe[1]
		sphere.height = float(lobe[1]) * 2.05
		sphere.radial_segments = 9
		sphere.rings = 5
		surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY, lobe[0]))
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func canopy_mesh_for(silhouette: StringName) -> ArrayMesh:
	match silhouette:
		&"spruce":
			return spruce_canopy_mesh()
		&"pine":
			return pine_canopy_mesh()
		&"column":
			return column_canopy_mesh()
		_:
			return leaf_canopy_mesh()


static func grass_tuft_mesh() -> ArrayMesh:
	const CACHE_KEY := &"grass_tuft"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_count := 7
	for blade in blade_count:
		var yaw := TAU * float(blade) / float(blade_count) + MeshMath.hash01(blade, 3, 17) * 0.9
		var lean := 0.10 + MeshMath.hash01(blade, 7, 29) * 0.22
		var blade_height := 0.26 + MeshMath.hash01(blade, 11, 41) * 0.24
		var half_width := 0.020 + MeshMath.hash01(blade, 13, 53) * 0.012
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		var root_center := direction * 0.03
		var tip := root_center + direction * lean + Vector3(0.0, blade_height, 0.0)
		var mid := root_center + direction * lean * 0.45 + Vector3(0.0, blade_height * 0.55, 0.0)
		var normal := Vector3.UP.cross(side).normalized() + Vector3(0.0, 0.4, 0.0)
		normal = normal.normalized()
		var quad := [
			[root_center - side * half_width, Vector2(0.0, 0.0)],
			[root_center + side * half_width, Vector2(1.0, 0.0)],
			[mid + side * half_width * 0.55, Vector2(1.0, 0.55)],
			[mid - side * half_width * 0.55, Vector2(0.0, 0.55)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(normal)
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
		var tip_triangle := [
			[mid - side * half_width * 0.55, Vector2(0.0, 0.55)],
			[mid + side * half_width * 0.55, Vector2(1.0, 0.55)],
			[tip, Vector2(0.5, 1.0)],
		]
		for point in tip_triangle:
			surface.set_normal(normal)
			surface.set_uv(point[1])
			surface.add_vertex(point[0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func reed_stem_mesh() -> ArrayMesh:
	const CACHE_KEY := &"reed_stem"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_sign in [-1.0, 1.0]:
		var half_width := 0.018
		var quad := [
			[Vector3(-half_width * side_sign, 0.0, 0.0), Vector2(0.0, 0.0)],
			[Vector3(half_width * side_sign, 0.0, 0.0), Vector2(1.0, 0.0)],
			[Vector3(half_width * side_sign * 0.6, 0.95, 0.0), Vector2(1.0, 1.0)],
			[Vector3(-half_width * side_sign * 0.6, 0.95, 0.0), Vector2(0.0, 1.0)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3(0.0, 0.0, 1.0))
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## A riverbank cattail cluster distinct from the simple authored reed stem:
## crossed narrow leaves surround several tall stalks with dark seed heads.
## Vertex colors keep the seed heads brown while the instance tint varies the
## green foliage. UV.y still runs root-to-tip for the shared wind shader.
static func cattail_cluster_mesh() -> ArrayMesh:
	const CACHE_KEY := &"cattail_cluster"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalks := [
		[Vector2(-0.12, 0.02), 0.92],
		[Vector2(0.04, -0.08), 1.08],
		[Vector2(0.15, 0.08), 0.84],
	]
	for stalk_index in stalks.size():
		var stalk: Array = stalks[stalk_index]
		var stalk_position: Vector2 = stalk[0]
		var base := Vector3(stalk_position.x, 0.0, stalk_position.y)
		var height: float = stalk[1]
		for yaw in [0.0, PI * 0.5]:
			var side := Vector3(cos(yaw), 0.0, sin(yaw)) * 0.018
			var stem_top := base + Vector3(0.0, height - 0.16, 0.0)
			var stem := [
				[base - side, Vector2(0.0, 0.0)],
				[base + side, Vector2(1.0, 0.0)],
				[stem_top + side, Vector2(1.0, 0.82)],
				[stem_top - side, Vector2(0.0, 0.82)],
			]
			for index in [0, 1, 2, 0, 2, 3]:
				surface.set_color(Color.WHITE)
				surface.set_normal(Vector3(cos(yaw), 0.15, sin(yaw)).normalized())
				surface.set_uv(stem[index][1])
				surface.add_vertex(stem[index][0])
			var head_bottom := base + Vector3(0.0, height - 0.18, 0.0)
			var head_top := base + Vector3(0.0, height, 0.0)
			var head_side := side * 2.25
			var head := [
				[head_bottom - head_side, Vector2(0.0, 0.82)],
				[head_bottom + head_side, Vector2(1.0, 0.82)],
				[head_top + head_side * 0.72, Vector2(1.0, 1.0)],
				[head_top - head_side * 0.72, Vector2(0.0, 1.0)],
			]
			for index in [0, 1, 2, 0, 2, 3]:
				# HDR vertex tint counterbalances the green blade base color and
				# yields a readable dark-brown seed head after instance tinting.
				surface.set_color(Color(2.25, 0.72, 0.28))
				surface.set_normal(Vector3(cos(yaw), 0.0, sin(yaw)))
				surface.set_uv(head[index][1])
				surface.add_vertex(head[index][0])
	for leaf_index in 7:
		var yaw := TAU * float(leaf_index) / 7.0 + MeshMath.hash01(leaf_index, 5, 301) * 0.45
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		var leaf_height := 0.48 + MeshMath.hash01(leaf_index, 7, 307) * 0.32
		var lean := 0.18 + MeshMath.hash01(leaf_index, 11, 311) * 0.18
		var half_width := 0.022 + MeshMath.hash01(leaf_index, 13, 313) * 0.012
		var root := direction * 0.035
		var middle := root + direction * lean * 0.42 + Vector3.UP * leaf_height * 0.58
		var tip := root + direction * lean + Vector3.UP * leaf_height
		var leaf := [
			[root - side * half_width, Vector2(0.0, 0.0)],
			[root + side * half_width, Vector2(1.0, 0.0)],
			[middle + side * half_width * 0.55, Vector2(1.0, 0.58)],
			[middle - side * half_width * 0.55, Vector2(0.0, 0.58)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_color(Color(0.82, 1.0, 0.66))
			surface.set_normal((direction + Vector3.UP * 0.2).normalized())
			surface.set_uv(leaf[index][1])
			surface.add_vertex(leaf[index][0])
		for point in [leaf[3], leaf[2], [tip, Vector2(0.5, 1.0)]]:
			surface.set_color(Color(0.82, 1.0, 0.66))
			surface.set_normal((direction + Vector3.UP * 0.2).normalized())
			surface.set_uv(point[1])
			surface.add_vertex(point[0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func clover_patch_mesh() -> ArrayMesh:
	const CACHE_KEY := &"clover_patch"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 3:
		var yaw := TAU * float(leaf) / 3.0
		var direction := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-sin(yaw), 0.0, cos(yaw))
		var center := direction * 0.08
		var tip := center + direction * 0.16 + Vector3(0.0, 0.02, 0.0)
		var quad := [
			[center - side * 0.05, Vector2(0.0, 0.0)],
			[center + side * 0.05, Vector2(1.0, 0.0)],
			[tip + side * 0.03, Vector2(1.0, 1.0)],
			[tip - side * 0.03, Vector2(0.0, 1.0)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Landscape ring outside the playable rectangle. Each authored side may
## continue town silhouettes, open water, or an explicit woodland apron with a
## treeline. Unlisted sides render nothing so maps define their own horizon.
