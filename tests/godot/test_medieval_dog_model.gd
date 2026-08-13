extends "res://tests/godot/test_case.gd"

## Contract for the P2-024 street dog production GLB (medieval_dog.glb). The
## authored hound replaced the shared procedural silhouette, so the test pins
## its metric envelope, closed anatomy, rig, and locomotion clips.

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")


func test_dog_has_production_model_with_grounded_pbr_body() -> void:
	assert_true(
		Models.has_model(MammalSpecies.SPECIES_DOG),
		"Dog must use the authored production GLB"
	)
	var host := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var model := Models.add_model(host, MammalSpecies.SPECIES_DOG)
	assert_true(model != null, "Dog needs an imported production model")
	assert_true(model.get_meta(&"production_animal_model", false))
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null, "Dog needs AnimalMesh")
	assert_true(
		mesh.mesh.get_surface_count() == 1,
		"Dog body must remain one portable production surface"
	)
	var material := mesh.mesh.surface_get_material(0)
	assert_true(material is StandardMaterial3D, "Dog must import as StandardMaterial3D")
	var std := material as StandardMaterial3D
	assert_ne(
		std.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Dog must react to scene lighting"
	)
	assert_true(std.normal_enabled and std.normal_texture != null, "Dog needs a short-hair normal map")
	assert_true(
		std.roughness_texture != null or (std.roughness > 0.05 and std.roughness < 1.0),
		"Dog needs an authored roughness response"
	)
	var aabb := mesh.get_aabb()
	assert_true(absf(aabb.position.y) < 0.001, "Dog feet must touch Y=0")
	assert_true(aabb.size.x >= 0.95, "Dog must keep a long hound silhouette")
	assert_true(aabb.size.x < 1.10, "Dog must not inherit an inflated helper bound")
	assert_true(aabb.size.y >= 0.58, "Dog legs and pricked ears must retain standing height")
	assert_true(aabb.size.y < 0.72, "Dog must stay a medium street hound, not a wolfhound")
	assert_true(aabb.size.z >= 0.24, "Dog chest must retain believable width")
	assert_true(aabb.size.z < 0.36, "Dog must not become an over-wide generic blob")
	host.free()


func test_dog_has_rigged_face_and_locomotion_clips() -> void:
	var host := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var model := Models.add_model(host, MammalSpecies.SPECIES_DOG)
	assert_true(model != null)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	assert_true(skeletons.size() >= 1, "Dog needs an imported skeleton")
	var skeleton := skeletons[0] as Skeleton3D
	var animated_bones: Array[StringName] = [
		&"Neck",
		&"Tail",
		&"FrontLeftLeg",
		&"FrontRightLeg",
		&"BackLeftLeg",
		&"BackRightLeg",
	]
	for bone_name: StringName in animated_bones:
		assert_true(skeleton.find_bone(bone_name) >= 0, "Dog needs an authored %s bone" % bone_name)
	var eye_left := model.find_child("EyeLeft", true, false) as Node3D
	var eye_right := model.find_child("EyeRight", true, false) as Node3D
	assert_true(eye_left != null, "Dog needs a visible left eye")
	assert_true(eye_right != null, "Dog needs a visible right eye")
	assert_true(eye_left.global_position.x < -0.40, "Dog eyes must sit on the head side of the body")
	assert_true(eye_right.global_position.x < -0.40, "Dog eyes must sit on the head side of the body")
	assert_true(
		model.find_child("NoseTip", true, false) != null,
		"Dog muzzle needs a dark nose detail"
	)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert_true(players.size() >= 1, "Dog needs imported skeletal animation")
	var player := players[0] as AnimationPlayer
	assert_true(
		player.has_animation(Models.IDLE_ANIMATION),
		"Idle must animate tail, head, and blinking eyes"
	)
	assert_true(
		player.has_animation(Models.WALK_ANIMATION),
		"Walk must animate all four legs and tail"
	)
	assert_true(
		player.has_animation(Models.TROT_ANIMATION),
		"Trot must give fast dogs a distinct gait"
	)
	assert_true(
		player.has_animation(Models.SNIFF_ANIMATION),
		"Paused dogs need a head-down sniff variation"
	)
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.062, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	assert_true(
		is_equal_approx(player.speed_scale, 1.0),
		"Walk tempo should match distance travelled"
	)
	Models.sync_animation(host, host.position - Vector3(0.14, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.TROT_ANIMATION)
	Models.sync_animation(host, host.position, Models.DOG_SNIFF_INTERVAL)
	assert_eq(player.current_animation, Models.SNIFF_ANIMATION)
	host.free()


func test_dog_clips_deform_legs_tail_and_head_between_key_poses() -> void:
	var host := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var model := Models.add_model(host, MammalSpecies.SPECIES_DOG)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_assert_bone_moves(player, skeleton, Models.WALK_ANIMATION, &"FrontLeftLeg", 0.0, 0.27)
	_assert_bone_moves(player, skeleton, Models.WALK_ANIMATION, &"BackRightLeg", 0.0, 0.27)
	_assert_bone_moves(player, skeleton, Models.IDLE_ANIMATION, &"Tail", 0.0, 0.30)
	_assert_bone_moves(player, skeleton, Models.SNIFF_ANIMATION, &"Neck", 0.0, 0.65)
	host.free()


func _assert_bone_moves(
	player: AnimationPlayer,
	skeleton: Skeleton3D,
	animation_name: StringName,
	bone_name: StringName,
	from_time: float,
	to_time: float
) -> void:
	var bone := skeleton.find_bone(bone_name)
	player.play(animation_name)
	player.seek(from_time, true)
	var pose_a := skeleton.get_bone_pose_rotation(bone)
	player.seek(to_time, true)
	var pose_b := skeleton.get_bone_pose_rotation(bone)
	assert_true(
		pose_a.angle_to(pose_b) > deg_to_rad(4.0),
		"%s must visibly move during %s" % [bone_name, animation_name]
	)
