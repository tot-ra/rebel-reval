class_name MapViewBushMeshes
extends RefCounted

## Cached procedural shrub geometry for the P0-115 catalog. Archetypes keep mesh
## builders bounded while species profiles vary height, spread, and accent reads.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")
const BushSpecies := preload("res://scripts/map/view3d/map_view_bush_species.gd")

static var _mesh_cache: Dictionary = {}


static func mesh_for(species: StringName) -> ArrayMesh:
	if _mesh_cache.has(species):
		return _mesh_cache[species]
	var profile := BushSpecies.profile_for(species)
	var archetype: StringName = profile.get("archetype", BushSpecies.ARCHETYPE_ROUND)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	match archetype:
		BushSpecies.ARCHETYPE_SPREAD:
			_build_spread(surface, profile)
		BushSpecies.ARCHETYPE_UPRIGHT:
			_build_upright(surface, profile)
		BushSpecies.ARCHETYPE_COASTAL:
			_build_coastal(surface, profile)
		BushSpecies.ARCHETYPE_WETLAND:
			_build_wetland(surface, profile)
		BushSpecies.ARCHETYPE_BOG:
			_build_bog(surface, profile)
		BushSpecies.ARCHETYPE_CONIFER:
			_build_conifer(surface, profile)
		_:
			_build_round(surface, profile)
	var mesh := surface.commit()
	_mesh_cache[species] = mesh
	return mesh


static func reset_cache() -> void:
	_mesh_cache.clear()


static func geometry_stats(species: StringName) -> Dictionary:
	var mesh := mesh_for(species)
	if mesh.get_surface_count() == 0:
		return {}
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return {
		"vertices": vertices.size(),
		"triangles": vertices.size() / 3,
		"aabb": mesh.get_aabb(),
		"group": BushSpecies.group_for(species),
		"archetype": BushSpecies.profile_for(species).get("archetype", &""),
	}


static func _build_round(surface: SurfaceTool, profile: Dictionary) -> void:
	var cluster_count := int(profile.get("clusters", 4))
	var height := float(profile.get("height", 0.4))
	var spread := float(profile.get("spread", 0.5))
	var leaf: Color = profile["color"]
	var accent: Color = profile["accent"]
	for cluster_index in cluster_count:
		var yaw := (
			TAU * float(cluster_index) / float(cluster_count)
			+ MeshMath.hash01(cluster_index, 11, 4103) * 0.8
		)
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var center := radial * spread * lerpf(0.08, 0.34, MeshMath.hash01(cluster_index, 17, 4117))
		var radius := spread * lerpf(0.16, 0.28, MeshMath.hash01(cluster_index, 23, 4129))
		var cluster_height := height * lerpf(0.78, 1.08, MeshMath.hash01(cluster_index, 29, 4139))
		_append_ellipsoid(
			surface,
			center + Vector3.UP * cluster_height * 0.42,
			Vector3(radius, cluster_height * 0.5, radius * 0.92),
			leaf
		)
		if cluster_index % 2 == 0:
			_append_berry(
				surface,
				center + Vector3.UP * cluster_height * 0.62,
				radius * 0.18,
				accent,
				cluster_index
			)


static func _build_spread(surface: SurfaceTool, profile: Dictionary) -> void:
	var cluster_count := int(profile.get("clusters", 6))
	var height := float(profile.get("height", 0.3))
	var spread := float(profile.get("spread", 0.5))
	var leaf: Color = profile["color"]
	var accent: Color = profile["accent"]
	for cluster_index in cluster_count:
		var yaw := TAU * float(cluster_index) / float(cluster_count)
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var center := radial * spread * lerpf(0.04, 0.28, MeshMath.hash01(cluster_index, 31, 4151))
		var patch_radius := spread * lerpf(0.10, 0.18, MeshMath.hash01(cluster_index, 37, 4163))
		_append_disc(
			surface, center + Vector3.UP * height * 0.22, patch_radius, leaf.darkened(0.04)
		)
		if cluster_index % 3 == 0:
			_append_berry(
				surface,
				center + Vector3.UP * height * 0.34,
				patch_radius * 0.35,
				accent,
				cluster_index
			)


