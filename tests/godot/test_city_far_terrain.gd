extends "res://tests/godot/test_case.gd"

## FarTerrain must never draw near the camera (docs/SYSTEMS/SEAMLESS_CITY.md):
## its coarse chords stood above concave beach faces as straight slabs through
## the swash wherever the camera was far from the plan centre.

const Builder := preload("res://scripts/city/city_terrain_builder.gd")
const GROUND_SHADER := "res://scripts/city/city_ground.gdshader"


func test_far_mesh_is_marked_and_near_chunks_are_not() -> void:
	var plan := CityPlan.load_default()
	var far := Builder._chunk_mesh(plan, 0, 0, 24, 24, Builder.FAR_STEP, Builder.FAR_DROP, true)
	var near := Builder._chunk_mesh(plan, 0, 0, 24, 24, 1, 0.0)
	var colors: PackedColorArray = far.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_true(colors.size() > 0, "far mesh carries a colour array")
	for c in colors:
		assert_almost_eq(c.a, Builder.FAR_MARK, 0.001, "far mark alpha")
	assert_true(near.surface_get_arrays(0)[Mesh.ARRAY_COLOR] == null, "near chunks read white")
	assert_true(
		Builder.FAR_MARK > 0.5 and Builder.FAR_MARK < 0.9, "mark sits between relief and chunks"
	)


func test_far_cut_stays_inside_the_near_chunk_cover() -> void:
	var source := FileAccess.get_file_as_string(GROUND_SHADER)
	var found := RegEx.create_from_string("const float FAR_TERRAIN_CUT = ([0-9.]+);").search(source)
	assert_true(found != null, "ground shader declares the far cut")
	var cut := float(found.get_string(1))
	var half_chunk := float(Builder.CHUNK_CELLS) * 2.0 * sqrt(2.0) * 0.5
	var far_triangle := float(Builder.FAR_STEP) * 2.0 * sqrt(2.0)
	# A near chunk hides only past NEAR_RANGE to its centre; every pixel it drops
	# must still be drawn by an unsunk far triangle.
	assert_true(cut + far_triangle < Builder.NEAR_RANGE - half_chunk, "no hole between near and far")
	assert_true(source.contains("COLOR.a > 0.5 && COLOR.a < 0.9"), "vertex stage reads the far mark")


func test_far_mesh_has_no_visibility_range_on_a_small_site_plan() -> void:
	# A visibility range is measured to the mesh centre (the plan centre): on a 700 m
	# site the far mesh stayed hidden while chunks past NEAR_RANGE were culled, leaving
	# a sky-coloured hole in the middle distance. The shader's FAR_TERRAIN_CUT hides it
	# near the camera instead.
	var parent := Node3D.new()
	var terrain := Builder.build(CityPlan.load_site("harju"), parent)
	var far := terrain.get_node("FarTerrain") as MeshInstance3D
	assert_almost_eq(far.visibility_range_begin, 0.0, 0.001, "far mesh draws at any range")
	parent.free()
