class_name MapViewPlantMeshes
extends RefCounted

## Bounded procedural botany. Every concrete species receives a cached mesh built
## from its growth profile, while MultiMesh handles all repeated map instances.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")
const PlantSpecies := preload("res://scripts/map/view3d/map_view_plant_species.gd")

static var _mesh_cache: Dictionary = {}


static func mesh_for(species: StringName) -> ArrayMesh:
	if _mesh_cache.has(species):
		return _mesh_cache[species]
	var profile := PlantSpecies.profile_for(species)
	var archetype: StringName = profile["archetype"]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	match archetype:
		PlantSpecies.ARCHETYPE_ROSETTE, PlantSpecies.ARCHETYPE_BROAD:
			_build_rosette(surface, profile, archetype == PlantSpecies.ARCHETYPE_BROAD)
		PlantSpecies.ARCHETYPE_FROND:
			_build_fronds(surface, profile)
		PlantSpecies.ARCHETYPE_MOSS:
			_build_moss(surface, profile)
		PlantSpecies.ARCHETYPE_AQUATIC:
			_build_aquatic(surface, profile)
		_:
			_build_standing(surface, profile, archetype)
	var mesh := surface.commit()
	_mesh_cache[species] = mesh
	return mesh


static func reset_cache() -> void:
	_mesh_cache.clear()


static func _build_standing(surface: SurfaceTool, profile: Dictionary, archetype: StringName) -> void:
	var stem_count := int(profile["stems"])
	var height := float(profile["height"])
	var spread := float(profile["spread"])
	var leaf_color: Color = profile["color"]
	var accent: Color = profile["accent"]
	for stem_index in stem_count:
		var yaw := TAU * float(stem_index) / float(stem_count) + MeshMath.hash01(stem_index, 17, 2903) * 0.62
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-sin(yaw), 0.0, cos(yaw))
		var root := radial * spread * lerpf(0.08, 0.38, MeshMath.hash01(stem_index, 23, 2917))
		var stem_height := height * lerpf(0.82, 1.08, MeshMath.hash01(stem_index, 29, 2927))
		var lean := radial * spread * lerpf(0.08, 0.28, MeshMath.hash01(stem_index, 31, 2939))
		var top := root + lean + Vector3.UP * stem_height
		var stem_width := maxf(0.009, spread * 0.045)
		_append_ribbon(surface, root, top, side, stem_width, leaf_color.darkened(0.10), 0.0, 0.82)

		if archetype in [PlantSpecies.ARCHETYPE_HERB, PlantSpecies.ARCHETYPE_STALK, PlantSpecies.ARCHETYPE_VINE, PlantSpecies.ARCHETYPE_FLOWER]:
			var leaf_pairs := 3 if archetype != PlantSpecies.ARCHETYPE_STALK else 4
			for leaf_index in leaf_pairs:
				var t := 0.24 + float(leaf_index) * 0.18
				var center := root.lerp(top, t)
				var leaf_side := side if leaf_index % 2 == 0 else -side
				var leaf_length := spread * lerpf(0.55, 0.9, MeshMath.hash01(stem_index, leaf_index, 2953))
				if archetype == PlantSpecies.ARCHETYPE_STALK:
					leaf_length *= 0.62
				_append_leaf(surface, center, leaf_side, leaf_length, maxf(leaf_length * 0.34, 0.025), leaf_color)

		match archetype:
			PlantSpecies.ARCHETYPE_FLOWER:
				_append_flower(surface, top, maxf(0.045, spread * 0.15), accent, stem_index)
			PlantSpecies.ARCHETYPE_CEREAL:
				_append_seed_head(surface, top, side, stem_height * 0.18, maxf(0.025, spread * 0.10), accent, stem_index)
			PlantSpecies.ARCHETYPE_REED:
				_append_seed_head(surface, top, side, stem_height * 0.13, maxf(0.018, spread * 0.07), accent, stem_index)
				_append_leaf(surface, root + Vector3.UP * stem_height * 0.16, radial, spread * 0.75, spread * 0.08, leaf_color)
			PlantSpecies.ARCHETYPE_CATTAIL:
				_append_cattail_head(surface, top - Vector3.UP * stem_height * 0.10, side, stem_height * 0.17, maxf(0.025, spread * 0.09), accent)
				_append_leaf(surface, root + Vector3.UP * stem_height * 0.12, radial, spread * 0.8, spread * 0.07, leaf_color)
			PlantSpecies.ARCHETYPE_VINE:
				_append_flower(surface, top - Vector3.UP * stem_height * 0.08, maxf(0.035, spread * 0.10), accent, stem_index)