static func _build_upright(surface: SurfaceTool, profile: Dictionary) -> void:
	var stem_count := int(profile.get("clusters", 4))
	var height := float(profile.get("height", 0.8))
	var spread := float(profile.get("spread", 0.4))
	var leaf: Color = profile["color"]
	var accent: Color = profile["accent"]
	for stem_index in stem_count:
		var yaw := (
			TAU * float(stem_index) / float(stem_count)
			+ MeshMath.hash01(stem_index, 41, 4177) * 0.5
		)
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var root := radial * spread * lerpf(0.06, 0.22, MeshMath.hash01(stem_index, 43, 4187))
		var stem_height := height * lerpf(0.82, 1.06, MeshMath.hash01(stem_index, 47, 4199))
		var lean := radial * spread * 0.12
		var top := root + lean + Vector3.UP * stem_height
		var width := maxf(0.012, spread * 0.05)
		_append_tube(surface, root, top, width, leaf.darkened(0.12))
		_append_ellipsoid(
			surface,
			top + Vector3.UP * spread * 0.08,
			Vector3(spread * 0.22, spread * 0.18, spread * 0.20),
			leaf
		)
		if stem_index % 2 == 0:
			_append_berry(
				surface, top + Vector3.UP * spread * 0.12, spread * 0.08, accent, stem_index
			)


static func _build_coastal(surface: SurfaceTool, profile: Dictionary) -> void:
	var cluster_count := int(profile.get("clusters", 5))
	var height := float(profile.get("height", 0.9))
	var spread := float(profile.get("spread", 0.55))
	var leaf: Color = profile["color"]
	var accent: Color = profile["accent"]
	for cluster_index in cluster_count:
		var yaw := TAU * float(cluster_index) / float(cluster_count)
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var center := radial * spread * lerpf(0.10, 0.30, MeshMath.hash01(cluster_index, 53, 4211))
		var branch := center + Vector3.UP * height * 0.18
		var tip := branch + radial * spread * 0.18 + Vector3.UP * height * 0.42
		_append_tube(surface, center, branch, spread * 0.04, leaf.darkened(0.08))
		_append_tube(surface, branch, tip, spread * 0.03, leaf)
		_append_ellipsoid(
			surface, tip, Vector3(spread * 0.16, spread * 0.12, spread * 0.14), leaf.lightened(0.04)
		)
		if cluster_index % 2 == 0:
			_append_berry(
				surface, tip + Vector3.UP * spread * 0.06, spread * 0.07, accent, cluster_index
			)


static func _build_wetland(surface: SurfaceTool, profile: Dictionary) -> void:
	var stem_count := int(profile.get("clusters", 5))
	var height := float(profile.get("height", 0.9))
	var spread := float(profile.get("spread", 0.5))
	var leaf: Color = profile["color"]
	for stem_index in stem_count:
		var yaw := TAU * float(stem_index) / float(stem_count)
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var root := radial * spread * 0.14
		var droop := root + radial * spread * 0.28 + Vector3.UP * height * 0.55
		var tip := droop + Vector3(-0.08, -height * 0.22, radial.z * 0.08)
		_append_tube(surface, root, droop, spread * 0.035, leaf.darkened(0.10))
		_append_tube(surface, droop, tip, spread * 0.028, leaf)
		_append_disc(surface, tip, spread * 0.10, leaf.lightened(0.06))


static func _build_bog(surface: SurfaceTool, profile: Dictionary) -> void:
	var cluster_count := int(profile.get("clusters", 6))
	var height := float(profile.get("height", 0.25))
	var spread := float(profile.get("spread", 0.5))
	var leaf: Color = profile["color"]
	var accent: Color = profile["accent"]
	_append_disc(
		surface, Vector3.ZERO + Vector3.UP * height * 0.18, spread * 0.34, leaf.darkened(0.06)
	)
	for cluster_index in cluster_count:
		var yaw := TAU * float(cluster_index) / float(cluster_count)
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var center := radial * spread * lerpf(0.08, 0.26, MeshMath.hash01(cluster_index, 59, 4229))
		_append_ellipsoid(
			surface,
			center + Vector3.UP * height * 0.42,
			Vector3(spread * 0.12, height * 0.55, spread * 0.11),
			leaf
		)
		if cluster_index % 2 == 0:
			_append_berry(
				surface, center + Vector3.UP * height * 0.62, spread * 0.06, accent, cluster_index
			)


static func _build_conifer(surface: SurfaceTool, profile: Dictionary) -> void:
	var cluster_count := int(profile.get("clusters", 4))
	var height := float(profile.get("height", 0.7))
	var spread := float(profile.get("spread", 0.45))
	var leaf: Color = profile["color"]
	for cluster_index in cluster_count:
		var yaw := TAU * float(cluster_index) / float(cluster_count)
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var center := radial * spread * 0.12
		var tip := center + Vector3.UP * height
		_append_tube(surface, center, tip, spread * 0.05, leaf.darkened(0.14))
		_append_cone(surface, tip, spread * 0.22, height * 0.42, leaf)


