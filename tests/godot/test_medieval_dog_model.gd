extends "res://tests/godot/test_case.gd"

## Smoke contract for the P0-209 street dog production GLB loaded through the
## shared livestock registry.

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")


func test_storybook_dog_loads_with_grounded_pbr_and_locomotion_clips() -> void:
	assert_true(Models.has_model(MammalSpecies.SPECIES_DOG))
	var host := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var model := Models.add_model(host, MammalSpecies.SPECIES_DOG)
	assert_true(model != null, "Dog needs an imported production model")
	assert_true(model.get_meta(&"production_animal_model", false))
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 1, "Dog needs render geometry")
	var mesh := meshes[0] as MeshInstance3D
	var material := mesh.mesh.surface_get_material(0)
	assert_true(material is StandardMaterial3D, "Dog must import as StandardMaterial3D")
	var std := material as StandardMaterial3D
	assert_ne(
		std.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Dog must react to scene lighting"
	)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	assert_true(skeletons.size() >= 1, "Dog needs an imported skeleton")
	var player := host.get_meta(Models.ANIMATION_PLAYER_META) as AnimationPlayer
	assert_false(Models._clip_name(player, Models.IDLE_ANIMATION).is_empty())
	assert_false(Models._clip_name(player, Models.WALK_ANIMATION).is_empty())
	assert_false(Models._clip_name(player, Models.TROT_ANIMATION).is_empty())
	Models.sync_animation(host, host.position - Vector3(0.08, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models._clip_name(player, Models.WALK_ANIMATION))
	host.free()
