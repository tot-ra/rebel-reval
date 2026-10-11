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
	assert_eq(CityLeafFall.shed_weight(&"spruce", JAN, 0.9), 0.0, "winter conifers keep their needles")
	assert_eq(
		CityLeafFall.shed_weight(&"pine", JUL, 0.9), 0.0, "city leaf particles are deciduous-only"
	)


## Real crowns drop a few tenths of a leaf per second in calm air and a few in a
## gale; the emitter must not saturate into a leaf blizzard near a handful of trees.
func test_leaf_fall_rate_per_tree_is_realistic() -> void:
	var per_weight := CityLeafFall.LEAVES_PER_SECOND_PER_WEIGHT
	var calm := CityLeafFall.shed_weight(&"birch", OCT, 0.2) * per_weight
	var gale := CityLeafFall.shed_weight(&"birch", OCT, 1.0) * per_weight
	print("birch Oct 20 leaves/s per tree: calm %.2f, gale %.2f" % [calm, gale])
	assert_true(calm > 0.05 and calm < 1.0, "calm October tree: a trickle, got %.2f/s" % calm)
	assert_true(gale < 3.0, "a gale strips leaves but not as a blizzard, got %.2f/s" % gale)


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


func test_moat_floaters_are_textured_cut_outs() -> void:
	var root := Node3D.new()
	var xf: Array[Transform3D] = [Transform3D.IDENTITY]
	var colors: Array[Color] = [Color.WHITE]
	CityMoatPlants._add_floating(
		root,
		"LilyPads",
		CityMoatPlants._pad_mesh(),
		xf,
		colors,
		CityMoatPlants.PAD_TINT,
		CityMoatPlants.PAD_TEXTURE
	)
	CityMoatPlants._add_reeds(root, xf, colors)
	var pad_mat := (root.get_node("LilyPads") as MultiMeshInstance3D).material_override
	assert_eq(pad_mat.albedo_texture, CityMoatPlants.PAD_TEXTURE)
	assert_eq(pad_mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	var reed_mat := (root.get_node("Reeds") as MultiMeshInstance3D).material_override
	assert_eq(reed_mat.albedo_texture, CityMoatPlants.BLADE_TEXTURE)
	assert_false(pad_mat.texture_repeat, "the pad UV overshoot must clamp, not wrap")
	# The pad UVs cover the photo (overshooting by about 1 %) so the scissor,
	# not the 16-gon, draws the leaf outline.
	var uvs: PackedVector2Array = CityMoatPlants._pad_mesh().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	for uv in uvs:
		assert_true(uv.x >= -0.01 and uv.x <= 1.01 and uv.y >= -0.01 and uv.y <= 1.01)
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
		if CitySnow.patch(Vector2(i * 7.3, i * 3.1), 0.2) > CitySnow.LYING:
			covered += 1
	assert_true(covered > 10 and covered < 190, "thin cover is patchy, got %d/200" % covered)


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


func test_snow_depth_grows_with_cover_and_drifts() -> void:
	var spot := Vector2(123.4, -56.7)
	assert_eq(CitySnow.depth_at(spot, 0.0), 0.0)
	assert_true(CitySnow.depth_at(spot, 1.0) > CitySnow.depth_at(spot, 0.5))
	var lo := INF
	var hi := 0.0
	for i in 300:
		var d := CitySnow.depth_at(Vector2(i * 13.7, i * 5.3), 1.0)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	assert_true(hi > 0.5, "drifts pile past half a metre at full cover, got %.2f" % hi)
	assert_true(hi - lo > 0.3, "depth varies a lot across the country")


func test_walking_slows_by_snow_depth() -> void:
	assert_eq(CitySnow.walk_drag(0.0), 1.0)
	assert_eq(CitySnow.walk_drag(CitySnow.DRAG_START), 1.0, "a dusting is free")
	var knee := CitySnow.walk_drag(CitySnow.DRAG_KNEE)
	assert_almost_eq(knee, CitySnow.DRAG_KNEE_SPEED, 0.001)
	assert_true(CitySnow.walk_drag(0.2) > knee, "shallower is faster")
	assert_true(CitySnow.walk_drag(0.7) < 0.1, "past half a metre you barely move")


func test_snow_map_is_bare_on_paving_and_deeper_in_woods() -> void:
	var plan := CityPlan.load_default()
	var trees: Array = plan.data.get("trees", [])
	CitySnow.bake(plan, func(_p: Vector2) -> Color: return Color(0, 1, 0, 0), trees, [])
	var open_total := 0.0
	var samples := 0
	var wood_total := 0.0
	var wood_samples := 0
	for t: Array in trees.slice(0, 400):
		var at := Vector2(float(t[0]), float(t[1]))
		if plan.building_at(at) >= 0 or plan.ground_height(at) < 0.4:
			continue
		wood_total += CitySnow.factor_at(at)
		wood_samples += 1
	for i in 400:
		var at := plan.bounds.position + Vector2(fmod(i * 97.3, 1500.0), fmod(i * 61.1, 1500.0))
		if plan.building_at(at) >= 0 or plan.ground_height(at) < 0.4:
			continue
		open_total += CitySnow.factor_at(at)
		samples += 1
	assert_true(wood_samples > 20 and samples > 20)
	var woods := wood_total / float(wood_samples)
	var open := open_total / float(samples)
	assert_true(woods > open * 0.9, "woods hold at least as much snow: %.2f vs %.2f" % [woods, open])
	CitySnow.bake(plan, func(_p: Vector2) -> Color: return Color(1, 0, 0, 0), trees, [])
	var paved_max := 0.0
	for i in 200:
		paved_max = maxf(paved_max, CitySnow.factor_at(plan.bounds.position + Vector2(i * 7.1, i * 7.9)))
	assert_true(paved_max < 0.15, "paving stays clear, got %.2f" % paved_max)
	CitySnow.clear_map()


## The 8 m depth map bled snow through walls and lifted the ground above interior
## floors; the 1 m shelter mask must keep every enterable house and site room dry.
func test_snow_never_lies_indoors() -> void:
	var plan := CityPlan.load_default()
	var turf := func(_p: Vector2) -> Color: return Color(0, 1, 0, 0)
	CitySnow.bake(plan, turf, plan.data.get("trees", []), [])
	var polygons: Array[PackedVector2Array] = []
	for i in plan.buildings.size():
		if bool(plan.buildings[i].get("enterable", false)):
			polygons.append(plan.footprint(i))
	for site in plan.sites:
		for room: Dictionary in site.rooms:
			polygons.append(room["polygon"])
	assert_true(polygons.size() > 50)
	var checked := 0
	var snowy := 0
	for ring in polygons:
		var box := Rect2(ring[0], Vector2.ZERO)
		for q in ring:
			box = box.expand(q)
		for y in range(int(box.position.y), int(box.end.y) + 1, 2):
			for x in range(int(box.position.x), int(box.end.x) + 1, 2):
				var p := Vector2(x, y)
				if not Geometry2D.is_point_in_polygon(p, ring):
					continue
				checked += 1
				if CitySnow.depth_at(p, 1.0) > 0.0:
					snowy += 1
	assert_true(checked > 1000, "sampled %d interior points" % checked)
	assert_eq(snowy, 0, "interior points under snow")
	CitySnow.clear_map()
