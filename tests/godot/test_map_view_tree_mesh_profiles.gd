extends "res://tests/godot/test_case.gd"


func test_profiles_cover_every_catalog_species() -> void:
	for species in MapViewTreeSpecies.ALL_SPECIES:
		var profile := MapViewTreeMeshProfiles.profile_for(species)
		assert_true(float(profile.get("trunk_height", 0.0)) > 0.0, "%s needs trunk height" % species)
		assert_true(int(profile.get("leaf_sprays", 0)) > 0, "%s needs leaf sprays" % species)
