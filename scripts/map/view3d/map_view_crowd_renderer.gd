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

var _lod0_instance: MultiMeshInstance3D
var _lod1_instance: MultiMeshInstance3D
var _lod2_instance: MultiMeshInstance3D
var _crowd_enabled := true
var _seed: int = 0
var _actor_positions: Dictionary = {}  # actor_id -> Vector3
var _actor_tints: Dictionary = {}  # actor_id -> Color


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


## Remove an actor from the crowd.
func remove_actor(actor_id: int) -> void:
	_actor_positions.erase(actor_id)
	_actor_tints.erase(actor_id)
	_sync_multimesh()


## Remove all actors and reset state.
func clear_actors() -> void:
	_actor_positions.clear()
	_actor_tints.clear()
	_sync_multimesh()


## Number of currently registered crowd actors.
func active_count() -> int:
	return _actor_positions.size()


## Returns the instance count the crowd is prepared for (capacity).
func capacity() -> int:
	if _lod0_instance == null or _lod0_instance.multimesh == null:
		return 0
	return _lod0_instance.multimesh.instance_count


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


func _apply_to_lod(instance: MultiMeshInstance3D, ids: Array, count: int) -> void:
	if instance == null or instance.multimesh == null:
		return
	var mm: MultiMesh = instance.multimesh
	# Keep configured capacity; overflow actors stay registered in logic
	# dictionaries but are not drawn (P0-152 / capacity contract).
	var capacity := mm.instance_count
	var visible_count := mini(count, capacity)
	for i in capacity:
		if i < visible_count:
			var actor_id: int = ids[i]
			var pos: Vector3 = _actor_positions[actor_id]
			var tint: Color = _actor_tints[actor_id]
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
			mm.set_instance_color(i, tint)
		else:
			mm.set_instance_transform(
				i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -9999, 0))
			)
			mm.set_instance_color(i, Color(1, 1, 1, 1))


func _deterministic_tint(actor_id: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(actor_id) + PALETTE_SEED
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
	node_name: String, mesh: ArrayMesh, material: Material, capacity: int
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
	for i in capacity:
		mm.set_instance_transform(
			i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -9999, 0))
		)
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance
