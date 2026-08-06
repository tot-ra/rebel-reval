extends "res://tests/godot/test_case.gd"

## Contract for the P2-024 street dog production GLB (medieval_dog.glb). The
## authored hound replaced the shared procedural silhouette, so the test pins
## its metric envelope, closed anatomy, rig, and locomotion clips.

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")


func test_dog_has_production_model_with_grounded_pbr_body() -> void:
	assert_true(Models.has_model(MammalSpecies.SPECIES_DOG), "Dog must use the authored production GLB")
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_DOG)
	assert_true(model != null, "Dog needs an imported production model")
	assert_true(model.get_meta(&"production_animal_model", false))
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null, "Dog needs AnimalMesh")
	assert_true(mesh.mesh.get_surface_count() == 1, "Dog body must remain one portable production surface")
	var material := mesh.mesh.surface_get_material(0)
	assert_true(material is StandardMaterial3D, "Dog must import as StandardMaterial3D")
	var std := material as StandardMaterial3D
	assert_ne(std.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "Dog must react to scene lighting")
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
	var model := Models.add_model(host, MammalSpecies.SPECIES_DOG)
	assert_true(model != null)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	assert_true(skeletons.size() >= 1, "Dog needs an imported skeleton")
	var skeleton := skeletons[0] as Skeleton3D
	for bone_name: StringName in [&"Neck", &"Tail", &"FrontLeftLeg", &"FrontRightLeg", &"BackLeftLeg", &"BackRightLeg"]:
		assert_true(skeleton.find_bone(bone_name) >= 0, "Dog needs an authored %s bone" % bone_name)
	var eye_left := model.find_child("EyeLeft", true, false) as Node3D
	var eye_right := model.find_child("EyeRight", true, false) as Node3D
	assert_true(eye_left != null, "Dog needs a visible left eye")
	assert_true(eye_right != null, "Dog needs a visible right eye")
	assert_true(eye_left.global_position.x < -0.40, "Dog eyes must sit on the head side of the body")
	assert_true(eye_right.global_position.x < -0.40, "Dog eyes must sit on the head side of the body")
	assert_true(model.find_child("NoseTip", true, false) != null, "Dog muzzle needs a dark nose detail")
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert_true(players.size() >= 1, "Dog needs imported skeletal animation")
	var player := players[0] as AnimationPlayer
	assert_true(player.has_animation(Models.IDLE_ANIMATION), "Idle must animate tail, head, and blinking eyes")
	assert_true(player.has_animation(Models.WALK_ANIMATION), "Walk must animate legs and tail")
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	host.free()
