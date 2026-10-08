extends "res://tests/godot/test_case.gd"

## VEGR-4: grass is real blade geometry in two tiers, ground plates carry no plants.


func test_blade_clump_is_cached_curved_and_rooted() -> void:
	var mesh := MapViewMeshBuilderPrimitives.grass_blade_clump_mesh()
	assert_true(mesh == MapViewMeshBuilderPrimitives.grass_blade_clump_mesh(), "clump mesh is cached")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(vertices.size() / 3, 30, "six blades of five triangles")
	var top := 0.0
	var bent := false
	for i in vertices.size():
		top = maxf(top, vertices[i].y)
		if uvs[i].y == 0.0:
			assert_true(absf(vertices[i].y) < 0.00001, "wind weight zero must be the planted root")
		elif uvs[i].y >= 0.99:
			bent = bent or Vector2(vertices[i].x, vertices[i].z).length() > 0.05
	assert_true(top > 0.25 and top < 0.55, "blades stand 0.25-0.55 m tall")
	assert_true(bent, "blade tips bow away from the clump centre")
	for tag: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
		assert_eq(tag, Vector2.ZERO, "blades use the procedural, atlas-free shader path")


func test_blade_tiers_cross_fade() -> void:
	var near := MapViewMaterials.grass_blade_tier(true)
	var mid := MapViewMaterials.grass_blade_tier(false)
	assert_true(near != mid, "tiers use separate materials")
	assert_eq(float(near.get_shader_parameter("fade_in_end")), 0.0, "near tier is full size up close")
	var near_out := float(near.get_shader_parameter("fade_end"))
	var mid_in_start := float(mid.get_shader_parameter("fade_in_start"))
	var mid_in_end := float(mid.get_shader_parameter("fade_in_end"))
	var near_out_start := float(near.get_shader_parameter("fade_start"))
	assert_true(mid_in_start < near_out_start, "mid grows in before near fades")
	assert_true(mid_in_end <= near_out, "mid is full size by the time near has gone")
	assert_true(float(mid.get_shader_parameter("fade_end")) > 40.0, "mid tier reaches about 45 m")
	assert_true(near.get_shader_parameter("blade_atlas") != null, "shared shader still binds an atlas")


func test_far_tier_extends_range_and_hands_over_from_mid() -> void:
	var mid := MapViewMaterials.grass_blade_tier(false)
	var far := MapViewMaterials.grass_blade_far()
	assert_true(far != mid, "far tier has its own material")
	assert_true(
		float(far.get_shader_parameter("fade_in_start")) <= float(mid.get_shader_parameter("fade_start")),
		"far grows in before mid has gone"
	)
	assert_true(
		float(far.get_shader_parameter("fade_in_end")) >= float(mid.get_shader_parameter("fade_end")),
		"far is full size once mid has gone (no bare ring)"
	)
	var reach := float(far.get_shader_parameter("fade_end"))
	assert_true(reach > 100.0, "far tier reaches past 100 m")
	assert_true(
		reach <= CityGrass.FAR_CHUNK * CityGrass.FAR_RADIUS_CHUNKS,
		"far chunks cover the fade range in every direction"
	)


func test_ground_plates_are_plain() -> void:
	# The ground is a colour field: no plantain or flower may be baked into it.
	# Fine grain is small; a baked plant is a strong, large dark/bright blob.
	var path := "res://assets/materials/pbr/grass_ground/grass_ground_albedo_array.jpg"
	var image := Image.load_from_file(path)
	assert_true(image != null, "albedo array loads")
	var slice := image.get_width() / 4
	for index in 12:
		var tile := image.get_region(Rect2i((index % 4) * slice, (index / 4) * slice, slice, slice))
		var lo := 1.0
		var hi := 0.0
		for y in range(0, slice, 8):
			for x in range(0, slice, 8):
				var l := tile.get_pixel(x, y).get_luminance()
				lo = minf(lo, l)
				hi = maxf(hi, l)
		assert_true(hi - lo < 0.45, "plate %d stays low contrast (%.2f)" % [index, hi - lo])
