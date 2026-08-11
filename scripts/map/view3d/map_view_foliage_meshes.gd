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


## A small common-reed bed rather than one camera-facing rectangle. Rounded stems,
## curved leaves, and sparse branching panicles retain a readable silhouette from
## every gameplay angle while remaining one cached mesh for MultiMesh batching.
static func reed_stem_mesh() -> ArrayMesh:
	const CACHE_KEY := &"reed_cluster_v2"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stem_index in 7:
		var yaw := TAU * float(stem_index) / 7.0 + MeshMath.hash01(stem_index, 3, 211) * 0.7
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var radius_from_center := 0.025 + MeshMath.hash01(stem_index, 5, 223) * 0.12
		var base := direction * radius_from_center
		var height := 0.72 + MeshMath.hash01(stem_index, 7, 227) * 0.30
		var lean_direction := Vector3(sin(yaw + 0.65), 0.0, cos(yaw + 0.65))
		var top := (
			base
			+ Vector3.UP * height
			+ lean_direction * (0.035 + MeshMath.hash01(stem_index, 11, 229) * 0.045)
		)
		var stem_color := Color(0.92, 0.94, 0.62).lerp(
			Color(0.72, 0.78, 0.42), MeshMath.hash01(stem_index, 13, 233)
		)
		_add_tapered_stem(surface, base, top, 0.0075, 0.0045, 6, stem_color, 0.0, 0.88)

		for leaf_index in 2:
			var leaf_y := (
				0.10
				+ float(leaf_index) * 0.17
				+ MeshMath.hash01(stem_index, leaf_index, 239) * 0.07
			)
			var leaf_root := base.lerp(top, leaf_y / height)
			var leaf_yaw := (
				yaw
				+ (-0.95 if leaf_index == 0 else 1.15)
				+ MeshMath.hash01(stem_index, leaf_index, 241) * 0.35
			)
			var leaf_direction := Vector3(sin(leaf_yaw), 0.0, cos(leaf_yaw))
			var leaf_height := 0.36 + MeshMath.hash01(stem_index, leaf_index, 251) * 0.24
			var lean := 0.15 + MeshMath.hash01(stem_index, leaf_index, 257) * 0.14
			var half_width := 0.018 + MeshMath.hash01(stem_index, leaf_index, 263) * 0.009
			_add_curved_leaf(
				surface,
				_leaf_curve(leaf_root, leaf_direction, leaf_height, lean),
				PackedFloat32Array(
					[half_width, half_width * 0.92, half_width * 0.68, half_width * 0.34, 0.0]
				),
				Vector3(leaf_direction.z, 0.0, -leaf_direction.x),
				Color(0.82, 0.90, 0.56),
				Color(0.66, 0.72, 0.34),
				0.08,
				0.90
			)

		# Mature reeds carry airy panicles, but leaving some stems bare prevents the
		# bed from becoming a uniform row of yellow blocks.
		if stem_index % 2 == 0:
			_add_reed_panicle(surface, top, yaw, stem_index)
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Typha latifolia riverbank clump. Cylindrical stalks and faceted capsule heads
## replace crossed rectangles; mixed ages and curved leaves break the repeated
## comb silhouette visible in the former model.
static func cattail_cluster_mesh() -> ArrayMesh:
	const CACHE_KEY := &"cattail_cluster_v2"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalks := [
		[Vector2(-0.12, 0.03), 1.08, 1.00],
		[Vector2(0.03, -0.08), 1.18, 0.92],
		[Vector2(0.16, 0.09), 0.98, 0.84],
		[Vector2(-0.03, 0.15), 0.88, 0.76],
		# One younger, headless shoot makes neighboring MultiMesh instances less
		# obviously identical without introducing another draw call.
		[Vector2(0.12, -0.15), 0.78, 0.0],
	]
	for stalk_index in stalks.size():
		var stalk: Array = stalks[stalk_index]
		var offset: Vector2 = stalk[0]
		var base := Vector3(offset.x, 0.0, offset.y)
		var height: float = stalk[1]
		var head_scale: float = stalk[2]
		var lean_yaw := MeshMath.hash01(stalk_index, 17, 331) * TAU
		var lean := (
			Vector3(sin(lean_yaw), 0.0, cos(lean_yaw))
			* (0.015 + MeshMath.hash01(stalk_index, 19, 337) * 0.025)
		)
		var top := base + Vector3.UP * height + lean
		var stem_color := Color(0.76, 0.80, 0.43).lerp(
			Color(0.58, 0.66, 0.31), MeshMath.hash01(stalk_index, 23, 347)
		)
		_add_tapered_stem(surface, base, top, 0.008, 0.0055, 6, stem_color, 0.0, 1.0)
		if head_scale > 0.0:
			var head_height := 0.165 * head_scale
			var head_base := top - Vector3.UP * (head_height + 0.035)
			var head_radius := 0.034 * head_scale
			var head_color := Color(0.76, 0.39, 0.16).lerp(
				Color(0.56, 0.25, 0.09), MeshMath.hash01(stalk_index, 29, 349)
			)
			_add_cattail_head(surface, head_base, head_height, head_radius, head_color)

	for leaf_index in 12:
		var yaw := TAU * float(leaf_index) / 12.0 + MeshMath.hash01(leaf_index, 5, 353) * 0.42
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var root := direction * (0.025 + MeshMath.hash01(leaf_index, 7, 359) * 0.055)
		var leaf_height := 0.52 + MeshMath.hash01(leaf_index, 11, 367) * 0.40
		var lean := 0.13 + MeshMath.hash01(leaf_index, 13, 373) * 0.23
		var half_width := 0.024 + MeshMath.hash01(leaf_index, 17, 379) * 0.014
		var green_variation := MeshMath.hash01(leaf_index, 19, 383)
		_add_curved_leaf(
			surface,
			_leaf_curve(root, direction, leaf_height, lean),
			PackedFloat32Array([half_width, half_width, half_width * 0.72, half_width * 0.34, 0.0]),
			Vector3(direction.z, 0.0, -direction.x),
			Color(0.72, 0.80, 0.43).lerp(Color(0.57, 0.68, 0.32), green_variation),
			Color(0.58, 0.65, 0.28).lerp(Color(0.42, 0.52, 0.22), green_variation),
			0.0,
			0.86
		)
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func _leaf_curve(
	root: Vector3, direction: Vector3, height: float, lean: float
) -> Array[Vector3]:
	return [
		root,
		root + direction * lean * 0.10 + Vector3.UP * height * 0.27,
		root + direction * lean * 0.34 + Vector3.UP * height * 0.55,
		root + direction * lean * 0.68 + Vector3.UP * height * 0.80,
		root + direction * lean + Vector3.UP * height,
	]


