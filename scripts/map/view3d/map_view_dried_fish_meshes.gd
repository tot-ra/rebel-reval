class_name MapViewDriedFishMeshes
extends RefCounted

## Reusable low-poly dried fish silhouettes. The local origin is the tail tie,
## body length runs downward along -Y, and thickness runs along Z.

const SPECIES_HERRING := &"herring"
const SPECIES_COD := &"cod"
const ALL_SPECIES: Array[StringName] = [SPECIES_HERRING, SPECIES_COD]
const RADIAL_SEGMENTS := 8

const _PROFILES := {
	SPECIES_HERRING:
	{
		"length": 0.38,
		"depth": 0.075,
		"thickness": 0.028,
		"body_color": Color8(154, 151, 132),
		"belly_color": Color8(188, 178, 148),
	},
	SPECIES_COD:
	{
		"length": 0.46,
		"depth": 0.105,
		"thickness": 0.04,
		"body_color": Color8(137, 125, 101),
		"belly_color": Color8(174, 155, 119),
	},
}

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func add_hanging_fish(
	parent: Node3D,
	node_name: String,
	species: StringName,
	position: Vector3,
	yaw: float = 0.0,
	scale_factor: float = 1.0
) -> Node3D:
	var resolved_species := species if species in ALL_SPECIES else SPECIES_HERRING
	var fish := Node3D.new()
	fish.name = node_name
	fish.position = position
	fish.rotation.y = yaw
	fish.scale = Vector3.ONE * scale_factor
	fish.set_meta(&"dried_fish_species", resolved_species)
	parent.add_child(fish)

	var body := MeshInstance3D.new()
	body.name = "FishMesh"
	body.mesh = mesh_for(resolved_species)
	body.material_override = material_for(resolved_species)
	fish.add_child(body)
	return fish


static func mesh_for(species: StringName) -> ArrayMesh:
	var resolved_species := species if species in ALL_SPECIES else SPECIES_HERRING
	if _mesh_cache.has(resolved_species):
		return _mesh_cache[resolved_species]
	var mesh := _build_mesh(resolved_species)
	_mesh_cache[resolved_species] = mesh
	return mesh


static func material_for(species: StringName) -> StandardMaterial3D:
	var resolved_species := species if species in ALL_SPECIES else SPECIES_HERRING
	if _material_cache.has(resolved_species):
		return _material_cache[resolved_species]
	var profile: Dictionary = _PROFILES[resolved_species]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.94
	material.metallic = 0.0
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[resolved_species] = material
	return material


static func geometry_stats(species: StringName) -> Dictionary:
	var mesh := mesh_for(species)
	var triangles := 0
	for surface_index in mesh.get_surface_count():
		var index_count := mesh.surface_get_array_index_len(surface_index)
		if index_count > 0:
			triangles += index_count / 3
		else:
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += vertices.size() / 3
	return {"aabb": mesh.get_aabb(), "triangles": triangles}


static func reset_cache() -> void:
	_mesh_cache.clear()
	_material_cache.clear()


