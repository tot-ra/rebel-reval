class_name MapViewBirdMeshes
extends RefCounted

## Cached naturalistic catalogue geometry (P0-212). Legacy authored GLBs remain
## available through BirdAssets for reference; live poses use the same anatomy.

const BirdAssets := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const Anatomy := preload("res://scripts/map/view3d/map_view_bird_anatomy.gd")
## Wing flapping keyframes: -1.0 = wings fully down, 0.0 = neutral, 1.0 = fully up
const FLAP_KEYFRAMES: Array[float] = [-0.6, -0.3, 0.0, 0.4, 0.7, 0.4, 0.0, -0.3]
## The stroke also sweeps the primaries through the air. Keeping this separate
## from lift avoids the mechanical "elevator" motion of moving the whole wing
## straight up and down.
const FLAP_SWEEP_KEYFRAMES: Array[float] = [0.16, 0.08, -0.02, -0.12, -0.20, -0.10, 0.04, 0.12]

static var _mesh_cache: Dictionary = {}
static var _flap_mesh_cache: Dictionary = {}
static var _modular_flap_cache: Dictionary = {}


static func mesh_for(species: StringName, pose: StringName = &"") -> ArrayMesh:
	var resolved_pose := BirdSpecies.default_pose(species) if pose.is_empty() else pose
	if not BirdSpecies.is_known_species(species) or not BirdSpecies.is_known_pose(resolved_pose):
		return null
	var cache_key := "%s:%s" % [species, resolved_pose]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var mesh := _build_mesh(species, resolved_pose)
	_mesh_cache[cache_key] = mesh
	return mesh


static func uses_authored_mesh(_species: StringName, _pose: StringName = &"") -> bool:
	# Legacy source availability is queried through BirdAssets.has_authored_pose.
	return false


static func reset_cache() -> void:
	_mesh_cache.clear()
	_flap_mesh_cache.clear()
	_modular_flap_cache.clear()
	BirdAssets.reset_cache()


## Returns an array of ArrayMesh for one complete flapping cycle.
## Each entry corresponds to a FLAP_KEYFRAMES position.
static func flap_cycle(species: StringName) -> Array:
	var cache_key := String(species)
	if _flap_mesh_cache.has(cache_key):
		return _flap_mesh_cache[cache_key]
	var cycle: Array = []
	for frame_index in FLAP_KEYFRAMES.size():
		var mesh := _build_mesh(
			species,
			BirdSpecies.POSE_GLIDING,
			FLAP_KEYFRAMES[frame_index],
			FLAP_SWEEP_KEYFRAMES[frame_index]
		)
		cycle.append(mesh)
	_flap_mesh_cache[cache_key] = cycle
	return cycle


## Runtime-ready flap frames. The body and each wing side are separate meshes so
## the flight actor can rotate them around shoulder/elbow pivots instead of
## translating one monolithic wing card vertically.
static func modular_flap_cycle(species: StringName) -> Array:
	var cache_key := String(species)
	if _modular_flap_cache.has(cache_key):
		return _modular_flap_cache[cache_key]
	var cycle: Array = []
	for mesh: ArrayMesh in flap_cycle(species):
		cycle.append(_split_flap_mesh(mesh))
	_modular_flap_cache[cache_key] = cycle
	return cycle


static func modular_rig_for(species: StringName) -> Dictionary:
	# Live actors only need the neutral model, not eight complete baked meshes.
	var cache_key := "rig:%s" % species
	if not _modular_flap_cache.has(cache_key):
		_modular_flap_cache[cache_key] = _split_flap_mesh(mesh_for(species, BirdSpecies.POSE_GLIDING))
	return _modular_flap_cache[cache_key]


static func _split_flap_mesh(mesh: ArrayMesh) -> Dictionary:
	if mesh == null or mesh.get_surface_count() == 0:
		return {}
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() < 3:
		return {}
	var bounds := mesh.get_aabb()
	var max_x := maxf(absf(bounds.position.x), absf(bounds.position.x + bounds.size.x))
	var body_limit := maxf(max_x * 0.24, 0.025)
	var wing_span := maxf(max_x - body_limit, 0.01)
	var buckets: Array[Array] = [[], [], [], [], []]
	var source_indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		source_indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var regions: PackedInt32Array = mesh.get_meta(&"bird_rig_regions", PackedInt32Array())
	var triangle_indices: Array[int] = []
	if source_indices.size() >= 3:
		for source_index in source_indices:
			triangle_indices.append(int(source_index))
	else:
		for vertex_index in vertices.size():
			triangle_indices.append(vertex_index)
	for triangle_start in range(0, triangle_indices.size() - 2, 3):
		var first_index := triangle_indices[triangle_start]
		var second_index := triangle_indices[triangle_start + 1]
		var third_index := triangle_indices[triangle_start + 2]
		var centroid := (
			(vertices[first_index] + vertices[second_index] + vertices[third_index]) / 3.0
		)
		var abs_x := absf(centroid.x)
		var bucket := 0
		if regions.size() == vertices.size():
			# Keep complete anatomical components/feathers on their authored joint.
			# A centroid split would cut vanes open when the elbow rotates.
			bucket = regions[first_index]
		elif abs_x > body_limit:
			var outer_ratio := (abs_x - body_limit) / wing_span
			if centroid.x < 0.0:
				bucket = 1 if outer_ratio < 0.52 else 2
			else:
				bucket = 3 if outer_ratio < 0.52 else 4
		buckets[bucket].append(first_index)
		buckets[bucket].append(second_index)
		buckets[bucket].append(third_index)
	var raw_parts := {
		"body": _mesh_from_vertex_indices(mesh, arrays, buckets[0], Vector3.ZERO),
		"left_upper": _mesh_from_vertex_indices(mesh, arrays, buckets[1], Vector3.ZERO),
		"left_primary": _mesh_from_vertex_indices(mesh, arrays, buckets[2], Vector3.ZERO),
		"right_upper": _mesh_from_vertex_indices(mesh, arrays, buckets[3], Vector3.ZERO),
		"right_primary": _mesh_from_vertex_indices(mesh, arrays, buckets[4], Vector3.ZERO),
	}
	var left_upper_bounds := (raw_parts["left_upper"] as ArrayMesh).get_aabb()
	var left_primary_bounds := (raw_parts["left_primary"] as ArrayMesh).get_aabb()
	var right_upper_bounds := (raw_parts["right_upper"] as ArrayMesh).get_aabb()
	var right_primary_bounds := (raw_parts["right_primary"] as ArrayMesh).get_aabb()
	var left_shoulder := _wing_anchor(left_upper_bounds, -1.0, body_limit)
	var left_elbow := _wing_elbow(left_primary_bounds, -1.0, body_limit, max_x)
	var right_shoulder := _wing_anchor(right_upper_bounds, 1.0, body_limit)
	var right_elbow := _wing_elbow(right_primary_bounds, 1.0, body_limit, max_x)
	var anchors: Dictionary = mesh.get_meta(&"bird_rig_anchors", {})
	left_shoulder = anchors.get("left_shoulder", left_shoulder)
	left_elbow = anchors.get("left_elbow", left_elbow)
	right_shoulder = anchors.get("right_shoulder", right_shoulder)
	right_elbow = anchors.get("right_elbow", right_elbow)
	# Rebuild each wing section in its pivot-local space. At rest the section
	# lands exactly on the authored silhouette; rotation then happens around the
	# shoulder or elbow instead of around the bird origin.
	return {
		"body": raw_parts["body"],
		"left_upper": _mesh_from_vertex_indices(mesh, arrays, buckets[1], left_shoulder),
		"left_primary": _mesh_from_vertex_indices(mesh, arrays, buckets[2], left_elbow),
		"right_upper": _mesh_from_vertex_indices(mesh, arrays, buckets[3], right_shoulder),
		"right_primary": _mesh_from_vertex_indices(mesh, arrays, buckets[4], right_elbow),
		"left_shoulder": left_shoulder,
		"left_elbow": left_elbow,
		"right_shoulder": right_shoulder,
		"right_elbow": right_elbow,
	}


static func _mesh_from_vertex_indices(
	mesh: ArrayMesh, arrays: Array, indices: Array, local_origin: Vector3
) -> ArrayMesh:
	if indices.is_empty():
		return ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	if arrays[Mesh.ARRAY_COLOR] != null:
		colors = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var uvs := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	for source_index: int in indices:
		if colors.size() == vertices.size():
			surface.set_color(colors[source_index])
		if uvs.size() == vertices.size():
			surface.set_uv(uvs[source_index])
		if normals.size() == vertices.size():
			surface.set_normal(normals[source_index])
		if tags.size() == vertices.size():
			surface.set_uv2(tags[source_index])
		surface.add_vertex(vertices[source_index] - local_origin)
	if uvs.size() == vertices.size():
		surface.generate_tangents()
	var output := surface.commit()
	var source_material := mesh.surface_get_material(0)
	if output != null and source_material != null:
		output.surface_set_material(0, source_material)
	if output != null and mesh.has_meta(&"bird_catalog_revision"):
		# Keep the catalogue provenance on each runtime rig part. This lets the
		# game integration distinguish revised anatomy from archived GLB meshes.
		output.set_meta(&"bird_catalog_revision", mesh.get_meta(&"bird_catalog_revision"))
	return output


static func _merge_part_bounds(first: ArrayMesh, second: ArrayMesh) -> AABB:
	if first == null or first.get_surface_count() == 0:
		return second.get_aabb() if second != null else AABB()
	if second == null or second.get_surface_count() == 0:
		return first.get_aabb()
	return first.get_aabb().merge(second.get_aabb())


static func _wing_anchor(bounds: AABB, side: float, body_limit: float) -> Vector3:
	return Vector3(
		side * body_limit,
		bounds.position.y + bounds.size.y * 0.52,
		bounds.position.z + bounds.size.z * 0.52
	)


static func _wing_elbow(bounds: AABB, side: float, body_limit: float, max_x: float) -> Vector3:
	return Vector3(
		side * lerpf(body_limit, max_x, 0.50),
		bounds.position.y + bounds.size.y * 0.50,
		bounds.position.z + bounds.size.z * 0.50
	)


static func geometry_stats(species: StringName, pose: StringName = &"") -> Dictionary:
	var mesh := mesh_for(species, pose)
	if mesh == null or mesh.get_surface_count() == 0:
		return {}
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return {
		"vertices": vertices.size(),
		"triangles": vertices.size() / 3,
		"aabb": mesh.get_aabb(),
		"group": BirdSpecies.group_for(species),
		"pose": BirdSpecies.default_pose(species) if pose.is_empty() else pose,
	}


static func _build_mesh(
	species: StringName, pose: StringName, wing_lift: float = 0.0, wing_sweep: float = 0.0
) -> ArrayMesh:
	return Anatomy.build(species, pose, wing_lift, wing_sweep)