static func _add_curved_leaf(
	surface: SurfaceTool,
	centers: Array[Vector3],
	widths: PackedFloat32Array,
	side: Vector3,
	root_color: Color,
	tip_color: Color,
	uv_bottom: float,
	uv_top: float
) -> void:
	# Segmenting the ribbon is what lets the silhouette bend naturally; the
	# dedicated round stems and seed heads provide volume where it matters most.
	for segment_index in centers.size() - 1:
		var progress_a := float(segment_index) / float(centers.size() - 1)
		var progress_b := float(segment_index + 1) / float(centers.size() - 1)
		var center_a := centers[segment_index]
		var center_b := centers[segment_index + 1]
		var left_a := center_a - side * widths[segment_index]
		var right_a := center_a + side * widths[segment_index]
		var left_b := center_b - side * widths[segment_index + 1]
		var right_b := center_b + side * widths[segment_index + 1]
		var tangent := (center_b - center_a).normalized()
		var normal := side.cross(tangent).normalized()
		var color_a := root_color.lerp(tip_color, progress_a)
		var color_b := root_color.lerp(tip_color, progress_b)
		var uv_a := lerpf(uv_bottom, uv_top, progress_a)
		var uv_b := lerpf(uv_bottom, uv_top, progress_b)
		var vertices := [
			[left_a, Vector2(0.0, uv_a), color_a],
			[right_a, Vector2(1.0, uv_a), color_a],
			[right_b, Vector2(1.0, uv_b), color_b],
			[left_a, Vector2(0.0, uv_a), color_a],
			[right_b, Vector2(1.0, uv_b), color_b],
			[left_b, Vector2(0.0, uv_b), color_b],
		]
		for vertex: Array in vertices:
			surface.set_color(vertex[2])
			surface.set_normal(normal)
			surface.set_uv(vertex[1])
			surface.add_vertex(vertex[0])