static func _build_rosette(surface: SurfaceTool, profile: Dictionary, broad: bool) -> void:
	var count := int(profile["stems"])
	var height := float(profile["height"])
	var spread := float(profile["spread"])
	var color: Color = profile["color"]
	for leaf_index in count:
		var yaw := TAU * float(leaf_index) / float(count) + MeshMath.hash01(leaf_index, 37, 3001) * 0.32
		var direction := Vector3(cos(yaw), 0.0, sin(yaw))
		var lift := height * lerpf(0.34, 0.72, MeshMath.hash01(leaf_index, 41, 3011))
		var leaf_length := spread * lerpf(0.72, 1.04, MeshMath.hash01(leaf_index, 43, 3019))
		var width := leaf_length * (0.42 if broad else 0.25)
		var center := direction * leaf_length * 0.38 + Vector3.UP * lift * 0.45
		_append_leaf(surface, center, (direction + Vector3.UP * lift / maxf(leaf_length, 0.01)).normalized(), leaf_length, width, color.lightened(float(leaf_index % 3) * 0.035))
	if broad:
		var accent: Color = profile["accent"]
		_append_low_crown(surface, Vector3.UP * height * 0.52, spread * 0.32, height * 0.32, accent)


static func _build_fronds(surface: SurfaceTool, profile: Dictionary) -> void:
	var count := int(profile["stems"])
	var height := float(profile["height"])
	var spread := float(profile["spread"])
	var color: Color = profile["color"]
	for frond_index in count:
		var yaw := TAU * float(frond_index) / float(count)
		var direction := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-sin(yaw), 0.0, cos(yaw))
		var root := Vector3.UP * 0.025
		var middle := direction * spread * 0.48 + Vector3.UP * height * 0.72
		var tip := direction * spread + Vector3.UP * height * 0.48
		var width := spread * 0.10
		_append_colored_triangle(surface, root - side * width, root + side * width, middle + side * width * 0.72, color, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.62))
		_append_colored_triangle(surface, root - side * width, middle + side * width * 0.72, middle - side * width * 0.72, color.darkened(0.06), Vector2(0.0, 0.0), Vector2(1.0, 0.62), Vector2(0.0, 0.62))
		_append_colored_triangle(surface, middle - side * width * 0.72, middle + side * width * 0.72, tip, color.lightened(0.05), Vector2(0.0, 0.62), Vector2(1.0, 0.62), Vector2(0.5, 1.0))


static func _build_moss(surface: SurfaceTool, profile: Dictionary) -> void:
	var count := int(profile["stems"])
	var height := float(profile["height"])
	var spread := float(profile["spread"])
	var color: Color = profile["color"]
	for mound_index in count:
		var yaw := TAU * float(mound_index) / float(count)
		var radius := spread * lerpf(0.12, 0.24, MeshMath.hash01(mound_index, 47, 3041))
		var center := Vector3(cos(yaw), 0.0, sin(yaw)) * spread * 0.32
		center.y = height * lerpf(0.28, 0.62, MeshMath.hash01(mound_index, 53, 3049))
		_append_low_crown(surface, center, radius, height * 0.28, color.lightened(float(mound_index % 3) * 0.04))


static func _build_aquatic(surface: SurfaceTool, profile: Dictionary) -> void:
	var count := int(profile["stems"])
	var spread := float(profile["spread"])
	var color: Color = profile["color"]
	for pad_index in count:
		var yaw := TAU * float(pad_index) / float(count)
		var center := Vector3(cos(yaw), 0.018 + float(pad_index % 2) * 0.006, sin(yaw)) * spread * 0.28
		_append_horizontal_fan(surface, center, spread * lerpf(0.16, 0.25, MeshMath.hash01(pad_index, 59, 3061)), color.lightened(float(pad_index % 3) * 0.035), 8)
	var accent: Color = profile["accent"]
	_append_flower(surface, Vector3.UP * 0.08, spread * 0.12, accent, 0)


static func _append_ribbon(surface: SurfaceTool, root: Vector3, top: Vector3, side: Vector3, half_width: float, color: Color, uv_root: float, uv_top: float) -> void:
	var root_left := root - side * half_width
	var root_right := root + side * half_width
	var top_left := top - side * half_width * 0.55
	var top_right := top + side * half_width * 0.55
	_append_colored_triangle(surface, root_left, root_right, top_right, color, Vector2(0.0, uv_root), Vector2(1.0, uv_root), Vector2(1.0, uv_top))
	_append_colored_triangle(surface, root_left, top_right, top_left, color.darkened(0.04), Vector2(0.0, uv_root), Vector2(1.0, uv_top), Vector2(0.0, uv_top))


