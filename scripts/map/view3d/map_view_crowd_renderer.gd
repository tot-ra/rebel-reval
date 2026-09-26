class_name MapViewCrowdRenderer
extends Node3D

## Crowd/battle instancing renderer for Tier-2 characters (P0-152).
## Renders large counts of shared-rig NPCs through MultiMeshInstance3D
## with a simplified crowd shader and deterministic per-instance variation.
##
## WHY: SharedCharacterRig is expensive per-instance (skeleton, animation
## player, LOD mounting). Tier-2 crowd characters never animate individually;
## they share a frozen bind-pose mesh and are batched into one draw call
## per LOD via MultiMesh. Deterministic seed ensures the same palette and
## equipment tint every frame for the same actor set.

const CROWD_SHADER := preload("res://scripts/characters/crowd_shader.gdshader")

## LOD thresholds mirror SharedCharacterRig distance bands so crowd meshes
## cull at the same range as individual rigs.
const LOD0_END := 16.0
const LOD0_MARGIN := 1.0
const LOD1_BEGIN := 16.0
const LOD1_END := 46.0
const LOD1_MARGIN := 1.0
const LOD2_BEGIN := 46.0

## Deterministic palette: per-instance Color variation for clothing/skin.
## Seeded from the actor's stable ID hash so the same NPC always renders
## with the same tint.
const PALETTE_SEED := 42

## Fauna path (P0-159): flocks and herds reuse this renderer with arbitrary
## species meshes instead of the humanoid body. Fauna tint is only a subtle
## brightness spread; species colour comes from the mesh itself.
const TINT_PALETTE := 0
const TINT_FAUNA := 1
const FAUNA_RANGE_MARGIN := 2.0
const HIDDEN_SCALE := 0.001

var _lod0_instance: MultiMeshInstance3D
var _lod1_instance: MultiMeshInstance3D
var _lod2_instance: MultiMeshInstance3D
var _crowd_enabled := true
var _seed: int = 0
var _actor_positions: Dictionary = {}  # actor_id -> Vector3
var _actor_tints: Dictionary = {}  # actor_id -> Color
var _actor_bases: Dictionary = {}  # actor_id -> Basis (fauna heading/bank)
var _part_instances: Array[MultiMeshInstance3D] = []
var _part_offsets: Array[Transform3D] = []
var _tint_mode := TINT_PALETTE


## Build the crowd renderer from the shared character LOD2 mesh (the
## smallest decimated variant). Falls back to LOD1 or LOD0 if LOD2 is
## unavailable. `max_instances` caps the MultiMesh capacity so the GPU
## budget stays predictable.
func configure(max_instances: int = 200, seed_value: int = 0) -> void:
	_seed = seed_value
	var mesh := _load_crowd_mesh()
	if mesh == null:
		push_warning("MapViewCrowdRenderer: no crowd mesh available")
		return
	var shader := CROWD_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	# Apply a base albedo texture if the mesh carries one; otherwise the
	# shader falls back to vertex color only.
	# Surface materials live on the mesh, not in ARRAY_* buffers (Godot 4.7).
	if mesh.get_surface_count() > 0:
		var base_mat := mesh.surface_get_material(0) as StandardMaterial3D
		if base_mat != null and base_mat.albedo_texture != null:
			material.set_shader_parameter("albedo_texture", base_mat.albedo_texture)
		if base_mat != null and base_mat.normal_enabled and base_mat.normal_texture != null:
			material.set_shader_parameter("normal_texture", base_mat.normal_texture)
	_lod0_instance = _build_multimesh_node("CrowdLOD0", mesh, material, max_instances)
	_lod0_instance.visibility_range_end = LOD0_END
	_lod0_instance.visibility_range_end_margin = LOD0_MARGIN
	_lod0_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(_lod0_instance)

	var lod1_mesh := _load_crowd_mesh_variant(1)
	if lod1_mesh != null:
		_lod1_instance = _build_multimesh_node("CrowdLOD1", lod1_mesh, material, max_instances)
		_lod1_instance.visibility_range_begin = LOD1_BEGIN
		_lod1_instance.visibility_range_begin_margin = LOD1_MARGIN
		_lod1_instance.visibility_range_end = LOD1_END
		_lod1_instance.visibility_range_end_margin = LOD1_MARGIN
		_lod1_instance.visibility_range_fade_mode = (
			GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		)
		add_child(_lod1_instance)

	var lod2_mesh := _load_crowd_mesh_variant(2)
	if lod2_mesh != null:
		_lod2_instance = _build_multimesh_node("CrowdLOD2", lod2_mesh, material, max_instances)
		_lod2_instance.visibility_range_begin = LOD2_BEGIN
		_lod2_instance.visibility_range_begin_margin = LOD1_MARGIN
		_lod2_instance.visibility_range_fade_mode = (
			GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		)
		add_child(_lod2_instance)


