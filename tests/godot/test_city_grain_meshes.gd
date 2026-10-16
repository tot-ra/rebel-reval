extends "res://tests/godot/test_case.gd"

## Cereal clumps of the strip fields (R-2112, docs/SYSTEMS/FARMLAND.md): budgets,
## per-crop silhouettes, calendar stages and the near / mid tiers round the player.

const GrainMeshes := preload("res://scripts/city/city_grain_meshes.gd")


func test_every_model_is_cached_rooted_and_within_budget() -> void:
	for crop in GrainMeshes.ALL_CROPS:
		for stage in GrainMeshes.ALL_STAGES:
			for far: bool in [false, true]:
				var mesh := GrainMeshes.mesh_for(crop, stage, far)
				assert_true(mesh == GrainMeshes.mesh_for(crop, stage, far), "%s %s cached" % [crop, stage])
				var tris := GrainMeshes.triangle_count(crop, stage, far)
				var cap := GrainMeshes.FAR_TRI_BUDGET if far else GrainMeshes.NEAR_TRI_BUDGET
				assert_true(tris > 0 and tris <= cap, "%s %s far=%s: %d tris <= %d" % [crop, stage, far, tris, cap])  # gdlint: ignore=max-line-length
				var box := mesh.get_aabb()
				assert_true(box.position.y >= 0.0 and box.position.y < 0.01, "%s %s stands on the ground" % [crop, stage])  # gdlint: ignore=max-line-length
				assert_true(box.size.x < 0.6 and box.size.z < 0.6, "%s %s is one clump" % [crop, stage])


func test_far_models_are_much_lighter() -> void:
	for crop in GrainMeshes.ALL_CROPS:
		for stage in GrainMeshes.ALL_STAGES:
			var near := GrainMeshes.triangle_count(crop, stage, false)
			var far := GrainMeshes.triangle_count(crop, stage, true)
			assert_true(far * 3 <= near, "%s %s far %d vs near %d" % [crop, stage, far, near])


func test_crops_have_distinct_silhouettes() -> void:
	var sig := {}
	for crop in GrainMeshes.ALL_CROPS:
		sig[crop] = _signature(crop)
	# Height order of medieval landraces: rye tallest, barley shortest.
	assert_true(sig[&"rye"].x > sig[&"wheat"].x + 0.2, "rye stands above wheat")
	assert_true(sig[&"oat"].x > sig[&"barley"].x + 0.1, "oat above barley")
	assert_true(sig[&"wheat"].x > sig[&"barley"].x + 0.2, "wheat above barley")
	# Ripe barley hangs its head: its ears drop between heading and harvest,
	# wheat holds a compact ear upright.
	assert_true(sig[&"barley"].z > 0.03, "ripe barley nods: %s" % sig[&"barley"])
	assert_true(sig[&"wheat"].z < 0.01, "ripe wheat stays upright: %s" % sig[&"wheat"])
	# Oat panicle and the bearded ears carry more ear parts than beardless wheat.
	assert_true(sig[&"oat"].y > sig[&"wheat"].y, "oat panicle: %s vs %s" % [sig[&"oat"], sig[&"wheat"]])  # gdlint: ignore=max-line-length
	assert_true(sig[&"barley"].y > sig[&"wheat"].y, "barley awns: %s vs %s" % [sig[&"barley"], sig[&"wheat"]])  # gdlint: ignore=max-line-length
	for a in GrainMeshes.ALL_CROPS:
		for b in GrainMeshes.ALL_CROPS:
			if String(a) < String(b):
				assert_true((sig[a] as Vector3).distance_to(sig[b]) > 0.05, "%s and %s differ" % [a, b])


func test_ears_carry_the_ear_weight_and_leafy_tufts_have_none() -> void:
	for crop in GrainMeshes.ALL_CROPS:
		var headed := _ear_share(GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_HEADED))
		assert_true(headed > 0.15, "%s headed has ears (%.2f)" % [crop, headed])
		assert_eq(_ear_share(GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_LEAFY)), 0.0, "%s leafy has no ears" % crop)  # gdlint: ignore=max-line-length
		var ripe := GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_RIPE).get_aabb()
		var stubble := GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_STUBBLE).get_aabb()
		assert_true(stubble.size.y < 0.25 and stubble.size.y < ripe.size.y * 0.3, "%s stubble is cut short" % crop)  # gdlint: ignore=max-line-length


func test_ripe_grain_is_gold_and_headed_is_green() -> void:
	for crop in GrainMeshes.ALL_CROPS:
		var green := _mean_ear_color(GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_HEADED))
		var gold := _mean_ear_color(GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_RIPE))
		assert_true(green.g > green.r, "%s green ears %s" % [crop, green])
		assert_true(gold.r > gold.b * 1.4 and gold.r >= gold.g * 0.95, "%s ripe ears %s" % [crop, gold])


func test_stages_follow_the_calendar() -> void:
	# 21 April: winter grain is leaf tufts, spring grain is not up yet.
	assert_eq(CityFarmland.grain_stage(&"winter", 111), GrainMeshes.STAGE_LEAFY)
	assert_eq(CityFarmland.grain_stage(&"winter", 180), GrainMeshes.STAGE_HEADED)
	assert_eq(CityFarmland.grain_stage(&"winter", 200), GrainMeshes.STAGE_RIPE)
	assert_eq(CityFarmland.grain_stage(&"winter", 230), GrainMeshes.STAGE_STUBBLE)
	assert_eq(CityFarmland.grain_stage(&"spring", 205), GrainMeshes.STAGE_RIPE)
	assert_eq(CityFarmland.grain_stage(&"spring", 250), GrainMeshes.STAGE_STUBBLE)


func test_field_cells_are_deterministic_and_far_is_half() -> void:
	var plan := CityPlan.load_default()
	var field := _field(plan, &"rye")
	var a := CityFarmland.grain_cells(plan, field, 200)
	var b := CityFarmland.grain_cells(plan, field, 200)
	var near := _count(a["near"])
	var far := _count(a["far"])
	assert_true(near > 500, "a strip holds hundreds of clumps (%d)" % near)
	assert_eq(near, _count(b["near"]), "deterministic")
	assert_true(absf(float(far) / float(near) - 0.5) < 0.05, "far tier keeps half (%d of %d)" % [far, near])  # gdlint: ignore=max-line-length
	for key: Vector2i in a["near"]:
		assert_eq((a["near"][key] as PackedFloat32Array), (b["near"][key] as PackedFloat32Array), "cell %s" % key)  # gdlint: ignore=max-line-length
		break
	assert_eq(_count(CityFarmland.grain_cells(plan, _field(plan, &"oat"), 100)["near"]), 0, "spring oats not sown in April")  # gdlint: ignore=max-line-length


func test_farmland_draws_detail_only_round_the_player() -> void:
	var plan := CityPlan.load_default()
	var field := _field(plan, &"rye")
	var farmland := CityFarmland.create(plan)
	farmland.set_calendar_date({"year": 1343, "month": 7, "day": 20})
	var centre: Vector2 = field["centre"]
	for i in 200:
		farmland.update_for(centre)
		if farmland.grain_instance_count(field["id"], false) > 0:
			break
	var near := farmland.grain_instance_count(field["id"], false)
	var far := farmland.grain_instance_count(field["id"], true)
	var total := _count(CityFarmland.grain_cells(plan, field, farmland.day_of_year)["near"])
	assert_true(near > 0 and near < total / 3, "near tier is a ring round the player (%d of %d)" % [near, total])  # gdlint: ignore=max-line-length
	assert_true(far > 0, "mid tier draws the rest within range (%d)" % far)
	var node := farmland.find_child("Crop_rye", true, false) as MultiMeshInstance3D
	assert_true(node != null, "near grain node named for the benchmark census")
	assert_eq(node.multimesh.mesh, GrainMeshes.mesh_for(&"rye", GrainMeshes.STAGE_RIPE), "ripe rye in July")  # gdlint: ignore=max-line-length
	farmland.free()


func _field(plan: CityPlan, crop: StringName) -> Dictionary:
	var best := {}
	for f in CityFarmland.features_for(plan):
		if f["kind"] == &"field" and f["crop"] == crop and f["sowing"] != &"fallow":
			if best.is_empty() or String(f["id"]) < String(best["id"]):
				best = f
	return best


func _count(cells: Dictionary) -> int:
	var n := 0
	for key: Vector2i in cells:
		n += (cells[key] as PackedFloat32Array).size() / CityFarmland.GRAIN_STRIDE
	return n


## (ripe height, share of ear vertices, how far the mean ear vertex drops from
## heading to ripeness). Stages share their seed, so the stalks are the same.
func _signature(crop: StringName) -> Vector3:
	var ripe := GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_RIPE)
	var headed := GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_HEADED)
	return Vector3(ripe.get_aabb().end.y, _ear_share(ripe), _mean_ear_y(headed) - _mean_ear_y(ripe))


func _mean_ear_y(mesh: ArrayMesh) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var sum := 0.0
	var n := 0
	for i in verts.size():
		if uvs[i].y > 0.5:
			sum += verts[i].y
			n += 1
	return sum / float(maxi(n, 1))


func _ear_share(mesh: ArrayMesh) -> float:
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var ears := 0
	for uv in uvs:
		if uv.y > 0.5:
			ears += 1
	return float(ears) / float(maxi(uvs.size(), 1))


func _mean_ear_color(mesh: ArrayMesh) -> Color:
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for i in colors.size():
		if uvs[i].y > 0.5:
			sum += colors[i]
			n += 1
	return sum / float(maxi(n, 1))