static func _append_ellipsoid(
	surface: SurfaceTool, center: Vector3, radii: Vector3, color: Color
) -> void:
	var segments := 6
	var rings := 4
	for ring in range(rings):
		var v0 := float(ring) / float(rings)
		var v1 := float(ring + 1) / float(rings)
		var y0 := center.y - radii.y + sin(lerpf(-PI * 0.5, PI * 0.5, v0)) * radii.y + radii.y
		var y1 := center.y - radii.y + sin(lerpf(-PI * 0.5, PI * 0.5, v1)) * radii.y + radii.y
		var r0 := cos(lerpf(-PI * 0.5, PI * 0.5, v0)) * radii.x
		var r1 := cos(lerpf(-PI * 0.5, PI * 0.5, v1)) * radii.x
		for segment in range(segments):
			var u0 := TAU * float(segment) / float(segments)
			var u1 := TAU * float(segment + 1) / float(segments)
			var p00 := (
				center
				+ Vector3(
					cos(u0) * r0, y0 - center.y, sin(u0) * radii.z * (r0 / maxf(radii.x, 0.001))
				)
			)
			var p01 := (
				center
				+ Vector3(
					cos(u1) * r0, y0 - center.y, sin(u1) * radii.z * (r0 / maxf(radii.x, 0.001))
				)
			)
			var p10 := (
				center
				+ Vector3(
					cos(u0) * r1, y1 - center.y, sin(u0) * radii.z * (r1 / maxf(radii.x, 0.001))
				)
			)
			var p11 := (
				center
				+ Vector3(
					cos(u1) * r1, y1 - center.y, sin(u1) * radii.z * (r1 / maxf(radii.x, 0.001))
				)
			)
			surface.set_color(color)
			surface.add_vertex(p00)
			surface.set_color(color)
			surface.add_vertex(p10)
			surface.set_color(color)
			surface.add_vertex(p11)
			surface.set_color(color)
			surface.add_vertex(p00)
			surface.set_color(color)
			surface.add_vertex(p11)
			surface.set_color(color)
			surface.add_vertex(p01)


static func _append_disc(
	surface: SurfaceTool, center: Vector3, radius: float, color: Color
) -> void:
	var segments := 8
	for segment in range(segments):
		var a0 := TAU * float(segment) / float(segments)
		var a1 := TAU * float(segment + 1) / float(segments)
		var p0 := center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		surface.set_color(color)
		surface.add_vertex(center)
		surface.set_color(color)
		surface.add_vertex(p0)
		surface.set_color(color)
		surface.add_vertex(p1)


static func _append_tube(
	surface: SurfaceTool, base: Vector3, tip: Vector3, radius: float, color: Color
) -> void:
	var axis := (tip - base).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var forward := side.cross(axis).normalized()
	for corner in 4:
		var angle := TAU * float(corner) / 4.0
		var offset := side * cos(angle) * radius + forward * sin(angle) * radius
		surface.set_color(color)
		surface.add_vertex(base + offset)
		surface.set_color(color)
		surface.add_vertex(tip + offset)
		var next_angle := TAU * float(corner + 1) / 4.0
		var next_offset := side * cos(next_angle) * radius + forward * sin(next_angle) * radius
		surface.set_color(color)
		surface.add_vertex(tip + next_offset)
		surface.set_color(color)
		surface.add_vertex(base + offset)
		surface.set_color(color)
		surface.add_vertex(tip + next_offset)
		surface.set_color(color)
		surface.add_vertex(base + next_offset)


static func _append_cone(
	surface: SurfaceTool, tip: Vector3, radius: float, height: float, color: Color
) -> void:
	var base_center := tip - Vector3.UP * height
	var segments := 6
	for segment in range(segments):
		var a0 := TAU * float(segment) / float(segments)
		var a1 := TAU * float(segment + 1) / float(segments)
		var p0 := base_center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := base_center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		surface.set_color(color)
		surface.add_vertex(tip)
		surface.set_color(color)
		surface.add_vertex(p0)
		surface.set_color(color)
		surface.add_vertex(p1)


static func _append_berry(
	surface: SurfaceTool, center: Vector3, radius: float, color: Color, seed: int
) -> void:
	_append_ellipsoid(
		surface,
		(
			center
			+ Vector3(
				MeshMath.hash01(seed, 3, 4243) * radius,
				0.0,
				MeshMath.hash01(seed, 7, 4253) * radius
			)
		),
		Vector3(radius, radius * 0.92, radius * 0.88),
		color
	)