## Configure the fauna path (P0-159) from mesh parts instead of the shared
## humanoid body. Each part is `{"mesh": Mesh, "transform": Transform3D}` in
## actor space (optional `"material"` override) and becomes one MultiMesh
## draw; otherwise the mesh's own surface materials are used.
## `range_begin`/`range_end` are the visibility_range LOD band: a non-zero
## begin makes this renderer the far stand-in for a detailed actor that culls
## itself at the same distance.
func configure_parts(
	parts: Array,
	max_instances: int,
	range_begin: float,
	range_end: float,
	cast_shadow: bool = false
) -> void:
	_tint_mode = TINT_FAUNA
	for index in parts.size():
		var part: Dictionary = parts[index]
		var mesh := part.get("mesh") as Mesh
		if mesh == null:
			continue
		var node := _build_multimesh_node(
			"FaunaPart%d" % index, mesh, part.get("material") as Material, max_instances
		)
		node.visibility_range_begin = range_begin
		node.visibility_range_begin_margin = FAUNA_RANGE_MARGIN if range_begin > 0.0 else 0.0
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = FAUNA_RANGE_MARGIN
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if cast_shadow
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		add_child(node)
		_part_instances.append(node)
		_part_offsets.append(part.get("transform", Transform3D.IDENTITY))


## MultiMesh nodes built by `configure_parts`, for LOD and batching checks.
func part_instances() -> Array[MultiMeshInstance3D]:
	return _part_instances


## Collect every MeshInstance3D under `root` as a fauna part whose transform is
## relative to root's parent, so the root's own yaw/scale correction (for
## example MapViewBirdAssets' facing flip) carries into the instanced copy.
## Skinned meshes render in their bind pose, as the P0-152 humanoid crowd does,
## unless `bake_skinned_pose` is set: then the caller has already posed the
## skeleton (for example an Idle frame) and that pose is baked into the part.
static func mesh_parts_from_scene(root: Node3D, bake_skinned_pose: bool = false) -> Array:
	var parts: Array = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var xform := mesh_instance.transform
		var parent := mesh_instance.get_parent()
		while parent != null and parent != root:
			if parent is Node3D:
				xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		var mesh := mesh_with_active_materials(mesh_instance)
		if bake_skinned_pose and mesh_instance.skin != null:
			mesh = _baked_pose_mesh(mesh_instance)
		parts.append(
			{
				"mesh": mesh,
				"transform": root.transform * xform,
			}
		)
	return parts