static func _build_mesh(species: StringName) -> ArrayMesh:
	var profile: Dictionary = _PROFILES[species]
	var length := float(profile["length"])
	var depth := float(profile["depth"])
	var thickness := float(profile["thickness"])
	var body_color: Color = profile["body_color"]
	var belly_color: Color = profile["belly_color"]

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Radius profiles put a narrow caudal peduncle at the tie and taper into a
	# pointed snout. Cod keeps a deeper shoulder than the slender herring.
	var rings: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.18),
		Vector3(0.13, 0.11, 0.58),
		Vector3(0.34, 0.4, 0.95),
		Vector3(0.62, 0.48, 1.0),
		Vector3(0.84, 0.34, 0.72),
		Vector3(1.0, 0.08, 0.2),
	]
	for ring_index in rings.size() - 1:
		var current := rings[ring_index]
		var next := rings[ring_index + 1]
		for segment in RADIAL_SEGMENTS:
			var angle_a := TAU * float(segment) / float(RADIAL_SEGMENTS)
			var angle_b := TAU * float(segment + 1) / float(RADIAL_SEGMENTS)
			var a := _profile_vertex(current, angle_a, length, depth, thickness)
			var b := _profile_vertex(next, angle_a, length, depth, thickness)
			var c := _profile_vertex(next, angle_b, length, depth, thickness)
			var d := _profile_vertex(current, angle_b, length, depth, thickness)
			var color := belly_color if sin((angle_a + angle_b) * 0.5) < -0.15 else body_color
			_add_triangle(surface, a, b, c, color)
			_add_triangle(surface, a, c, d, color)

	_append_tail(surface, depth, thickness, body_color.darkened(0.04))
	_append_fins(surface, species, length, depth, thickness, body_color.darkened(0.12))
	_append_eyes(surface, length, depth, thickness)
	surface.generate_normals()
	return surface.commit()


static func _profile_vertex(
	ring: Vector3, angle: float, length: float, depth: float, thickness: float
) -> Vector3:
	return Vector3(cos(angle) * depth * ring.y, -length * ring.x, sin(angle) * thickness * ring.z)


static func _append_tail(
	surface: SurfaceTool, depth: float, thickness: float, color: Color
) -> void:
	var base := Vector3(0.0, -0.025, 0.0)
	for z_sign_value in [-1, 1]:
		var z_sign := float(z_sign_value)
		var z: float = z_sign * thickness * 0.42
		_add_triangle(
			surface,
			base + Vector3(0.0, 0.0, z),
			Vector3(-depth * 0.9, 0.075, z),
			Vector3(0.0, 0.035, z),
			color
		)
		_add_triangle(
			surface,
			base + Vector3(0.0, 0.0, z),
			Vector3(0.0, 0.035, z),
			Vector3(depth * 0.9, 0.075, z),
			color
		)


static func _append_fins(
	surface: SurfaceTool,
	species: StringName,
	length: float,
	depth: float,
	thickness: float,
	color: Color
) -> void:
	var dorsal_y := -length * 0.52
	var dorsal_height := depth * (0.65 if species == SPECIES_COD else 0.45)
	for z_sign_value in [-1, 1]:
		var z_sign := float(z_sign_value)
		var z: float = z_sign * thickness * 0.48
		_add_triangle(
			surface,
			Vector3(depth * 0.37, dorsal_y + length * 0.11, z),
			Vector3(depth + dorsal_height, dorsal_y, z),
			Vector3(depth * 0.4, dorsal_y - length * 0.13, z),
			color
		)
		_add_triangle(
			surface,
			Vector3(-depth * 0.25, -length * 0.66, z),
			Vector3(-depth * 0.85, -length * 0.58, z),
			Vector3(-depth * 0.28, -length * 0.76, z),
			color
		)


static func _append_eyes(
	surface: SurfaceTool, length: float, depth: float, thickness: float
) -> void:
	var center := Vector3(-depth * 0.19, -length * 0.88, 0.0)
	var radius := maxf(depth * 0.075, 0.005)
	for z_sign_value in [-1, 1]:
		var z_sign := float(z_sign_value)
		var z: float = z_sign * thickness * 0.96
		var eye_center := center + Vector3(0.0, 0.0, z)
		_add_triangle(
			surface,
			eye_center + Vector3(-radius, 0.0, 0.0),
			eye_center + Vector3(0.0, radius, 0.0),
			eye_center + Vector3(radius, 0.0, 0.0),
			Color("211f1b")
		)
		_add_triangle(
			surface,
			eye_center + Vector3(-radius, 0.0, 0.0),
			eye_center + Vector3(radius, 0.0, 0.0),
			eye_center + Vector3(0.0, -radius, 0.0),
			Color("211f1b")
		)


static func _add_triangle(
	surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color
) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)
