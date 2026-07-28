extends "res://tests/godot/test_case.gd"

const BirdAssets := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

func test_selected_hendrik_reyneke_models_are_runtime_assets() -> void:
	for species: StringName in [MammalSpecies.SPECIES_CHICKEN, MammalSpecies.SPECIES_DUCK, &"goat"]:
		assert_true(Models.has_model(species), "%s must use the authored CC BY model" % species)
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null)
		assert_true(model.find_children("*", "MeshInstance3D", true, false).size() >= 1)
		host.free()

func test_hendrik_sparrow_is_used_for_the_house_sparrow_perched_pose() -> void:
	assert_true(BirdAssets.has_authored_pose(BirdSpecies.SPECIES_HOUSE_SPARROW, BirdSpecies.POSE_PERCHED))
	assert_true(BirdAssets.mesh_for_pose(BirdSpecies.SPECIES_HOUSE_SPARROW, BirdSpecies.POSE_PERCHED) != null)