## CPU-skin the mesh into the skeleton's current pose. Needed because
## `MeshInstance3D.bake_mesh_from_current_skeleton_pose()` fails ("skin
## registered with a valid skeleton") on the storybook GLBs in Godot 4.7.
## Runs once per model at configure time, never per frame.
static func _baked_pose_mesh(mesh_instance: MeshInstance3D) -> Mesh:
	var skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D
	var source := mesh_instance.mesh as ArrayMesh
	var skin := mesh_instance.skin
	if skeleton == null or source == null or skin == null:
		return mesh_with_active_materials(mesh_instance)
	# Bind-index -> skinning matrix, expressed in the mesh instance's space.
	var to_mesh := (
		mesh_instance.transform.affine_inverse()
		if mesh_instance.get_parent() == skeleton
		else Transform3D.IDENTITY
	)
	var binds: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		binds.append(
			to_mesh * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind)
			if bone >= 0
			else Transform3D.IDENTITY
		)
	var baked := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		# Optional channels are null when a surface does not carry them.
		var bones := PackedInt32Array(_array_or_empty(arrays, Mesh.ARRAY_BONES))
		var weights := PackedFloat32Array(_array_or_empty(arrays, Mesh.ARRAY_WEIGHTS))
		var normals := PackedVector3Array(_array_or_empty(arrays, Mesh.ARRAY_NORMAL))
		var tangents := PackedFloat32Array(_array_or_empty(arrays, Mesh.ARRAY_TANGENT))
		var influences := bones.size() / maxi(vertices.size(), 1)
		if influences > 0:
			for vertex in vertices.size():
				var blended := Transform3D(Basis() * 0.0, Vector3.ZERO)
				for slot in influences:
					var weight := weights[vertex * influences + slot]
					var bind := bones[vertex * influences + slot]
					if weight <= 0.0 or bind >= binds.size():
						continue
					var matrix := binds[bind]
					blended.basis = Basis(
						blended.basis.x + matrix.basis.x * weight,
						blended.basis.y + matrix.basis.y * weight,
						blended.basis.z + matrix.basis.z * weight
					)
					blended.origin += matrix.origin * weight
				vertices[vertex] = blended * vertices[vertex]
				if vertex < normals.size():
					normals[vertex] = (blended.basis * normals[vertex]).normalized()
				if vertex * 4 + 2 < tangents.size():
					var tangent := (
						blended.basis
						* Vector3(
							tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2]
						)
					).normalized()
					tangents[vertex * 4] = tangent.x
					tangents[vertex * 4 + 1] = tangent.y
					tangents[vertex * 4 + 2] = tangent.z
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals if not normals.is_empty() else null
		arrays[Mesh.ARRAY_TANGENT] = tangents if not tangents.is_empty() else null
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		# Custom channels need their format flags re-declared on upload; the
		# StandardMaterial3D surfaces of the storybook GLBs never read them.
		for channel in [
			Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3
		]:
			arrays[channel] = null
		baked.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		baked.surface_set_material(surface, mesh_instance.get_active_material(surface))
	return baked


static func _array_or_empty(arrays: Array, channel: int) -> Variant:
	return arrays[channel] if arrays[channel] != null else []


## Bake per-instance surface overrides into a mesh copy so a MultiMesh (which
## has no per-surface overrides) draws the same materials as the source node.
static func mesh_with_active_materials(mesh_instance: MeshInstance3D) -> Mesh:
	var source := mesh_instance.mesh
	var has_override := mesh_instance.material_override != null
	for surface in source.get_surface_count():
		has_override = has_override or mesh_instance.get_surface_override_material(surface) != null
	if not has_override or not source is ArrayMesh:
		return source
	var mesh := source.duplicate() as ArrayMesh
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface, mesh_instance.get_active_material(surface))
	return mesh


func set_crowd_enabled(enabled: bool) -> void:
	_crowd_enabled = enabled
	visible = enabled


func is_crowd_enabled() -> bool:
	return _crowd_enabled


## Register an actor position for crowd instancing. `actor_id` is a stable
## identifier (e.g. the logic actor's name hash) used for deterministic
## palette tint. `world_pos` is the 3D world-space position.
func set_actor_position(actor_id: int, world_pos: Vector3) -> void:
	_actor_positions[actor_id] = world_pos
	if not _actor_tints.has(actor_id):
		_actor_tints[actor_id] = _deterministic_tint(actor_id)
	_sync_multimesh()


