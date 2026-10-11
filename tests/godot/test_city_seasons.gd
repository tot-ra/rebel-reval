extends "res://tests/godot/test_case.gd"

## ADR 0045 city seasons: leaf fall by tree and wind, water plants and moat ice.

const OCT := {"day": 20, "month": 10, "year": 1343}
const JAN := {"day": 15, "month": 1, "year": 1343}
const JUL := {"day": 15, "month": 7, "year": 1343}


func _doy(date: Dictionary) -> float:
	return SeasonState.day_of_year_for(date)


func test_leaf_shedding_follows_leaves_and_wind() -> void:
	assert_eq(CityLeafFall.shed_weight(&"birch", JAN, 0.9), 0.0, "a bare tree sheds nothing")
	var calm := CityLeafFall.shed_weight(&"birch", OCT, 0.1)
	var windy := CityLeafFall.shed_weight(&"birch", OCT, 0.8)
	assert_true(calm > 0.0, "October crowns shed even in a lull")
	assert_true(windy > calm * 1.5, "a stiff wind strips more leaves")
	assert_eq(CityLeafFall.shed_weight(&"birch", JUL, 0.1), 0.0, "summer crowns hold fast")
	assert_true(CityLeafFall.shed_weight(&"birch", JUL, 0.9) > 0.0, "a gale shakes summer leaves")


func test_tree_lod_lists_trees_near_a_point() -> void:
	var lod := CityTreeLod.new()
	var far := MultiMesh.new()
	far.transform_format = MultiMesh.TRANSFORM_3D
	far.instance_count = 2
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3.ONE * 2.0), Vector3(10.0, 1.0, 10.0)),
		Transform3D(Basis.IDENTITY, Vector3(300.0, 0.0, 300.0)),
	]
	var colors: Array[Color] = [Color.WHITE, Color.WHITE]
	lod.register(&"birch", 1.0, far, transforms, colors, false)
	var near := lod.trees_near(Vector3(12.0, 0.0, 12.0), 20.0)
	assert_eq(near.size(), 1)
	assert_eq(near[0][0], &"birch")
	assert_almost_eq(float(near[0][2]), 2.0, 0.001, "scale rides along for crown size")
	lod.free()


func test_water_plants_die_back_with_the_cold() -> void:
	assert_true(SeasonState.reed_standing(_doy(JUL)) > 0.99)
	assert_almost_eq(SeasonState.reed_standing(_doy(JAN)), 0.0, 0.001)
	assert_true(SeasonState.water_plant_vigour(_doy(JUL)) > 0.99)
	assert_almost_eq(SeasonState.water_plant_vigour(_doy(JAN)), 0.0, 0.001)
	assert_true(SeasonState.reed_dead_share(_doy(OCT)) > 0.4, "autumn reeds are yellowing")
	assert_almost_eq(SeasonState.reed_dead_share(_doy(JUL)), 0.0, 0.001)
	# Lily flowers need warmer water than the pads.
	assert_true(SeasonState.lily_flower_share(_doy(JUL)) > 0.5)
	assert_almost_eq(SeasonState.lily_flower_share(_doy(OCT)), 0.0, 0.001)


func test_moat_plants_thin_out_in_winter() -> void:
	var root := Node3D.new()
	var xf: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 10:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(float(i), 0.0, 0.0)))
		colors.append(Color.WHITE)
	CityMoatPlants._add_reeds(root, xf, colors)
	CityMoatPlants.apply_season(root, _doy(JUL))
	var reeds := root.get_node("Reeds") as MultiMeshInstance3D
	assert_eq(reeds.multimesh.visible_instance_count, 10)
	assert_true(reeds.visible)
	CityMoatPlants.apply_season(root, _doy(JAN))
	assert_eq(reeds.multimesh.visible_instance_count, 0, "a hard winter leaves no reeds")
	assert_false(reeds.visible)
	root.free()


func test_moat_freezes_by_temperature() -> void:
	assert_almost_eq(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(JUL)), 0.0, 0.001)
	assert_true(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(JAN)) > 0.2)
	var feb := {"day": 15, "month": 2, "year": 1343}
	assert_true(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(feb)) > 0.5)


func test_snow_patches_follow_cover() -> void:
	var spot := Vector2(123.4, -56.7)
	assert_eq(CitySnow.patch(spot, 0.0), 0.0)
	assert_almost_eq(CitySnow.patch(spot, 1.0), 1.0, 0.001, "deep winter covers everything")
	assert_eq(CitySnow.patch(spot, 0.5), CitySnow.patch(spot, 0.5), "deterministic")
	var covered := 0
	for i in 200:
		if CitySnow.patch(Vector2(i * 7.3, i * 3.1), 0.45) > CitySnow.LYING:
			covered += 1
	assert_true(covered > 10 and covered < 190, "half cover is patchy, got %d/200" % covered)


func test_snow_takes_footprints_where_paving_would_not() -> void:
	var plan := CityPlan.load_default()
	var paved := func(_p: Vector2) -> Color: return Color(1, 0, 0, 0)
	var bare := CityGroundTrail.create(plan, paved)
	bare.update_for(Vector2(0, -400), 0.016)
	var snowy := CityGroundTrail.create(plan, paved)
	snowy.snow_cover = 1.0
	snowy.update_for(Vector2(0, -400), 0.016)
	var pos := Vector2(0, -400)
	for i in 80:
		pos += Vector2(0.25, 0.0)
		bare.update_for(pos, 0.016)
		snowy.update_for(pos, 0.016)
	var pressed_bare := 0
	var pressed_snow := 0
	var x := 0.0
	while x < 20.0:
		var at := Vector2(x, -400.0 + CityGroundTrail.FOOT_SPREAD)
		if bare.value_at(at) < 0.4:
			pressed_bare += 1
		if snowy.value_at(at) < 0.4:
			pressed_snow += 1
		x += CityGroundTrail.CELL
	assert_eq(pressed_bare, 0, "paving takes no print")
	assert_true(pressed_snow > 10, "snow takes prints, counted %d cells" % pressed_snow)
	bare.free()
	snowy.free()


func test_footsteps_in_snow_crunch() -> void:
	var plan := CityPlan.load_default()
	var sampler := CitySurfaceSampler.new(plan)
	var checked := 0
	var y := plan.bounds.position.y + plan.bounds.size.y * 0.3
	while y < plan.bounds.end.y and checked < 20:
		var x := plan.bounds.position.x
		while x < plan.bounds.end.x and checked < 20:
			var xz := Vector2(x, y)
			var foot := Vector3(xz.x, 0.0, xz.y)
			if (
				plan.ground_height(xz) > 3.0
				and plan.building_at(xz) < 0
				and plan.site_at(xz) == null
				and is_nan(plan.bridge_deck_height(xz))
				and sampler.ground_surface(xz) == SurfaceResolver.SURFACE_GRASS
			):
				checked += 1
				assert_eq(sampler.surface_at(foot, 0.0, 0.0, 0.0), SurfaceResolver.SURFACE_GRASS)
				assert_eq(sampler.surface_at(foot, 0.0, 0.0, 1.0), SurfaceResolver.SURFACE_SNOW)
			x += 9.7
		y += 9.7
	assert_true(checked > 5, "the scan must reach open turf")
	# Boards and flagstones are never snow.
	for kept: StringName in [SurfaceResolver.SURFACE_WOOD, SurfaceResolver.SURFACE_STONE]:
		assert_eq(SurfaceResolver.with_snow(kept, true), kept)
	assert_eq(
		SurfaceResolver.with_snow(SurfaceResolver.SURFACE_MUD, true), SurfaceResolver.SURFACE_SNOW
	)
