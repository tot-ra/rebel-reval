class_name MapViewBirdAssets
extends RefCounted

## Legacy authored bird GLB loader for P2-033. Runtime convention:
## ``assets/birds/<species>/<pose>.glb`` for static poses and
## ``assets/birds/<species>/gliding_XX.glb`` (00-07) for the gliding flap cycle.
## These files remain available for archival/reference callers. Active map flight
## uses ``MapViewBirdMeshes`` P0-212 catalogue geometry, except the five
## explicitly listed skinned storybook species below.

const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")

const BIRDS_ROOT := "res://assets/birds/"
const FLAP_FRAME_COUNT := 8

const STATIC_POSE_FILES: Dictionary = {
	BirdSpecies.POSE_STANDING: "standing.glb",
	BirdSpecies.POSE_PERCHED: "perched.glb",
	BirdSpecies.POSE_GLIDING: "gliding.glb",
}

## The five higher-detail skinned assets remain active in live flight. All other
## catalogue species use P0-212 anatomy through ``MapViewBirdMeshes``.
const ANIMATED_MODELS := {
	&"european_robin": "res://assets/storybook/robin/robin.glb",
	&"hooded_crow": "res://assets/storybook/hooded_crow/hooded_crow.glb",
	&"herring_gull": "res://assets/storybook/gull/gull.glb",
	&"common_gull": "res://assets/storybook/gull/gull.glb",
	&"mallard": "res://assets/storybook/duck/duck.glb",
}

static var _mesh_cache: Dictionary = {}


static func birds_root() -> String:
	return BIRDS_ROOT


static func pose_glb_path(species: StringName, pose: StringName) -> String:
	if not BirdSpecies.is_known_species(species) or not BirdSpecies.is_known_pose(pose):
		return ""
	var file_name: String = STATIC_POSE_FILES.get(pose, "")
	if file_name.is_empty():
		return ""
	return "%s%s/%s" % [BIRDS_ROOT, species, file_name]


static func flap_frame_path(species: StringName, frame_index: int) -> String:
	if not BirdSpecies.is_known_species(species):
		return ""
	if frame_index < 0 or frame_index >= FLAP_FRAME_COUNT:
		return ""
	return "%s%s/gliding_%02d.glb" % [BIRDS_ROOT, species, frame_index]


static func has_authored_pose(species: StringName, pose: StringName) -> bool:
	var path := pose_glb_path(species, pose)
	return not path.is_empty() and ResourceLoader.exists(path)


static func has_authored_default_pose(species: StringName) -> bool:
	return has_authored_pose(species, BirdSpecies.default_pose(species))


static func has_complete_flap_cycle(species: StringName) -> bool:
	if not BirdSpecies.is_known_species(species):
		return false
	for frame_index in FLAP_FRAME_COUNT:
		if not ResourceLoader.exists(flap_frame_path(species, frame_index)):
			return false
	return true


static func mesh_for_pose(species: StringName, pose: StringName) -> ArrayMesh:
	if not BirdSpecies.is_known_species(species) or not BirdSpecies.is_known_pose(pose):
		return null
	var path := _resolve_pose_mesh_path(species, pose)
	if path.is_empty():
		return null
	return _load_mesh(path)


static func flap_cycle_meshes(species: StringName) -> Array:
	if not has_complete_flap_cycle(species):
		return []
	var cycle: Array = []
	for frame_index in FLAP_FRAME_COUNT:
		var mesh := _load_mesh(flap_frame_path(species, frame_index))
		if mesh == null:
			return []
		cycle.append(mesh)
	return cycle


static func reset_cache() -> void:
	_mesh_cache.clear()


static func _resolve_pose_mesh_path(species: StringName, pose: StringName) -> String:
	var path := pose_glb_path(species, pose)
	if ResourceLoader.exists(path):
		return path
	if pose == BirdSpecies.POSE_GLIDING:
		# Neutral flap frame doubles as a static gliding mesh when no gliding.glb exists.
		var neutral_path := flap_frame_path(species, 2)
		if ResourceLoader.exists(neutral_path):
			return neutral_path
	return ""


static func _load_mesh(scene_path: String) -> ArrayMesh:
	if _mesh_cache.has(scene_path):
		return _mesh_cache[scene_path]
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	var mesh_instances: Array = instance.find_children("*", "MeshInstance3D", true, false)
	if mesh_instances.is_empty():
		instance.free()
		return null
	var mesh_instance := mesh_instances[0] as MeshInstance3D
	var source_mesh := mesh_instance.mesh
	instance.free()
	if source_mesh == null:
		return null
	var mesh := source_mesh.duplicate() as ArrayMesh
	_mesh_cache[scene_path] = mesh
	return mesh

static func has_animated_model(species: StringName) -> bool:
	return ANIMATED_MODELS.has(species)

static func create_animated_model(species: StringName) -> Node3D:
	if not has_animated_model(species):
		return null
	var packed := load(ANIMATED_MODELS[species]) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	model.name = "AnimatedBird"
	model.rotation.y = PI # Generated birds face +Z; live flight uses look_at(-Z).
	model.scale = Vector3.ONE * (0.45 if species == &"european_robin" else 0.7)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: StringName in [&"Fly", &"Glide"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.play(&"Fly")
	model.set_meta(&"flight_player", player)
	return model