## Register an actor with a full transform (fauna heading, bank, scale).
func set_actor_transform(actor_id: int, xform: Transform3D) -> void:
	_store_actor_transform(actor_id, xform)
	_sync_multimesh()


## Replace the whole actor set with one MultiMesh upload. Flocks and herds
## move every frame; per-actor `set_actor_*` calls would re-upload the buffer
## once per actor. Tints survive for ids that stay registered.
func replace_actor_transforms(transforms: Dictionary) -> void:
	if transforms.is_empty() and _actor_positions.is_empty():
		return  # idle flock/herd layer: skip re-uploading parked slots
	for actor_id: int in _actor_tints.keys():
		if not transforms.has(actor_id):
			_actor_tints.erase(actor_id)
	_actor_positions.clear()
	_actor_bases.clear()
	for actor_id: int in transforms:
		_store_actor_transform(actor_id, transforms[actor_id])
	_sync_multimesh()


func _store_actor_transform(actor_id: int, xform: Transform3D) -> void:
	_actor_positions[actor_id] = xform.origin
	_actor_bases[actor_id] = xform.basis
	if not _actor_tints.has(actor_id):
		_actor_tints[actor_id] = _deterministic_tint(actor_id)


## Remove an actor from the crowd.
func remove_actor(actor_id: int) -> void:
	_actor_positions.erase(actor_id)
	_actor_bases.erase(actor_id)
	_actor_tints.erase(actor_id)
	_sync_multimesh()


## Remove all actors and reset state.
func clear_actors() -> void:
	_actor_positions.clear()
	_actor_bases.clear()
	_actor_tints.clear()
	_sync_multimesh()


## Number of currently registered crowd actors.
func active_count() -> int:
	return _actor_positions.size()


## Returns the instance count the crowd is prepared for (capacity).
func capacity() -> int:
	var instance := _lod0_instance
	if instance == null and not _part_instances.is_empty():
		instance = _part_instances[0]
	if instance == null or instance.multimesh == null:
		return 0
	return instance.multimesh.instance_count


## Instances actually submitted for drawing (min of actors and capacity).
func drawn_count() -> int:
	return mini(_actor_positions.size(), capacity())


## Returns true if the given instance index is actively used (has an actor).
func is_instance_active(index: int) -> bool:
	return index < _actor_positions.size()


func _sync_multimesh() -> void:
	var count := _actor_positions.size()
	var ids: Array = _actor_positions.keys()
	# Sort by actor_id for deterministic ordering.
	ids.sort()
	_apply_to_lod(_lod0_instance, ids, count)
	_apply_to_lod(_lod1_instance, ids, count)
	_apply_to_lod(_lod2_instance, ids, count)
	for index in _part_instances.size():
		_apply_to_lod(_part_instances[index], ids, count, _part_offsets[index])


func _apply_to_lod(
	instance: MultiMeshInstance3D, ids: Array, count: int, offset := Transform3D.IDENTITY
) -> void:
	if instance == null or instance.multimesh == null:
		return
	var mm: MultiMesh = instance.multimesh
	# Keep configured capacity; overflow actors stay registered in logic
	# dictionaries but are not drawn (P0-152 / capacity contract).
	var capacity := mm.instance_count
	var visible_count := mini(count, capacity)
	# Park unused slots at the first drawn actor, not far below the map: the
	# MultiMesh AABB covers every slot, and visibility_range LOD measures to
	# that AABB, so a distant parking spot would break the LOD band.
	var parked := Transform3D(Basis.from_scale(Vector3.ONE * HIDDEN_SCALE), Vector3.ZERO)
	if visible_count > 0:
		parked.origin = _actor_positions[ids[0]]
	for i in capacity:
		if i < visible_count:
			var actor_id: int = ids[i]
			var pos: Vector3 = _actor_positions[actor_id]
			var tint: Color = _actor_tints[actor_id]
			var basis: Basis = _actor_bases.get(actor_id, Basis.IDENTITY)
			mm.set_instance_transform(i, Transform3D(basis, pos) * offset)
			mm.set_instance_color(i, tint)
		else:
			mm.set_instance_transform(i, parked)
			mm.set_instance_color(i, Color(1, 1, 1, 1))
	# Only submit the used prefix to the GPU; parked instances stay allocated.
	mm.visible_instance_count = visible_count