static func _append_leaf(surface: SurfaceTool, center: Vector3, direction: Vector3, length: float, width: float, color: Color) -> void:
	var axis := direction.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var root := center - axis * length * 0.42
	var tip := center + axis * length * 0.58
	var left := center - side * width * 0.5
	var right := center + side * width * 0.5
	_append_colored_triangle(surface, root, right, tip, color.darkened(0.05), Vector2(0.5, 0.0), Vector2(1.0, 0.48), Vector2(0.5, 1.0))
	_append_colored_triangle(surface, root, tip, left, color, Vector2(0.5, 0.0), Vector2(0.5, 1.0), Vector2(0.0, 0.48))


static func _append_flower(surface: SurfaceTool, center: Vector3, radius: float, color: Color, seed: int) -> void:
	var petal_count := 6
	for petal_index in petal_count:
		var yaw := TAU * float(petal_index) / float(petal_count) + MeshMath.hash01(petal_index, seed, 3083) * 0.12
		var direction := Vector3(cos(yaw), 0.10, sin(yaw)).normalized()
		var side := Vector3(-sin(yaw), 0.0, cos(yaw))
		var root := center
		var shoulder := center + direction * radius * 0.72
		var tip := center + direction * radius
		_append_colored_triangle(surface, root, shoulder + side * radius * 0.26, tip, color, Vector2(0.5, 0.0), Vector2(1.0, 0.55), Vector2(0.5, 1.0))
		_append_colored_triangle(surface, root, tip, shoulder - side * radius * 0.26, color.darkened(0.04), Vector2(0.5, 0.0), Vector2(0.5, 1.0), Vector2(0.0, 0.55))
	_append_low_crown(surface, center + Vector3.UP * radius * 0.08, radius * 0.20, radius * 0.16, Color(0.92, 0.66, 0.12))


static func _append_seed_head(surface: SurfaceTool, bottom: Vector3, side: Vector3, height: float, width: float, color: Color, seed: int) -> void:
	var top := bottom + Vector3.UP * height
	_append_ribbon(surface, bottom, top, side, width, color, 0.82, 1.0)
	for grain_index in 4:
		var t := float(grain_index + 1) / 5.0
		var center := bottom.lerp(top, t)
		var grain_side := side if grain_index % 2 == 0 else -side
		_append_leaf(surface, center, (grain_side + Vector3.UP * 0.18).normalized(), height * lerpf(0.18, 0.28, MeshMath.hash01(grain_index, seed, 3109)), width * 1.5, color.lightened(0.04))


static func _append_cattail_head(surface: SurfaceTool, bottom: Vector3, side: Vector3, height: float, width: float, color: Color) -> void:
	_append_ribbon(surface, bottom, bottom + Vector3.UP * height, side, width, color, 0.78, 0.96)
	var cross_side := Vector3(side.z, 0.0, -side.x)
	_append_ribbon(surface, bottom, bottom + Vector3.UP * height, cross_side, width, color.darkened(0.08), 0.78, 0.96)


static func _append_low_crown(surface: SurfaceTool, center: Vector3, radius: float, height: float, color: Color) -> void:
	var top := center + Vector3.UP * height
	for side_index in 8:
		var next_index := (side_index + 1) % 8
		var a_angle := TAU * float(side_index) / 8.0
		var b_angle := TAU * float(next_index) / 8.0
		var a := center + Vector3(cos(a_angle) * radius, 0.0, sin(a_angle) * radius)
		var b := center + Vector3(cos(b_angle) * radius, 0.0, sin(b_angle) * radius)
		_append_colored_triangle(surface, a, b, top, color, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0))


static func _append_horizontal_fan(surface: SurfaceTool, center: Vector3, radius: float, color: Color, sides: int) -> void:
	for side_index in sides:
		var a_angle := TAU * float(side_index) / float(sides)
		var b_angle := TAU * float(side_index + 1) / float(sides)
		var a := center + Vector3(cos(a_angle) * radius, 0.0, sin(a_angle) * radius)
		var b := center + Vector3(cos(b_angle) * radius, 0.0, sin(b_angle) * radius)
		_append_colored_triangle(surface, center, a, b, color, Vector2(0.5, 0.5), Vector2(0.0, 0.0), Vector2(1.0, 0.0))


static func _append_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	for vertex in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.set_uv(vertex[1])
		surface.add_vertex(vertex[0])