static func _add_tapered_stem(
	surface: SurfaceTool,
	base: Vector3,
	top: Vector3,
	bottom_radius: float,
	top_radius: float,
	sides: int,
	color: Color,
	uv_bottom: float,
	uv_top: float
) -> void:
	var axis := (top - base).normalized()
	var ring_x := axis.cross(Vector3.FORWARD)
	if ring_x.length_squared() < 0.001:
		ring_x = axis.cross(Vector3.RIGHT)
	ring_x = ring_x.normalized()
	var ring_z := axis.cross(ring_x).normalized()
	for side_index in sides:
		var angle_a := TAU * float(side_index) / float(sides)
		var angle_b := TAU * float(side_index + 1) / float(sides)
		var radial_a := ring_x * cos(angle_a) + ring_z * sin(angle_a)
		var radial_b := ring_x * cos(angle_b) + ring_z * sin(angle_b)
		var base_a := base + radial_a * bottom_radius
		var base_b := base + radial_b * bottom_radius
		# Leaning cylinders tilt their bottom ring below local ground by a fraction
		# of a millimetre. Clamp only rooted stems; branch rings must stay circular.
		if base.y <= 0.0001:
			base_a.y = maxf(base_a.y, 0.0)
			base_b.y = maxf(base_b.y, 0.0)
		var top_a := top + radial_a * top_radius
		var top_b := top + radial_b * top_radius
		var vertices := [
			[base_a, radial_a, Vector2(float(side_index) / float(sides), uv_bottom)],
			[base_b, radial_b, Vector2(float(side_index + 1) / float(sides), uv_bottom)],
			[top_b, radial_b, Vector2(float(side_index + 1) / float(sides), uv_top)],
			[base_a, radial_a, Vector2(float(side_index) / float(sides), uv_bottom)],
			[top_b, radial_b, Vector2(float(side_index + 1) / float(sides), uv_top)],
			[top_a, radial_a, Vector2(float(side_index) / float(sides), uv_top)],
		]
		for vertex: Array in vertices:
			surface.set_color(color)
			surface.set_normal(vertex[1])
			surface.set_uv(vertex[2])
			surface.add_vertex(vertex[0])


static func _add_cattail_head(
	surface: SurfaceTool, base: Vector3, height: float, radius: float, color: Color
) -> void:
	# Six radial faces and a rounded profile are enough to read as a compact,
	# velvety seed head at gameplay scale without the old box silhouette.
	var profile := PackedVector2Array(
		[
			Vector2(0.0, radius * 0.34),
			Vector2(height * 0.08, radius * 0.82),
			Vector2(height * 0.22, radius),
			Vector2(height * 0.78, radius * 0.96),
			Vector2(height * 0.94, radius * 0.66),
			Vector2(height, radius * 0.28),
		]
	)
	var sides := 6
	for ring_index in profile.size() - 1:
		var ring_a := profile[ring_index]
		var ring_b := profile[ring_index + 1]
		var slope := (ring_a.y - ring_b.y) / maxf(ring_b.x - ring_a.x, 0.001)
		for side_index in sides:
			var angle_a := TAU * float(side_index) / float(sides)
			var angle_b := TAU * float(side_index + 1) / float(sides)
			var radial_a := Vector3(cos(angle_a), 0.0, sin(angle_a))
			var radial_b := Vector3(cos(angle_b), 0.0, sin(angle_b))
			var bottom_a := base + Vector3.UP * ring_a.x + radial_a * ring_a.y
			var bottom_b := base + Vector3.UP * ring_a.x + radial_b * ring_a.y
			var top_a := base + Vector3.UP * ring_b.x + radial_a * ring_b.y
			var top_b := base + Vector3.UP * ring_b.x + radial_b * ring_b.y
			var normal_a := Vector3(radial_a.x, slope, radial_a.z).normalized()
			var normal_b := Vector3(radial_b.x, slope, radial_b.z).normalized()
			var uv_a := ring_a.x / height
			var uv_b := ring_b.x / height
			var vertices := [
				[bottom_a, normal_a, Vector2(float(side_index) / float(sides), uv_a)],
				[bottom_b, normal_b, Vector2(float(side_index + 1) / float(sides), uv_a)],
				[top_b, normal_b, Vector2(float(side_index + 1) / float(sides), uv_b)],
				[bottom_a, normal_a, Vector2(float(side_index) / float(sides), uv_a)],
				[top_b, normal_b, Vector2(float(side_index + 1) / float(sides), uv_b)],
				[top_a, normal_a, Vector2(float(side_index) / float(sides), uv_b)],
			]
			for vertex: Array in vertices:
				surface.set_color(color)
				surface.set_normal(vertex[1])
				surface.set_uv(vertex[2])
				surface.add_vertex(vertex[0])


