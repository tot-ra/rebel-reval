extends "res://tests/godot/test_case.gd"


func test_cog_has_true_scale_parts_and_rudder() -> void:
	var cog := CogModel.build(FactionHeraldry.HANSEATIC, CogModel.SAIL_SET, true)
	for path in [
		"Hull",
		"Timber",
		"Ironwork",
		"Rigging",
		"Sail",
		"RudderPivot/Rudder/Blade",
		"RudderPivot/Rudder/Tiller"
	]:
		assert_true(cog.has_node(path), "cog needs %s" % path)
	assert_true(CogModel.rudder_of(cog) != null, "cog exposes its rudder for the helm")
	var box := (cog.get_node("Hull") as MeshInstance3D).get_aabb()
	# A 1343 trading cog is ~20-24 m over the stems and 6-8 m abeam, about 12 men long.
	assert_true(box.size.x > 17.0 and box.size.x < 26.0, "hull length in metres: %.1f" % box.size.x)
	assert_true(box.size.z > 5.5 and box.size.z < 9.0, "hull beam in metres: %.1f" % box.size.z)
	cog.free()


func test_furled_cog_has_no_sail_sheet_mesh() -> void:
	var cog := CogModel.build(FactionHeraldry.HANSEATIC, CogModel.SAIL_FURLED, false)
	assert_true(cog.has_node("FurledSail"), "sail is furled on the yard at anchor")
	assert_false(cog.has_node("Sail"), "no wind-filled sail at anchor")
	cog.free()


func test_decks_cabins_and_hold_are_walkable() -> void:
	var deck := CogModel.walk_height(5.0, 0.0)
	assert_true(absf(deck - CogModel.DECK_Y) < 0.01, "open deck at DECK_Y")
	assert_true(
		CogModel.walk_height(-0.5, 0.0) < CogModel.DECK_Y - 1.0, "hold well drops below the deck"
	)
	assert_true(is_nan(CogModel.walk_height(0.0, 6.0)), "nothing walkable beyond the hull")
	assert_true(is_nan(CogModel.walk_height(30.0, 0.0)), "nothing walkable past the stem")


func test_build_is_deterministic() -> void:
	var a := CogModel.build()
	var b := CogModel.build()
	var va: PackedVector3Array = (
		((a.get_node("Hull") as MeshInstance3D).mesh as ArrayMesh)
		. surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var vb: PackedVector3Array = (
		((b.get_node("Hull") as MeshInstance3D).mesh as ArrayMesh)
		. surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	assert_true(va == vb, "same cog every build")
	a.free()
	b.free()