func _deterministic_tint(actor_id: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(actor_id) + PALETTE_SEED
	if _tint_mode == TINT_FAUNA:
		# Plumage/coat colour lives in the mesh; only vary brightness so a flock
		# does not read as one bird stamped out N times.
		var value := rng.randf_range(0.86, 1.0)
		return Color(value, value, value * rng.randf_range(0.97, 1.0), 1.0)
	# Skin tone variation: warm range (0.6-0.9 red, 0.4-0.7 green, 0.3-0.5 blue)
	var skin_r := rng.randf_range(0.6, 0.9)
	var skin_g := rng.randf_range(0.4, 0.7)
	var skin_b := rng.randf_range(0.3, 0.5)
	# Clothing tint: desaturated earth tones or muted blues/greens
	var cloth_variant := rng.randi_range(0, 3)
	var cloth_color: Color
	match cloth_variant:
		0:
			cloth_color = Color(0.45, 0.35, 0.25)  # brown wool
		1:
			cloth_color = Color(0.35, 0.4, 0.3)  # green linen
		2:
			cloth_color = Color(0.3, 0.35, 0.45)  # blue-grey
		_:
			cloth_color = Color(0.5, 0.45, 0.4)  # undyed linen
	# Blend skin and cloth tint; at gameplay distance the combined
	# hue shift is enough to distinguish individual crowd members.
	var blend := rng.randf_range(0.3, 0.7)
	return Color(
		lerp(skin_r, cloth_color.r, blend),
		lerp(skin_g, cloth_color.g, blend),
		lerp(skin_b, cloth_color.b, blend),
		1.0
	)


func _load_crowd_mesh() -> ArrayMesh:
	return _load_crowd_mesh_variant(2)


func _load_crowd_mesh_variant(lod_level: int) -> ArrayMesh:
	# Try the LOD2 mesh first (smallest), then LOD1, then LOD0 body.
	var candidates: Array[String] = []
	match lod_level:
		2:
			candidates = [
				"res://assets/characters/shared/heroic_humanoid_lod2.glb",
				"res://assets/characters/shared/danish_warrior_lod2.glb",
			]
		1:
			candidates = [
				"res://assets/characters/shared/heroic_humanoid_lod1.glb",
				"res://assets/characters/shared/danish_warrior_lod1.glb",
			]
		0:
			candidates = [
				"res://assets/characters/shared/heroic_humanoid.glb",
				"res://assets/characters/shared/danish_warrior.glb",
			]
	for path: String in candidates:
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var root := scene.instantiate()
		var mesh := _extract_mesh(root)
		root.queue_free()
		if mesh != null:
			return mesh
	return null


## Walk the imported scene tree and return the first ArrayMesh found on
## any MeshInstance3D child. For crowd purposes we only need the body mesh;
## garments and accessories are omitted to keep the draw-call budget low.
static func _extract_mesh(root: Node) -> ArrayMesh:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		if mi.mesh is ArrayMesh:
			return mi.mesh as ArrayMesh
	for child: Node in root.get_children():
		var found := _extract_mesh(child)
		if found != null:
			return found
	return null


static func _build_multimesh_node(
	node_name: String, mesh: Mesh, material: Material, capacity: int
) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = capacity
	# Hide all instances by setting zero-scale transforms until an actor
	# is assigned. Active instances get proper transforms in _sync_multimesh.
	var parked := Transform3D(Basis.from_scale(Vector3.ONE * HIDDEN_SCALE), Vector3.ZERO)
	for i in capacity:
		mm.set_instance_transform(i, parked)
	mm.visible_instance_count = 0
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance
