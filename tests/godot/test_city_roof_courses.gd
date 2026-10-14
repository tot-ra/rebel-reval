extends "res://tests/godot/test_case.gd"

## R-1760: procedural roof courses, house details and per-house variety.
const Builder := preload("res://scripts/city/city_building_builder.gd")
const Details := preload("res://scripts/city/city_house_details.gd")
const ROOF := "res://scripts/city/city_weathered_roof.gdshader"
const RING := [Vector2(0, 0), Vector2(9, 0), Vector2(9, 7), Vector2(0, 7)]


func _house(id: String, material: String, roof: String) -> Dictionary:
	return {
		"id": id, "kind": "house", "material": material, "roof": roof,
		"base_h": 0.0, "wall_h": 4.5, "ridge_angle": 0.0, "roof_pitch_deg": 48.0,
		"door": [4.5, 0.0, -PI * 0.5],
	}


func _ring() -> PackedVector2Array:
	return Builder.normalized_ring(PackedVector2Array(RING))


func test_roof_shader_draws_courses_not_blotches() -> void:
	var code := FileAccess.get_file_as_string(ROOF)
	for fragment: String in [
		"vec3 shingles(", "vec3 boards(", "vec3 thatch(", "seed < board_share",
		"WOOD_SILVER", "eave_t", "GROWTH_ROOF_SPECIES",
	]:
		assert_true(code.contains(fragment), "roof shader keeps %s" % fragment)
	# R-1465: the thresholded metre-scale fbm that drew camouflage blotches.
	assert_false(code.contains("smoothstep(0.5, 0.78, patch"), "no thresholded moss blotches")
	assert_false(code.contains("texture(albedo_tex"), "no stretched roof plate")


func test_roof_materials_pick_cover() -> void:
	Builder.bind_ground(CityPlan.load_default())
	var thatch := Builder.roof_material(&"thatch") as ShaderMaterial
	var shingle := Builder.roof_material(&"shingle") as ShaderMaterial
	assert_eq(int(thatch.get_shader_parameter("cover")), 1)
	assert_eq(int(shingle.get_shader_parameter("cover")), 0)


func test_per_house_seed_tint_and_pitch() -> void:
	var a := _house("bldg.test.a", "log", "shingle")
	var b := _house("bldg.test.b", "log", "shingle")
	var rng := RandomNumberGenerator.new()
	var ta := Builder.roof_tint_for(a, rng)
	var tb := Builder.roof_tint_for(b, rng)
	assert_ne(ta.a, tb.a, "each house has its own wear seed")
	assert_true(ta.a >= 0.0 and ta.a <= 1.0)
	var pa := Builder.roof_pitch(a)
	assert_eq(pa, Builder.roof_pitch(a), "pitch jitter is deterministic")
	assert_true(absf(pa - 48.0) <= Builder.PITCH_JITTER + 0.001)
	var landmark := a.duplicate()
	landmark["landmark_id"] = "landmark.test"
	assert_eq(Builder.roof_pitch(landmark), 48.0, "landmarks keep the plan pitch")
	var site := a.duplicate()
	site["openings"] = false
	assert_eq(Builder.roof_pitch(site), 48.0, "site models keep the plan pitch")
	# Plan houses spread over several degrees, not one pitch per cover.
	var plan := CityPlan.load_default()
	var lo := INF
	var hi := -INF
	for house: Dictionary in plan.buildings:
		if String(house["roof"]) == "shingle" and String(house.get("landmark_id", "")) == "":
			lo = minf(lo, Builder.roof_pitch(house))
			hi = maxf(hi, Builder.roof_pitch(house))
	assert_true(hi - lo > 5.0, "shingle pitches spread %.1f..%.1f" % [lo, hi])


func test_roof_uv_bands_mark_ridge_and_edge() -> void:
	var built := Builder.build_building(_house("bldg.test.uv", "log", "shingle"), _ring(), 0.0, false)
	var surf: Builder.Surf = (built["roof"] as Builder.Shell).surface("roof:shingle")
	var field := 0
	var ridge := 0
	var edge := 0
	for uv in surf.uvs:
		if uv.y >= 0.0:
			field += 1
		elif uv.y <= -2.5:
			edge += 1
		elif uv.y <= -0.5:
			ridge += 1
	assert_true(
		field > 0 and ridge > 0 and edge > 0, "field %d ridge %d edge %d" % [field, ridge, edge]
	)
	var seed := surf.colors[0].a
	for c in surf.colors:
		assert_almost_eq(c.a, seed, 0.0001, "one wear seed per house roof")


func test_verge_boards_on_shingle_not_thatch() -> void:
	var shingle := Builder.build_building(
		_house("bldg.test.v1", "log", "shingle"), _ring(), 0.0, false
	)
	var thatch := Builder.build_building(_house("bldg.test.v2", "log", "thatch"), _ring(), 0.0, false)
	var boards: Builder.Surf = (shingle["roof"] as Builder.Shell).surface("timber")
	# Two rakes per gable, two gables, four faces of two triangles each.
	assert_eq(boards.verts.size(), 4 * 8 * 3, "a verge board up each rake")
	assert_false((thatch["roof"] as Builder.Shell).surfaces.has("timber"), "thatch ends in its roll")


func test_quoins_only_on_limestone_and_plinth_everywhere() -> void:
	var ring := _ring()
	var stone_shell := Builder.Shell.new()
	var blocks := Details.quoins(stone_shell, ring, 0.3, 4.4)
	assert_eq(blocks, 4 * int(4.1 / Details.QUOIN_COURSE), "one block per course per corner")
	var stone := Builder.build_building(_house("bldg.test.q1", "limestone", "tile"), ring, 0.0, false)
	var log := Builder.build_building(_house("bldg.test.q2", "log", "thatch"), ring, 0.0, false)
	var stone_tris := (stone["shell"] as Builder.Shell).surface("stone").verts.size()
	var log_tris := (log["shell"] as Builder.Shell).surface("stone").verts.size()
	assert_true(log_tris > 0, "timber houses stand on fieldstone pads (R-1933 CityFooting)")
	assert_true(
		stone_tris > log_tris + 200,
		"limestone houses add quoins (%d vs %d)" % [stone_tris, log_tris]
	)