static func _add_reed_panicle(
	surface: SurfaceTool, base: Vector3, yaw: float, panicle_seed: int
) -> void:
	var direction := Vector3(sin(yaw), 0.0, cos(yaw))
	var plume_color := Color(1.35, 0.90, 0.38).lerp(
		Color(1.08, 0.68, 0.28), MeshMath.hash01(panicle_seed, 31, 401)
	)
	var tip := base + Vector3.UP * 0.16 + direction * 0.035
	_add_tapered_stem(surface, base, tip, 0.0035, 0.0015, 4, plume_color, 0.88, 1.0)
	for branch_index in 5:
		var branch_progress := 0.18 + float(branch_index) * 0.14
		var branch_base := base.lerp(tip, branch_progress)
		var branch_yaw := (
			yaw + (-1.0 if branch_index % 2 == 0 else 1.0) * (0.62 + float(branch_index) * 0.10)
		)
		var branch_direction := Vector3(sin(branch_yaw), 0.0, cos(branch_yaw))
		var branch_length := 0.035 + MeshMath.hash01(panicle_seed, branch_index, 409) * 0.035
		var branch_tip := (
			branch_base
			+ branch_direction * branch_length
			+ Vector3.UP * (0.025 + branch_progress * 0.025)
		)
		_add_tapered_stem(
			surface, branch_base, branch_tip, 0.0022, 0.0008, 3, plume_color, 0.90, 1.0
		)


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


## Seed-bearing grass reads as a second vegetation family at eye level instead
## of merely recoloring the same tuft silhouette.
static func grass_seed_head_mesh() -> ArrayMesh:
	const CACHE_KEY := &"grass_seed_head"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stem in 5:
		var yaw := TAU * float(stem) / 5.0 + MeshMath.hash01(stem, 19, 401) * 0.7
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var height := 0.34 + MeshMath.hash01(stem, 23, 409) * 0.18
		var root := direction * (0.02 + MeshMath.hash01(stem, 29, 419) * 0.06)
		var top := root + direction * 0.09 + Vector3.UP * height
		var half_width := 0.012
		var stem_vertices := [
			root - side * half_width,
			root + side * half_width,
			top + side * half_width * 0.55,
			root - side * half_width,
			top + side * half_width * 0.55,
			top - side * half_width * 0.55
		]
		for index in stem_vertices.size():
			surface.set_uv(Vector2(float(index % 3) * 0.5, 0.0 if index < 2 else 0.82))
			surface.add_vertex(stem_vertices[index])
		var head_height := 0.10
		var head_width := 0.028
		var head_top := top + Vector3.UP * head_height
		for vertex in [
			top - side * head_width,
			top + side * head_width,
			head_top,
			top - side * head_width,
			head_top,
			top - side * head_width * 0.3 + Vector3.UP * head_height * 0.55
		]:
			surface.set_uv(Vector2(0.5, 1.0))
			surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Low radial fern fronds create broad non-flat undergrowth distinct from both
## blade grass and clover.
static func fern_frond_mesh() -> ArrayMesh:
	const CACHE_KEY := &"fern_frond"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in 6:
		var yaw := TAU * float(frond) / 6.0
		var direction := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-sin(yaw), 0.0, cos(yaw))
		var root := Vector3.UP * 0.035
		var middle := direction * 0.18 + Vector3.UP * 0.19
		var tip := direction * 0.38 + Vector3.UP * 0.28
		var width := 0.055
		for vertex in [
			root - side * width,
			root + side * width,
			middle + side * width * 0.72,
			root - side * width,
			middle + side * width * 0.72,
			middle - side * width * 0.72,
			middle - side * width * 0.72,
			middle + side * width * 0.72,
			tip
		]:
			surface.set_uv(Vector2(0.5, clampf(vertex.y / 0.28, 0.0, 1.0)))
			surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh

## Landscape ring outside the playable rectangle. Each authored side may
## continue town silhouettes, open water, or an explicit woodland apron with a
## treeline. Unlisted sides render nothing so maps define their own horizon.
