extends "res://tests/godot/test_case.gd"

const BirdAssets := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

const EXPECTED_LARGEST_AXIS_M: Dictionary = {
	MammalSpecies.SPECIES_CHICKEN: 0.46,
	MammalSpecies.SPECIES_DUCK: 0.56,
	&"goat": 1.20,
}


func test_selected_hendrik_reyneke_models_are_runtime_assets() -> void:
	for species: StringName in EXPECTED_LARGEST_AXIS_M:
		assert_true(Models.has_model(species), "%s must use the authored CC BY model" % species)
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		assert_true(meshes.size() >= 1)
		var bounds := (meshes[0] as MeshInstance3D).get_aabb()
		for index in range(1, meshes.size()):
			bounds = bounds.merge((meshes[index] as MeshInstance3D).get_aabb())
		var largest_axis := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		assert_true(
			absf(largest_axis - float(EXPECTED_LARGEST_AXIS_M[species])) < 0.001,
			"%s must stay at authored metric scale, got %.3f m" % [species, largest_axis]
		)
		host.free()

func test_hendrik_sparrow_is_used_for_the_house_sparrow_perched_pose() -> void:
	assert_true(BirdAssets.has_authored_pose(BirdSpecies.SPECIES_HOUSE_SPARROW, BirdSpecies.POSE_PERCHED))
	assert_true(BirdAssets.mesh_for_pose(BirdSpecies.SPECIES_HOUSE_SPARROW, BirdSpecies.POSE_PERCHED) != null)
